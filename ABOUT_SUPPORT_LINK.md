# In-app "Support" link — store builds (iOS / Android)

The in-app support link on App Store and Google Play builds points to
**Buy Me a Coffee**. Liberapay is the F-Droid / GitHub surface.

Support URL:  https://buymeacoffee.com/rabanheller

## iOS (SwiftUI)
```swift
Link("Support development ☕", destination: URL(string: "https://buymeacoffee.com/rabanheller")!)
```

## Android (Compose)
```kotlin
val ctx = LocalContext.current
TextButton(onClick = { ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://buymeacoffee.com/rabanheller"))) }) {
    Text("Support development ☕")
}
```
