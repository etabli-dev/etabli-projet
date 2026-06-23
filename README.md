# Etabli Projet

> Your OpenProject tasks in your pocket.

`iOS` `Android` · Apache-2.0 · Part of the [Etabli Suite](https://github.com/etabli-dev)

Etabli Projet is a client for a self-hosted OpenProject instance. Browse tasks, filter, and assign. Consumes the OpenProject HAL+JSON API with bearer-token auth, talking only to your own server.

## Availability

- **App Store (iOS):** available.
- **Google Play:** available.
- **F-Droid (main repo):** built from this repo's `/android` source.

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

**Status:** Complete. Android: move bearer token to EncryptedSharedPreferences before public release

## Support development

- 💚 **[Liberapay](https://liberapay.com/rabanheller/)** — recurring, 0% commission, shown on F-Droid.
- ☕ [Buy Me a Coffee](https://buymeacoffee.com/rabanheller) — one-off tip (also the in-app link on iOS/Android).

## License

Apache License 2.0 — see [LICENSE](LICENSE) and [NOTICE](NOTICE).

Copyright 2026 Raban Heller.
