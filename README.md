# BeTheHabit

A free, open-source habit tracker for iPhone and iPad, built with SwiftUI.
Track routines you want to build or reduce using check-ins, numbers, or timers.

## Features

- Goals, progress history, notes, custom icons and colors.
- Drag to reorder habits.
- Interactive Home Screen widget for check-ins and timers.
- Optional private, read-only friend sharing with CloudKit.
- Local app/widget storage with coordinated writes and migration support.
- Personal notes excluded from shared snapshots.

Requires iOS 17 or later. The internal Swift package and app product retain
`HabitQuest`, and the widget product retains `BeHabitWidget`.

## Source layout

| Directory | Purpose |
| --- | --- |
| `Sources/HabitQuest` | SwiftUI app and CloudKit sharing |
| `Sources/HabitShared` | Habit models, local storage and sharing snapshot |
| `Sources/BeHabitWidget` | WidgetKit UI, habit picker and interactive intents |
| `Tests/HabitSharedTests` | Storage, migration, widget coordination and privacy tests |
| `Validation` | Standalone package for testing the shared code on Linux/macOS |

## Run the shared-code tests

With Swift 6 installed:

```bash
swift test --package-path Validation
```

The standalone package avoids compiling iOS-only SwiftUI and WidgetKit targets
on Linux. Its `Sources` and `Tests` symlinks point to the same files used by the app.

## Building the iOS app

This repository uses a Swift package and `xtool.yml`; it does not include an
Xcode project. The reference development environment uses
[xtool](https://github.com/xtool-org/xtool), a matching Swift/iOS SDK toolchain,
and separate icon, App Intents metadata and signing preparation.

An unsigned compile/package check is:

```bash
xtool dev build
```

This command alone is not an App Store-ready distribution build. Interactive
widget configuration also needs extracted App Intents metadata. An Xcode-based
port should create app and Widget Extension targets using these same sources.

For your own installable build, configure your own signing and identifiers:

1. Select an app bundle identifier and widget identifier in `xtool.yml`.
2. Set the same App Group in both entitlement files and
   `HabitRepository.appGroup` in `Sources/HabitShared/HabitRepository.swift`.
3. Configure your own CloudKit container in `BeHabit.CloudKit.entitlements` and
   `CloudHabitSharing.containerIdentifier` in `Sources/HabitQuest/CloudHabitSharing.swift`.
4. Register capabilities and obtain matching profiles for your own Apple team.
5. For App Store/TestFlight, use distribution signing, Production CloudKit,
   the deployed production schema, matching app/widget versions, the privacy
   manifest, compiled icon assets and complete widget metadata.

The identifiers in the source describe the official app and are public
configuration, not credentials or access to its private user data. Do not
attempt to sign or distribute a fork using the official developer’s identity.
To build without friend sharing, set `BeHabitCloudSharingEnabled` to false in
`AppInfo.plist` and use `BeHabit.entitlements` in `xtool.yml` instead of the
CloudKit entitlement file. Widget App Groups are still needed.

Local machine signing/upload utilities, profiles, certificates, credentials,
release artifacts and session notes are intentionally absent. This repository
contains the complete app/widget Swift source and shared-code tests, but does
not currently provide a portable, one-command signed release pipeline.

## Sharing behavior

Only selected habits are uploaded to private/shared CloudKit databases. Friends
have read-only access; notes are removed at the serialization boundary. Updates
sync while the app is active and on refresh, not through background push sync.
Two-account invitation and production-environment testing is still required
before the first public App Store release.

## Support and privacy

- [Support](https://augblake.github.io/BeTheHabit-support/support.html)
- [Privacy policy](https://augblake.github.io/BeTheHabit-support/privacy.html)
- Email: bryce7cs@gmail.com

## Contributing

Issues and pull requests are welcome. Describe the change and its reason, run
shared-code tests for storage/model changes, and report device validation for
UI, widget or CloudKit behavior. Never include passwords, signing material or
private habit data in an issue or pull request.

## License

Code and technical documentation are available under the [MIT license](LICENSE).
The BeTheHabit name and icon artwork are excluded; see [BRANDING.md](BRANDING.md).
Forks should use their own name and artwork.
