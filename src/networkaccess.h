#ifndef NETWORKACCESS_H
#define NETWORKACCESS_H

#include <QAtomicInt>
#include <QCoreApplication>
#include <QList>
#include <QMetaObject>
#include <QMutex>
#include <QMutexLocker>
#include <QObject>
#include <QPointer>
#include <QNetworkAccessManager>
#include <QNetworkDiskCache>
#include <QNetworkRequest>
#include <QQmlNetworkAccessManagerFactory>
#include <QStandardPaths>
#include <QThread>

// Works around a Qt 5.6 bearer management problem on Sailfish OS:
// after an offline phase (e.g. flight mode) a QNetworkAccessManager can stay
// in the state "not accessible" even when the connection is back. Every
// request - QML Image, XMLHttpRequest, ArtComposer - then fails immediately
// with "Network access is disabled" until the app is restarted.
//
// Keeping the manager "accessible" is safe: when the device really is offline,
// requests still fail, just with a normal network error, which the app
// already handles ("Try again").
namespace NetworkAccess {

inline void keepAccessible(QNetworkAccessManager *manager)
{
    manager->setNetworkAccessible(QNetworkAccessManager::Accessible);
    QObject::connect(manager, &QNetworkAccessManager::networkAccessibleChanged, manager,
                     [manager](QNetworkAccessManager::NetworkAccessibility accessible) {
        if (accessible != QNetworkAccessManager::Accessible) {
            manager->setNetworkAccessible(QNetworkAccessManager::Accessible);
        }
    });
}

// --- Disk cache for images (station logos, album covers) ---
// Without it every logo and cover was downloaded again after each app start
// and in every size. Images are cached on disk and then taken from there
// without asking the server again ("PreferCache", also when the cached copy
// is older than the server's expiry): logos and covers practically never
// change, and this also makes them appear when offline. Failed downloads
// are not stored. API answers (XMLHttpRequest) are NOT cached here - they
// have their own 10-minute cache in PersistentState.
const qint64 QmlImageCacheBytes = 40 * 1024 * 1024;
const qint64 ComposerImageCacheBytes = 20 * 1024 * 1024;

inline QString imageCacheDirectory(const QString &name)
{
    return QStandardPaths::writableLocation(QStandardPaths::CacheLocation)
            + QStringLiteral("/images/") + name;
}

// All image caches of the app (QML image loader thread, ArtComposer), so
// that "Clear cache" in Settings can empty them. The caches live in
// different threads; clear() is a slot and is therefore called queued, in
// the cache's own thread.
inline QMutex &imageCacheMutex()
{
    static QMutex mutex;
    return mutex;
}

inline QList<QPointer<QNetworkDiskCache> > &imageCaches()
{
    static QList<QPointer<QNetworkDiskCache> > caches;
    return caches;
}

inline void registerImageCache(QNetworkDiskCache *cache)
{
    QMutexLocker locker(&imageCacheMutex());
    imageCaches().append(QPointer<QNetworkDiskCache>(cache));
}

inline void clearImageCaches()
{
    QMutexLocker locker(&imageCacheMutex());
    for (int i = 0; i < imageCaches().size(); ++i) {
        QNetworkDiskCache *cache = imageCaches().at(i).data();
        if (cache) {
            QMetaObject::invokeMethod(cache, "clear", Qt::QueuedConnection);
        }
    }
}

// Network manager that serves GET requests from its disk cache if possible
class ImageCachingManager : public QNetworkAccessManager
{
public:
    ImageCachingManager(const QString &cacheName, qint64 maxBytes, QObject *parent = nullptr)
        : QNetworkAccessManager(parent)
    {
        QNetworkDiskCache *cache = new QNetworkDiskCache(this);
        cache->setCacheDirectory(imageCacheDirectory(cacheName));
        cache->setMaximumCacheSize(maxBytes);
        setCache(cache);   // the manager takes ownership
        registerImageCache(cache);
    }

protected:
    QNetworkReply *createRequest(Operation op, const QNetworkRequest &request,
                                 QIODevice *outgoingData) override
    {
        if (op == GetOperation) {
            QNetworkRequest cachedRequest(request);
            cachedRequest.setAttribute(QNetworkRequest::CacheLoadControlAttribute,
                                       QNetworkRequest::PreferCache);
            return QNetworkAccessManager::createRequest(op, cachedRequest, outgoingData);
        }
        return QNetworkAccessManager::createRequest(op, request, outgoingData);
    }
};

// Creates the network managers the QML engine uses. The engine asks for one
// manager per thread: the main thread's manager handles XMLHttpRequest (API,
// iTunes search - no disk cache), the image loader thread's manager loads
// every network image of QML Image elements (disk cache). Only the first
// non-main manager gets the cache, so no two caches share a directory.
class Factory : public QQmlNetworkAccessManagerFactory
{
public:
    QNetworkAccessManager *create(QObject *parent) override
    {
        QNetworkAccessManager *manager = nullptr;
        bool mainThread = QCoreApplication::instance()
                && QThread::currentThread() == QCoreApplication::instance()->thread();
        if (!mainThread && m_imageManagers.fetchAndAddOrdered(1) == 0) {
            manager = new ImageCachingManager(QStringLiteral("qml"), QmlImageCacheBytes, parent);
        } else {
            manager = new QNetworkAccessManager(parent);
        }
        keepAccessible(manager);
        return manager;
    }

private:
    QAtomicInt m_imageManagers;
};

// Available in QML as "imageCache" (context property, see main):
// imageCache.clear() empties all image caches on disk. Images already shown
// stay in the memory of the running app until it is restarted.
class ImageCacheControl : public QObject
{
    Q_OBJECT
public:
    explicit ImageCacheControl(QObject *parent = nullptr) : QObject(parent) {}

    Q_INVOKABLE void clear() { clearImageCaches(); }
};

} // namespace NetworkAccess

#endif // NETWORKACCESS_H
