import Flutter
import UIKit

/// Opens links (the Paystrater app, a wallet, the browser) and the share sheet, instead of url_launcher.
public class PaystraterFlutterPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "com.paystrater.flutter/links", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(PaystraterFlutterPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any]
    switch call.method {
    case "openUrl":
      guard let raw = args?["url"] as? String, let url = URL(string: raw) else { return result(false) }
      UIApplication.shared.open(url, options: [:]) { opened in result(opened) }
    case "canOpenUrl":
      // ethereum: must be listed in the app's LSApplicationQueriesSchemes (see the README)
      guard let raw = args?["url"] as? String, let url = URL(string: raw) else { return result(false) }
      result(UIApplication.shared.canOpenURL(url))
    case "share":
      guard let text = args?["text"] as? String else { return result(nil) }
      let sheet = UIActivityViewController(activityItems: [text], applicationActivities: nil)
      guard let root = PaystraterFlutterPlugin.topController() else { return result(nil) }
      // On iPad the sheet needs an anchor
      sheet.popoverPresentationController?.sourceView = root.view
      sheet.popoverPresentationController?.sourceRect = CGRect(x: root.view.bounds.midX, y: root.view.bounds.midY, width: 0, height: 0)
      root.present(sheet, animated: true)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static func topController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    var top = scenes.flatMap { $0.windows }.first { $0.isKeyWindow }?.rootViewController
    while let presented = top?.presentedViewController { top = presented }
    return top
  }
}
