import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerDeviceKindChannel(with: engineBridge.pluginRegistry)
  }

  /// Answers which kind of device this is. `dart:io` reports `ios` for an
  /// iPhone and an iPad alike, and the reader's other devices need to tell
  /// the two apart (lib/shared/platform/ios_device_kind.dart).
  private func registerDeviceKindChannel(with registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "NovelViewerDeviceKind") else {
      return
    }
    let channel = FlutterMethodChannel(
      name: "novel_viewer/device_kind",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "idiom" else {
        result(FlutterMethodNotImplemented)
        return
      }
      switch UIDevice.current.userInterfaceIdiom {
      case .phone: result("phone")
      case .pad: result("pad")
      default: result("unknown")
      }
    }
  }
}
