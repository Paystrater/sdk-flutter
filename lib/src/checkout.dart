// The checkout flow in Dart: the same states, actions and
// polling as @paystrater/react's core/checkout.ts. The page never creates a
// payment and never takes an amount from the app: it reads the payment and
// starts a method.
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'client.dart';
import 'core.dart';
import 'models.dart';

enum Stage {
  loading,
  methods,
  payWithPaystrater,
  transferToPay,
  agentic,
  processing,
  finalStatus,
  updating,
  unavailable
}

enum FieldProblem {
  email,
  refundAddressFormat,
  refundAddressChecksum,
  payerRequired,
  chain
}

/// When the checkout may call the API: only while the app is in the foreground.
abstract class ActivitySource {
  bool get isActive;

  /// Calls back with the new state on every change; returns the unsubscribe.
  VoidCallback subscribe(void Function(bool active) listener);
}

class AlwaysActive implements ActivitySource {
  const AlwaysActive();

  @override
  bool get isActive => true;

  @override
  VoidCallback subscribe(void Function(bool active) listener) => () {};
}

/// One Transfer to Pay deposit, from the start answer or the payment's transferToPay.
class Deposit {
  const Deposit({
    required this.depositAddress,
    required this.amount,
    required this.tokenTicker,
    required this.expiresAt,
    this.fee,
    this.chainId,
    this.chainName,
    this.tokenAddress,
    this.tokenDecimals,
    this.receivedAmount,
    this.excessRefunded,
  });

  final String depositAddress;

  /// The exact amount to send, fee included.
  final String amount;
  final String tokenTicker;
  final String expiresAt;
  final String? fee;
  final int? chainId;
  final String? chainName;
  final String? tokenAddress;
  final int? tokenDecimals;
  final String? receivedAmount;
  final String? excessRefunded;
}

class ActionResult {
  const ActionResult.ok()
      : ok = true,
        field = null,
        error = null;
  const ActionResult.fail({this.field, this.error}) : ok = false;

  final bool ok;
  final FieldProblem? field;
  final PaystraterError? error;
}

const _methodOrder = ['pay_with_paystrater', 'transfer_to_pay', 'agentic'];
final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// The Transfer to Pay chains: a fixed chain gives one; Solana is never offered; `narrow` only narrows.
List<ChainOption> transferChains(CheckoutPayment? payment, List<int>? narrow) {
  if (payment == null) return const [];
  bool solana(String name) => name.toLowerCase().contains('solana');
  var chains = payment.chains.where((c) => !solana(c.chainName)).toList();
  final fixed = payment.chainId;
  if (fixed != null && fixed != 0) {
    chains = chains.where((c) => c.chainId == fixed).toList();
  }
  final fixedName = payment.chainName;
  if (chains.isEmpty &&
      fixed != null &&
      fixed != 0 &&
      fixedName != null &&
      !solana(fixedName)) {
    chains = [ChainOption(chainId: fixed, chainName: fixedName)];
  }
  if (narrow != null && narrow.isNotEmpty) {
    final narrowed = chains.where((c) => narrow.contains(c.chainId)).toList();
    if (narrowed.isNotEmpty) chains = narrowed;
  }
  return List.unmodifiable(chains);
}

/// Methods to offer, in the order of 5.1.
List<String> offeredMethods(
    CheckoutPayment? payment, List<ChainOption> chains) {
  if (payment == null ||
      payment.status != 'requires_action' ||
      payment.method != null) {
    return const [];
  }
  return _methodOrder
      .where((m) =>
          payment.methods.contains(m) &&
          (m != 'transfer_to_pay' || chains.isNotEmpty))
      .toList(growable: false);
}

Deposit? depositFrom(CheckoutPayment? payment, TransferToPayStart? started) {
  final t = payment?.transferToPay;
  final customerFee = payment?.feeBearer == 'customer';
  if (payment != null && t != null) {
    return Deposit(
      depositAddress: t.depositAddress,
      amount: t.expectedAmount,
      fee: customerFee ? (started?.fee ?? payment.fee) : null,
      tokenTicker: payment.tokenTicker,
      chainId: payment.chainId ?? started?.chainId,
      chainName: payment.chainName ?? started?.chainName,
      expiresAt: t.depositExpiresAt,
      tokenAddress: t.tokenAddress ?? started?.tokenAddress,
      tokenDecimals: t.tokenDecimals ?? started?.tokenDecimals,
      receivedAmount: t.receivedAmount,
      excessRefunded: t.excessRefunded,
    );
  }
  if (started != null) {
    return Deposit(
      depositAddress: started.depositAddress,
      amount: started.totalAmount,
      fee: customerFee ? started.fee : null,
      tokenTicker: started.tokenTicker,
      chainId: started.chainId,
      chainName: started.chainName,
      expiresAt: started.expiresAt,
      tokenAddress: started.tokenAddress,
      tokenDecimals: started.tokenDecimals,
    );
  }
  return null;
}

Stage _stageFor(CheckoutPayment payment, String? chosen, List<String> methods) {
  if (isFinalStatus(payment.status)) return Stage.finalStatus;
  if (payment.status == 'processing') return Stage.processing;
  if (payment.status != 'requires_action') return Stage.updating;
  final method =
      payment.method ?? chosen ?? (methods.length == 1 ? methods.first : null);
  switch (method) {
    case 'pay_with_paystrater':
      return Stage.payWithPaystrater;
    case 'transfer_to_pay':
      return Stage.transferToPay;
    case 'agentic':
      return Stage.agentic;
    default:
      return Stage.methods;
  }
}

class Checkout extends ChangeNotifier {
  Checkout({
    required CheckoutApi api,
    required this.paymentId,
    List<int>? chains,
    ActivitySource activity = const AlwaysActive(),
    this.onStatusChange,
    this.onSuccess,
    this.onExpired,
    this.onCancelled,
    this.onError,
    Duration pollEvery = const Duration(seconds: 4),
  })  : _api = api,
        _narrow = chains,
        _activity = activity,
        _pollEvery = pollEvery;

  final CheckoutApi _api;
  final String paymentId;
  final List<int>? _narrow;
  final ActivitySource _activity;
  final Duration _pollEvery;

  final void Function(CheckoutPayment payment)? onStatusChange;

  /// For the payer's experience only: ship goods on the incoming_payment.succeeded webhook.
  final void Function(CheckoutPayment payment)? onSuccess;
  final void Function(CheckoutPayment payment)? onExpired;
  final void Function(CheckoutPayment payment)? onCancelled;
  final void Function(PaystraterError error)? onError;

  static const _slowPoll = Duration(seconds: 10);
  static const _slowUnder = 50;
  static const _maxBackoff = Duration(seconds: 30);

  CheckoutPayment? _payment;
  TransferToPayStart? _started;
  String? _chosen;
  bool _busy = false;
  bool _slowed = false;
  bool _unavailable = false;
  PaystraterError? _error;
  Timer? _timer;
  CancelToken? _inFlight;
  VoidCallback? _stopActivity;
  bool _running = false;
  int _failures = 0;
  String? _lastStatus;

  // ---- state ----

  CheckoutPayment? get payment => _payment;
  KeyMode? get mode => _api.mode;
  bool get busy => _busy;

  /// Polling slowed to every 10 seconds because RateLimit-Remaining fell under 50.
  bool get slowed => _slowed;
  PaystraterError? get error => _error;
  List<ChainOption> get chains => transferChains(_payment, _narrow);
  List<String> get methods => offeredMethods(_payment, chains);
  String? get chosen =>
      _chosen != null && methods.contains(_chosen) ? _chosen : null;
  Deposit? get deposit => depositFrom(_payment, _started);

  Stage get stage {
    final p = _payment;
    if (p == null) return _unavailable ? Stage.unavailable : Stage.loading;
    return _stageFor(p, chosen, methods);
  }

  bool get _expiredWithMoney {
    final t = _payment?.transferToPay;
    return _payment?.status == 'expired' &&
        t != null &&
        isPositiveAmount(t.receivedAmount);
  }

  /// Expired with less than the amount received: a return link is emailed.
  bool get underpaid =>
      _expiredWithMoney &&
      (compareAmounts(_payment!.transferToPay!.receivedAmount!,
                  _payment!.transferToPay!.expectedAmount) ??
              0) <
          0;

  /// Expired, and the whole amount arrived after the deadline.
  bool get arrivedLate => _expiredWithMoney && !underpaid;

  // ---- lifecycle ----

  /// Starts reading and polling. Call once; stop() undoes it.
  void start() {
    if (_running) return;
    _running = true;
    final problem = _api.setupProblem;
    if (problem != null) {
      _unavailable = true;
      _error = problem;
      notifyListeners();
      onError?.call(problem);
      return;
    }
    _stopActivity = _activity.subscribe((active) {
      if (active) {
        // Back in the foreground: one read straight away, then the normal rhythm
        _clearTimer();
        unawaited(_read());
      } else {
        _pause();
      }
    });
    if (_activity.isActive) unawaited(_read());
  }

  void stop() {
    _running = false;
    _pause();
    _stopActivity?.call();
    _stopActivity = null;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }

  /// Reads the payment again now (after an error, or when a countdown ends).
  void refresh() {
    if (!_running) return;
    _clearTimer();
    unawaited(_read());
  }

  void choose(String method) {
    if (_payment?.method != null || !methods.contains(method)) return;
    _chosen = method;
    _error = null;
    notifyListeners();
  }

  /// Back to the method picker, until a start call has locked the method.
  void back() {
    if (_payment?.method != null) return;
    _chosen = null;
    _error = null;
    notifyListeners();
  }

  Future<ActionResult> startTransferToPay(
      {required int chainId,
      String? payerEmail,
      String? payerName,
      String? refundAddress}) async {
    final email = (payerEmail ?? '').trim();
    final name = (payerName ?? '').trim();
    final refund = (refundAddress ?? '').trim();
    if (!chains.any((c) => c.chainId == chainId)) {
      return const ActionResult.fail(field: FieldProblem.chain);
    }
    if (email.isNotEmpty && !_email.hasMatch(email)) {
      return const ActionResult.fail(field: FieldProblem.email);
    }
    if (refund.isNotEmpty) {
      final check = checkEvmAddress(refund);
      if (check == AddressCheck.format) {
        return const ActionResult.fail(field: FieldProblem.refundAddressFormat);
      }
      if (check == AddressCheck.checksum) {
        return const ActionResult.fail(
            field: FieldProblem.refundAddressChecksum);
      }
    }
    final body = <String, Object?>{
      'receivePaymentId': paymentId,
      'chainId': chainId,
      'payerEmail': email.isEmpty ? null : email,
      'payerName': name.isEmpty ? null : name,
      'refundAddress': refund.isEmpty ? null : refund,
    };
    return _act(() async {
      var res = await _api.startTransferToPay(body);
      // "The deposit address was taken; please try again" (500): the same call once more
      final err = res.error;
      if (err != null && err.kind == ErrorKind.api && err.status == 500) {
        res = await _api.startTransferToPay(body);
      }
      if (res.ok) _started = res.data;
      return res;
    });
  }

  Future<ActionResult> payWithPaystrater(String payer) async {
    final value = payer.trim();
    if (value.isEmpty || value.length > 100) {
      return const ActionResult.fail(field: FieldProblem.payerRequired);
    }
    return _act(() async {
      final res = await _api
          .payWithPaystrater({'receivePaymentId': paymentId, 'payer': value});
      final data = res.data;
      if (data != null) _observe(data);
      return res;
    });
  }

  // ---- internals ----

  Future<ActionResult> _act(Future<CallResult<Object>> Function() run) async {
    if (_busy) return const ActionResult.fail();
    _busy = true;
    _error = null;
    notifyListeners();
    final res = await run();
    _noteRate(res.rateLimit);
    _busy = false;
    final error = res.error;
    if (error == null) {
      notifyListeners();
      refresh();
      return const ActionResult.ok();
    }
    // Locked to another method, expired or cancelled since the last read: read it again
    _error = error;
    notifyListeners();
    onError?.call(error);
    refresh();
    return ActionResult.fail(error: error);
  }

  Future<void> _read() async {
    if (!_running || !_activity.isActive) return;
    _inFlight?.cancel();
    final token = CancelToken();
    _inFlight = token;
    final res = await _api.getPayment(paymentId, cancel: token);
    if (identical(_inFlight, token)) _inFlight = null;
    if (token.isCancelled || !_running) return;
    _noteRate(res.rateLimit);

    final data = res.data;
    if (data != null) {
      _failures = 0;
      if (_error != null && _error!.kind != ErrorKind.api) _error = null;
      _observe(data);
      _schedule(_slowed ? _slowPoll : _pollEvery);
      return;
    }
    final error = res.error!;
    if (error.kind == ErrorKind.cancelled) return;
    final fatal = error.kind == ErrorKind.setup ||
        (error.kind == ErrorKind.api &&
            const [400, 401, 403, 404].contains(error.status));
    if (fatal) {
      _error = error;
      if (_payment == null) _unavailable = true;
      notifyListeners();
      onError?.call(error);
      return;
    }
    _failures++;
    _error = error;
    notifyListeners();
    // 429: wait Retry-After; network and 5xx: back off
    final wait = error.kind == ErrorKind.api && error.status == 429
        ? Duration(seconds: error.retryAfter ?? 10)
        : _backoff();
    _schedule(wait < _pollEvery ? _pollEvery : wait);
  }

  Duration _backoff() {
    final ms =
        _pollEvery.inMilliseconds * (1 << (_failures > 6 ? 6 : _failures));
    return ms > _maxBackoff.inMilliseconds
        ? _maxBackoff
        : Duration(milliseconds: ms);
  }

  void _observe(CheckoutPayment payment) {
    final changed = payment.status != _lastStatus;
    _lastStatus = payment.status;
    _payment = payment;
    notifyListeners();
    if (!changed) return;
    onStatusChange?.call(payment);
    switch (payment.status) {
      case 'succeeded':
        onSuccess?.call(payment);
      case 'expired':
        onExpired?.call(payment);
      case 'cancelled':
        onCancelled?.call(payment);
    }
  }

  void _noteRate(RateLimit rate) {
    // Under 50 left: every 10 seconds; back at 50 or more, or when the header is missing
    final remaining = rate.remaining;
    final slowed = remaining != null && remaining < _slowUnder;
    if (slowed != _slowed) {
      _slowed = slowed;
      notifyListeners();
    }
  }

  void _schedule(Duration wait) {
    _clearTimer();
    final status = _payment?.status;
    // Every status but a final one keeps the page reading, unknown ones included
    if (!_running || status == null || isFinalStatus(status)) return;
    _timer = Timer(wait, () => unawaited(_read()));
  }

  void _clearTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _pause() {
    // In the background: no timer and no call in flight
    _clearTimer();
    _inFlight?.cancel();
    _inFlight = null;
  }
}
