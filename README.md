# Établi Projet

> Your OpenProject tasks in your pocket.

`iOS` `Android` · Apache-2.0 · Part of the [Établi Suite](https://github.com/etabli-dev)

Établi Projet is a client for a self-hosted OpenProject instance. Browse tasks, filter, and assign. Consumes the OpenProject HAL+JSON API with bearer-token auth, talking only to your own server.

## Availability

Établi Projet is **under active development**. There are no App Store, Google Play or F-Droid releases yet.

- **Android:** install the current **development build** as a signed **APK** from **[GitHub Releases](../../releases)**.
- **App Store (iOS):** planned — not yet available.
- **Google Play:** planned — not yet available.
- **F-Droid:** planned — not yet available.

## Privacy

No analytics. No third-party SDKs. No accounts. Credentials, where needed, live only in the platform secure store (iOS Keychain / Android EncryptedSharedPreferences). This app talks only to the self-hosted server you point it at — never to any service operated by the author.

## Repository layout

```
ios/        SwiftUI app
android/    Kotlin + Jetpack Compose app
fastlane/   F-Droid / store listing metadata
```

Both platforms are one product, sharing the Coder Design System tokens.

## Tech

iOS: SwiftUI + URLSession. Android: Compose, OkHttp, DataStore

**Status:** In active development — not yet released. Android: move the bearer token to EncryptedSharedPreferences before any public release. Dev builds available as a signed APK via [GitHub Releases](../../releases).

## Support development

- 💚 **[Liberapay](https://liberapay.com/rabanheller/)** — recurring, 0% commission, to be shown on the F-Droid listing once published.
- ☕ [Buy Me a Coffee](https://buymeacoffee.com/rabanheller) — one-off tip (also the in-app link on iOS/Android).

## License

Apache License 2.0 — see [LICENSE](LICENSE) and [NOTICE](NOTICE).

Copyright 2026 R. Heller.
