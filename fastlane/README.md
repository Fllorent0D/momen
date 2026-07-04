fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios build

```sh
[bundle exec] fastlane ios build
```

Build iOS App Store (.ipa)

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Build + upload TestFlight iOS

### ios screenshots

```sh
[bundle exec] fastlane ios screenshots
```

Captures d'écran iOS (iPhone + iPad)

### ios inspect

```sh
[bundle exec] fastlane ios inspect
```

Inspecte l'état App Store Connect du record (locales, noms, primary)

### ios rename_and_release

```sh
[bundle exec] fastlane ios rename_and_release
```

Renomme le record via l'API (contourne le blocage deliver) puis upload + submit

### ios meta

```sh
[bundle exec] fastlane ios meta
```

Upload métadonnées + captures seules (sans build/binaire) — itération rapide

### ios release

```sh
[bundle exec] fastlane ios release
```

Build + envoi App Store iOS (métadonnées + binaire, sans soumission auto)

----


## Mac

### mac build

```sh
[bundle exec] fastlane mac build
```

Build Mac App Store (.pkg)

### mac beta

```sh
[bundle exec] fastlane mac beta
```

Build + upload TestFlight Mac

### mac release

```sh
[bundle exec] fastlane mac release
```

Build + envoi App Store Mac (sans soumission auto)

----


## tv

### tv build

```sh
[bundle exec] fastlane tv build
```

Build tvOS App Store (.ipa)

### tv beta

```sh
[bundle exec] fastlane tv beta
```

Build + upload TestFlight tvOS

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
