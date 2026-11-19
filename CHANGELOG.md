## 0.1.0-dev.8

- AI agent payments: a third method tile, "Pay with an AI agent". Continue starts the payment (POST /v1/checkout/agentic) and shows the prompt to copy for the customer's agent. New: `Checkout.startAgentic` and `CheckoutApi.startAgentic`
- "Send to my app" no longer opens the Paystrater app by itself: the request is sent, the checkout shows the approve step, and the app opens only when the customer taps "Open the Paystrater app"
- The amount due is bold (700, was 600), and so is the total under the deposit address on Transfer to Pay
- Copy speaks of the business being paid, not "the shop"; "Not your account?" now says to go back and start again with the right Paystrater ID
- New package description and topics (stablecoin and crypto payments, AI agents), and a rewritten README

## 0.1.0-dev.7

- The checkout looks like the web SDK and the sandbox app: method tiles with icons, pill buttons, the amount in the brand colour, "← <method>" under each step and "Powered by Paystrater" under every screen
- Dark mode keeps the brand dark buttons when the theme uses Paystrater blue; a custom colorPrimary gets a readable hover, button text and brand text (WCAG AA). New: PaystraterTheme.resolve, readableOn, capitalizeWords
- Names are capitalized; amounts show at least two decimals
- A publishable key is checked by its pk_live_ or pk_test_ prefix only; a key with a space or line break is refused with a clear message

## 0.1.0-dev.6

- Default theme follows the updated design guideline
- The checkout no longer uses Material (deprecated in Flutter 3.47). It is drawn with Flutter's widgets library only, so it works in Material, Cupertino or plain apps and still needs Flutter 3.22 or later with no other dependencies. The text fields have their own Cut, Copy, Paste and Select all menu, and the amount and token contract get Copy links

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
