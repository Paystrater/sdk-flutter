# paystrater_flutter

[![pub](https://img.shields.io/pub/v/paystrater_flutter)](https://pub.dev/packages/paystrater_flutter)
[![license](https://img.shields.io/github/license/Paystrater/sdk-flutter)](https://github.com/Paystrater/sdk-flutter/blob/main/LICENSE)

The Paystrater checkout for Flutter on Android and iOS: one widget, or build your own UI on its controller. Accept stablecoin and crypto payments, including USDC, USDT, ETH, BNB and SOL. Your payment settings decide which tokens and networks a payment accepts. Your server creates the payment with its secret key; the app only needs your publishable key.

## Features

- **Pay with Paystrater:** the customer enters their Paystrater ID; the SDK hands them to the Paystrater app to approve, and shows the result when they come back.
- **Transfer to Pay:** the customer sends from any wallet on the phone, with copy, share and **Open in wallet** when a wallet app can take the payment.
- **AI agent payments:** the customer gets a prompt to copy for their own AI agent, which pays within the limits they set.
- **Light and dark themes** that follow the device (`theme` and `darkTheme`), with the same variable names as `@paystrater/react`.
- **Works in any app:** Material, Cupertino or neither; it uses Flutter's widgets library only.
- **No dependencies** beyond the Flutter SDK: no `http`, no `url_launcher`, no other packages.
- **Accessible:** labelled controls with large tap areas, and steps announced to screen readers.

## Requirements

- Flutter 3.22 or later (Dart 3.4 or later).
- Android and iOS. Flutter web apps should use the hosted checkout page instead.
- A Paystrater business account, with a secret key on your server and a publishable key for the app, from the [dashboard](https://dashboard.paystrater.com).

## Install

```bash
flutter pub add paystrater_flutter
```

## Quick start

1. On your server, create the payment with your **secret key** and pass its `rcv_` ID to your app. See [Create the payment on your server](https://docs.paystrater.com/docs/sdks/flutter#create-the-payment-on-your-server) for examples in every server language.
2. Show the checkout with your **publishable key**:

```dart
import 'package:paystrater_flutter/paystrater_flutter.dart';

PaystraterCheckout(
  paymentId: paymentId,
  publishableKey: 'pk_live_…',
  onSuccess: (payment) => Navigator.of(context).pushNamed('/thanks'),
)
```

3. **Fulfil the order on the `incoming_payment.succeeded` webhook**, or after your server reads `GET /v1/transactions/{id}`. `onSuccess` is for the payer's experience only: an app can be tampered with, so never fulfil on it.

## Payment methods

- **Pay with Paystrater:** the customer enters their Paystrater ID or username; the SDK sends the request and opens `https://app.paystrater.com/pay?id=rcv_…`, which opens the Paystrater app (or, without it, a page with store links). When the customer comes back, the checkout reads the payment and shows the result.
- **Transfer to Pay:** the customer picks a network; email, name and refund address are optional. The deposit address is selectable, with copy and share, and **Open in wallet** appears when an installed wallet can open the EIP-681 `ethereum:` link. The token contract, network and chain ID sit in a collapsed **Payment details** section. There is no QR code: the payer is already on this phone.
- **AI agent payments:** the customer taps **Continue** and gets a prompt for their AI agent, with a copy button. The agent pays through Paystrater within the limits the customer set, and the checkout shows the result.

The checkout reads the payment every 4 seconds while the app is in the foreground, makes no calls in the background, reads once straight away on return, and stops at a final status.

Which tokens a customer can pay in comes from your payment settings in the dashboard: stablecoins (USDC, USDT, USDT0, PYUSD, EURC, USDG, cNGN) and coins (ETH, BNB, SOL, HYPE, WETH), each on the networks that carry it. Transfer to Pay is not available on Solana yet, so SOL and Solana tokens are paid with Pay with Paystrater.

## Platform set-up

The package has a few lines of Kotlin and Swift to open links and the share sheet.

- **Android:** nothing to add; the package declares the `ethereum` and `https` link queries Android 11 and later need.
- **iOS:** to let "Open in wallet" check for a wallet app, add `ethereum` to `LSApplicationQueriesSchemes` in `Info.plist`. Without it the button is not shown.

Already using a launcher? Pass `openUrl: (url) => yourLauncher(url)`.

## The widget

| Parameter | |
| --- | --- |
| `paymentId` | The `rcv_` ID your server created |
| `publishableKey` | `pk_live_…` or `pk_test_…`. A secret key is refused before any call |
| `chains` | Chain IDs that narrow the payment's networks for Transfer to Pay. It can only narrow |
| `themeMode` | `PaystraterThemeMode.auto` (the default: follows the device), `light` or `dark` |
| `theme`, `darkTheme` | Your `PaystraterTheme` for light and for dark mode |
| `onSuccess`, `onExpired`, `onCancelled`, `onStatusChange` | Called with the `CheckoutPayment`, for the payer's experience |
| `onError` | Called with a `PaystraterError` |
| `onStartAgain` | Shows "Start again" on an expired payment |
| `openUrl` | Your own launcher; defaults to the package's own |
| `strings` | Replace any wording, by key |
| `apiBase`, `api` | Override the API host, or replace the HTTP client (for tests) |

## Theme

```dart
PaystraterCheckout(
  themeMode: PaystraterThemeMode.auto,
  theme: PaystraterTheme.light.copyWith(colorPrimary: const Color(0xFF0F766E)),
  darkTheme: PaystraterTheme.dark.copyWith(colorPrimary: const Color(0xFF5EEAD4)),
  …
)
```

`PaystraterTheme` has the same variables and defaults as `@paystrater/react` (see its [Appearance section](https://github.com/Paystrater/sdk-react#appearance)), with sizes as numbers. Without a `darkTheme`, dark mode uses the Paystrater dark theme; Paystrater's own blue (`0xFF285BB6`) also becomes the brand's dark buttons there. A `colorPrimary` of your own gets a readable hover, button text and brand text (`PaystraterTheme.resolve`). The SDK never loads fonts: pass `fontFamily` for one your app ships. Merchant and payer names are shown capitalized, and every screen ends with "Powered by Paystrater", which opens paystrater.com.

## Accessibility

Controls are labelled with tap areas of at least 40 points, and steps and status changes are announced to screen readers. The spinner holds still when the device asks for reduced motion. In debug builds on a test key, colours under WCAG AA contrast are printed.

## Your own UI

`Checkout` is the controller under the widget: give it a `PaystraterClient` and listen to it (`ListenableBuilder`). Its actions are `choose`, `back`, `startTransferToPay`, `payWithPaystrater`, `startAgentic` and `refresh`. Its `stage` is `loading`, `methods`, `payWithPaystrater`, `transferToPay`, `agentic`, `processing`, `finalStatus`, `updating` or `unavailable`.

## Test mode

Test keys (`pk_test_…`) use the sandbox and show a Test mode chip. Approve Pay with Paystrater requests in the [sandbox app](https://sandbox.paystrater.com), or send test USDC from any wallet on a test network for Transfer to Pay ([Circle's faucet](https://faucet.circle.com) gives it out free). See the [sandbox guide](https://docs.paystrater.com/docs/sandbox).

## Errors and troubleshooting

Errors come back as a `PaystraterError` (`kind`, `status`, `message`) through `onError`. The message is the API's own words.

- **"A publishable key starts with pk_live_ or pk_test_":** pass the publishable key, not the secret key or a key with spaces.
- **The payment does not load:** check that `paymentId` is the `rcv_` ID your server created with the same mode (live or test) as the key.
- **Open in wallet is missing on iOS:** add `ethereum` to `LSApplicationQueriesSchemes`.

More in the [errors reference](https://docs.paystrater.com/docs/errors).

## Security

- A key in an app bundle is public, so only a publishable key is accepted: it can read a payment and start a deposit, never move money.
- The secret key stays on your server. The checkout refuses a secret key before making any call.
- Fulfil orders on the webhook or a server-side read, never on an app callback.

## Links

- Docs: https://docs.paystrater.com/docs/sdks/flutter
- Dashboard: https://dashboard.paystrater.com
- Changelog: [CHANGELOG.md](https://github.com/Paystrater/sdk-flutter/blob/main/CHANGELOG.md)

## License

MIT. See [LICENSE](https://github.com/Paystrater/sdk-flutter/blob/main/LICENSE).
