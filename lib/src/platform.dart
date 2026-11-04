// The package's own platform calls: a tiny method channel,
// a few lines of Kotlin and Swift, instead of url_launcher or share_plus. An
// app that already uses a launcher can pass `openUrl` to the widget instead.
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'checkout.dart';

class PaystraterPlatform {
  static const MethodChannel _channel =
      MethodChannel('com.paystrater.flutter/links');

  /// Opens a link in the app that handles it (the Paystrater app, a wallet) or the browser.
  static Future<bool> openUrl(String url) async {
    try {
      return await _channel.invokeMethod<bool>('openUrl', {'url': url}) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// True when an installed app can open the link (ethereum: needs the scheme declared, see the README).
  static Future<bool> canOpenUrl(String url) async {
    try {
      return await _channel.invokeMethod<bool>('canOpenUrl', {'url': url}) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// The system share sheet with plain text.
  static Future<void> share(String text) async {
    try {
      await _channel.invokeMethod<void>('share', {'text': text});
    } on PlatformException {
      // Nothing to share with: the text stays selectable on screen
    } on MissingPluginException {
      // Same
    }
  }
}

/// Flutter's side of "only while the payer is looking": the app lifecycle.
class AppLifecycleActivity implements ActivitySource {
  @override
  bool get isActive {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  @override
  VoidCallback subscribe(void Function(bool active) listener) {
    var last = isActive;
    final lifecycle = AppLifecycleListener(onStateChange: (_) {
      final now = isActive;
      if (now != last) {
        last = now;
        listener(now);
      }
    });
    return lifecycle.dispose;
  }
}
