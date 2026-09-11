#if os(iOS)
import Flutter
#elseif os(macOS)
import FlutterMacOS
#else
#error("foundation_models_llm supports iOS and macOS only.")
#endif

import FoundationModels
import Foundation

/// Bridges Apple's on-device foundation model to Dart.
///
/// Everything the model framework offers is behind an availability check, so
/// this compiles and runs against an operating system older than the one the
/// framework arrived in. There the plugin answers that the platform is
/// unsupported, which is the same answer Dart produces for a build with no
/// native side at all.
public class FoundationModelsLlmPlugin: NSObject, FlutterPlugin {
  /// Must match `FoundationModelsLlm.channelName` on the Dart side.
  private static let channelName = "jp.novelviewer/foundation_models_llm"

  public static func register(with registrar: FlutterPluginRegistrar) {
    #if os(iOS)
    let messenger = registrar.messenger()
    #else
    let messenger = registrar.messenger
    #endif
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    registrar.addMethodCallDelegate(FoundationModelsLlmPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "availability":
      result(Self.availabilityName())
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// The availability, as the name Dart reads back.
  ///
  /// The three unavailable reasons are reported separately because they ask
  /// different things of the reader: an ineligible device is permanent, a
  /// disabled intelligence feature is a switch, and a model that is not ready
  /// only needs time. A reason added by a later operating system falls to
  /// "unknown", which Dart treats as unavailable rather than as available.
  private static func availabilityName() -> String {
    guard #available(iOS 26.0, macOS 26.0, *) else {
      return "unsupportedPlatform"
    }
    switch SystemLanguageModel.default.availability {
    case .available:
      return "available"
    case .unavailable(.deviceNotEligible):
      return "deviceNotEligible"
    case .unavailable(.appleIntelligenceNotEnabled):
      return "intelligenceNotEnabled"
    case .unavailable(.modelNotReady):
      return "modelNotReady"
    case .unavailable:
      return "unknown"
    }
  }
}
