## 0.1.0-dev.6

- Default theme follows the updated design guideline

## 0.1.0-dev.5

- First published version with the refreshed theme. `0.1.0-dev.4` was never published.

## 0.1.0-dev.4

- Restyled the checkout to the refreshed Paystrater theme

## 0.1.0-dev.3

- Show the error and Try again when the first read fails, and keep retrying it.
- Treat a block in front of the API as temporary, and poll more slowly after a limit.

## 0.1.0-dev.2

- Initial build: `PaystraterCheckout` widget and `Checkout` controller for Pay with Paystrater and Transfer to Pay on a publishable key, polling only while the app is in the foreground, Paystrater theme, and a method channel to open the Paystrater app, wallets and the share sheet. Plain JSON over TLS (no app-layer encryption in v1).
- Swift Package Manager support for iOS, beside CocoaPods.
- Tested with Flutter 3.38.10: `flutter analyze` clean, 27 tests, the shared core vectors, pana 160/160.
