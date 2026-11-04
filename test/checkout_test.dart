// The checkout flow and polling, the same cases as
// @paystrater/react's test/core/checkout.test.ts. testWidgets runs the
// controller's timers on fake time.
import 'package:flutter_test/flutter_test.dart';
import 'package:paystrater_flutter/src/checkout.dart';
import 'package:paystrater_flutter/src/client.dart';
import 'package:paystrater_flutter/src/models.dart';

import 'fakes.dart';

Checkout make(FakeApi api,
        {FakeActivity? activity, List<String>? events, List<int>? chains}) =>
    Checkout(
      api: api,
      paymentId: id,
      chains: chains,
      activity: activity ?? FakeActivity(),
      onSuccess: (_) => events?.add('success'),
      onExpired: (_) => events?.add('expired'),
      onCancelled: (_) => events?.add('cancelled'),
      onError: (e) => events?.add('error:${e.status}'),
    );

void main() {
  testWidgets('offers the methods in the documented order and never Solana',
      (tester) async {
    final c = make(FakeApi(read: () => okPayment()))..start();
    await tester.pump();
    expect(c.stage, Stage.methods);
    expect(c.methods, ['pay_with_paystrater', 'transfer_to_pay', 'agentic']);
    expect(c.chains.map((x) => x.chainName), ['Base', 'Polygon']);
    c.dispose();
  });

  testWidgets('narrows chains, never widens; a fixed method skips the picker',
      (tester) async {
    final narrowed = make(FakeApi(read: () => okPayment()), chains: [137, 999])
      ..start();
    await tester.pump();
    expect(narrowed.chains.map((x) => x.chainId), [137]);
    narrowed.dispose();
    final fixed = make(FakeApi(
        read: () => okPayment({'method': 'transfer_to_pay', 'methods': null})))
      ..start();
    await tester.pump();
    expect(fixed.stage, Stage.transferToPay);
    fixed.dispose();
  });

  testWidgets('lets the payer go back until a start call locks the method',
      (tester) async {
    final c = make(FakeApi(read: () => okPayment()))..start();
    await tester.pump();
    c.choose('transfer_to_pay');
    expect(c.stage, Stage.transferToPay);
    c.back();
    expect(c.stage, Stage.methods);
    c.dispose();
  });

  testWidgets(
      'Transfer to Pay sends only the fields given and checks the refund address first',
      (tester) async {
    var started = false;
    final api = FakeApi(
      read: () => started
          ? okPayment({
              'method': 'transfer_to_pay',
              'methods': null,
              'chainId': 8453,
              'chainName': 'Base',
              'transferToPay': ttpJson
            })
          : okPayment(),
      start: () {
        started = true;
        return CallResult.ok(TransferToPayStart.fromJson(startJson));
      },
    );
    final c = make(api)..start();
    await tester.pump();
    c.choose('transfer_to_pay');
    expect(
        (await c.startTransferToPay(chainId: 8453, refundAddress: '0x123'))
            .field,
        FieldProblem.refundAddressFormat);
    expect(
        (await c.startTransferToPay(
                chainId: 8453,
                refundAddress: '0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAeD'))
            .field,
        FieldProblem.refundAddressChecksum);
    expect(
        (await c.startTransferToPay(chainId: 8453, payerEmail: 'nope')).field,
        FieldProblem.email);
    expect(
        (await c.startTransferToPay(chainId: 101)).field, FieldProblem.chain);
    expect(api.bodies, isEmpty);
    expect((await c.startTransferToPay(chainId: 8453)).ok, isTrue);
    expect(api.bodies.single, {
      'receivePaymentId': id,
      'chainId': 8453,
      'payerEmail': null,
      'payerName': null,
      'refundAddress': null
    });
    await tester.pump();
    expect(c.deposit?.amount, '25.25');
    expect(c.deposit?.fee, '0.25');
    expect(c.deposit?.tokenDecimals, 6);
    c.dispose();
  });

  testWidgets('retries the start once when the deposit address was taken (500)',
      (tester) async {
    var posts = 0;
    final api = FakeApi(
      read: () => okPayment(),
      start: () => posts++ == 0
          ? failWith(500, 'The deposit address was taken; please try again')
          : CallResult.ok(TransferToPayStart.fromJson(startJson)),
    );
    final c = make(api)..start();
    await tester.pump();
    c.choose('transfer_to_pay');
    expect((await c.startTransferToPay(chainId: 8453)).ok, isTrue);
    expect(posts, 2);
    c.dispose();
  });

  testWidgets('resumes from transferToPay after a reload', (tester) async {
    final c = make(FakeApi(
        read: () => okPayment({
              'method': 'transfer_to_pay',
              'methods': null,
              'chainId': 8453,
              'chainName': 'Base',
              'transferToPay': {...ttpJson, 'receivedAmount': '10'}
            })))
      ..start();
    await tester.pump();
    expect(c.stage, Stage.transferToPay);
    expect(c.deposit?.depositAddress, ttpJson['depositAddress']);
    expect(c.deposit?.receivedAmount, '10');
    c.dispose();
  });

  testWidgets('tells underpaid from late from an empty expiry', (tester) async {
    Map<String, Object?> expired(String? received) => {
          'status': 'expired',
          'method': 'transfer_to_pay',
          'transferToPay': {
            ...ttpJson,
            if (received != null) 'receivedAmount': received
          },
        };
    final short = make(FakeApi(read: () => okPayment(expired('10'))))..start();
    final lateOne = make(FakeApi(read: () => okPayment(expired('25.25'))))
      ..start();
    final none = make(FakeApi(read: () => okPayment(expired(null))))..start();
    await tester.pump();
    expect([short.underpaid, short.arrivedLate], [true, false]);
    expect([lateOne.underpaid, lateOne.arrivedLate], [false, true]);
    expect([none.underpaid, none.arrivedLate], [false, false]);
    for (final c in [short, lateOne, none]) {
      expect(c.stage, Stage.finalStatus);
      c.dispose();
    }
  });

  testWidgets('Pay with Paystrater needs a payer and shows who it was sent to',
      (tester) async {
    final api = FakeApi(
      read: () => okPayment({
        'method': 'pay_with_paystrater',
        'payer': {'name': 'Ada Lovelace'}
      }),
      pay: () => okPayment({
        'method': 'pay_with_paystrater',
        'payer': {'name': 'Ada Lovelace'}
      }),
    );
    final c = make(api)..start();
    await tester.pump();
    expect((await c.payWithPaystrater('  ')).field, FieldProblem.payerRequired);
    expect((await c.payWithPaystrater('ada')).ok, isTrue);
    expect(api.bodies.single, {'receivePaymentId': id, 'payer': 'ada'});
    expect(c.payment?.payer?.name, 'Ada Lovelace');
    c.dispose();
  });

  testWidgets(
      'polls every 4 seconds while in the foreground and stops at a final status',
      (tester) async {
    var n = 0;
    final events = <String>[];
    final api = FakeApi(
        read: () =>
            okPayment({'status': ++n >= 3 ? 'succeeded' : 'requires_action'}));
    final c = make(api, events: events)..start();
    await tester.pump();
    expect(api.reads, 1);
    await tester.pump(const Duration(seconds: 4));
    expect(api.reads, 2);
    await tester.pump(const Duration(seconds: 4));
    expect(api.reads, 3);
    expect(c.stage, Stage.finalStatus);
    await tester.pump(const Duration(seconds: 20));
    expect(api.reads, 3);
    expect(events, ['success']);
    c.dispose();
  });

  testWidgets('makes no calls in the background and reads once on return',
      (tester) async {
    final activity = FakeActivity();
    final api = FakeApi(read: () => okPayment());
    final c = make(api, activity: activity)..start();
    await tester.pump();
    activity.set(false);
    await tester.pump(const Duration(seconds: 60));
    expect(api.reads, 1);
    activity.set(true);
    await tester.pump();
    expect(api.reads, 2);
    c.dispose();
  });

  testWidgets('slows to every 10 seconds while RateLimit-Remaining is under 50',
      (tester) async {
    var remaining = 49;
    final api = FakeApi(
        read: () => okPayment(const {}, RateLimit(remaining: remaining)));
    final c = make(api)..start();
    await tester.pump();
    expect(c.slowed, isTrue);
    await tester.pump(const Duration(seconds: 9));
    expect(api.reads, 1);
    remaining = 50;
    await tester.pump(const Duration(seconds: 1));
    expect(api.reads, 2);
    expect(c.slowed, isFalse);
    c.dispose();
  });

  testWidgets('waits for Retry-After on a 429', (tester) async {
    var n = 0;
    final api = FakeApi(
        read: () => n++ == 1
            ? failWith(429, 'Too many requests.', retryAfter: 30)
            : okPayment());
    final c = make(api)..start();
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(api.reads, 2);
    await tester.pump(const Duration(seconds: 29));
    expect(api.reads, 2);
    await tester.pump(const Duration(seconds: 1));
    expect(api.reads, 3);
    c.dispose();
  });

  testWidgets(
      'shows the unavailable stage for a missing payment or a wrong key',
      (tester) async {
    final events = <String>[];
    final missing = make(
        FakeApi(read: () => failWith(404, 'Payment not found')),
        events: events)
      ..start();
    await tester.pump();
    expect(missing.stage, Stage.unavailable);
    expect(events, ['error:404']);
    missing.dispose();
    final wrongKey = Checkout(
        api: PaystraterClient(publishableKey: 'sk_live_x'), paymentId: id)
      ..start();
    expect(wrongKey.stage, Stage.unavailable);
    expect(wrongKey.error?.kind, ErrorKind.setup);
    wrongKey.dispose();
  });
}
