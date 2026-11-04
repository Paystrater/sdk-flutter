// Shows the checkout for a payment your server created. Run with:
//   flutter run --dart-define=PAYSTRATER_PK=pk_test_… --dart-define=PAYMENT_ID=rcv_…
import 'package:flutter/material.dart';
import 'package:paystrater_flutter/paystrater_flutter.dart';

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
    return const MaterialApp(
        title: 'Paystrater checkout', home: CheckoutPage());
  }
}

class CheckoutPage extends StatelessWidget {
  const CheckoutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: PaystraterCheckout(
            paymentId: ExampleApp.paymentId,
            publishableKey: ExampleApp.publishableKey,
            // For the payer's experience only: ship the order on the incoming_payment.succeeded webhook
            onSuccess: (payment) => ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('Paid: ${payment.id}'))),
          ),
        ),
      ),
    );
  }
}
