// Shows the checkout for a payment your server created. Run with:
//   flutter run --dart-define=PAYSTRATER_PK=pk_test_… --dart-define=PAYMENT_ID=rcv_…
import 'package:flutter/widgets.dart';
import 'package:paystrater_flutter/paystrater_flutter.dart';

// A plain WidgetsApp: the checkout needs no Material or Cupertino, so neither
// does this example. Your app can use whichever design library it likes.
void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  // Your publishable key only: anything in an app bundle is public
  static const publishableKey = String.fromEnvironment('PAYSTRATER_PK',
      defaultValue: 'pk_test_replace_me');

  // Created on your server with your secret key (POST /v1/receive-payments)
  static const paymentId =
      String.fromEnvironment('PAYMENT_ID', defaultValue: 'rcv_replace_me');

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      title: 'Paystrater checkout',
      color: const Color(0xFF285BB6),
      pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) =>
          PageRouteBuilder<T>(
              settings: settings,
              pageBuilder: (context, _, __) => builder(context)),
      home: const CheckoutPage(),
    );
  }
}

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  String? _paid;

  @override
  Widget build(BuildContext context) {
    final dark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final ink = dark ? const Color(0xFFE3E2E6) : const Color(0xFF1B1B1F);
    return ColoredBox(
      // The app surface from the Paystrater brand theme
      color: dark ? const Color(0xFF131519) : const Color(0xFFECF0F3),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Checkout',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w600, color: ink)),
              if (_paid != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Paid: $_paid', style: TextStyle(color: ink)),
                ),
              const SizedBox(height: 16),
              PaystraterCheckout(
                paymentId: ExampleApp.paymentId,
                publishableKey: ExampleApp.publishableKey,
                themeMode: PaystraterThemeMode.auto,
                // For the payer's experience only: ship the order on the incoming_payment.succeeded webhook
                onSuccess: (payment) => setState(() => _paid = payment.id),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
