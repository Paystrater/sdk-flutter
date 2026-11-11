import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paystrater_flutter/paystrater_flutter.dart';

import 'fakes.dart';

Widget host(Widget child) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.paystrater.flutter/links'),
      (call) async {
        calls.add(call);
        return call.method == 'canOpenUrl' ? false : true;
      },
    );
  });

  testWidgets(
      'offers Pay with Paystrater and Transfer to Pay, not the agent, with a Test mode ribbon',
      (tester) async {
    await tester.pumpWidget(host(PaystraterCheckout(
        paymentId: id,
        publishableKey: 'pk_test_x',
        api: FakeApi(read: () => okPayment()))));
    await tester.pump();
    expect(find.text('Pay with Paystrater'), findsOneWidget);
    expect(find.text('Transfer to Pay'), findsOneWidget);
    expect(find.text('Pay with an AI agent'), findsNothing);
    expect(find.text('Test mode'), findsOneWidget);
    expect(find.text('Acme Shoes'), findsOneWidget);
  });

  testWidgets(
      'shows the deposit: selectable address, copy, share, details closed, no QR',
      (tester) async {
    final api = FakeApi(
        read: () => okPayment({
              'method': 'transfer_to_pay',
              'methods': null,
              'chainId': 8453,
              'chainName': 'Base',
              'transferToPay': ttpJson
            }));
    await tester.pumpWidget(host(PaystraterCheckout(
        paymentId: id, publishableKey: 'pk_test_x', api: api)));
    await tester.pump();
    expect(find.text('Send exactly 25.25 USDC on Base'), findsOneWidget);
    expect(
        find.widgetWithText(
            SelectableText, '0xdbF03B407c01E7cD3CBea99509d93f8DDDC8C6FB'),
        findsOneWidget);
    expect(
        find.text('0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913'), findsNothing);
    await tester.tap(find.text('Share address'));
    expect(calls.map((c) => c.method), contains('share'));
    await tester.tap(find.text('Payment details'));
    await tester.pump();
    expect(
        find.widgetWithText(
            SelectableText, '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913'),
        findsOneWidget);
    // canOpenUrl answered false, so no wallet button
    expect(find.text('Open in wallet'), findsNothing);
  });

  testWidgets('opens the Paystrater app after sending a request',
      (tester) async {
    final opened = <String>[];
    var sent = false;
    final api = FakeApi(
      read: () => sent
          ? okPayment({
              'method': 'pay_with_paystrater',
              'payer': {'name': 'Ada Lovelace'}
            })
          : okPayment(),
      pay: () {
        sent = true;
        return okPayment({
          'method': 'pay_with_paystrater',
          'payer': {'name': 'Ada Lovelace'}
        });
      },
    );
    await tester.pumpWidget(host(PaystraterCheckout(
      paymentId: id,
      publishableKey: 'pk_test_x',
      api: api,
      openUrl: (url) async {
        opened.add(url);
        return true;
      },
    )));
    await tester.pump();
    await tester.tap(find.text('Pay with Paystrater'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'ada');
    await tester.tap(find.text('Send to my app'));
    await tester.pump();
    await tester.pump();
    expect(opened, ['https://app.paystrater.com/pay?id=$id']);
    expect(find.text('Sent to Ada Lovelace'), findsOneWidget);
  });

  testWidgets('shows the end states', (tester) async {
    final states = <Map<String, Object?>, String>{
      {'status': 'succeeded'}: 'Paid',
      {
        'status': 'expired',
        'method': 'transfer_to_pay',
        'transferToPay': {...ttpJson, 'receivedAmount': '10'}
      }: 'You sent less than the amount',
      {'status': 'cancelled'}: 'This payment was cancelled',
      {'status': 'processing'}: 'Payment received, confirming',
    };
    for (final e in states.entries) {
      await tester.pumpWidget(host(PaystraterCheckout(
          key: UniqueKey(),
          paymentId: id,
          publishableKey: 'pk_test_x',
          api: FakeApi(read: () => okPayment(e.key)))));
      await tester.pump();
      expect(find.text(e.value), findsOneWidget, reason: e.value);
    }
  });

  testWidgets('shows the error and Try again when the first read fails',
      (tester) async {
    await tester.pumpWidget(host(PaystraterCheckout(
        paymentId: id,
        publishableKey: 'pk_test_x',
        api: FakeApi(
            read: () => CallResult<CheckoutPayment>.fail(const PaystraterError(
                ErrorKind.network, 0, "We couldn't reach Paystrater."))))));
    await tester.pump();
    expect(find.textContaining("couldn't reach Paystrater"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('refuses a secret key and says why', (tester) async {
    await tester.pumpWidget(host(const PaystraterCheckout(
        paymentId: id, publishableKey: 'sk_live_oops')));
    await tester.pump();
    expect(find.textContaining('secret key'), findsOneWidget);
  });

  test('the default theme is the Paystrater design and passes WCAG AA', () {
    expect(PaystraterTheme.light.colorPrimary, const Color(0xFF285BB6));
    expect(PaystraterTheme.dark.colorPrimary, const Color(0xFFA2AED1));
    expect(PaystraterTheme.dark.colorOnPrimary, const Color(0xFF131519));
    expect(contrastWarnings(PaystraterTheme.light), isEmpty);
    expect(contrastWarnings(PaystraterTheme.dark), isEmpty);
    expect(
        contrastWarnings(PaystraterTheme.light
            .copyWith(colorPrimary: const Color(0xFF9FC5FF))),
        isNotEmpty);
  });
}
