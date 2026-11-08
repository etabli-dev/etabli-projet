# Platform roadmap

Établi Projet · state as of 2026-11-08 · this is a plan. Observed results stay in the
[current status page](current-status.qmd) and the [refinement record](refinement-2026-10.md);
Android release steps are detailed in
[android/SUBMISSION.md](https://github.com/etabli-dev/etabli-projet/blob/main/android/SUBMISSION.md).

The [2026-11-08 Apple refinement](apple-audit-2026-11-08.md) records the implemented iOS metadata/detail parity and current unsigned build verification. Live-service and signed-distribution gates remain open.

## 1. Platform role

Établi Projet is a **mobile-only** app for Android and iOS, on phones and tablets (the iOS
target already includes iPad). It is for checking your OpenProject work away from the desk:
what is assigned to you, what a project contains, and small corrections such as a
work-package subject.

No Ubuntu/Debian, Windows or macOS application is planned. OpenProject's own web interface
is a complete desktop client (boards, Gantt charts, time tracking, wiki) that a thin mobile
client cannot match, so a desktop build would add maintenance without adding capability.

| Platform | Role | Used for |
|---|---|---|
| Android | release target | phones and tablets; signed APK on GitHub Releases, Google Play, later F-Droid |
| iOS / iPadOS | release target | iPhone and iPad; TestFlight, then App Store |
| Ubuntu/Debian, Windows, macOS | not planned | the OpenProject web interface in a browser |

## 2. Current state

| Platform | Status | Technology | How it is built | What is verified | Distribution |
|---|---|---|---|---|---|
| Android | in development | Kotlin 1.9.24, Jetpack Compose (Material 3), OkHttp 4.12, DataStore, Android Keystore; minSdk 26, compile/target SDK 36; AGP 8.13.2, Gradle 8.13, JDK 17 | `cd android && ./gradlew testDebugUnitTest lintDebug assembleDebug bundleRelease`; CI job `android` in `.github/workflows/android.yml` (ubuntu-24.04) | CI on 2026-10-31: unit and TLS-fixture tests (including Bearer/Basic token negotiation), lint, debug APK, unsigned release AAB. Locally: production-Keystore instrumented tests on an API 36 emulator (2026-10-31) and an account-free UI journey on an API 35 emulator (2026-11-02). Not verified: a live OpenProject server, a physical device, a release-signed build | GitHub Releases `v0.1.0` (2026-06-24): one APK signed with the Android debug key, built before the October–November changes. No Google Play or F-Droid listing |
| iOS | in development | SwiftUI, URLSession, Keychain, HAL+JSON decoding; iOS 17+; iPhone and iPad | Xcode project `ios/EtabliProjet.xcodeproj`; CI job `ios` (macos-15): `python3 scripts/check_swift.py` plus an unsigned simulator build | CI on 2026-10-31: Foundation client checks and the full unsigned simulator build. Not verified: any device run, a live server, signing | none (no TestFlight, no App Store) |
| Ubuntu/Debian | not planned | — | — | — | — |
| Windows | not planned | — | — | — | — |
| macOS | not planned | — | — | — | — (see decision D8 on iPad apps on Apple silicon Macs) |

Shared behaviour on both platforms: personal API token with Bearer first and one Basic
(`apikey`) retry on HTTP 401 during the connection check; no OAuth; HTTPS only, authenticated
redirects refused, 8 MiB JSON bound, 45-second request budget; lists request up to 200
projects and 100 work packages without further pagination; no assignment changes.

## 3. Architecture

**Now.** Two independent native codebases with no shared code:

- `android/`: `net/OPClient.kt` (OpenProject client, token negotiation, DataStore settings,
  Keystore-encrypted token), `net/Models.kt` (HAL parsing), `net/HttpTransport.kt` (bounded,
  cancellable OkHttp), `ui/screens/` (Compose: Projects, My work, Settings).
- `ios/`: `App/Net/Client.swift` (`OPClient`), `App/Net/HAL.swift`, `App/Net/HttpTransport.swift`,
  `App/Shell/` (SwiftUI: My work, Projects with drill-down, work-package detail, Settings).

What the two share today is the OpenProject API v3 contract (`/api/v3/users/me`,
`/api/v3/projects`, `/api/v3/work_packages` with JSON `filters`,
`/api/v3/projects/{id}/work_packages`, `PATCH /api/v3/work_packages/{id}` with `lockVersion`),
the limits above and the Coder design tokens copied by `tool/sync_style.sh`.

**Target.** Keep two native apps; iOS stays SwiftUI. With no desktop target there is no reason
for a Kotlin Multiplatform module, and each client is a few hundred lines. Keep the platforms
in step with:

1. the parity tables in section 4, updated in the same commit as any feature change;
2. one set of HTTP reply fixtures (HAL collections, single work package, 401/409 replies) in a
   new top-level `fixtures/openproject/` folder, read by both
   `android/app/src/test/.../OPClientTest.kt` and `scripts/check_client.swift`;
3. the acceptance column of each parity row as the behaviour specification.

## 4. Per-platform execution

### 4.1 Android

**Feature gap: present on iOS, missing on Android**

| # | Feature | Where it exists (iOS) | Android work | Accepted when |
|---|---|---|---|---|
| A1 | Open a project and list its work packages | `ios/App/Shell/ProjectsView.swift` (`ProjectWorkPackagesView`); `ios/App/Net/Client.swift` `listWorkPackages(projectID:assignedToMe:query:offset:pageSize:)` using `/api/v3/projects/{id}/work_packages` | Generalise `OPClient.listMyWorkPackages()` into `listWorkPackages(projectId, assignedToMe, query, offset, pageSize)` with the same JSON filter encoding; add a project screen reached from `ProjectsScreen.kt` with system back | Fixture test asserts path, `pageSize`, `offset` and the encoded `filters` value; back returns to the project list with its scroll position |
| A2 | Search work packages within a project | `ProjectsView.swift` ("filter by subject") sending `{"search":{"operator":"**","values":[q]}}` | Debounced query field on the project screen using the existing cancellation guard | Fixture test for the encoded search filter; an older reply never replaces a newer query |
| A3 | Work-package detail: project, status, type, priority, assignee, lock version, description | `ios/App/Shell/WorkPackageDetailView.swift`; `Client.swift` `fetchWorkPackage(id:)` | Extend `OPWorkPackage` in `Models.kt` with `lockVersion` and `description.raw`; add a detail screen opened from My work and from the project list | Missing optional fields render as "—"; a missing `id` or `subject` still fails visibly (current strict parsing) |
| A4 | Edit the subject with optimistic locking | `Client.swift` `updateSubject(id:lockVersion:newSubject:)` (`PATCH` with `lockVersion`); HTTP 409 becomes `versionConflict`, after which the view reloads the work package | Add a `PATCH` request through `HttpTransport.kt`; map 409 to a conflict error, reload the work package, never retry automatically; refresh the list after a successful save | Fixture tests for success, 409 (reload, unchanged local subject) and 422/other errors; the save button is disabled while saving or when the subject is unchanged |
| A5 | Pull to refresh | `.refreshable` on My work and project lists | Replace the "Reload" buttons with Material 3 pull-to-refresh (keep an accessible refresh action) | Works with TalkBack |
| A6 | Theme choice Auto / Light / Dark | `ios/App/Shell/SettingsView.swift` (`ThemePreference`) | Store the choice in DataStore and pass it to `CoderTheme(darkOverride = …)`, which already accepts an override; Établi Focus has an Android implementation to mirror (`android/app/src/main/java/com/raban/etabli/focus/prefs/ThemePreference.kt`) | Choice survives relaunch; "Auto" follows the system |

**Build and run**

```sh
cd android
./gradlew --no-daemon testDebugUnitTest lintDebug assembleDebug bundleRelease
adb install -r app/build/outputs/apk/debug/app-debug.apk
./gradlew connectedDebugAndroidTest        # emulator or test device attached
```

Release candidate, once `android/keystore.properties` exists (see SUBMISSION.md):

```sh
./gradlew --no-daemon testDebugUnitTest lintRelease assembleRelease bundleRelease
"$ANDROID_HOME/build-tools/35.0.0/apksigner" verify --print-certs app/build/outputs/apk/release/app-release.apk
"$ANDROID_HOME/build-tools/35.0.0/zipalign" -c -P 16 -v 4 app/build/outputs/apk/release/app-release.apk
```

**Packages and channels**

- *GitHub Releases:* release-signed APK plus `SHA256SUMS`; the hash in the release notes
  must equal GitHub's asset digest. A release-signed APK cannot update the debug-signed
  `v0.1.0` install: the release notes must say to uninstall it first (the token is excluded
  from backup, so users simply reconnect).
- *Google Play:* AAB (`bundleRelease`) with Play App Signing; internal testing, then closed
  testing, then production. The first upload of a new app is done in Play Console; later
  uploads can be automated.
- *F-Droid:* later (M8). Only listing text exists (`fastlane/metadata/android/en-US`); there
  is no build recipe yet. The dependencies (AndroidX, Compose, OkHttp) are free software, so
  a source build is realistic. With reproducible builds F-Droid can publish the developer
  signature, keeping GitHub, Play and F-Droid installs interchangeable (decision D1).

**Signing prerequisites (owner):** an app signing key and an upload key per decision D1,
kept outside the repository with backups; a Google Play developer account (D4); a privacy
policy URL (D5). CI secrets in a GitHub environment named `release` with the owner as
required reviewer: `ANDROID_KEYSTORE_B64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`,
`ANDROID_KEY_PASSWORD`; later `PLAY_SERVICE_ACCOUNT_JSON` for automated Play uploads.

**CI**

- Keep `android.yml` unchanged as the per-push verification.
- Add `.github/workflows/android-release.yml`: triggered by tags `v*` and
  `workflow_dispatch`; one job on ubuntu-24.04 in environment `release`; workflow-level
  `permissions: contents: read`, `contents: write` only on the job that creates the draft
  release; reuse the pinned `actions/checkout`, `actions/setup-java` and
  `android-actions/setup-android` SHAs from `android.yml`. Steps: decode the keystore into
  `$RUNNER_TEMP`, write `android/keystore.properties` with an absolute `storeFile`, run tests,
  `lintRelease assembleRelease bundleRelease`, verify the signature (fail if the certificate
  is `CN=Android Debug`) and 16 KB alignment, write `SHA256SUMS`, then
  `gh release create "$GITHUB_REF_NAME" --draft` with the APK and `SHA256SUMS`; keep the AAB
  as a workflow artifact for Play. Delete the keystore files in an `if: always()` step.
- Later: an internal-track Play upload step through the Play Developer API, pinned to a full
  commit SHA like every other action.

**Acceptance criteria (Android)**

- A1–A6 done, each with the automated test named in its row, green in CI.
- Live journey on a disposable OpenProject test instance (D3), once with a server that accepts
  Bearer tokens and once with one that needs the Basic `apikey` form: connect, My work, open a
  project, search in it, open a work package, change its subject, provoke a version conflict
  by editing the same item in the web interface, reload, disconnect.
- Release APK: `apksigner` shows the owner's certificate; the 16 KB alignment check passes;
  installs and runs on API 26 and API 36; an upgrade from the previous signed build keeps the
  account.
- Play: the internal-track build installs from the Play Store; the pre-launch report shows no
  crash; the Data safety answers match the shipped artifact.

### 4.2 iOS

**Feature gap: present on Android, missing on iOS**

| # | Feature | Where it exists (Android) | iOS work | Accepted when |
|---|---|---|---|---|
| I1 | Project description excerpt in the project list | `ProjectsScreen.kt` (first 200 characters of `description.raw`) | `HAL.swift` already decodes the project `description`, but `ProjectsView.swift` rows show only the identifier; add the excerpt | Empty or missing descriptions add no blank line |
| I2 | Priority visible in list rows | `MyWorkScreen.kt` shows status, type and priority labels | iOS rows show project, status and type (`MyWorkView.swift`) or status and type (`ProjectWorkPackagesView`); add priority to both | Same fields visible on both platforms for the same work package |

**Build and run** (a Mac with Xcode; CI uses the default Xcode of macos-15):

```sh
python3 scripts/check_swift.py
xcodebuild -project ios/EtabliProjet.xcodeproj -scheme EtabliProjet -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Archive and upload to App Store Connect (TestFlight):

```sh
xcodebuild archive -project ios/EtabliProjet.xcodeproj -scheme EtabliProjet -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/EtabliProjet.xcarchive \
  DEVELOPMENT_TEAM="$APPLE_TEAM_ID" MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD" \
  -allowProvisioningUpdates -authenticationKeyPath "$ASC_KEY_PATH" \
  -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID"
xcodebuild -exportArchive -archivePath build/EtabliProjet.xcarchive -exportPath build/export \
  -exportOptionsPlist "$RUNNER_TEMP/export.plist" -allowProvisioningUpdates \
  -authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID"
```

`export.plist` sets `method` = `app-store-connect`, `destination` = `upload` and `teamID`. Write
it at run time: the repository's `.gitignore` excludes `ExportOptions.plist`.

**Distribution path:** TestFlight internal testing (no review) → external TestFlight (Beta
App Review) → App Store. Already in place: App icon, privacy manifest
(`ios/App/PrivacyInfo.xcprivacy`, declaring the UserDefaults and file-timestamp reasons),
`ITSAppUsesNonExemptEncryption = NO` in both build configurations. Still needed: iPhone and
iPad screenshots (the target includes iPad), privacy policy and support URLs, App Privacy
answers, age rating, and review notes with a reachable demo OpenProject account and its API
token (D3).

**Signing prerequisites (owner):** Apple Developer Program membership and Team ID (D4); the
bundle ID `com.raban.etabli.projet` registered with an App Store Connect app record; an App
Store Connect API team key (Key ID, Issuer ID, `.p8`) whose role may manage signing (Admin, or
App Manager with access to certificates and profiles). If the key cannot manage cloud signing,
also an Apple Distribution certificate exported as `.p12`. CI secrets in environment `release`:
`APPLE_TEAM_ID`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8_B64`, and if needed
`IOS_DIST_CERT_P12_B64`, `IOS_DIST_CERT_PASSWORD`.

**CI**

- Keep the `ios` job in `android.yml` as the per-push check.
- Add `.github/workflows/ios-release.yml` (macos-15, tags `v*` and `workflow_dispatch`,
  environment `release`, `permissions: contents: read`): decode the API key into
  `$RUNNER_TEMP`, import the certificate into a temporary keychain if one is used, run
  `scripts/check_swift.py`, archive, export and upload as above; delete key and keychain in an
  `if: always()` step.

**Acceptance criteria (iOS)**

- I1–I2 done; `scripts/check_swift.py` and the simulator build green in CI.
- On an iPhone and an iPad (TestFlight build) against the test instance: the same journey as
  Android, including the version-conflict case; account kept after relaunch.
- VoiceOver reads rows and the detail sheet; the largest Dynamic Type size stays usable; iPad
  rotation and Split View keep the layout usable.
- The TestFlight build is processed and installs from the TestFlight app; App Review approves
  the submission.

### 4.3 Ubuntu/Debian — not planned

No Linux application is planned. OpenProject's web interface works in any desktop browser and
offers far more than this client; a native client would duplicate a subset of it. On Ubuntu or
Debian, open your OpenProject address in Firefox or Chromium and keep it as a bookmark or
browser shortcut.

### 4.4 Windows — not planned

No Windows application is planned, for the same reason: the OpenProject web interface in Edge,
Firefox or Chrome is the desktop client.

### 4.5 macOS — not planned

No macOS application is planned; use the OpenProject web interface in Safari or another
browser. Note that App Store Connect offers iPhone and iPad apps on Apple silicon Macs by
default; decision D8 covers whether to opt out until that is tested.

## 5. Milestones

Owner prerequisites (section 6) can be prepared in parallel with M1–M2.

1. **M1 — Android parity.** Implement A5, A6, A1, A2, A3, A4 in that order (A4 builds on A3).
   *Exit:* every A row marked done in this file with its test; `android.yml` green; account-free
   emulator journey repeated.
2. **M2 — iOS parity and shared fixtures.** I1–I2; move reply fixtures to
   `fixtures/openproject/` and read them from both test suites. *Exit:* both suites use the
   shared fixtures; `check_swift.py` and the simulator build green in CI.
3. **M3 — Android live acceptance.** Needs D3. *Exit:* the Android journey in 4.1 passes on an
   emulator and one physical device; results recorded in `docs/current-status.qmd`.
4. **M4 — Signed Android build on GitHub Releases.** Needs D1, D2. Add `android-release.yml`.
   *Exit:* a draft release with a release-signed APK and `SHA256SUMS`; signature, 16 KB alignment
   and upgrade path checked; README availability updated.
5. **M5 — Google Play.** Needs D4, D5. *Exit:* internal track installed; closed testing done
   (if the account requires it); production release approved.
6. **M6 — TestFlight.** Needs D4. Add `ios-release.yml`. *Exit:* a processed TestFlight build
   installed on an iPhone and an iPad; the iOS journey in 4.2 passes.
7. **M7 — App Store.** *Exit:* listing complete, App Review approved, release published.
8. **M8 — F-Droid (optional).** Needs D9. *Exit:* fdroiddata merge request with a source-build
   recipe accepted, or the decision not to publish recorded here.

At each exit, update the README availability lines and `docs/current-status.qmd` with what
was actually observed.

## 6. Owner decisions and prerequisites

| ID | Decision or prerequisite | Recommendation |
|---|---|---|
| D1 | Android signing model: own app signing key uploaded to Play App Signing plus a separate upload key, or a Google-generated app signing key | Own app signing key: GitHub, Play and reproducible F-Droid builds then share one signature and users can switch channels |
| D2 | Version scheme | Tag `vX.Y.Z` sets `versionName` and `MARKETING_VERSION`; a monotonically increasing integer sets `versionCode` and `CURRENT_PROJECT_VERSION`; first signed release above `0.1.0` |
| D3 | Disposable OpenProject test instance (ideally one current release with Bearer tokens and one older release that needs Basic) with a demo user and API token reachable from the internet | Required for live acceptance, Play "App access" and App Review; never a production instance |
| D4 | Store accounts: Google Play developer account (personal or organisation) and Apple Developer Program (individual or organisation) | Check Play's rule for new personal accounts (currently a closed test with 12 opted-in testers for 14 days before production) |
| D5 | Privacy policy and support URLs | Host them on the documentation site; both stores require a privacy policy |
| D6 | Scope of editing on mobile beyond the subject (status, assignee, comments) | Keep subject-only until both platforms reach parity and pass live acceptance |
| D7 | Pagination beyond 200 projects / 100 work packages | Add offset paging on both platforms together after M3, using the `nextByOffset` link iOS already decodes |
| D8 | Offer the iPad app on Apple silicon Macs | Opt out in App Store Connect until it has been tested, consistent with macOS being "not planned" |
| D9 | F-Droid main repository with reproducible builds, or no F-Droid | Decide after M5 |
| D10 | Where CI signing secrets live: per-repository environment or organisation secrets for the suite | Per-repository `release` environment with required reviewer |
