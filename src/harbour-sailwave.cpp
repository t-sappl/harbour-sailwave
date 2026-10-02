#include <sailfishapp.h>
#include <QGuiApplication>
#include <QQuickView>
#include <QQmlContext>
#include <QQmlEngine>
#include <QtQml>

#include "artcomposer.h"
#include "filehelper.h"
#include "networkaccess.h"
#include "webdavclient.h"

int main(int argc, char *argv[])
{
    QScopedPointer<QGuiApplication> app(SailfishApp::application(argc, argv));

    // C++ helper for the lock screen cover art (see artcomposer.h).
    // Harbour requires private QML imports to start with the app name.
    qmlRegisterType<ArtComposer>("harbour.sailwave", 1, 0, "ArtComposer");

    // Declared before the view so they outlive the QML engine that uses them
    NetworkAccess::Factory networkFactory;
    NetworkAccess::ImageCacheControl imageCacheControl;
    // Favourites backup / M3U export (files) and WebDAV sync (see I3-I5)
    FileHelper fileHelper;
    WebDavClient webDav;

    QScopedPointer<QQuickView> view(SailfishApp::createView());

    // Must be set before any QML is loaded (see networkaccess.h)
    view->engine()->setNetworkAccessManagerFactory(&networkFactory);
    // "Clear cache" in Settings also empties the image caches
    view->rootContext()->setContextProperty(QStringLiteral("imageCache"), &imageCacheControl);
    view->rootContext()->setContextProperty(QStringLiteral("fileHelper"), &fileHelper);
    view->rootContext()->setContextProperty(QStringLiteral("webDav"), &webDav);

    view->setSource(SailfishApp::pathTo("qml/harbour-sailwave.qml"));
    view->show();

    return app->exec();
}
