// The one network wrapper of the Flutter SDK: dart:io's
// HttpClient, no package:http. It owns the headers, the timeout and retries,
// reads the rate limit headers and never throws: every call answers a
// CallResult with the server's error.message unchanged. Plain JSON over TLS:
// the mobile SDKs do not encrypt in v1. Nothing here logs a body.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'core.dart';
import 'models.dart';

enum ErrorKind { api, network, timeout, setup, cancelled }

class PaystraterError {
  const PaystraterError(this.kind, this.status, this.message,
      {this.type, this.retryAfter});

  final ErrorKind kind;

  /// HTTP status; 0 when there was no answer.
  final int status;

  /// For people: the server's own words when it sent them.
  final String message;

  /// The server's error.type, for logs only.
  final String? type;

  /// Seconds to wait (429, from Retry-After).
  final int? retryAfter;
}

const _blockedMessage =
    'Too many requests from your network. Wait a moment, then try again.';

const genericSetupMessage =
    'This checkout is not set up correctly. Ask the shop for a new link.';

/// What a payer sees: set-up problems in plain words on a test key, a generic line on a live key.
String errorForPayer(PaystraterError error, KeyMode? mode) {
  if (mode == KeyMode.test || (mode == null && error.kind == ErrorKind.setup)) {
    return error.message;
  }
  final setup = error.kind == ErrorKind.setup ||
      (error.kind == ErrorKind.api &&
          (error.status == 401 || error.status == 403));
  return setup ? genericSetupMessage : error.message;
}

class RateLimit {
  const RateLimit({this.limit, this.remaining, this.reset});

  final int? limit;
  final int? remaining;
  final int? reset;
}

class CallResult<T> {
  const CallResult.ok(T this.data,
      {this.message = '', this.rateLimit = const RateLimit()})
      : error = null;
  const CallResult.fail(PaystraterError this.error,
      {this.rateLimit = const RateLimit()})
      : data = null,
        message = '';

  final T? data;
  final PaystraterError? error;
  final String message;
  final RateLimit rateLimit;

  bool get ok => error == null;
}

/// Lets a caller stop waiting; the request in flight is aborted.
class CancelToken {
  bool _cancelled = false;
  HttpClientRequest? _request;

  bool get isCancelled => _cancelled;

  void cancel() {
    _cancelled = true;
    _request?.abort();
  }
}

/// The checkout's routes, so the flow can be tested without a network.
abstract class CheckoutApi {
  KeyMode? get mode;
  PaystraterError? get setupProblem;
  Future<CallResult<CheckoutPayment>> getPayment(String id,
      {CancelToken? cancel});
  Future<CallResult<TransferToPayStart>> startTransferToPay(
      Map<String, Object?> body,
      {CancelToken? cancel});
  Future<CallResult<CheckoutPayment>> payWithPaystrater(
      Map<String, Object?> body,
      {CancelToken? cancel});
}

class PaystraterClient implements CheckoutApi {
  PaystraterClient(
      {required this.publishableKey,
      Uri? apiBase,
      HttpClient? httpClient,
      this.timeout = const Duration(seconds: 30)})
      : _http = httpClient ?? HttpClient(),
        mode = publishableKeyMode(publishableKey),
        setupProblem = keyProblem(publishableKey) == null
            ? null
            : PaystraterError(ErrorKind.setup, 0, keyProblem(publishableKey)!) {
    final m = mode;
    _base = apiBase ?? (m == null ? null : apiBaseFor(m));
    _http.connectionTimeout = timeout;
  }

  final String publishableKey;
  final Duration timeout;
  final HttpClient _http;
  Uri? _base;

  @override
  final KeyMode? mode;

  @override
  final PaystraterError? setupProblem;

  static const _retryable = {429, 502, 503};
  static const _maxRetryWait = 10;

  @override
  Future<CallResult<CheckoutPayment>> getPayment(String id,
      {CancelToken? cancel}) {
    // The path ID is checked and never URL-encoded
    if (!isPaymentId(id)) return Future.value(_badId<CheckoutPayment>());
    return _call('GET', '/v1/checkout/payments/$id', null,
        (j) => CheckoutPayment.fromJson(j), cancel);
  }

  @override
  Future<CallResult<TransferToPayStart>> startTransferToPay(
          Map<String, Object?> body,
          {CancelToken? cancel}) =>
      _call('POST', '/v1/checkout/transfer-to-pay', body,
          (j) => TransferToPayStart.fromJson(j), cancel);

  @override
  Future<CallResult<CheckoutPayment>> payWithPaystrater(
          Map<String, Object?> body,
          {CancelToken? cancel}) =>
      _call('POST', '/v1/checkout/pay-with-paystrater', body,
          (j) => CheckoutPayment.fromJson(j), cancel);

  /// Closes the HTTP client; the checkout calls this when it is disposed.
  void close() => _http.close(force: true);

  CallResult<T> _badId<T>() => CallResult<T>.fail(
        const PaystraterError(ErrorKind.setup, 0,
            'This payment link is incomplete. The payment ID must look like rcv_…'),
      );

  // Reads retry once on a network error, a timeout, 429 (after a short Retry-After), 502 or 503.
  // Starts never retry here: the checkout reads the payment again instead
  Future<CallResult<T>> _call<T>(
    String method,
    String path,
    Map<String, Object?>? body,
    T Function(Map<String, Object?>) parse,
    CancelToken? cancel,
  ) async {
    final first = await _once(method, path, body, parse, cancel);
    final error = first.error;
    if (error == null || method != 'GET' || (cancel?.isCancelled ?? false)) {
      return first;
    }
    final retryable = error.kind == ErrorKind.network ||
        error.kind == ErrorKind.timeout ||
        (error.kind == ErrorKind.api && _retryable.contains(error.status));
    if (!retryable || (error.retryAfter ?? 0) > _maxRetryWait) return first;
    await Future<void>.delayed(error.kind == ErrorKind.api
        ? Duration(seconds: error.retryAfter ?? 2)
        : const Duration(milliseconds: 800));
    if (cancel?.isCancelled ?? false) return first;
    return _once(method, path, body, parse, cancel);
  }

  Future<CallResult<T>> _once<T>(
    String method,
    String path,
    Map<String, Object?>? body,
    T Function(Map<String, Object?>) parse,
    CancelToken? cancel,
  ) async {
    final problem = setupProblem;
    if (problem != null) return CallResult<T>.fail(problem);
    final base = _base;
    if (base == null) {
      return CallResult<T>.fail(
          const PaystraterError(ErrorKind.setup, 0, genericSetupMessage));
    }
    if (cancel?.isCancelled ?? false) {
      return CallResult<T>.fail(
          const PaystraterError(ErrorKind.cancelled, 0, 'Cancelled.'));
    }

    HttpClientRequest? request;
    try {
      request = await _http
          .openUrl(method, base.replace(path: path))
          .timeout(timeout);
      cancel?._request = request;
      request.followRedirects = false;
      request.headers.set('x-paystrater-api-key', publishableKey);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (body != null) {
        request.headers.contentType = ContentType.json;
        // Optional fields that are null are left out
        request.write(jsonEncode({
          for (final e in body.entries)
            if (e.value != null) e.key: e.value
        }));
      }
      final response = await request.close().timeout(timeout);
      final text =
          await response.transform(utf8.decoder).join().timeout(timeout);
      final rate = RateLimit(
        limit: int.tryParse(response.headers.value('RateLimit-Limit') ?? ''),
        remaining:
            int.tryParse(response.headers.value('RateLimit-Remaining') ?? ''),
        reset: int.tryParse(response.headers.value('RateLimit-Reset') ?? ''),
      );
      Object? json;
      try {
        json = jsonDecode(text);
      } on FormatException {
        json = null;
      }
      final map =
          json is Map<String, Object?> ? json : const <String, Object?>{};
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          map['isError'] == true) {
        final err = map['error'] is Map<String, Object?>
            ? map['error']! as Map<String, Object?>
            : const <String, Object?>{};
        // A 403 with no Paystrater error body came from in front of the API (a per-IP block), so it will pass
        if (response.statusCode == 403 && err['message'] is! String) {
          return CallResult<T>.fail(
              const PaystraterError(ErrorKind.network, 403, _blockedMessage),
              rateLimit: rate);
        }
        final message =
            err['message'] is String && (err['message']! as String).isNotEmpty
                ? err['message']! as String
                : _fallback(response.statusCode);
        return CallResult<T>.fail(
          PaystraterError(ErrorKind.api, response.statusCode, message,
              type: err['type'] is String ? err['type']! as String : null,
              retryAfter: _retryAfter(response.headers.value('Retry-After'))),
          rateLimit: rate,
        );
      }
      final data = map['response'];
      if (data is! Map<String, Object?>) {
        return CallResult<T>.fail(
            PaystraterError(ErrorKind.api, response.statusCode, _fallback(500)),
            rateLimit: rate);
      }
      return CallResult<T>.ok(parse(data),
          message: map['message'] is String ? map['message']! as String : '',
          rateLimit: rate);
    } on TimeoutException {
      request?.abort();
      return CallResult<T>.fail(const PaystraterError(ErrorKind.timeout, 0,
          'Paystrater took too long to answer. Check your connection and try again.'));
    } on Object {
      if (cancel?.isCancelled ?? false) {
        return CallResult<T>.fail(
            const PaystraterError(ErrorKind.cancelled, 0, 'Cancelled.'));
      }
      return CallResult<T>.fail(const PaystraterError(ErrorKind.network, 0,
          "We couldn't reach Paystrater. Check your connection and try again."));
    } finally {
      if (cancel != null && identical(cancel._request, request)) {
        cancel._request = null;
      }
    }
  }

  static String _fallback(int status) {
    if (status == 429) {
      return 'Too many requests. Wait a moment, then try again.';
    }
    if (status >= 500) {
      return 'Something went wrong at Paystrater. Try again in a moment.';
    }
    return 'The request could not be completed.';
  }

  /// Retry-After as seconds or an HTTP date.
  static int? _retryAfter(String? value) {
    if (value == null || value.isEmpty) return null;
    final seconds = int.tryParse(value);
    if (seconds != null) return seconds < 0 ? 0 : seconds;
    try {
      final at = HttpDate.parse(value);
      final diff = at.difference(DateTime.now()).inSeconds;
      return diff < 0 ? 0 : diff;
    } on FormatException {
      return null;
    }
  }
}
