# Transitional package harbour-sailwave (OpenRepos only)

Sailwave was packaged as `harbour-sailwave` up to 1.0.1. Since 1.1 the package is called `harbour-sailwave-radio`, because the old name was already taken in the Jolla Store.

This folder builds one last `harbour-sailwave` package (1.1, noarch) without any app files. It only requires `harbour-sailwave-radio`. Users who installed Sailwave from OpenRepos (e.g. with Storeman) get it as a normal update: the old app is removed and the new one installed. Favorites, histories and settings are kept – both versions use the same data folders.

It is published on OpenRepos only (old Sailwave page), never in the Jolla Store or on Chum.

Build, in this folder:

```
sfdk -c target=SailfishOS-5.1.0.11-aarch64 build
```

or with `rpmbuild` on the PC:

```
rpmbuild -bb --define "_topdir $PWD/build" rpm/harbour-sailwave.spec
```

Testing on a device: install it **together** with the new package, e.g. `devel-su pkcon install-local harbour-sailwave-radio-1.1-1.aarch64.rpm harbour-sailwave-1.1-1.noarch.rpm`. Alone, PackageKit may report "nothing provides harbour-sailwave-radio" if that package was deployed from Qt Creator (installed with rpm directly). With packages from OpenRepos (Storeman) this does not happen.

Build with `-c no-fix-version`, otherwise sfdk appends branch/time/commit to the version in a git repository:

```
sfdk -c target=SailfishOS-5.1.0.11-aarch64 -c no-fix-version build
```

