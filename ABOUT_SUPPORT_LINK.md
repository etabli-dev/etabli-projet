# In-app "Support" link

The in-app support link points to **Liberapay** — recurring support, 0% commission.

Support URL:  https://liberapay.com/rabanheller/

## iOS (SwiftUI)
```swift
Link("Support development 💚", destination: URL(string: "https://liberapay.com/rabanheller/")!)
```

## Android (Compose)
```kotlin
val ctx = LocalContext.current
TextButton(onClick = { ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://liberapay.com/rabanheller/"))) }) {
    Text("Support development 💚")
}
```

## Flutter
```dart
ListTile(title: const Text('Support 💚 (Liberapay)'),
  onTap: () => launchUrl(Uri.parse('https://liberapay.com/rabanheller/')));
```
