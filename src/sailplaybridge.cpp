// SPDX-License-Identifier: GPL-3.0-or-later
#include "sailplaybridge.h"

#include "sailplaycontent.h"
#include "sailplayprovider.h"

#include <QCryptographicHash>
#include <QDBusConnection>
#include <QSet>
#include <QVector>

namespace {

const QString RootId = QStringLiteral("root");
const QString FavoritesId = QStringLiteral("favorites");
const QString HistoryId = QStringLiteral("history");
const QString GroupPrefix = QStringLiteral("group/");
const QString StationPrefix = QStringLiteral("station/");
const QString PlayAction = QStringLiteral("sailwave.play");
const int OtherFavoritesGroup = 0;
const int MaxSearchRows = 100;

// Content1 text fields hold at most 1024 characters
QString bounded(const QString &text, int limit = 1024)
{
    QString t = text;
    t.replace(QChar::Null, QChar::Space);
    const QVector<uint> ucs4 = t.toUcs4();
    return ucs4.size() <= limit ? t : QString::fromUcs4(ucs4.constData(), limit);
}

// Lower case without accents, so "cafe" finds "Café" and "fm4" "FM4"
QString folded(const QString &text)
{
    const QString decomposed = text.toLower().normalized(QString::NormalizationForm_D);
    QString result;
    result.reserve(decomposed.size());
    for (const QChar c : decomposed) {
        if (c.category() != QChar::Mark_NonSpacing) {
            result.append(c);
        }
    }
    return result;
}

} // namespace

SailplayBridge::SailplayBridge(QObject *parent)
    : QObject(parent)
{
    // Restoring a backup changes the favourites many times in a row: one
    // new catalog version per half second at most
    m_changeTimer.setSingleShot(true);
    m_changeTimer.setInterval(500);
    connect(&m_changeTimer, &QTimer::timeout, this, [this]() {
        ++m_version;
        publish();
    });
}

SailplayBridge::~SailplayBridge()
{
    if (m_provider) {
        m_provider->close();
        delete m_provider;
    }
}

QString SailplayBridge::keyOf(const QString &url)
{
    // Row ids hold at most 256 characters, stream addresses can be longer
    return QString::fromLatin1(QCryptographicHash::hash(url.toUtf8(), QCryptographicHash::Sha1).toHex().left(20));
}

bool SailplayBridge::start()
{
    if (m_provider) {
        return true;
    }
    m_provider = new SailplayProvider(QDBusConnection::sessionBus(), QStringLiteral("harbour-sailwave-radio"),
                                      state(),
                                      QStringList() << QStringLiteral("media") << QStringLiteral("content"),
                                      this);
    const auto browse = [this](qulonglong invocation, const QVariantMap &parameters, bool search) {
        QString error;
        QVariantMap presentation;
        const QVariantMap page = query(parameters, search, &error, &presentation);
        if (page.isEmpty()) {
            m_provider->fail(invocation, QStringLiteral("NotFound"), error);
            return;
        }
        QVariantMap result{{QStringLiteral("content"), page}};
        if (!presentation.isEmpty()) {
            result.insert(QStringLiteral("presentation"), presentation);
        }
        m_provider->complete(invocation, result);
    };
    m_provider->setActionHandler(QStringLiteral("content.browse"),
        [browse](qulonglong invocation, const QVariantMap &parameters) { browse(invocation, parameters, false); });
    m_provider->setActionHandler(QStringLiteral("content.search"),
        [browse](qulonglong invocation, const QVariantMap &parameters) { browse(invocation, parameters, true); });
    m_provider->setActionHandler(PlayAction, [this](qulonglong invocation, const QVariantMap &parameters) {
        const QString key = parameters.value(QStringLiteral("key")).toString();
        if (!m_stations.contains(key)) {
            m_provider->fail(invocation, QStringLiteral("NotFound"), QStringLiteral("Station is no longer in the list"));
            return;
        }
        emit playRequested(m_stations.value(key));
        m_provider->complete(invocation, QVariantMap{{QStringLiteral("started"), true}});
    });
    if (!m_provider->start()) {
        qWarning("Sailwave: Sailplay SDK objects not exported");
        delete m_provider;
        m_provider = nullptr;
        return false;
    }
    return true;
}

void SailplayBridge::setFavorites(const QVariantList &favorites, const QVariantList &groups)
{
    m_favorites = favorites;
    m_groups = groups;
    changed();
}

void SailplayBridge::setHistory(const QVariantList &stations)
{
    m_history = stations;
    changed();
}

void SailplayBridge::setPlayback(const QString &stationName, const QString &title, bool playing)
{
    if (stationName == m_stationName && title == m_title && playing == m_playing) {
        return;
    }
    m_stationName = stationName;
    m_title = title;
    m_playing = playing;
    publish();
}

void SailplayBridge::changed()
{
    // Every station the car can show, by key (also for a choice made on a
    // page loaded before the change)
    QHash<QString, QVariantMap> stations;
    for (const QVariantList *list : {&m_history, &m_favorites}) {
        for (const QVariant &v : *list) {
            const QVariantMap s = v.toMap();
            const QString url = s.value(QStringLiteral("url")).toString();
            if (!url.isEmpty()) {
                stations.insert(keyOf(url), s);
            }
        }
    }
    m_stations = stations;
    if (m_provider) {
        m_changeTimer.start();
    } else {
        ++m_version;
    }
}

QVariantMap SailplayBridge::state() const
{
    // D-Bus needs a concrete type for every value, also before a station
    QVariantMap media;
    media.insert(QStringLiteral("station"), bounded(m_stationName));
    media.insert(QStringLiteral("title"), bounded(m_title));
    media.insert(QStringLiteral("playing"), m_playing);
    return QVariantMap{{QStringLiteral("media"), media}, {QStringLiteral("content"), root()},
                       {QStringLiteral("contentPresentation"), rootPresentation()}};
}

void SailplayBridge::publish()
{
    if (m_provider && !m_provider->publish(state())) {
        qWarning("Sailwave: Sailplay state not published");
    }
}

QVariantMap SailplayBridge::root() const
{
    QVariantMap page = SailplayContent::page(RootId, QStringLiteral("Sailwave"));
    page.insert(QStringLiteral("version"), m_version);
    page.insert(QStringLiteral("searchEnabled"), true);
    QVariantList items;
    items << SailplayContent::item(FavoritesId, tr("Favorites"))
          << SailplayContent::item(HistoryId, tr("Station history"));
    page.insert(QStringLiteral("items"), items);
    return page;
}

QVariantMap SailplayBridge::rootPresentation() const
{
    // Favorites and Station history as tabs
    return SailplayContent::presentation(QStringLiteral("list"), true);
}

QVariantMap SailplayBridge::query(const QVariantMap &parameters, bool search, QString *error,
                                  QVariantMap *presentation) const
{
    if (!SailplayContent::validQuery(parameters, search)) {
        if (error) *error = QStringLiteral("Invalid query");
        return QVariantMap();
    }
    const QString id = parameters.value(QStringLiteral("id")).toString();
    const uint offset = parameters.value(QStringLiteral("offset")).toUInt();
    const uint limit = parameters.value(QStringLiteral("limit")).toUInt();

    QString title;
    QString message;
    QString layout = QStringLiteral("list");
    QVariantList all;
    if (search) {
        title = tr("Search");
        all = searchItems(parameters.value(QStringLiteral("query")).toString());
        if (all.isEmpty()) {
            message = tr("No stations found");
        }
    } else if (id == RootId) {
        title = QStringLiteral("Sailwave");
        all = root().value(QStringLiteral("items")).toList();
    } else {
        bool found = false;
        all = folderItems(id, &title, &message, &found, &layout);
        if (!found) {
            if (error) *error = QStringLiteral("Content folder is unavailable");
            return QVariantMap();
        }
    }

    QVariantMap page = SailplayContent::page(id, bounded(title));
    page.insert(QStringLiteral("version"), m_version);
    page.insert(QStringLiteral("offset"), offset);
    page.insert(QStringLiteral("searchEnabled"), id == RootId);
    QVariantList items;
    if (offset < uint(all.size())) {
        items = all.mid(int(offset), int(limit));
    }
    page.insert(QStringLiteral("items"), items);
    page.insert(QStringLiteral("hasMore"), !items.isEmpty() && offset + uint(items.size()) < uint(all.size()));
    if (!message.isEmpty() && offset == 0) {
        page.insert(QStringLiteral("message"), bounded(message));
        page.insert(QStringLiteral("messageKind"), QStringLiteral("info"));
    }
    if (!SailplayContent::validPage(page)) {
        if (error) *error = QStringLiteral("Content page could not be built");
        return QVariantMap();
    }
    if (presentation) {
        *presentation = (!search && id == RootId) ? rootPresentation() : SailplayContent::presentation(layout);
        // Each station row: its logo, and "playing" for the station on air
        for (const QVariant &v : items) {
            const QVariantMap row = v.toMap();
            if (row.value(QStringLiteral("kind")).toString() != QStringLiteral("action")) continue;
            const QVariantMap station = m_stations.value(
                row.value(QStringLiteral("parameters")).toMap().value(QStringLiteral("key")).toString());
            const QString rowId = row.value(QStringLiteral("id")).toString();
            const QString name = station.value(QStringLiteral("name")).toString().trimmed();
            const QString playback = m_playing && !name.isEmpty() && name == m_stationName.trimmed()
                    ? QStringLiteral("playing") : QString();
            const QString logo = station.value(QStringLiteral("favicon")).toString().trimmed();
            // A logo address the car cannot use costs the logo, not the mark
            if (!SailplayContent::hint(*presentation, rowId, logo, playback)) {
                SailplayContent::hint(*presentation, rowId, QString(), playback);
            }
        }
    }
    return page;
}

QVariantList SailplayBridge::favoritesOfGroup(int groupId) const
{
    QVariantList result;
    for (const QVariant &v : m_favorites) {
        if (v.toMap().value(QStringLiteral("groupId")).toInt() == groupId) {
            result << v;
        }
    }
    return result;
}

bool SailplayBridge::hasUngrouped() const
{
    return !favoritesOfGroup(OtherFavoritesGroup).isEmpty();
}

QVariantList SailplayBridge::folderItems(const QString &id, QString *title, QString *message, bool *found,
                                         QString *layout) const
{
    QVariantList items;
    *found = true;
    // Stations as cards with their logo
    *layout = QStringLiteral("grid");
    if (id == FavoritesId) {
        *title = tr("Favorites");
        if (m_groups.isEmpty()) {
            for (const QVariant &v : m_favorites) {
                items << stationItem(v.toMap());
            }
        } else {
            // Groups on the left, the chosen group's stations on the right
            *layout = QStringLiteral("split");
            // As on the Favorites page: the groups, then "Other favorites"
            for (const QVariant &g : m_groups) {
                const QVariantMap group = g.toMap();
                const int groupId = group.value(QStringLiteral("id")).toInt();
                const int count = favoritesOfGroup(groupId).size();
                if (count == 0) continue;
                QString name = group.value(QStringLiteral("name")).toString();
                QVariantMap item = SailplayContent::item(GroupPrefix + QString::number(groupId),
                                                         bounded(name.isEmpty() ? tr("Group") : name));
                item.insert(QStringLiteral("subtitle"), tr("%n stations", nullptr, count));
                items << item;
            }
            if (hasUngrouped()) {
                QVariantMap item = SailplayContent::item(GroupPrefix + QString::number(OtherFavoritesGroup),
                                                         tr("Other favorites"));
                item.insert(QStringLiteral("subtitle"),
                            tr("%n stations", nullptr, favoritesOfGroup(OtherFavoritesGroup).size()));
                items << item;
            }
        }
        if (items.isEmpty()) *message = tr("No favorites yet");
    } else if (id.startsWith(GroupPrefix)) {
        bool ok = false;
        const int groupId = id.mid(GroupPrefix.size()).toInt(&ok);
        if (!ok) {
            *found = false;
            return items;
        }
        if (groupId == OtherFavoritesGroup) {
            *title = tr("Other favorites");
        } else {
            bool known = false;
            for (const QVariant &g : m_groups) {
                const QVariantMap group = g.toMap();
                if (group.value(QStringLiteral("id")).toInt() == groupId) {
                    *title = group.value(QStringLiteral("name")).toString();
                    known = true;
                }
            }
            if (!known) {
                *found = false;
                return items;
            }
        }
        for (const QVariant &v : favoritesOfGroup(groupId)) {
            items << stationItem(v.toMap());
        }
        if (items.isEmpty()) *message = tr("No favorites yet");
    } else if (id == HistoryId) {
        *title = tr("Station history");
        for (const QVariant &v : m_history) {
            items << stationItem(v.toMap());
        }
        if (items.isEmpty()) *message = tr("No station played yet");
    } else {
        *found = false;
    }
    return items;
}

QVariantList SailplayBridge::searchItems(const QString &query) const
{
    // Favourites first, then the station history; every word of the query
    // in the name, the country or the tags
    QVariantList items;
    const QStringList words = folded(query).split(QLatin1Char(' '), QString::SkipEmptyParts);
    if (words.isEmpty()) {
        return items;
    }
    QSet<QString> seen;
    for (const QVariantList *list : {&m_favorites, &m_history}) {
        for (const QVariant &v : *list) {
            const QVariantMap s = v.toMap();
            const QString url = s.value(QStringLiteral("url")).toString();
            if (url.isEmpty() || seen.contains(url)) continue;
            const QString haystack = folded(s.value(QStringLiteral("name")).toString() + QLatin1Char(' ')
                                            + s.value(QStringLiteral("country")).toString() + QLatin1Char(' ')
                                            + s.value(QStringLiteral("tags")).toString());
            bool all = true;
            for (const QString &w : words) {
                if (!haystack.contains(w)) {
                    all = false;
                    break;
                }
            }
            if (!all) continue;
            seen.insert(url);
            items << stationItem(s);
            if (items.size() >= MaxSearchRows) return items;
        }
    }
    return items;
}

QVariantMap SailplayBridge::stationItem(const QVariantMap &station) const
{
    const QString url = station.value(QStringLiteral("url")).toString();
    QVariantMap parameters;
    parameters.insert(QStringLiteral("key"), keyOf(url));
    const QString name = station.value(QStringLiteral("name")).toString().trimmed();
    QVariantMap item = SailplayContent::item(StationPrefix + keyOf(url),
                                             bounded(name.isEmpty() ? url : name),
                                             QStringLiteral("action"), PlayAction, parameters);
    // "Austria · MP3 128 kbps"
    QStringList parts;
    const QString country = station.value(QStringLiteral("country")).toString().trimmed();
    if (!country.isEmpty()) parts << country;
    QString format = station.value(QStringLiteral("codec")).toString().trimmed();
    const int bitrate = station.value(QStringLiteral("bitrate")).toInt();
    if (bitrate > 0) format = (format + QLatin1Char(' ') + tr("%1 kbps").arg(bitrate)).trimmed();
    if (!format.isEmpty()) parts << format;
    item.insert(QStringLiteral("subtitle"), bounded(parts.join(QStringLiteral(" · "))));
    return item;
}
