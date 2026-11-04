// PaystraterCheckout for Flutter: Pay with Paystrater hands
// off to the Paystrater app; Transfer to Pay shows the deposit with copy,
// share and, when a wallet can open it, an EIP-681 link. No QR: the payer is on
// this phone. Plain JSON over TLS; no encryption in v1.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'checkout.dart';
import 'client.dart';
import 'core.dart';
import 'models.dart';
import 'platform.dart';
import 'strings.dart';
import 'theme.dart';

const _appLink = 'https://app.paystrater.com/pay?id=';

/// Mobile offers Pay with Paystrater and Transfer to Pay; an agent payment is the merchant's to hand to the agent.
const _mobileMethods = ['pay_with_paystrater', 'transfer_to_pay'];

class PaystraterCheckout extends StatefulWidget {
  const PaystraterCheckout({
    super.key,
    required this.paymentId,
    required this.publishableKey,
    this.chains,
    this.themeMode = PaystraterThemeMode.auto,
    this.theme,
    this.darkTheme,
    this.strings = const {},
    this.onSuccess,
    this.onExpired,
    this.onCancelled,
    this.onStatusChange,
    this.onError,
    this.onStartAgain,
    this.openUrl,
    this.apiBase,
    this.api,
  });

  /// The rcv_ ID your server created with your secret key.
  final String paymentId;

  /// pk_live_… or pk_test_…; a secret key is refused before any call.
  final String publishableKey;

  /// Only narrows the payment's chains.
  final List<int>? chains;
  final PaystraterThemeMode themeMode;
  final PaystraterTheme? theme;
  final PaystraterTheme? darkTheme;

  /// Replace any of the checkout's words.
  final Map<String, String> strings;

  /// For the payer's experience only: ship goods on the incoming_payment.succeeded webhook.
  final void Function(CheckoutPayment payment)? onSuccess;
  final void Function(CheckoutPayment payment)? onExpired;
  final void Function(CheckoutPayment payment)? onCancelled;
  final void Function(CheckoutPayment payment)? onStatusChange;
  final void Function(PaystraterError error)? onError;
  final VoidCallback? onStartAgain;

  /// Your own launcher, if the app already uses one; defaults to this package's method channel.
  final Future<bool> Function(String url)? openUrl;

  /// Overrides the API host the key picks.
  final Uri? apiBase;

  /// Replaces the HTTP client: for tests, or a custom transport.
  final CheckoutApi? api;

  @override
  State<PaystraterCheckout> createState() => _PaystraterCheckoutState();
}

class _PaystraterCheckoutState extends State<PaystraterCheckout> {
  late PaystraterClient _client;
  late Checkout _checkout;
  Stage? _lastStage;
  PaystraterTheme? _checkedTheme;

  @override
  void initState() {
    super.initState();
    _create();
  }

  void _create() {
    _client = PaystraterClient(
        publishableKey: widget.publishableKey, apiBase: widget.apiBase);
    _checkout = Checkout(
      api: widget.api ?? _client,
      paymentId: widget.paymentId,
      chains: widget.chains,
      activity: AppLifecycleActivity(),
      onSuccess: (p) => widget.onSuccess?.call(p),
      onExpired: (p) => widget.onExpired?.call(p),
      onCancelled: (p) => widget.onCancelled?.call(p),
      onStatusChange: (p) => widget.onStatusChange?.call(p),
      onError: (e) => widget.onError?.call(e),
    )..addListener(_announce);
    _checkout.start();
  }

  void _destroy() {
    _checkout
      ..removeListener(_announce)
      ..dispose();
    _client.close();
  }

  @override
  void didUpdateWidget(PaystraterCheckout old) {
    super.didUpdateWidget(old);
    if (old.paymentId != widget.paymentId ||
        old.publishableKey != widget.publishableKey ||
        old.apiBase != widget.apiBase ||
        old.api != widget.api) {
      _destroy();
      _create();
    }
  }

  @override
  void dispose() {
    _destroy();
    super.dispose();
  }

  // Screen readers hear each new step
  void _announce() {
    final stage = _checkout.stage;
    if (stage == _lastStage) return;
    _lastStage = stage;
    final text = _statusLine(_checkout, PaystraterStrings(widget.strings));
    if (text.isNotEmpty) {
      // sendAnnouncement replaces announce from Flutter 3.35, but the package supports 3.22 and later
      // ignore: deprecated_member_use
      unawaited(SemanticsService.announce(
          text, Directionality.maybeOf(context) ?? TextDirection.ltr));
    }
  }

  Future<bool> _open(String url) =>
      (widget.openUrl ?? PaystraterPlatform.openUrl)(url);

  @override
  Widget build(BuildContext context) {
    final brightness =
        MediaQuery.maybePlatformBrightnessOf(context) ?? Brightness.light;
    final base = PaystraterTheme.of(widget.themeMode, brightness);
    final dark = widget.themeMode == PaystraterThemeMode.dark ||
        (widget.themeMode == PaystraterThemeMode.auto &&
            brightness == Brightness.dark);
    final theme = (dark ? widget.darkTheme : widget.theme) ?? base;
    final t = PaystraterStrings(widget.strings);
    // Accessibility is not themeable away: colours under WCAG AA are named once per theme on a test key
    if (kDebugMode &&
        _checkout.mode == KeyMode.test &&
        !identical(theme, _checkedTheme)) {
      _checkedTheme = theme;
      for (final w in contrastWarnings(theme)) {
        debugPrint('[Paystrater] $w');
      }
    }
    return Material(
      type: MaterialType.transparency,
      child: ListenableBuilder(
        listenable: _checkout,
        builder: (context, _) => _Frame(
            c: _checkout,
            t: t,
            theme: theme,
            open: _open,
            onStartAgain: widget.onStartAgain),
      ),
    );
  }
}

String _statusLine(Checkout c, PaystraterStrings t) {
  switch (c.stage) {
    case Stage.processing:
      return t['statusProcessing'];
    case Stage.finalStatus:
      final s = c.payment?.status;
      if (s == 'succeeded') return t['statusSucceeded'];
      if (c.underpaid) return t['statusUnderpaid'];
      if (c.arrivedLate) return t['statusLate'];
      if (s == 'expired') return t['statusExpired'];
      if (s == 'cancelled') return t['statusCancelled'];
      return t['statusFailed'];
    default:
      return '';
  }
}

String _duration(int seconds) {
  if (seconds >= 3600) {
    return '${seconds ~/ 3600} h ${(seconds % 3600) ~/ 60} min';
  }
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

class _Frame extends StatelessWidget {
  const _Frame(
      {required this.c,
      required this.t,
      required this.theme,
      required this.open,
      this.onStartAgain});

  final Checkout c;
  final PaystraterStrings t;
  final PaystraterTheme theme;
  final Future<bool> Function(String url) open;
  final VoidCallback? onStartAgain;

  @override
  Widget build(BuildContext context) {
    final p = c.payment;
    final s = _Styles(theme);
    return Semantics(
      container: true,
      label: p == null
          ? t['loading']
          : t.fill('payTo', {'merchant': p.merchantName ?? ''}),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: theme.colorBackground,
          border: Border.all(color: theme.colorBorder),
          borderRadius: BorderRadius.circular(theme.borderRadiusSurface),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (p != null) _Header(payment: p, t: t, s: s),
                  _Body(
                      c: c, t: t, s: s, open: open, onStartAgain: onStartAgain),
                ],
              ),
            ),
            if (c.mode == KeyMode.test)
              Positioned(
                top: 0,
                right: 0,
                child: Semantics(
                  label: t['testModeHint'],
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: theme.colorSurface,
                      borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(theme.borderRadius)),
                    ),
                    child: Text(t['testMode'],
                        style: s.small.copyWith(
                            color: theme.colorWarning,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Styles {
  _Styles(this.theme)
      : body = TextStyle(
            fontSize: 15,
            color: theme.colorTextBody,
            fontFamily: theme.fontFamily,
            height: 1.4),
        strong = TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: theme.colorText,
            fontFamily: theme.fontFamily),
        muted = TextStyle(
            fontSize: 13,
            color: theme.colorTextMuted,
            fontFamily: theme.fontFamily,
            height: 1.4),
        small = TextStyle(
            fontSize: 12,
            color: theme.colorTextMuted,
            fontFamily: theme.fontFamily),
        title = TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: theme.colorText,
            fontFamily: theme.fontFamily),
        mono = TextStyle(
            fontSize: 14,
            color: theme.colorText,
            fontFamily: theme.fontFamilyMono ?? 'monospace'),
        error = TextStyle(
            fontSize: 13,
            color: theme.colorDanger,
            fontFamily: theme.fontFamily);

  final PaystraterTheme theme;
  final TextStyle body;
  final TextStyle strong;
  final TextStyle muted;
  final TextStyle small;
  final TextStyle title;
  final TextStyle mono;
  final TextStyle error;
}

class _Header extends StatelessWidget {
  const _Header({required this.payment, required this.t, required this.s});

  final CheckoutPayment payment;
  final PaystraterStrings t;
  final _Styles s;

  String get _initials => (payment.merchantName ?? '')
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .take(2)
      .map((w) => w[0].toUpperCase())
      .join();

  @override
  Widget build(BuildContext context) {
    final theme = s.theme;
    final logo = payment.merchantLogoUrl;
    final fallback = Center(
        child: Text(_initials.isEmpty ? '₱' : _initials, style: s.strong));
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: theme.colorSurface,
                  border: Border.all(color: theme.colorBorder),
                  borderRadius: BorderRadius.circular(theme.borderRadius),
                ),
                child: ExcludeSemantics(
                  child: logo == null
                      ? fallback
                      : Image.network(logo,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => fallback),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(payment.merchantName ?? '', style: s.strong),
                    if (payment.description != null)
                      Text(payment.description!, style: s.muted),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(t['amountDue'], style: s.muted),
          Semantics(
            label: '${payment.amount} ${payment.tokenTicker}',
            excludeSemantics: true,
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                    text: formatAmount(payment.amount),
                    style: s.mono
                        .copyWith(fontSize: 28, fontWeight: FontWeight.w600)),
                TextSpan(
                  text:
                      '  ${payment.tokenTicker}${payment.chainName != null ? ' · ${payment.chainName}' : ''}',
                  style: s.muted.copyWith(fontSize: 15),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _Button extends StatelessWidget {
  const _Button(
      {required this.label,
      required this.onPressed,
      required this.s,
      this.kind = _Kind.primary,
      this.disabled = false});

  final String label;
  final VoidCallback onPressed;
  final _Styles s;
  final _Kind kind;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final theme = s.theme;
    final primary = kind == _Kind.primary;
    final link = kind == _Kind.link;
    return Semantics(
      button: true,
      enabled: !disabled,
      child: Opacity(
        opacity: disabled ? 0.6 : 1,
        child: InkWell(
          onTap: disabled ? null : onPressed,
          borderRadius: BorderRadius.circular(theme.borderRadius),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            alignment: link ? Alignment.centerLeft : Alignment.center,
            padding: EdgeInsets.symmetric(horizontal: link ? 0 : 16),
            decoration: link
                ? null
                : BoxDecoration(
                    color: primary ? theme.colorPrimary : theme.colorBackground,
                    border:
                        primary ? null : Border.all(color: theme.colorBorder),
                    borderRadius: BorderRadius.circular(theme.borderRadius),
                  ),
            child: Text(
              label,
              style: link
                  ? s.strong.copyWith(
                      color: theme.colorPrimaryText,
                      decoration: TextDecoration.underline,
                      fontWeight: FontWeight.w500)
                  : s.strong.copyWith(
                      color: primary ? theme.colorOnPrimary : theme.colorText),
            ),
          ),
        ),
      ),
    );
  }
}

enum _Kind { primary, secondary, link }

class _Field extends StatelessWidget {
  const _Field(
      {required this.label,
      required this.controller,
      required this.s,
      this.optional,
      this.help,
      this.error,
      this.keyboardType,
      this.hint});

  final String label;
  final TextEditingController controller;
  final _Styles s;
  final String? optional;
  final String? help;
  final String? error;
  final TextInputType? keyboardType;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = s.theme;
    OutlineInputBorder border(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(theme.borderRadius),
        borderSide: BorderSide(color: c));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(TextSpan(children: [
            TextSpan(
                text: label,
                style: s.strong
                    .copyWith(fontSize: 14, fontWeight: FontWeight.w500)),
            if (optional != null)
              TextSpan(text: ' ($optional)', style: s.muted),
          ])),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            autocorrect: false,
            style: s.body.copyWith(color: theme.colorText),
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              hintStyle: s.muted,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              enabledBorder:
                  border(error == null ? theme.colorBorder : theme.colorDanger),
              focusedBorder: border(theme.colorPrimaryText),
              semanticCounterText: '',
            ),
          ),
          if (help != null)
            Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(help!, style: s.muted)),
          if (error != null)
            Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Semantics(
                    liveRegion: true, child: Text(error!, style: s.error))),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body(
      {required this.c,
      required this.t,
      required this.s,
      required this.open,
      this.onStartAgain});

  final Checkout c;
  final PaystraterStrings t;
  final _Styles s;
  final Future<bool> Function(String url) open;
  final VoidCallback? onStartAgain;

  Widget _title(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Semantics(header: true, child: Text(text, style: s.title)),
      );

  Widget? get _actionError {
    final e = c.error;
    if (e == null) return null;
    return _Alert(text: errorForPayer(e, c.mode), s: s);
  }

  @override
  Widget build(BuildContext context) {
    final methods = c.methods.where(_mobileMethods.contains).toList();
    switch (c.stage) {
      case Stage.loading:
        return Center(
            child: Semantics(
                label: t['loading'],
                child: CircularProgressIndicator(color: s.theme.colorPrimary)));
      case Stage.unavailable:
        final e = c.error;
        final retry = e != null &&
            (e.kind == ErrorKind.network ||
                e.kind == ErrorKind.timeout ||
                e.status >= 500);
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _title(t['errorTitle']),
              if (e != null) _Alert(text: errorForPayer(e, c.mode), s: s),
              if (retry)
                _Button(
                    label: t['tryAgain'],
                    onPressed: c.refresh,
                    s: s,
                    kind: _Kind.secondary),
            ]);
      case Stage.methods:
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _title(t['chooseMethod']),
              for (final m in methods)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Semantics(
                    button: true,
                    child: InkWell(
                      onTap: () => c.choose(m),
                      borderRadius:
                          BorderRadius.circular(s.theme.borderRadiusSurface),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 56),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          border: Border.all(color: s.theme.colorBorder),
                          borderRadius: BorderRadius.circular(
                              s.theme.borderRadiusSurface),
                        ),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  m == 'pay_with_paystrater'
                                      ? t['methodPayWithPaystrater']
                                      : t['methodTransferToPay'],
                                  style: s.strong),
                              Text(
                                m == 'pay_with_paystrater'
                                    ? t['methodPayWithPaystraterHint']
                                    : t.fill('methodTransferToPayHint', {
                                        'chains': c.chains
                                            .map((x) => x.chainName)
                                            .join(', ')
                                      }),
                                style: s.muted,
                              ),
                            ]),
                      ),
                    ),
                  ),
                ),
              if (_actionError != null) _actionError!,
            ]);
      case Stage.payWithPaystrater:
        return _PayWithPaystrater(
            c: c,
            t: t,
            s: s,
            open: open,
            title: _title,
            actionError: _actionError,
            canGoBack: methods.length > 1);
      case Stage.transferToPay:
        final d = c.deposit;
        return d == null
            ? _TransferForm(
                c: c,
                t: t,
                s: s,
                title: _title,
                actionError: _actionError,
                canGoBack: methods.length > 1)
            : _DepositView(
                c: c,
                t: t,
                s: s,
                deposit: d,
                open: open,
                title: _title,
                actionError: _actionError);
      case Stage.agentic:
        final prompt = c.payment?.agentPrompt;
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _title(t['agentTitle']),
              Text(t['agentHint'], style: s.muted),
              if (prompt != null) ...[
                const SizedBox(height: 12),
                _Well(s: s, child: SelectableText(prompt, style: s.mono)),
                const SizedBox(height: 12),
                _Button(
                    label: t['copyPrompt'],
                    s: s,
                    kind: _Kind.secondary,
                    onPressed: () =>
                        Clipboard.setData(ClipboardData(text: prompt))),
              ],
            ]);
      case Stage.processing:
      case Stage.updating:
        return Column(children: [
          CircularProgressIndicator(color: s.theme.colorPrimary),
          const SizedBox(height: 12),
          _title(c.stage == Stage.processing
              ? t['statusProcessing']
              : t['statusUnknown']),
          if (c.stage == Stage.processing)
            Text(t['statusProcessingHint'], style: s.muted),
        ]);
      case Stage.finalStatus:
        return _Result(
            c: c, t: t, s: s, title: _title, onStartAgain: onStartAgain);
    }
  }
}

class _Alert extends StatelessWidget {
  const _Alert({required this.text, required this.s});

  final String text;
  final _Styles s;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Semantics(
          liveRegion: true,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: s.theme.colorDanger),
              borderRadius: BorderRadius.circular(s.theme.borderRadius),
            ),
            child: Text(text, style: s.error.copyWith(fontSize: 14)),
          ),
        ),
      );
}

class _Well extends StatelessWidget {
  const _Well({required this.s, required this.child});

  final _Styles s;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: s.theme.colorSurface,
          border: Border.all(color: s.theme.colorBorder),
          borderRadius: BorderRadius.circular(s.theme.borderRadiusSurface),
        ),
        child: child,
      );
}

class _Note extends StatelessWidget {
  const _Note({required this.text, required this.s});

  final String text;
  final _Styles s;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: s.theme.colorPrimarySoft,
            borderRadius: BorderRadius.circular(s.theme.borderRadius)),
        child:
            Text(text, style: s.muted.copyWith(color: s.theme.colorTextBody)),
      );
}

/// Seconds until `expiresAt`; reads the payment once when it reaches zero.
class _Countdown extends StatefulWidget {
  const _Countdown(
      {required this.expiresAt, required this.onEnd, required this.builder});

  final String expiresAt;
  final VoidCallback onEnd;
  final Widget Function(int secondsLeft) builder;

  @override
  State<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<_Countdown> {
  Timer? _timer;
  int? _left;
  bool _ended = false;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void didUpdateWidget(_Countdown old) {
    super.didUpdateWidget(old);
    if (old.expiresAt != widget.expiresAt) {
      _ended = false;
      _tick();
    }
  }

  void _tick() {
    final end = DateTime.tryParse(widget.expiresAt);
    if (end == null) return;
    final left = end.difference(DateTime.now()).inSeconds;
    final clamped = left < 0 ? 0 : left;
    if (mounted) setState(() => _left = clamped);
    if (clamped == 0 && !_ended) {
      _ended = true;
      widget.onEnd();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _left == null ? const SizedBox.shrink() : widget.builder(_left!);
}

class _PayWithPaystrater extends StatefulWidget {
  const _PayWithPaystrater({
    required this.c,
    required this.t,
    required this.s,
    required this.open,
    required this.title,
    required this.actionError,
    required this.canGoBack,
  });

  final Checkout c;
  final PaystraterStrings t;
  final _Styles s;
  final Future<bool> Function(String url) open;
  final Widget Function(String) title;
  final Widget? actionError;
  final bool canGoBack;

  @override
  State<_PayWithPaystrater> createState() => _PayWithPaystraterState();
}

class _PayWithPaystraterState extends State<_PayWithPaystrater> {
  final _payer = TextEditingController();
  FieldProblem? _problem;

  @override
  void dispose() {
    _payer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final t = widget.t;
    final s = widget.s;
    final payment = c.payment!;
    final link = '$_appLink${payment.id}';
    final sent = payment.payer;
    if (sent != null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        widget.title(t['approveInApp']),
        if (sent.name != null)
          _Note(text: t.fill('sentTo', {'name': sent.name}), s: s),
        Text(t['approveInAppHint'], style: s.muted),
        const SizedBox(height: 12),
        _Button(
            label: t['openApp'],
            s: s,
            onPressed: () => unawaited(widget.open(link))),
        const SizedBox(height: 8),
        _Countdown(
          expiresAt: payment.expiresAt,
          onEnd: c.refresh,
          builder: (left) => Text(
              left > 0
                  ? t.fill('expiresIn', {'time': _duration(left)})
                  : t['expired'],
              style: s.muted),
        ),
        const SizedBox(height: 8),
        Text(t['wrongAccount'], style: s.muted),
        if (widget.actionError != null) widget.actionError!,
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      widget.title(t['methodPayWithPaystrater']),
      _Field(
        label: t['payerLabel'],
        controller: _payer,
        s: s,
        help: t['payerHelp'],
        error:
            _problem == FieldProblem.payerRequired ? t['payerRequired'] : null,
      ),
      if (widget.actionError != null) widget.actionError!,
      _Button(
        label: t['sendRequest'],
        s: s,
        disabled: c.busy,
        onPressed: () async {
          final res = await c.payWithPaystrater(_payer.text);
          if (!mounted) return;
          setState(() => _problem = res.field);
          // Hand off to the Paystrater app; without it the link opens the web page with store links
          if (res.ok) unawaited(widget.open(link));
        },
      ),
      if (widget.canGoBack)
        _Button(label: t['back'], s: s, kind: _Kind.link, onPressed: c.back),
    ]);
  }
}

class _TransferForm extends StatefulWidget {
  const _TransferForm(
      {required this.c,
      required this.t,
      required this.s,
      required this.title,
      required this.actionError,
      required this.canGoBack});

  final Checkout c;
  final PaystraterStrings t;
  final _Styles s;
  final Widget Function(String) title;
  final Widget? actionError;
  final bool canGoBack;

  @override
  State<_TransferForm> createState() => _TransferFormState();
}

class _TransferFormState extends State<_TransferForm> {
  final _email = TextEditingController();
  final _name = TextEditingController();
  final _refund = TextEditingController();
  int? _chainId;
  FieldProblem? _problem;

  @override
  void dispose() {
    _email.dispose();
    _name.dispose();
    _refund.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final t = widget.t;
    final s = widget.s;
    final chains = c.chains;
    final chosen =
        _chainId ?? (chains.length == 1 ? chains.first.chainId : null);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      widget.title(t['methodTransferToPay']),
      if (chains.length > 1) ...[
        Text(t['chooseChain'], style: s.muted),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final ch in chains)
            Semantics(
              inMutuallyExclusiveGroup: true,
              checked: chosen == ch.chainId,
              button: true,
              child: InkWell(
                onTap: () => setState(() => _chainId = ch.chainId),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color:
                        chosen == ch.chainId ? s.theme.colorPrimarySoft : null,
                    border: Border.all(
                        color: chosen == ch.chainId
                            ? s.theme.colorPrimary
                            : s.theme.colorBorder),
                    borderRadius: BorderRadius.circular(s.theme.borderRadius),
                  ),
                  child: Text(ch.chainName, style: s.strong),
                ),
              ),
            ),
        ]),
        if (_problem == FieldProblem.chain)
          Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(t['chooseChain'], style: s.error)),
        const SizedBox(height: 12),
      ],
      _Field(
        label: t['emailLabel'],
        optional: t['optional'],
        help: t['emailHelp'],
        error: _problem == FieldProblem.email ? t['emailFormat'] : null,
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        s: s,
      ),
      _Field(
          label: t['nameLabel'],
          optional: t['optional'],
          controller: _name,
          keyboardType: TextInputType.name,
          s: s),
      _Field(
        label: t['refundAddressLabel'],
        optional: t['optional'],
        help: t['refundAddressHelp'],
        hint: '0x…',
        error: _problem == FieldProblem.refundAddressFormat
            ? t['refundAddressFormat']
            : _problem == FieldProblem.refundAddressChecksum
                ? t['refundAddressChecksum']
                : null,
        controller: _refund,
        s: s,
      ),
      if (widget.actionError != null) widget.actionError!,
      _Button(
        label: t['getAddress'],
        s: s,
        disabled: c.busy,
        onPressed: () async {
          if (chosen == null) {
            setState(() => _problem = FieldProblem.chain);
            return;
          }
          final res = await c.startTransferToPay(
              chainId: chosen,
              payerEmail: _email.text,
              payerName: _name.text,
              refundAddress: _refund.text);
          if (mounted) setState(() => _problem = res.field);
        },
      ),
      if (widget.canGoBack)
        _Button(label: t['back'], s: s, kind: _Kind.link, onPressed: c.back),
    ]);
  }
}

class _DepositView extends StatefulWidget {
  const _DepositView({
    required this.c,
    required this.t,
    required this.s,
    required this.deposit,
    required this.open,
    required this.title,
    required this.actionError,
  });

  final Checkout c;
  final PaystraterStrings t;
  final _Styles s;
  final Deposit deposit;
  final Future<bool> Function(String url) open;
  final Widget Function(String) title;
  final Widget? actionError;

  @override
  State<_DepositView> createState() => _DepositViewState();
}

class _DepositViewState extends State<_DepositView> {
  bool _walletReady = false;
  bool _details = false;
  bool _copied = false;

  String? get _link {
    final d = widget.deposit;
    final chainId = d.chainId;
    if (chainId == null) return null;
    return walletLink(
        tokenAddress: d.tokenAddress,
        tokenDecimals: d.tokenDecimals,
        chainId: chainId,
        depositAddress: d.depositAddress,
        amount: d.amount);
  }

  @override
  void initState() {
    super.initState();
    _checkWallet();
  }

  @override
  void didUpdateWidget(_DepositView old) {
    super.didUpdateWidget(old);
    if (old.deposit.tokenAddress != widget.deposit.tokenAddress ||
        old.deposit.amount != widget.deposit.amount) {
      _checkWallet();
    }
  }

  // "Open in wallet" only when an installed app can open an ethereum: link
  void _checkWallet() {
    final link = _link;
    if (link == null) {
      _walletReady = false;
      return;
    }
    unawaited(PaystraterPlatform.canOpenUrl(link).then((yes) {
      if (mounted) setState(() => _walletReady = yes);
    }));
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.deposit;
    final t = widget.t;
    final s = widget.s;
    final chain = d.chainName ?? '';
    final link = _link;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      widget.title(t.fill('sendExactly', {
        'amount': formatAmount(d.amount),
        'token': d.tokenTicker,
        'chain': chain
      })),
      if (isPositiveAmount(d.fee))
        Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
                t.fill('fee',
                    {'fee': formatAmount(d.fee!), 'token': d.tokenTicker}),
                style: s.muted)),
      _Well(
        s: s,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t['depositAddress'], style: s.muted),
          const SizedBox(height: 6),
          SelectableText(d.depositAddress, style: s.mono),
          const SizedBox(height: 6),
          SelectableText('${formatAmount(d.amount)} ${d.tokenTicker}',
              style: s.muted),
        ]),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: _Button(
            label: _copied ? t['copied'] : t['copyAddress'],
            s: s,
            kind: _Kind.secondary,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: d.depositAddress));
              if (!mounted) return;
              setState(() => _copied = true);
              Timer(const Duration(milliseconds: 1500), () {
                if (mounted) setState(() => _copied = false);
              });
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _Button(
              label: t['shareAddress'],
              s: s,
              kind: _Kind.secondary,
              onPressed: () =>
                  unawaited(PaystraterPlatform.share(d.depositAddress))),
        ),
      ]),
      if (_walletReady && link != null) ...[
        const SizedBox(height: 8),
        _Button(
            label: t['openInWallet'],
            s: s,
            onPressed: () => unawaited(widget.open(link))),
      ],
      const SizedBox(height: 12),
      _Note(
          text:
              t.fill('depositNotice', {'token': d.tokenTicker, 'chain': chain}),
          s: s),
      if (isPositiveAmount(d.receivedAmount))
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
              t.fill('received', {
                'amount': formatAmount(d.receivedAmount!),
                'token': d.tokenTicker
              }),
              style: s.muted),
        ),
      Row(children: [
        SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: s.theme.colorPrimary)),
        const SizedBox(width: 8),
        Expanded(
            child: Semantics(
                liveRegion: true,
                child: Text(t['waitingForDeposit'], style: s.muted))),
        _Countdown(
          expiresAt: d.expiresAt,
          onEnd: widget.c.refresh,
          builder: (left) => Text(
              left > 0
                  ? t.fill('expiresIn', {'time': _duration(left)})
                  : t['expired'],
              style: s.muted),
        ),
      ]),
      Semantics(
        button: true,
        value: _details ? 'open' : 'closed',
        child: InkWell(
          onTap: () => setState(() => _details = !_details),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            alignment: Alignment.centerLeft,
            child: Text(t['paymentDetails'],
                style: s.strong.copyWith(
                    color: s.theme.colorPrimaryText,
                    fontWeight: FontWeight.w500)),
          ),
        ),
      ),
      if (_details)
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (d.tokenAddress != null) ...[
            Text(t['tokenContract'], style: s.muted),
            SelectableText(d.tokenAddress!, style: s.mono),
            const SizedBox(height: 6),
          ],
          Text(t['network'], style: s.muted),
          Text(chain, style: s.body),
          if (d.chainId != null) ...[
            const SizedBox(height: 6),
            Text(t['chainId'], style: s.muted),
            SelectableText('${d.chainId}', style: s.body),
          ],
        ]),
      if (widget.actionError != null) widget.actionError!,
    ]);
  }
}

class _Result extends StatelessWidget {
  const _Result(
      {required this.c,
      required this.t,
      required this.s,
      required this.title,
      this.onStartAgain});

  final Checkout c;
  final PaystraterStrings t;
  final _Styles s;
  final Widget Function(String) title;
  final VoidCallback? onStartAgain;

  @override
  Widget build(BuildContext context) {
    final p = c.payment!;
    final theme = s.theme;
    final merchant = p.merchantName ?? 'the shop';
    var heading = t['statusFailed'];
    String? hint = p.failureReason;
    var mark = '!';
    var tone = theme.colorDanger;
    final excess = p.transferToPay?.excessRefunded;
    if (p.status == 'succeeded') {
      heading = t['statusSucceeded'];
      hint = isPositiveAmount(excess)
          ? t.fill('excessRefunded',
              {'amount': formatAmount(excess!), 'token': p.tokenTicker})
          : t.fill('statusSucceededHint', {'merchant': merchant});
      mark = '✓';
      tone = theme.colorSuccess;
    } else if (c.underpaid) {
      heading = t['statusUnderpaid'];
      hint = t['statusUnderpaidHint'];
    } else if (c.arrivedLate) {
      heading = t['statusLate'];
      hint = t['statusLateHint'];
      tone = theme.colorTextMuted;
    } else if (p.status == 'expired') {
      heading = t['statusExpired'];
      hint = t.fill('statusExpiredHint', {'merchant': merchant});
      tone = theme.colorTextMuted;
    } else if (p.status == 'cancelled') {
      heading = t['statusCancelled'];
      hint = t.fill('statusCancelledHint', {'merchant': merchant});
      tone = theme.colorTextMuted;
    } else if (p.status == 'refunded') {
      heading = t['statusRefunded'];
      hint = null;
      tone = theme.colorTextMuted;
    }
    return Column(children: [
      ExcludeSemantics(
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: tone, width: 2)),
          child: Text(mark,
              style: TextStyle(
                  color: tone, fontSize: 22, fontWeight: FontWeight.w700)),
        ),
      ),
      const SizedBox(height: 10),
      title(heading),
      if (hint != null) Text(hint, style: s.muted, textAlign: TextAlign.center),
      if (p.status == 'expired' &&
          !c.underpaid &&
          !c.arrivedLate &&
          onStartAgain != null) ...[
        const SizedBox(height: 12),
        _Button(
            label: t['startAgain'],
            s: s,
            kind: _Kind.secondary,
            onPressed: onStartAgain!),
      ],
    ]);
  }
}
