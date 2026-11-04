## 0.1.0-dev.2

- Initial build: `PaystraterCheckout` widget and `Checkout` controller for Pay with Paystrater and Transfer to Pay on a publishable key, polling only while the app is in the foreground, Paystrater theme, and a method channel to open the Paystrater app, wallets and the share sheet. Plain JSON over TLS (no app-layer encryption in v1).
- Swift Package Manager support for iOS, beside CocoaPods.
- Tested with Flutter 3.38.10: `flutter analyze` clean, 27 tests, the shared core vectors, pana 160/160.
