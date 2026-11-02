# October 2026 refinement

## API-token compatibility plan — 2026-11-02

The [current OpenProject API contract](https://www.openproject.org/docs/api/introduction/#authentication)
accepts personal API tokens as Bearer or Basic credentials. Bearer support for
newly generated personal tokens arrived in [OpenProject 17.2](https://www.openproject.org/docs/release-notes/17-2-0/);
older servers require Basic with username `apikey`. At the start of this
increment, both clients sent Bearer unconditionally, while setup instructions
gave no server-version boundary.

Repair the connection handshake on both platforms: try Bearer first on the safe
`GET /api/v3/users/me`, then retry that same HTTPS request once with Basic only
after HTTP 401. Both attempts must share the existing 45-second budget. Persist
the successful authentication mode atomically with validated credentials; records
without a mode retain Bearer. Ordinary requests and subject updates use the saved
mode without authentication retries. Keep failed-candidate preservation,
cancellation, encrypted storage and Disconnect's generation guard intact.

Acceptance: header-dependent fixtures cover current Bearer and Basic-only
servers, restored old/new records, invalid credentials preserving the old
account, no fallback after non-401 failures, one retry only, and Disconnect during
the fallback. Swift updates must send the selected mode once without retrying a
mutation. Update setup/release documentation and retain separate local build,
remote CI and live-server evidence. No real-server acceptance is inferred from
these fixtures.

## API-token compatibility implementation and evidence — 2026-11-02

Both clients now negotiate only while connecting a candidate account. They send
Bearer first and retry the same HTTPS `GET /api/v3/users/me` once with Basic
`apikey:<token>` only after HTTP 401. Redirects remain disabled; HTTP 403, server
errors, transport failures and invalid identity responses do not trigger a
fallback. Both attempts share the 45-second connection budget. Later connection
checks, reads and Swift subject updates use the saved method without negotiation
or mutation retries.

The verified method is saved together with the URL and encrypted token in one
Android DataStore transaction or the existing Swift Keychain envelope. Older
records without a method retain Bearer; reconnecting can select Basic. Failed
candidate checks preserve the existing account, and disconnect/cancellation
guards still prevent a delayed response from restoring it. Basic must be enabled
on a server that needs it. OAuth sign-in and token refresh are outside this
personal-token setup.

Local `python3 scripts/check_swift.py` passed in
`projet-auth-swift-r2-20261102` on 2026-11-02. The production Foundation client and
real Keychain wrapper typechecked, all SwiftUI files parsed, and executable
fixtures checked header-dependent Bearer/Basic behavior, the remaining request
timeout, persisted Basic restoration, both older Bearer storage formats, failed
configuration and secure-write preservation, bounded retries, a single rejected
PATCH and disconnect during a delayed Basic response. These fixtures use a fake
Keychain and URLProtocol; they do not establish live-server acceptance or a full
iOS application build for this increment.

The Android TLS regressions cover Basic-only and current Bearer servers,
persisted/restored modes, legacy credential migration, failure preservation,
non-401 responses, delayed disconnect and the shared deadline. On 2026-11-02,
`testDebugUnitTest lintDebug assembleDebug bundleRelease` passed in
`projet-auth-android-20261102`. JUnit XML records 13 tests (eight client and five
credential-cipher tests), with zero failures, errors or skips. The debug APK and
unsigned release AAB include this increment. Earlier CI and device results below
apply to their dated source states. Independent read-only review found no
material authentication defect. Real OpenProject accounts, installed UI flows,
release signing and store acceptance remain separate gates.

## First published CI run and follow-up

On 2026-10-31, the [first published verification run](https://github.com/etabli-dev/etabli-projet/actions/runs/41200110679) failed in the Android SDK installation step with `sdkmanager: command not found` (exit 127), before Android tests, lint or packaging ran. The workflow now explicitly installs Android command-line tools using `android-actions/setup-android` v4.0.4, pinned to its verified commit, before requesting API 36 and build-tools 35.0.0. Existing checks and artifact collection remain intact. YAML and the action reference were checked locally before the follow-up run. Earlier local build and device evidence below remains separate from this failed remote run.

Later on 2026-10-31, the [follow-up verification run](https://github.com/etabli-dev/etabli-projet/actions/runs/41200530308) passed for [commit `718f7597603c`](https://github.com/etabli-dev/etabli-projet/commit/718f7597603cdac5a3c300f866656727fad04e1b): Android `testDebugUnitTest lintDebug assembleDebug bundleRelease` and the full unsigned iOS simulator build succeeded. The [documentation build and deployment](https://github.com/etabli-dev/etabli-projet/actions/runs/41200530495) also passed for that commit. These results verify compilation and the recorded automated checks; installed application journeys, release signing and store acceptance remain separate gates.

## Scope and acceptance

Harden the existing self-hosted client without changing server APIs or deleting user configuration. Required gates: reproducible Android unit tests, lint and APK build; secure credential migration; explicit network failures; accurate setup and platform status. iOS device and live-server acceptance are separate gates.

## Findings and roadmap

| Finding | Evidence and impact | Action / validation |
|---|---|---|
| Major: plaintext API token | Android network client persists the token in ordinary preferences DataStore, contrary to the privacy statement. | Encrypt using an app-specific Android Keystore AES-256-GCM key; bind ciphertext to the configured server. Test round-trip, tampering, changed server, lost key and legacy migration. |
| Major: credential backup | Backup configuration says there is no personal information and includes the default data. | Exclude the credential DataStore from cloud backup and device transfer on both Android backup schemas. Restored installations must reconnect. |
| Verification gap | At baseline, CI built documentation only and there were no tracked application tests. | Add meaningful regression tests and Android build checks; exercise the real server separately. |

## Implemented increment

The encrypted token and legacy-key removal are written in one DataStore transaction. Existing plaintext tokens migrate on the first authenticated request; failed encryption retains the original settings. Unreadable ciphertext is refused with a reconnect instruction, never used as an authentication token. No additional production dependency is introduced.

Crypto follows the [Android Keystore documentation](https://developer.android.com/reference/android/security/keystore/KeyGenParameterSpec). JVM tests cover encryption and migration logic. The [device coverage below](#android-keystore-device-coverage) records four passing production-Keystore tests on the API 36 emulator with 4 KiB pages; physical-device hardware backing and backup restoration remain unverified.

## Verification

The first Android build overlapped provisioning/security edits and is not treated as an unchanged-source baseline. Subsequent API 36 and server-workflow builds passed; exact later receipts supersede that initial run.

## First use

Install JDK 17, Android SDK Platform 36 and Build Tools 35.0.0, set `ANDROID_HOME`, then run `cd android && ./gradlew testDebugUnitTest lintDebug assembleDebug`. The development APK is `app/build/outputs/apk/debug/app-debug.apk`. Configure your own server in Settings. Never commit credentials or signing files. Xcode and a device/simulator are required for separate iOS acceptance.

## Android submission compatibility milestone

The baseline targeted API 34, below the [current Google Play submission requirement](https://developer.android.com/google/play/requirements/target-sdk). Compile/target SDK now move to 36 while retaining minimum SDK 26. AGP 8.13.2, Gradle 8.13 (distribution SHA-256 pinned), and JDK 17 are a [documented compatible toolchain](https://developer.android.com/build/releases/agp-8-13-0-release-notes). The API 27 navigation-bar attribute is now in qualified resources; Android 8.0 uses a dark navigation bar so its white icons remain visible. Validate tests, lint, debug APK and unsigned release packaging after migration. Device checks must cover insets, predictive back, rotation and existing saved data.

## Server workflow increment

Confirmed in the clients: response bodies are read without a limit, redirects are
followed implicitly on authenticated requests, and broad Throwable catches obscure
cancellation. Missing list fields are treated as empty results, hiding malformed
server responses. Keep existing encrypted credentials and identifiers; add a
cancellable, bounded HTTPS transport, strict required response fields and failure
fixtures using normal TLS trust. Inject the existing preference store and cipher
for JVM integration tests rather than replacing production client behavior.

Acceptance: real token/configuration → list/search/details requests against TLS
fixtures; unauthorized, malformed and oversized replies fail visibly; cancellation
closes active work; a failed connect preserves the previous configuration. Then
run tests, lint and debug/release packaging, reconcile first-use/product scope,
and keep live-server/device acceptance separate.

## Server increment results

Android now validates the candidate connection before replacing stored credentials,
uses cancellable requests with 8 MiB JSON bounds, refuses authenticated redirects
and rejects missing required response fields. TLS integration plus the existing
crypto/migration suite pass 7 tests. `testDebugUnitTest lintDebug assembleDebug
bundleRelease` passed in `projet-server-r1`; the final screen changes have a separate
`projet-server-final` receipt. Screen loads cancel previous work so an older search
or row selection cannot overwrite a newer one. Optional tag-name failures in Doc
no longer hide otherwise valid documents.

Swift client tests pass with a fake Keychain and URLProtocol responses, including
failed configuration preservation and actual account restore. The production
Foundation sources, including the real Keychain wrapper, typecheck locally;
SwiftUI sources parsed locally; the full unsigned simulator build later passed
in the 2026-10-31 CI run above. Credentials now
use one server/token Keychain envelope, with legacy reads preserved. JSON requests
are cancellable and bounded; Doc downloads stream to a temporary file with a
256 MiB bound. UI loads reject responses from older selections/accounts.

Package inspection: all produced 64-bit ELF load segments and APK entries meet
16 KiB alignment; the AAB contains no signing block. The 2026-10-31 remote CI
outcome is recorded above. The README gives exact setup commands and current
platform differences. Live server/device acceptance, release signing and store
submission remain external gates.

Final screen revisions were followed by another complete local Android test/lint/debug APK/release AAB run and `python3 scripts/check_swift.py`; both passed on 2026-10-30. Production Foundation clients and Keychain code typechecked; all SwiftUI files parsed. The full unsigned iOS simulator build subsequently passed in the 2026-10-31 CI run above; it was not run locally because Xcode is absent.

## Local account lifecycle review

Disconnect remained available while a candidate connection was awaiting its server response. An older successful reply could then persist credentials after Disconnect had completed. Connection attempts now carry a generation checked inside the DataStore write; disconnect invalidates that generation before clearing settings. A TLS fixture holds the candidate response until after disconnect, then verifies cancellation and an empty stored configuration. Disconnect remains available during connection attempts.

## Android Keystore device coverage

The device test suite uses the production `CredentialCipher.android` implementation with test-only aliases and temporary DataStore files. It checks randomized encryption, a non-exportable key, decryption through a fresh cipher instance, wrong-server and altered-ciphertext rejection, durable legacy migration after reopening DataStore, and preservation of saved preferences when the Keystore key disappears. It never opens the app account store or removes a production key.

Run on an attached emulator or test device from `android/`: `./gradlew connectedDebugAndroidTest`. These checks complement the injected-key JVM tests; they do not establish physical-device hardware backing or account-server compatibility.

Final native build evidence (2026-10-30, inspected 2026-10-31): `testDebugUnitTest lintDebug assembleDebug bundleRelease` passed in `projet-android-device-prep`. The JUnit XML records 8 tests, zero failures, errors or skips. The delayed-login regression confirms Disconnect remains effective after an older successful reply. Debug APK and unsigned release AAB include these changes. Installed user journeys and signing/store acceptance remain separate gates.

Device verification on 2026-10-31: `connectedDebugAndroidTest` passed in `projet-android-keystore-device-r2`. The Android 16/API 36 ARM64 AOSP test emulator (`etabli_api36_atd`, 4 KiB pages) ran all four production-Keystore tests with zero failures, errors or skips. JUnit XML confirms randomized encryption/non-exportable-key reopening, wrong-server and altered-ciphertext rejection, durable legacy migration, and preservation after key loss. The emulator was stopped after all three applications completed. This verifies the Android Keystore/storage paths on that emulator; it does not establish physical-device hardware backing, 16 KiB runtime, UI workflows, live-server compatibility, backup restoration or release signing.
