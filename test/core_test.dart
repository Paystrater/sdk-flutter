// The shared core vectors (test/vectors/core.json, copied from
// sdk-react/test/vectors): the Dart port gives the same answers as
// @paystrater/react and @paystrater/react-native.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paystrater_flutter/src/core.dart';

void main() {
  final vectors = jsonDecode(File('test/vectors/core.json').readAsStringSync())
      as Map<String, dynamic>;
  List<Map<String, dynamic>> cases(String name) =>
      (vectors[name] as List).cast<Map<String, dynamic>>();

  test('base units without floating point', () {
    for (final v in cases('baseUnits')) {
      expect(
          toBaseUnits(v['amount'] as String, v['decimals'] as int)?.toString(),
          v['units'],
          reason: v['amount'] as String);
    }
  });

  test('formatting and comparing amounts', () {
    for (final v in cases('formatAmount')) {
      expect(formatAmount(v['amount'] as String), v['formatted']);
    }
    for (final v in cases('compareAmounts')) {
      expect(compareAmounts(v['a'] as String, v['b'] as String), v['result']);
    }
  });

  test('EIP-681 wallet links', () {
    for (final v in cases('walletLink')) {
      expect(
        walletLink(
          tokenAddress: v['tokenAddress'] as String,
          tokenDecimals: v['tokenDecimals'] as int,
          chainId: v['chainId'] as int,
          depositAddress: v['depositAddress'] as String,
          amount: v['amount'] as String,
        ),
        v['link'],
      );
    }
    expect(
        walletLink(
            tokenAddress: null,
            tokenDecimals: null,
            chainId: 1,
            depositAddress: '0x1',
            amount: '1'),
        isNull);
  });

  test('Keccak-256 and EIP-55', () {
    String hex(List<int> b) =>
        b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    for (final v in cases('keccak256')) {
      expect(hex(keccak256(utf8.encode(v['utf8'] as String))), v['hash']);
    }
    expect(keccak256(List<int>.filled(200, 0)), hasLength(32));
    for (final v in cases('evmAddress')) {
      expect(checkEvmAddress(v['address'] as String).name, v['check'],
          reason: v['address'] as String);
    }
  });

  test('keys and payment IDs', () {
    for (final v in cases('publishableKey')) {
      expect(publishableKeyMode(v['key'] as String)?.name, v['mode']);
    }
    expect(keyProblem('sk_live_abc'), secretKeyMessage);
    for (final v in cases('paymentId')) {
      expect(isPaymentId(v['id'] as String), v['valid']);
    }
    expect(apiBaseFor(KeyMode.test).toString(),
        'https://staging-api.paystrater.com');
  });
}
