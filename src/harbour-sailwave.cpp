// SPDX-License-Identifier: GPL-3.0-or-later
#include <sailfishapp.h>
#include <QGuiApplication>
#include <QQuickView>
#include <QQmlContext>
#include <QQmlEngine>
#include <QtQml>
#include <QDBusConnection>
#include <QDBusError>
#include <QDebug>

#include "artcomposer.h"
#include "filehelper.h"
#include "networkaccess.h"
#include "nextcloudlogin.h"
#include "sailplaybridge.h"
#include "secretstore.h"
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
    // Nextcloud sign-in in the browser (Login Flow v2)
    NextcloudLogin nextcloudLogin;
    // WebDAV password in Sailfish Secrets instead of the app database
    SecretStore secretStore;
    // Sailwave in the car with Sailplay (see sailplaybridge.h); QML hands it
    // the favourites and the station history
    SailplayBridge sailplay;

    QScopedPointer<QQuickView> view(SailfishApp::createView());

    // Must be set before any QML is loaded (see networkaccess.h)
    view->engine()->setNetworkAccessManagerFactory(&networkFactory);
    // "Clear cache" in Settings also empties the image caches
    view->rootContext()->setContextProperty(QStringLiteral("imageCache"), &imageCacheControl);
    view->rootContext()->setContextProperty(QStringLiteral("fileHelper"), &fileHelper);
    view->rootContext()->setContextProperty(QStringLiteral("webDav"), &webDav);
    view->rootContext()->setContextProperty(QStringLiteral("nextcloudLogin"), &nextcloudLogin);
    view->rootContext()->setContextProperty(QStringLiteral("secretStore"), &secretStore);
    view->rootContext()->setContextProperty(QStringLiteral("sailplay"), &sailplay);

    view->setSource(SailfishApp::pathTo("qml/harbour-sailwave.qml"));

    // Sailplay: the SDK objects first, then the app's D-Bus name
    // (OrganizationName.ApplicationName of the .desktop file), so that a car
    // starting Sailwave over D-Bus (ExecDBus) opens its session as soon as
    // the name appears.
    sailplay.start();
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.registerService(QStringLiteral("harbour-sailwave.harbour-sailwave"))) {
        qWarning() << "D-Bus name not registered:" << bus.lastError().message();
    }
    view->show();

    return app->exec();
}
