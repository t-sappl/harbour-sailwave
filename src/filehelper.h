// SPDX-License-Identifier: GPL-3.0-or-later
#ifndef FILEHELPER_H
#define FILEHELPER_H

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QObject>
#include <QStandardPaths>
#include <QTextStream>
#include <QVariantList>
#include <QVariantMap>

// Plain file access for QML (favourites backup, M3U export, file chooser).
// QML itself cannot write files. Available in QML as "fileHelper".
// Paths outside the app's own data folder need the matching Sailjail
// permission in harbour-sailwave.desktop (Documents, UserDirs ...).
class FileHelper : public QObject
{
    Q_OBJECT
public:
    explicit FileHelper(QObject *parent = nullptr) : QObject(parent) {}

    // ~/Documents
    Q_INVOKABLE QString documentsPath() const
    {
        return QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
    }

    // Home folder (upper limit of the file chooser)
    Q_INVOKABLE QString homePath() const
    {
        return QDir::homePath();
    }

    // The app's own data folder (always writable, not visible to the user)
    Q_INVOKABLE QString dataPath() const
    {
        return QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    }

    Q_INVOKABLE bool ensureDir(const QString &path) const
    {
        return QDir().mkpath(path);
    }

    Q_INVOKABLE bool exists(const QString &path) const
    {
        return QFileInfo(path).exists();
    }

    // Writes UTF-8 text; via a temporary file, so a crash never leaves a
    // half-written file behind
    Q_INVOKABLE bool writeText(const QString &path, const QString &text) const
    {
        QFileInfo info(path);
        QDir().mkpath(info.absolutePath());
        const QString tmp = path + QStringLiteral(".tmp");
        QFile file(tmp);
        if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
            qWarning("[FileHelper] Cannot write %s", qPrintable(path));
            return false;
        }
        file.write(text.toUtf8());
        file.close();
        QFile::remove(path);
        if (!QFile::rename(tmp, path)) {
            qWarning("[FileHelper] Cannot replace %s", qPrintable(path));
            return false;
        }
        return true;
    }

    // Empty string if the file cannot be read
    Q_INVOKABLE QString readText(const QString &path) const
    {
        QFile file(path);
        if (!file.open(QIODevice::ReadOnly)) {
            return QString();
        }
        return QString::fromUtf8(file.readAll());
    }

    Q_INVOKABLE bool removeFile(const QString &path) const
    {
        return QFile::remove(path);
    }

    // Folders and files of a folder: [{ name, path, isDir, modified (ms) }],
    // folders first, then files matching nameFilters (e.g. ["*.json"]),
    // each sorted by name; hidden entries are left out
    Q_INVOKABLE QVariantList listDir(const QString &path, const QStringList &nameFilters) const
    {
        QVariantList result;
        QDir dir(path);
        const QFileInfoList dirs = dir.entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name | QDir::IgnoreCase);
        for (const QFileInfo &info : dirs) {
            result.append(entry(info));
        }
        const QFileInfoList files = dir.entryInfoList(nameFilters, QDir::Files, QDir::Name | QDir::IgnoreCase);
        for (const QFileInfo &info : files) {
            result.append(entry(info));
        }
        return result;
    }

private:
    static QVariantMap entry(const QFileInfo &info)
    {
        QVariantMap map;
        map.insert(QStringLiteral("name"), info.fileName());
        map.insert(QStringLiteral("path"), info.absoluteFilePath());
        map.insert(QStringLiteral("isDir"), info.isDir());
        map.insert(QStringLiteral("modified"), static_cast<double>(info.lastModified().toMSecsSinceEpoch()));
        return map;
    }
};

#endif // FILEHELPER_H
