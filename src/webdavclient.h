#ifndef WEBDAVCLIENT_H
#define WEBDAVCLIENT_H

#include <QByteArray>
#include <QHash>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QObject>
#include <QTimer>
#include <QUrl>

#include "networkaccess.h"

// Minimal WebDAV client for the favourites sync (I4). The sync logic lives
// in QML (FavoritesBackup.qml); this class only sends single requests
// (HEAD, GET, PUT, MKCOL, PROPFIND) with basic authentication and reports
// the result. QML's XMLHttpRequest in Qt 5.6 does not reliably support
// all WebDAV methods, hence C++. Available in QML as "webDav".
class WebDavClient : public QObject
{
    Q_OBJECT
public:
    explicit WebDavClient(QObject *parent = nullptr);

    // Result arrives via finished() with the same requestId
    Q_INVOKABLE void request(int requestId, const QString &method, const QString &url,
                             const QString &user, const QString &password,
                             const QString &body = QString());

signals:
    // status: HTTP status (0 = no connection / timeout), etag: ETag of the
    // resource if the server sent one, error: text for the log
    void finished(int requestId, int status, const QString &body,
                  const QString &etag, const QString &error);

private:
    QNetworkAccessManager *m_network;
};

#endif // WEBDAVCLIENT_H
