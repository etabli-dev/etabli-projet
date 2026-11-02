# Établi Projet — Android submission checklist

This guide describes the current source and release prerequisites. Observed build
and test results are recorded in [the refinement record](../docs/refinement-2026-10.md).
Compilation, local installation and Google Play acceptance are separate checks.

## Toolchain and build outputs

Use JDK 17, Android SDK Platform 36 and Build Tools 35.0.0. Set `JAVA_HOME` and
`ANDROID_HOME`; the pinned wrapper supplies Gradle 8.13 with AGP 8.13.2. The app
compiles and targets API 36 and supports API 26+. As checked on 2026-11-02, API 36
meets the [Google Play target requirement for new apps and updates](https://developer.android.com/google/play/requirements/target-sdk);
check the requirement again at submission time.

From the repository root:

```sh
cd android
./gradlew --no-daemon testDebugUnitTest lintDebug assembleDebug bundleRelease
```

| Output | Identity and signing |
|---|---|
| `app/build/outputs/apk/debug/app-debug.apk` | Android debug signing; ID `com.raban.etabli.projet.debug`, separate from release data. |
| `app/build/outputs/bundle/release/app-release.aab` | ID `com.raban.etabli.projet`; R8 and resource shrinking enabled. Unsigned unless private release signing is configured. |

An unsigned AAB is a review artifact, not a Play upload. Output existence alone
does not establish signing, device behavior or store readiness.

## Private release signing

`app/build.gradle.kts` optionally reads `android/keystore.properties`. A `storeFile`
entry enables release signing; `storePassword`, `keyAlias` and `keyPassword` must
match the private keystore. Relative `storeFile` paths resolve from `android/`;
an absolute path outside the checkout also works. Without that configuration,
release builds remain unsigned. A configured missing or invalid key fails the
build rather than silently producing a signed release.

No particular keystore, alias or password is assumed to exist. Use the upload
identity registered for this application, or establish one for a new application.
Preserve existing keys, certificates and backups; do not replace a key merely to
follow this guide. The repository ignores `keystore.properties`, `*.jks` and
`*.keystore`; keep credentials and key backups private.

[Play App Signing](https://developer.android.com/studio/publish/app-signing)
separates the upload key from the app signing key used for distributed APKs.
Configure it for bundle distribution and verify the upload certificate before
uploading. A lost upload key can be reset through Play's process; losing an
unmanaged app signing key has different consequences for updates. A debug key is
not the release upload identity.

## Implemented Android scope

- Read-only OpenProject project and assigned-work browsing over HTTPS using OkHttp and HAL+JSON. Subject editing is an iOS feature, not an Android workflow.
- The current Android client sends the API token as a Bearer credential. The token is encrypted with an app-specific Android Keystore key before persistence in DataStore; migration preserves existing settings.
- Credentials are excluded from Android cloud backup/device transfer; restored installations must reconnect. Unreadable keys fail visibly without erasing stored preferences.
- Kotlin 1.9.24, Compose, edge-to-edge layout, system-following light/dark themes and R8 rules preserving DTO field names.

## Device and release review

From `android/`, install the debug artifact on a designated test device without
clearing existing app data:

```sh
adb install -r app/build/outputs/apk/debug/app-debug.apk
adb shell am start -n com.raban.etabli.projet.debug/com.raban.etabli.projet.MainActivity
```

For the minified bundle, use [Android Studio or bundletool](https://developer.android.com/tools/bundletool)
to generate and install a test APK set with an explicitly chosen signing identity.
Without signing options, bundletool may use a debug key; this does not validate the
Play upload certificate. Keep test installs separate from any production release
whose data and signing identity must be preserved.

- [ ] Run tests, lint and debug/release packaging for the exact candidate commit; retain results and artifact hashes.
- [ ] Inspect the final APK/AAB manifest and verify minimum/target SDK, requested permissions, signatures and native-library/ZIP alignment. Keep 16 KiB-device execution separate from static alignment checks.
- [ ] On a designated test account, connect to the canonical HTTPS OpenProject URL, browse Projects and My Work and exercise failure/cancellation paths.
- [ ] Verify encrypted credential migration and unreadable-key handling, account persistence and reconnect after backup restore. Preserve real account settings and server work packages.
- [ ] Check rotation, insets, large text, accessibility and the minified release variant; retain documented project/work-package result limits.
- [ ] Configure and verify the private upload key, Play App Signing, release version code and recovery backups. Generate and inspect the signed release candidate.
- [ ] Provide a working privacy-policy URL and in-app policy access. Complete [Data safety and SDK review](https://support.google.com/googleplay/android-developer/answer/10144311?hl=en) against the actual artifact. Describe configured-server authentication and project/work requests, encrypted local tokens and backup exclusions; fixture tests do not establish a production OpenProject connection. Do not substitute a blanket “no third-party SDKs” assertion.
- [ ] Prepare listing text, icon, feature graphic and screenshots of the current app. Complete content rating, accurate target audience, app category, advertising declaration, pricing and distribution in Play Console.
- [ ] Complete applicable permission declarations and account-specific testing/release requirements. Validate the signed candidate on an internal test track before requesting production rollout.

Publishing source or documentation does not publish an Android app. A signed
release, Play upload, policy approval and production rollout require their own
recorded outcomes.
