// SPDX-License-Identifier: GPL-3.0-or-later
import QtQuick 2.6
import Sailfish.Silica 1.0
import "../"

// Settings -> Backup and sync: the automatic backup on this device, "Back up
// now" / "Back up and share" / "Restore", and the WebDAV server for backups
// and automatic sync between devices. (The same functions are still in the
// pulley of "Manage favorites".)
Page {
    id: settingsPage
    objectName: "settingsBackupPage"

    // WebDAV connection test
    property bool webdavTesting: false
    property string webdavStatus: ""

    // Times of the last backups, re-read when the page is shown and after
    // "Back up now" (reading the files is cheap, there are at most a few)
    property int refreshCount: 0
    property double lastState: 0
    property double lastFile: 0

    function refresh() {
        lastState = appWindow.favoritesBackup.lastStateTime()
        lastFile = appWindow.favoritesBackup.lastManualTime()
        refreshCount++
    }

    function dateText(ms) {
        return ms > 0 ? Qt.formatDateTime(new Date(ms), Qt.DefaultLocaleShortDate) : qsTr("never")
    }

    onStatusChanged: if (status === PageStatus.Activating) refresh()

    // Nextcloud sign-in in the browser (Login Flow v2)
    Connections {
        target: nextcloudLogin
        onLoginUrl: Qt.openUrlExternally(url)
        onFinished: {
            urlField.text = server
            userField.text = user
            passwordField.text = appPassword
            appWindow.appSettings.webdavEtag = ""
            settingsPage.webdavStatus = qsTr("Signed in as %1 – checking the connection …").arg(user)
            appWindow.favoritesBackup.testConnection(function(ok, status) {
                settingsPage.webdavStatus = ok ? qsTr("Connection successful")
                    : qsTr("Connection failed – check the URL")
                if (ok) appWindow.favoritesBackup.syncNow(true)
            })
        }
        onFailed: {
            settingsPage.webdavStatus = error === 0 ? qsTr("Invalid server address")
                : error === 1 ? qsTr("No Nextcloud found at this address")
                : error === 2 ? qsTr("Server not reachable") + (detail.length > 0 ? " (" + detail + ")" : "")
                : error === 3 ? qsTr("The server did not start the sign-in – is it a Nextcloud?")
                : error === 4 ? qsTr("The sign-in in the browser was not completed in time")
                : qsTr("The server sent an incomplete answer")
        }
    }

    Component.onDestruction: nextcloudLogin.cancel()

    Component.onCompleted: {
        refresh()
        if (appWindow.appSettings.webdavUse) {
            appWindow.appSettings.ensurePasswordLoaded()
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        Column {
            id: column
            width: parent.width

            PageHeader {
                title: qsTr("Backup and sync")
            }

            SectionHeader { text: qsTr("On this phone") }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                color: Theme.secondaryHighlightColor
                font.pixelSize: Theme.fontSizeExtraSmall
                text: qsTr("Favorites are always backed up on this device (Documents/Sailwave, last 5 states).")
                      + "\n" + qsTr("Last automatic backup: %1").arg(settingsPage.refreshCount >= 0 ? settingsPage.dateText(settingsPage.lastState) : "")
                      + "\n" + qsTr("Last backup file: %1").arg(settingsPage.refreshCount >= 0 ? settingsPage.dateText(settingsPage.lastFile) : "")
            }

            Item { width: 1; height: Theme.paddingLarge }

            Flow {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                spacing: Theme.paddingMedium

                ActionPill {
                    kind: "primary"
                    text: qsTr("Back up now")
                    onClicked: {
                        var path = appWindow.favoritesBackup.backupToDevice("json")
                        appWindow.showMessage(path.length > 0
                                              ? qsTr("Backup saved as %1").arg(path.substring(path.lastIndexOf("/") + 1))
                                              : qsTr("Backup could not be saved"))
                        settingsPage.refresh()
                    }
                }
                ActionPill {
                    text: qsTr("Back up and share …")
                    onClicked: pageStack.push(Qt.resolvedUrl("BackupPage.qml"))
                }
                ActionPill {
                    text: qsTr("Restore …")
                    onClicked: pageStack.push(Qt.resolvedUrl("RestorePage.qml"))
                }
            }

            Item { width: 1; height: Theme.paddingMedium }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                wrapMode: Text.Wrap
                color: Theme.secondaryHighlightColor
                font.pixelSize: Theme.fontSizeExtraSmall
                text: qsTr("New phone: share a backup (or use a WebDAV server) and restore it there. The copies on this device stay on this device.")
            }

            // ---------------------------------------------------------
            SectionHeader { text: qsTr("Your own server") }

            // A server for manual backups/restoring; automatic sync is a
            // separate switch below. Switching off keeps the access data.
            TextSwitch {
                text: qsTr("WebDAV server (e.g. Nextcloud)")
                description: qsTr("For backups on your own server and, if wanted, automatic sync between devices.")
                checked: appWindow.appSettings.webdavUse
                automaticCheck: false
                onClicked: appWindow.appSettings.webdavUse = !appWindow.appSettings.webdavUse
            }

            Column {
                width: parent.width
                visible: appWindow.appSettings.webdavUse

                TextField {
                    id: urlField
                    width: parent.width
                    text: appWindow.appSettings.webdavUrl
                    label: qsTr("WebDAV URL")
                    placeholderText: "https://cloud.example.com"
                    inputMethodHints: Qt.ImhUrlCharactersOnly | Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                    EnterKey.iconSource: "image://theme/icon-m-enter-next"
                    EnterKey.onClicked: focus = false
                    onTextChanged: {
                        if (text !== appWindow.appSettings.webdavUrl) {
                            appWindow.appSettings.webdavUrl = text
                            // Another server: the next sync checks again
                            appWindow.appSettings.webdavEtag = ""
                            settingsPage.webdavStatus = ""
                        }
                    }
                }
                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    wrapMode: Text.Wrap
                    color: Theme.secondaryHighlightColor
                    font.pixelSize: Theme.fontSizeExtraSmall
                    text: qsTr("Nextcloud and ownCloud: the server address is enough (e.g. https://cloud.example.com). "
                               + "Other WebDAV storage: the full folder address.")
                }

                // Nextcloud: sign in in the browser, no app password to type
                // (as in Sailcast)
                ActionPill {
                    kind: "primary"
                    x: Theme.horizontalPageMargin
                    visible: !nextcloudLogin.active
                    text: qsTr("Sign in with the browser")
                    enabled: urlField.text.trim().length > 0
                    onClicked: {
                        settingsPage.webdavStatus = ""
                        nextcloudLogin.start(urlField.text)
                    }
                }
                Row {
                    visible: nextcloudLogin.active
                    x: Theme.horizontalPageMargin
                    spacing: Theme.paddingMedium
                    BusyIndicator {
                        anchors.verticalCenter: parent.verticalCenter
                        size: BusyIndicatorSize.Small
                        running: parent.visible
                    }
                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: qsTr("Waiting for the login in the browser …")
                        color: Theme.secondaryHighlightColor
                        font.pixelSize: Theme.fontSizeSmall
                    }
                }
                ActionPill {
                    kind: "secondary"
                    x: Theme.horizontalPageMargin
                    visible: nextcloudLogin.active
                    text: qsTr("Cancel")
                    onClicked: {
                        nextcloudLogin.cancel()
                        settingsPage.webdavStatus = ""
                    }
                }
                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    wrapMode: Text.Wrap
                    color: Theme.secondaryHighlightColor
                    font.pixelSize: Theme.fontSizeExtraSmall
                    text: qsTr("Or enter the user name and an app password by hand:")
                }

                TextField {
                    id: userField
                    width: parent.width
                    text: appWindow.appSettings.webdavUser
                    label: qsTr("User name")
                    placeholderText: qsTr("User name")
                    inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhNoPredictiveText
                    EnterKey.iconSource: "image://theme/icon-m-enter-next"
                    EnterKey.onClicked: passwordField.focus = true
                    onTextChanged: {
                        if (text !== appWindow.appSettings.webdavUser) {
                            appWindow.appSettings.webdavUser = text
                            appWindow.appSettings.webdavEtag = ""
                            settingsPage.webdavStatus = ""
                        }
                    }
                }

                PasswordField {
                    id: passwordField
                    width: parent.width
                    text: appWindow.appSettings.webdavPassword
                    EnterKey.iconSource: "image://theme/icon-m-enter-close"
                    EnterKey.onClicked: focus = false
                    // Stored in Sailfish Secrets (see AppSettings.setWebdavPassword).
                    // The binding also fills the field when the password
                    // arrives from Secrets after the page was opened.
                    onTextChanged: {
                        if (text !== appWindow.appSettings.webdavPassword) {
                            appWindow.appSettings.setWebdavPassword(text)
                            settingsPage.webdavStatus = ""
                        }
                    }
                }
                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    visible: appWindow.appSettings.webdavPasswordError
                    wrapMode: Text.Wrap
                    color: Theme.highlightColor
                    font.pixelSize: Theme.fontSizeExtraSmall
                    text: appWindow.appSettings.webdavPassword.length > 0
                          ? qsTr("The password could not be saved securely and will be lost when the app is closed.")
                          : qsTr("The saved password could not be read. Please enter it again.")
                }
                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    wrapMode: Text.Wrap
                    color: Theme.secondaryHighlightColor
                    font.pixelSize: Theme.fontSizeExtraSmall
                    text: qsTr("Recommended: a separate app password from the security settings of "
                               + "Nextcloud instead of the login password.")
                }

                TextSwitch {
                    text: qsTr("Sync automatically")
                    description: qsTr("Uploads every change and checks for changes from other devices at start-up. "
                                      + "When off, the server is only used when backing up or restoring manually.")
                    checked: appWindow.appSettings.webdavAutoSync
                    automaticCheck: false
                    onClicked: appWindow.appSettings.webdavAutoSync = !appWindow.appSettings.webdavAutoSync
                }

                Item { width: parent.width; height: Theme.paddingLarge }

                ActionPill {
                    kind: "secondary"
                    x: Theme.horizontalPageMargin
                    text: qsTr("Test connection")
                    enabled: appWindow.appSettings.webdavUrl.length > 0 && !settingsPage.webdavTesting
                    onClicked: {
                        settingsPage.webdavTesting = true
                        settingsPage.webdavStatus = qsTr("Connecting …")
                        appWindow.favoritesBackup.testConnection(function(ok, status) {
                            settingsPage.webdavTesting = false
                            settingsPage.webdavStatus = ok ? qsTr("Connection successful")
                                : (status === 401 || status === 403) ? qsTr("Sign-in failed – check user name and password")
                                : status === 0 ? qsTr("Server not reachable")
                                : qsTr("Connection failed – check the URL")
                            // First successful connection: sync right away
                            // (only with automatic sync; syncNow checks that)
                            if (ok) appWindow.favoritesBackup.syncNow(true)
                        })
                    }
                }
                Label {
                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    visible: settingsPage.webdavStatus.length > 0
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    color: Theme.highlightColor
                    font.pixelSize: Theme.fontSizeSmall
                    text: settingsPage.webdavStatus
                }
            }
        }

        VerticalScrollDecorator {}
    }
}
