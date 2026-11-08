# Établi Projet

> OpenProject projects and assigned work.

`iOS` `Android` · Apache-2.0 · Part of the [Établi Suite](https://github.com/etabli-dev)

Android lists projects and work packages assigned to you. iOS additionally browses a project’s work packages, searches within a project and edits work-package subjects with optimistic lock-version handling. Assignment changes are not implemented. Lists currently request up to 200 projects and 100 work packages in the screens; further UI pagination is deferred.

## Availability

Établi Projet is **under active development**. There are no App Store, Google Play or F-Droid releases yet.

- **Android:** install the current **development build** as a debug-signed **APK** from **[GitHub Releases](../../releases)** (v0.1.0, built before the October–November 2026 changes).
- **App Store (iOS):** planned — not yet available.
- **Google Play:** planned — not yet available.
- **F-Droid:** planned — not yet available.

## Platforms

Établi Projet is a mobile app for Android and iOS, including tablets. Desktop
applications for Ubuntu/Debian, Windows and macOS are not planned; use the
OpenProject web interface there. The [platform roadmap](docs/platform-roadmap.md)
lists the remaining Android/iOS feature differences, signing and store steps, and
their acceptance criteria.

## First use

Create an OpenProject API token under My account → Access tokens. Enter the HTTPS server URL and token in Settings and connect. Browse Projects and My Work. On iOS open a work package to inspect or change its subject; a version conflict requires reloading before retrying.

Connection setup tries Bearer authentication first. OpenProject 17.2+ supports
newly generated personal API tokens this way; older servers use Basic with the
fixed username `apikey`. After HTTP 401 on the connection check only, the client
tries that Basic form once against the same HTTPS URL. It saves the successful
method with your credentials and uses it for later requests without retries.
Both connection attempts share a 45-second budget. Basic must be enabled on a
server that requires it. See the [current authentication contract](https://www.openproject.org/docs/api/introduction/#authentication)
and [17.2 release notes](https://www.openproject.org/docs/release-notes/17-2-0/).

Existing saved accounts keep Bearer unless you reconnect successfully. The app
does not perform OAuth sign-in or refresh OAuth access tokens; use a personal API
token for this setup. Authentication fixtures are tested separately from live
server acceptance.

Use the canonical HTTPS URL: authenticated redirects are refused, and normal
system certificate validation remains enabled. Reconnect after restoring an
Android backup; the encrypted token file is deliberately excluded from backup.
A lost or unreadable key does not cause the app to overwrite the saved data.

JSON replies are limited to 8 MiB and requests have a 45-second total timeout.
Failures and cancellation remain visible or cancel the active operation; they
are not converted into empty successful lists.

## Build and checks

Android prerequisites: JDK 17, Android SDK 36 and build-tools 35.0.0,
with `ANDROID_HOME` pointing to that SDK.

```sh
cd android
./gradlew testDebugUnitTest lintDebug assembleDebug bundleRelease
adb install -r app/build/outputs/apk/debug/app-debug.apk
```

Open the app and follow the server setup above. The debug APK is for testing;
the release AAB is unsigned until a signing configuration is supplied. For iOS,
open `ios/EtabliProjet.xcodeproj` in Xcode, choose your development team and an
iOS 17+ destination, then run.

The Foundation client checks run with macOS command-line tools and Python 3:

```sh
python3 scripts/check_swift.py
```

These checks compile the production client/transport/Keychain wrapper, exercise
the client using isolated in-memory credentials and HTTP protocol fixtures, and
parse the SwiftUI sources. They do not establish a complete iOS build or a real
server connection. Android TLS fixtures use normal trust validation with a local
test certificate. See [the refinement record](docs/refinement-2026-10.md).

With an attached Android emulator or test device, run the production Keystore
and credential-migration checks from `android/`:

```sh
./gradlew connectedDebugAndroidTest
```

These use isolated test keys and storage; they do not connect to your server.

## Privacy and storage

No analytics or author-operated service. You use your own server account;
requests go to that server.
Android uses Compose, OkHttp and DataStore; its token is protected by an
app-specific Android Keystore AES-256-GCM key and bound to the configured server.
Existing plaintext Android tokens migrate atomically on first use. iOS stores
the server/token pair in one Keychain item; existing installations retain legacy
read compatibility. Server addresses and UI settings are also local preferences.

Server content is loaded for viewing; no background synchronization service is implemented.

## Readiness and deferred work

Android crypto and server integration tests (8), lint, debug APK and release
bundle passed locally before the final screen review. Swift client checks and
production Foundation typechecking also passed. Final screen/build evidence is
recorded in the refinement record. Remote CI, a current SwiftUI/Xcode build,
device accessibility/lifecycle/credential restore and a real-server journey remain
separate acceptance gates. No store submission or deployment was performed.

Next release step: run the documented journey on both devices with a test server,
resolve device findings, configure signing and prepare the store package for approval.

## License

Apache License 2.0 — see [LICENSE](LICENSE) and [NOTICE](NOTICE).
Copyright 2026 R. Heller.
