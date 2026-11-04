import 'package:paystrater_flutter/src/checkout.dart';
import 'package:paystrater_flutter/src/client.dart';
import 'package:paystrater_flutter/src/core.dart';
import 'package:paystrater_flutter/src/models.dart';

const id = 'rcv_test0001';

Map<String, Object?> paymentJson([Map<String, Object?> extra = const {}]) => {
      'id': id,
      'transactionType': 'incoming_payment',
      'status': 'requires_action',
      'merchantName': 'Acme Shoes',
      'amount': '25.00',
      'tokenTicker': 'USDC',
      'feeBearer': 'customer',
      'chains': [
        {'chainId': 8453, 'chainName': 'Base'},
        {'chainId': 137, 'chainName': 'Polygon'},
        {'chainId': 101, 'chainName': 'Solana'},
      ],
      'methods': ['agentic', 'transfer_to_pay', 'pay_with_paystrater'],
      'expiresAt':
          DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
      'livemode': false,
      ...extra,
    };

final ttpJson = {
  'depositAddress': '0xdbF03B407c01E7cD3CBea99509d93f8DDDC8C6FB',
  'expectedAmount': '25.25',
  'depositExpiresAt':
      DateTime.now().add(const Duration(minutes: 20)).toIso8601String(),
  'tokenAddress': '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913',
  'tokenDecimals': 6,
};

final startJson = {
  'receivePaymentId': id,
  'depositAddress': '0xdbF03B407c01E7cD3CBea99509d93f8DDDC8C6FB',
  'chainId': 8453,
  'chainName': 'Base',
  'tokenTicker': 'USDC',
  'amount': '25.00',
  'fee': '0.25',
  'totalAmount': '25.25',
  'expiresAt':
      DateTime.now().add(const Duration(minutes: 20)).toIso8601String(),
  'tokenAddress': '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913',
  'tokenDecimals': 6,
};

/// A scripted API: each read answers what `read` returns; starts answer `start` and `pay`.
class FakeApi implements CheckoutApi {
  FakeApi(
      {required this.read,
      this.start,
      this.pay,
      this.keyMode = KeyMode.test,
      this.problem});

  CallResult<CheckoutPayment> Function() read;
  CallResult<TransferToPayStart> Function()? start;
  CallResult<CheckoutPayment> Function()? pay;
  final KeyMode keyMode;
  final PaystraterError? problem;
  int reads = 0;
  final List<Map<String, Object?>> bodies = [];

  @override
  KeyMode? get mode => keyMode;

  @override
  PaystraterError? get setupProblem => problem;

  @override
  Future<CallResult<CheckoutPayment>> getPayment(String id,
      {CancelToken? cancel}) async {
    reads++;
    return read();
  }

  @override
  Future<CallResult<TransferToPayStart>> startTransferToPay(
      Map<String, Object?> body,
      {CancelToken? cancel}) async {
    bodies.add(body);
    return start!();
  }

  @override
  Future<CallResult<CheckoutPayment>> payWithPaystrater(
      Map<String, Object?> body,
      {CancelToken? cancel}) async {
    bodies.add(body);
    return pay!();
  }
}

CallResult<CheckoutPayment> okPayment(
        [Map<String, Object?> extra = const {},
        RateLimit rate = const RateLimit()]) =>
    CallResult.ok(CheckoutPayment.fromJson(paymentJson(extra)),
        rateLimit: rate);

CallResult<T> failWith<T>(int status, String message, {int? retryAfter}) =>
    CallResult<T>.fail(PaystraterError(ErrorKind.api, status, message,
        retryAfter: retryAfter));

/// An app whose foreground state the test controls.
class FakeActivity implements ActivitySource {
  bool active = true;
  void Function(bool)? _listener;

  @override
  bool get isActive => active;

  @override
  void Function() subscribe(void Function(bool active) listener) {
    _listener = listener;
    return () => _listener = null;
  }

  void set(bool value) {
    active = value;
    _listener?.call(value);
  }
}
