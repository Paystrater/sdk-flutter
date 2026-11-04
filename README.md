# paystrater_flutter

The Paystrater checkout for Flutter on Android and iOS. Customers pay with **Pay with Paystrater** (the SDK hands them to the Paystrater app to approve) or **Transfer to Pay** (they send from any wallet). It depends on the Flutter SDK only: no `http`, no `url_launcher`, no other packages.

```bash
flutter pub add paystrater_flutter
```

## Quick start

1. On your server, create the payment with your **secret key** (`POST /v1/receive-payments`) and send its `rcv_` ID to the app.
2. Show the checkout with your **publishable key**:

```dart
import 'package:paystrater_flutter/paystrater_flutter.dart';

PaystraterCheckout(
  paymentId: paymentId,
  publishableKey: 'pk_live_…',
  onSuccess: (payment) => Navigator.of(context).pushNamed('/thanks'),
)
```

3. **Ship the order on the `incoming_payment.succeeded` webhook**, or after your server reads `GET /v1/transactions/{id}`. `onSuccess` is for the payer's experience only: an app can be tampered with, so never fulfil on it.

A key in an app bundle is public, which is why only a publishable key is accepted; a secret key is refused before any call. Test keys (`pk_test_…`) use the sandbox and show a Test mode ribbon.

## What it does

- **Pay with Paystrater:** the customer enters their Paystrater ID or username; the SDK sends the request and opens `https://app.paystrater.com/pay?id=rcv_…`, which opens the Paystrater app (or, without it, a page with store links). When the customer comes back, the checkout reads the payment and shows the result.
- **Transfer to Pay:** the customer picks a network; email, name and refund address are optional. The deposit address is selectable, with copy (Flutter's own clipboard) and share. **Open in wallet** appears when an installed wallet can open the EIP-681 `ethereum:` link. The token contract, network and chain ID sit in a collapsed **Payment details** section. No QR code: the payer is already on this phone.
- **Agent payments** are not an app flow: your server gives the payment's `agentPrompt` to the customer's agent.
- The checkout reads the payment every 4 seconds while the app is in the foreground, makes no calls in the background, reads once straight away on return, and stops at a final status.

## Platform set-up

The package has a few lines of Kotlin and Swift to open links and the share sheet.

- **Android:** nothing to add; the package declares the `ethereum` and `https` link queries Android 11+ needs.
- **iOS:** to let "Open in wallet" check for a wallet, add `ethereum` to `LSApplicationQueriesSchemes` in `Info.plist`. Without it the button is not shown.

Already using a launcher? Pass `openUrl: (url) => yourLauncher(url)`.

## Theme

```dart
PaystraterCheckout(
  themeMode: PaystraterThemeMode.auto, // light, dark or auto
  theme: PaystraterTheme.light.copyWith(colorPrimary: const Color(0xFF285BB6)),
  …
)
```

`PaystraterTheme` uses the same variable names as `@paystrater/react`. The defaults are the Paystrater design. The SDK never loads fonts: pass `fontFamily` for one your app ships. In debug builds on a test key, colours under WCAG AA contrast are printed. Controls are at least 44 points tall, labelled, and announced to screen readers.

## Encryption

Not in v1. The checkout sends plain JSON over TLS, which Android and iOS enforce. Dart's core libraries have no secp256k1 or AES-GCM, and adding them would mean a crypto package. The checkout carries a payment ID, a chain and an optional email, never a secret.

## Your own UI

`Checkout` is the controller under the widget: give it a `PaystraterClient` and listen to it (`ListenableBuilder`). Its `stage` is `loading`, `methods`, `payWithPaystrater`, `transferToPay`, `agentic`, `processing`, `finalStatus`, `updating` or `unavailable`.

v1 supports Android and iOS. Flutter web apps should use the hosted checkout page.

Docs: https://docs.paystrater.com/docs/sdks/flutter
