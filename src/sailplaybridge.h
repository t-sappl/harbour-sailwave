// SPDX-License-Identifier: GPL-3.0-or-later
#ifndef SAILPLAYBRIDGE_H
#define SAILPLAYBRIDGE_H

#include <QHash>
#include <QObject>
#include <QTimer>
#include <QVariantMap>

class SailplayProvider;

// Sailwave in the car with Sailplay (wireless CarPlay / Android Auto, see
// sailplay-sdk/README.md). Sailplay's car screen shows the player through
// MPRIS as for any music app; with the SDK it can also browse Sailwave's
// stations (Favorites with their groups, Station history, a search in
// both) and start one.
//
// The stations live in QML (FavoritesStore, PersistentState), so QML hands
// them over whenever they change (setFavorites, setHistory); the bridge
// answers the car from that copy and gives a chosen station back to QML
// (playRequested -> appWindow.playStation). It exports the SDK objects on
// the session bus under Sailwave's D-Bus name harbour-sailwave.harbour-sailwave
// (OrganizationName.ApplicationName of the .desktop file, declared there
// with X-Sailplay-Service).
//
// Presentation hints (optional, Sailplay's Content1 "presentation", read
// only by a car screen that knows them): the root page is a tab bar,
// stations are shown as cards with their logo (the favicon from
// radio-browser.info), favourites with groups are split (groups on the
// left, the chosen group's stations on the right) and the station playing
// now is marked. An older car screen ignores them and shows the plain lists.
class SailplayBridge : public QObject
{
    Q_OBJECT

public:
    explicit SailplayBridge(QObject *parent = nullptr);
    ~SailplayBridge() override;

    // Exports the SDK objects (before the D-Bus name is registered)
    bool start();

    // Favourites in their order, each {url, name, groupId, country, codec,
    // bitrate, tags, ...} as in FavoritesStore; groups [{id, name}]
    Q_INVOKABLE void setFavorites(const QVariantList &favorites, const QVariantList &groups);
    // Recently played stations, newest first (PersistentState.getStationHistory)
    Q_INVOKABLE void setHistory(const QVariantList &stations);
    // What plays now (the SDK state "media")
    Q_INVOKABLE void setPlayback(const QString &stationName, const QString &title, bool playing);

    qulonglong catalogVersion() const { return m_version; }
    // The pages as the car gets them, for tests (no D-Bus)
    QVariantMap root() const;
    QVariantMap rootPresentation() const;
    // presentation: the hints of the returned page (may be null)
    QVariantMap query(const QVariantMap &parameters, bool search, QString *error = nullptr,
                      QVariantMap *presentation = nullptr) const;

signals:
    // A station chosen in the car, as the lists have it (for playStation)
    void playRequested(const QVariantMap &station);

private:
    static QString keyOf(const QString &url);
    QVariantMap stationItem(const QVariantMap &station) const;
    QVariantList folderItems(const QString &id, QString *title, QString *message, bool *found,
                             QString *layout) const;
    QVariantList searchItems(const QString &query) const;
    QVariantList favoritesOfGroup(int groupId) const;
    bool hasUngrouped() const;
    QVariantMap state() const;
    void changed();
    void publish();

    SailplayProvider *m_provider = nullptr;
    QTimer m_changeTimer;
    qulonglong m_version = 1;
    QVariantList m_favorites;
    QVariantList m_groups;
    QVariantList m_history;
    QHash<QString, QVariantMap> m_stations;   // key -> station
    QString m_stationName;
    QString m_title;
    bool m_playing = false;
};

#endif // SAILPLAYBRIDGE_H
