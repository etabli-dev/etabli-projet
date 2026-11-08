# Apple build and roadmap refinement — 2026-11-08

## iOS project and work-package metadata parity

Project rows include non-empty description excerpts (up to 200 characters). Both My work and project work-package lists include priority. Existing optimistic-locking edit behavior is unchanged; Android project/detail/edit parity remains open.

## Verification

- `python3 scripts/check_swift.py` passed: production Foundation typecheck, Swift source parse and client fixture checks.
- Full unsigned iOS simulator build passed with Xcode 27.2 and iOS 27.2 SDK, using the repository's scheme and `CODE_SIGNING_ALLOWED=NO`.
- The build includes the UI changes above.
- No live service, physical device, signed archive or store upload was tested. Simulator installation/interactive journeys remain separate from compilation.

Local command logs are in the fleet audit directory `native-apple/`; they are not runtime data or release artifacts.
