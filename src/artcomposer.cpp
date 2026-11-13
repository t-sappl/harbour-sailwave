// SPDX-License-Identifier: GPL-3.0-or-later
#include "artcomposer.h"
#include "networkaccess.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QPainter>
#include <QPainterPath>
#include <QStandardPaths>
#include <QTimer>
#include <QUrl>
#include <QDebug>

namespace {
// Give up on a single download after this time
const int RequestTimeoutMs = 15000;
// Keep the last few images: the lock screen may still be reading the
// previous one while the new one is announced
const int FilesToKeep = 2;

QString artDirectory()
{
    return QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + QStringLiteral("/cover-art");
}
}

ArtComposer::ArtComposer(QObject *parent)
    : QObject(parent)
    // Own disk cache (separate directory from the QML image cache)
    , m_network(new NetworkAccess::ImageCachingManager(QStringLiteral("composer"),
                                                       NetworkAccess::ComposerImageCacheBytes, this))
    , m_imageSize(512)
    , m_jobId(0)
    , m_logoIndex(0)
    , m_albumDone(true)
    , m_logoDone(true)
{
    NetworkAccess::keepAccessible(m_network);

    // Unlike QML, C++ can create the folder and clean up files from earlier sessions
    QDir().mkpath(artDirectory());
    removeOldFiles();
}

void ArtComposer::setUserAgent(const QString &userAgent)
{
    if (m_userAgent != userAgent) {
        m_userAgent = userAgent;
        emit userAgentChanged();
    }
}

void ArtComposer::setImageSize(int size)
{
    if (size > 0 && m_imageSize != size) {
        m_imageSize = size;
        emit imageSizeChanged();
    }
}

void ArtComposer::compose(const QString &albumUrl, const QStringList &logoUrls, const QString &key)
{
    // A new job replaces the previous one; replies of older jobs are ignored
    ++m_jobId;
    m_key = key;
    m_logoUrls = logoUrls;
    m_logoIndex = 0;
    m_album = QImage();
    m_logo = QImage();
    m_albumDone = albumUrl.isEmpty();
    m_logoDone = logoUrls.isEmpty();

    if (!m_albumDone) {
        fetch(albumUrl, true);
    }
    if (!m_logoDone) {
        fetch(m_logoUrls.at(0), false);
    }
    finishIfReady();
}

void ArtComposer::fetch(const QString &url, bool isAlbum)
{
    QNetworkRequest request(QUrl(url, QUrl::TolerantMode));
    if (!m_userAgent.isEmpty()) {
        request.setHeader(QNetworkRequest::UserAgentHeader, m_userAgent);
    }
    // Favicon URLs often redirect (http -> https, www -> bare domain)
    request.setAttribute(QNetworkRequest::FollowRedirectsAttribute, true);
    // Some servers only deliver images when asked for them explicitly
    request.setRawHeader("Accept", "image/*,*/*;q=0.8");

    QNetworkReply *reply = m_network->get(request);
    reply->setProperty("jobId", m_jobId);
    reply->setProperty("isAlbum", isAlbum);
    reply->setProperty("sourceUrl", url);

    // QNetworkAccessManager has no timeout of its own in Qt 5.6
    QTimer::singleShot(RequestTimeoutMs, reply, SLOT(abort()));

    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        onReplyFinished(reply);
    });
}

void ArtComposer::onReplyFinished(QNetworkReply *reply)
{
    reply->deleteLater();

    if (reply->property("jobId").toULongLong() != m_jobId) {
        return; // belongs to an outdated job
    }

    const bool isAlbum = reply->property("isAlbum").toBool();
    const QString url = reply->property("sourceUrl").toString();

    QImage image;
    if (reply->error() == QNetworkReply::NoError) {
        const QByteArray data = reply->readAll();
        if (!image.loadFromData(data)) {
            // Downloaded, but Qt cannot decode it (e.g. .ico/.svg without plugin)
            qWarning() << "[ArtComposer] Unsupported image format:" << url
                       << "(" << data.size() << "bytes )";
        }
    } else {
        qWarning() << "[ArtComposer] Download failed:" << url << "-" << reply->errorString();
    }

    if (isAlbum) {
        m_album = image;
        m_albumDone = true;
    } else if (!image.isNull()) {
        m_logo = image;
        m_logoDone = true;
    } else {
        emit logoFailed(url);
        // Try the next logo candidate, if any
        ++m_logoIndex;
        if (m_logoIndex < m_logoUrls.size()) {
            fetch(m_logoUrls.at(m_logoIndex), false);
        } else {
            m_logoDone = true;
        }
    }

    finishIfReady();
}

void ArtComposer::finishIfReady()
{
    if (!m_albumDone || !m_logoDone) {
        return;
    }
    if (m_album.isNull() && m_logo.isNull()) {
        emit failed(m_key);
        return;
    }
    const QString path = save(render());
    if (path.isEmpty()) {
        emit failed(m_key);
    } else {
        emit composed(m_key, path);
    }
}

namespace {
// Station logo on a tile that works on every background (same rule as
// StationIcon.qml): a logo with transparent edges (or a wide one) gets a
// tile - light for dark and coloured logos, dark only for very bright
// logos (average brightness of the opaque pixels > 0.8). A logo that fills
// its square (opaque edges) is only clipped with rounded corners.
void drawLogoTile(QPainter &painter, const QRectF &rect, const QImage &logoIn)
{
    if (logoIn.isNull()) {
        return;
    }
    const QImage logo = logoIn.convertToFormat(QImage::Format_ARGB32);
    const int w = logo.width();
    const int h = logo.height();
    const bool wide = w > h * 1.05;
    const bool transparentEdge = qMin(qAlpha(logo.pixel(w / 2, 0)), qAlpha(logo.pixel(w / 2, h - 1))) < 153;
    const bool tile = wide || transparentEdge;

    const qreal radius = rect.width() * 0.2;
    QPainterPath path;
    path.addRoundedRect(rect, radius, radius);

    painter.save();
    painter.setPen(Qt::NoPen);
    // soft shadow (the tile also sits on album covers)
    painter.setBrush(QColor(0, 0, 0, 90));
    painter.drawRoundedRect(rect.translated(0, rect.width() * 0.02), radius, radius);
    painter.setClipPath(path);

    if (tile) {
        qreal sum = 0;
        int count = 0;
        for (int y = 0; y < h; y += qMax(1, h / 24)) {
            const QRgb *line = reinterpret_cast<const QRgb *>(logo.constScanLine(y));
            for (int x = 0; x < w; x += qMax(1, w / 24)) {
                if (qAlpha(line[x]) > 128) {
                    sum += (0.299 * qRed(line[x]) + 0.587 * qGreen(line[x]) + 0.114 * qBlue(line[x])) / 255.0;
                    ++count;
                }
            }
        }
        const qreal lum = count > 0 ? sum / count : 0.5;
        const bool darkTile = lum > 0.8;
        painter.setBrush(darkTile ? QColor(0x2b, 0x2b, 0x2b) : QColor(0xf2, 0xf2, 0xf2));
        painter.drawRoundedRect(rect, radius, radius);
        const qreal inset = rect.width() * 0.12;
        const QRectF area = rect.adjusted(inset, inset, -inset, -inset);
        const QImage fitted = logo.scaled(area.size().toSize(), Qt::KeepAspectRatio, Qt::SmoothTransformation);
        painter.drawImage(QPointF(area.center().x() - fitted.width() / 2.0,
                                  area.center().y() - fitted.height() / 2.0), fitted);
    } else {
        const QImage fitted = logo.scaled(rect.size().toSize(), Qt::KeepAspectRatio, Qt::SmoothTransformation);
        painter.drawImage(QPointF(rect.center().x() - fitted.width() / 2.0,
                                  rect.center().y() - fitted.height() / 2.0), fitted);
    }
    painter.restore();
}
}

QImage ArtComposer::render() const
{
    const int size = m_imageSize;
    QImage canvas(size, size, QImage::Format_ARGB32_Premultiplied);
    canvas.fill(Qt::transparent);

    QPainter painter(&canvas);
    painter.setRenderHint(QPainter::Antialiasing);
    painter.setRenderHint(QPainter::SmoothPixmapTransform);

    if (!m_album.isNull()) {
        // Album cover fills the square (cropped to the centre if not square)
        const QImage scaled = m_album.scaled(size, size, Qt::KeepAspectRatioByExpanding,
                                             Qt::SmoothTransformation);
        painter.drawImage(0, 0, scaled, (scaled.width() - size) / 2, (scaled.height() - size) / 2,
                          size, size);

        if (!m_logo.isNull()) {
            // Station logo on a tile in the bottom right
            const qreal badge = size * 0.32;
            const qreal margin = size * 0.04;
            drawLogoTile(painter, QRectF(size - badge - margin, size - badge - margin, badge, badge), m_logo);
        }
    } else {
        // Station logo alone, centred and as large as possible
        const qreal side = size * 0.8;
        drawLogoTile(painter, QRectF((size - side) / 2, (size - side) / 2, side, side), m_logo);
    }

    painter.end();
    return canvas;
}

QString ArtComposer::save(const QImage &image)
{
    const QString dir = artDirectory();
    QDir().mkpath(dir);

    // A new file name for every image: the lock screen does not reload a file
    // whose name it already knows
    const QString path = dir + QStringLiteral("/art-")
            + QString::number(QDateTime::currentMSecsSinceEpoch()) + QStringLiteral(".png");
    if (!image.save(path, "PNG")) {
        qWarning() << "[ArtComposer] Could not save" << path;
        return QString();
    }

    m_writtenFiles.append(path);
    while (m_writtenFiles.size() > FilesToKeep) {
        QFile::remove(m_writtenFiles.takeFirst());
    }
    return path;
}

void ArtComposer::removeOldFiles()
{
    QDir dir(artDirectory());
    const QStringList files = dir.entryList(QStringList() << QStringLiteral("art-*.png"), QDir::Files);
    for (const QString &file : files) {
        dir.remove(file);
    }
}
