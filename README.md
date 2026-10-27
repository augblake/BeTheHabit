# BeTheHabit

A free, open-source habit tracker for iPhone, built with SwiftUI.
Track routines you want to build or reduce using check-ins, numbers, or timers.
For number and timer habits, a day streak continues when the recorded value moves
in the intended direction or stays level: up for Build, down for Remove. Yes/No
streaks count consecutive successful check-ins.

## Features

- Goals, progress history, notes, custom icons and colors.
- Drag to reorder habits.
- Interactive Home Screen widget for check-ins and timers.
- Optional private, read-only friend sharing with CloudKit.
- Automatic private iCloud backup and reinstall recovery for habits, history,
  notes, widget selection, appearance, momentum and sharing setup when signed into iCloud.
- Local app/widget storage with coordinated writes and migration support.
- Personal notes excluded from shared snapshots.

The app requires iOS 16 or later. The configurable widget requires iOS 17 or later
and supports interactive check-ins and timers. The internal Swift package and app product retain
`HabitQuest`, and the widget product retains `BeHabitWidget`.

## Source layout

| Directory | Purpose |
| --- | --- |
| `Sources/HabitQuest` | SwiftUI app, private CloudKit backup and friend sharing |
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
For a locally signed development IPA, `tools/sign-dev.sh` extracts the widget's
App Intents metadata before signing. Omitting that step can leave the widget's
Start and Stop buttons visible but inactive.

For the official app's Linux TestFlight packaging, `tools/prepare-testflight.py`
uses the sibling `omarchy-apple-dev` toolchain (override with
`APPLE_TOOLCHAIN_ROOT`). Supply `ASC_KEY_ID`, `ASC_ISSUER_ID` and
`ASC_KEY_PATH` through the environment and run it with the toolchain's
`pymobile3-venv` Python. It stages a separate release under
`xtool/testflight-source`, preserves the registered app/widget identifiers,
enables CloudKit in Production, extracts widget metadata, includes the privacy
manifest, signs and validates the IPA. It does not upload. Signing material and
release output stay under the ignored `xtool` directory. This helper is specific
to the official developer account; forks must configure their own identifiers.

Friend sharing is disabled by default (`BeHabitCloudSharingEnabled = false`)
so builds without CloudKit provisioning can open and track habits locally.
To enable it, select `BeHabit.CloudKit.entitlements` in `xtool.yml` and set the
flag to true only after the signed app has the matching CloudKit container and
service entitlements. Creating a `CKContainer` without them can terminate the
app with an Objective-C exception, which Swift `do`/`catch` cannot recover from.

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
The default configuration builds without friend sharing. Widget App Groups are
still needed.

Local machine signing/upload utilities, profiles, certificates, credentials,
release artifacts and session notes are intentionally absent. This repository
contains the complete app/widget Swift source and shared-code tests, but does
not currently provide a portable, one-command signed release pipeline.

## Sharing behavior

Only selected habits are uploaded to private/shared CloudKit databases. Friends
have read-only access; notes are removed at the serialization boundary. Updates
sync while the app is active and on refresh, not through background push sync.

## Private iCloud recovery

CloudKit-enabled builds save a complete archive in each signed-in user's private
database. After deleting and reinstalling the app, the first launch downloads
that archive from the same iCloud account before uploading local changes. The
archive includes the owner's sharing name and identifiers of their existing
shared habits; accepted friend shares are rediscovered from CloudKit. The
home screen reports when the backup was last saved or why it is paused. Local
tracking remains available without iCloud. This is automatic backup and
reinstall recovery; it does not reconcile edits made simultaneously on multiple
devices using one account. The `HabitArchive` record type has an `archive` Asset,
`formatVersion` Int and `savedAt` Date field. Deploy that schema to Production
before distributing a build with this feature through TestFlight or the App Store.
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
