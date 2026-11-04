// The Dart models read the spec's own examples (test/fixtures/spec_examples.json,
// built from developer-api.yaml), so a renamed field fails here.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paystrater_flutter/src/models.dart';

void main() {
  final fixtures =
      jsonDecode(File('test/fixtures/spec_examples.json').readAsStringSync())
          as Map<String, dynamic>;

  test('CheckoutPayment reads ReceivePayment', () {
    final json = (fixtures['checkoutPayment'] as Map).cast<String, Object?>();
    final p = CheckoutPayment.fromJson(json);
    expect(p.id, json['id']);
    expect(p.status, json['status']);
    expect(p.amount, json['amount']);
    expect(p.tokenTicker, json['tokenTicker']);
    expect(p.feeBearer, json['feeBearer']);
    expect(p.expiresAt, json['expiresAt']);
    expect(p.livemode, json['livemode']);
    expect(p.chainId, json['chainId']);
    expect(p.successUrl, json['successUrl']);
    final ttp = (json['transferToPay'] as Map).cast<String, Object?>();
    expect(p.transferToPay?.depositAddress, ttp['depositAddress']);
    expect(p.transferToPay?.expectedAmount, ttp['expectedAmount']);
    expect(p.transferToPay?.depositExpiresAt, ttp['depositExpiresAt']);
    expect(p.transferToPay?.tokenDecimals, ttp['tokenDecimals']);
  });

  test('TransferToPayStart reads TransferToPayCheckout', () {
    final json =
        (fixtures['transferToPayStart'] as Map).cast<String, Object?>();
    final s = TransferToPayStart.fromJson(json);
    expect(s.depositAddress, json['depositAddress']);
    expect(s.totalAmount, json['totalAmount']);
    expect(s.expiresAt, json['expiresAt']);
    expect(s.tokenAddress, json['tokenAddress']);
    expect(s.tokenDecimals, json['tokenDecimals']);
    expect(s.chainName, json['chainName']);
  });

  test('a missing or wrong-typed field never throws', () {
    final p = CheckoutPayment.fromJson({
      'id': 'rcv_x',
      'status': 'requires_action',
      'chains': 'nope',
      'methods': [1, 'agentic']
    });
    expect(p.chains, isEmpty);
    expect(p.methods, ['agentic']);
    expect(p.livemode, isFalse);
  });
}
