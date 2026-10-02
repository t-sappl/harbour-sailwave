#include "webdavclient.h"

#include <QBuffer>

namespace {
const int TimeoutMs = 20000;
}

WebDavClient::WebDavClient(QObject *parent)
    : QObject(parent)
    , m_network(new QNetworkAccessManager(this))
{
    // Same Qt 5.6 workaround as everywhere (see networkaccess.h)
    NetworkAccess::keepAccessible(m_network);
}

void WebDavClient::request(int requestId, const QString &method, const QString &url,
                           const QString &user, const QString &password, const QString &body)
{
    QNetworkRequest req{QUrl(url)};
    // Basic authentication sent right away (no extra round trip)
    const QByteArray credentials = (user + QLatin1Char(':') + password).toUtf8().toBase64();
    req.setRawHeader("Authorization", "Basic " + credentials);
    req.setAttribute(QNetworkRequest::CacheLoadControlAttribute, QNetworkRequest::AlwaysNetwork);
    req.setAttribute(QNetworkRequest::FollowRedirectsAttribute, true);

    const QByteArray verb = method.toUtf8();
    QByteArray data;
    if (verb == "PUT") {
        data = body.toUtf8();
        req.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json; charset=utf-8"));
    } else if (verb == "PROPFIND") {
        req.setRawHeader("Depth", "0");
        req.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/xml; charset=utf-8"));
        data = QByteArrayLiteral("<?xml version=\"1.0\"?><d:propfind xmlns:d=\"DAV:\"><d:prop><d:getetag/></d:prop></d:propfind>");
    }

    QBuffer *buffer = new QBuffer;
    buffer->setData(data);
    buffer->open(QIODevice::ReadOnly);
    QNetworkReply *reply = m_network->sendCustomRequest(req, verb, buffer);
    buffer->setParent(reply);

    QTimer *timer = new QTimer(reply);
    timer->setSingleShot(true);
    connect(timer, &QTimer::timeout, reply, &QNetworkReply::abort);
    timer->start(TimeoutMs);

    connect(reply, &QNetworkReply::finished, this, [this, reply, requestId]() {
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        QString etag = QString::fromUtf8(reply->rawHeader("ETag"));
        if (etag.isEmpty()) {
            etag = QString::fromUtf8(reply->rawHeader("OC-ETag"));
        }
        etag.remove(QLatin1Char('"'));
        if (etag.startsWith(QLatin1String("W/"))) {
            etag = etag.mid(2);
        }
        const QString body = QString::fromUtf8(reply->readAll());
        const QString error = reply->error() == QNetworkReply::NoError ? QString() : reply->errorString();
        reply->deleteLater();
        emit finished(requestId, status, body, etag, error);
    });
}
