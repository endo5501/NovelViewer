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
    case "generate":
      handleGenerate(call.arguments, result: result)
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

  private func handleGenerate(_ arguments: Any?, result: @escaping FlutterResult) {
    guard #available(iOS 26.0, macOS 26.0, *) else {
      result(
        FlutterError(
          code: "modelUnavailable",
          message: "This operating system has no on-device model.",
          details: nil))
      return
    }
    guard let arguments = arguments as? [String: Any],
      let prompt = arguments["prompt"] as? String
    else {
      result(
        FlutterError(
          code: "badArguments",
          message: "generate needs a prompt.",
          details: nil))
      return
    }
    guard SystemLanguageModel.default.availability == .available else {
      // Asked before the caller checked, or the state changed under it. Said
      // plainly, so it is not mistaken for the content having been refused.
      result(
        FlutterError(
          code: "modelUnavailable",
          message: "The on-device model is not available: "
            + Self.availabilityName(),
          details: nil))
      return
    }

    let schemaFieldName = arguments["schemaFieldName"] as? String
    let maxResponseTokens = arguments["maxResponseTokens"] as? Int

    // `result` has to be called back on the platform thread, which is where
    // this hop lands.
    Task { @MainActor in
      do {
        let text = try await Self.generate(
          prompt: prompt,
          schemaFieldName: schemaFieldName,
          maxResponseTokens: maxResponseTokens)
        result(text)
      } catch let error as LanguageModelSession.GenerationError {
        result(
          FlutterError(
            code: Self.wireCode(for: error),
            message: error.failureReason ?? String(describing: error),
            details: nil))
      } catch {
        result(
          FlutterError(
            code: "unknown",
            message: error.localizedDescription,
            details: nil))
      }
    }
  }

  /// Generates, constraining the answer to a one-field object when the caller
  /// named a field.
  ///
  /// The field name is only known at run time — the pipeline asks for `facts`
  /// in one stage and `summary` in the next — so the schema is built with the
  /// dynamic API rather than declared as a type. The result is handed back as
  /// the JSON the caller already knows how to read, which is why nothing here
  /// reshapes it.
  @available(iOS 26.0, macOS 26.0, *)
  private static func generate(
    prompt: String,
    schemaFieldName: String?,
    maxResponseTokens: Int?
  ) async throws -> String {
    // A session per request. The prompts a run issues do not depend on one
    // another, and the model's window is shared between prompt and response,
    // so carrying a transcript forward would spend that window on text
    // nothing later needs.
    let session = LanguageModelSession()
    let options = GenerationOptions(maximumResponseTokens: maxResponseTokens)

    guard let schemaFieldName else {
      return try await session.respond(to: prompt, options: options).content
    }

    let root = DynamicGenerationSchema(
      name: "Answer",
      properties: [
        DynamicGenerationSchema.Property(
          name: schemaFieldName,
          schema: DynamicGenerationSchema(type: String.self))
      ])
    let schema = try GenerationSchema(root: root, dependencies: [])
    let response = try await session.respond(
      to: prompt, schema: schema, options: options)
    return response.content.jsonString
  }

  /// The error code Dart reads back.
  ///
  /// A guardrail block and the model's own refusal are reported separately by
  /// the framework and kept separate here, so a log says which happened; Dart
  /// reads both as the text having been refused.
  @available(iOS 26.0, macOS 26.0, *)
  private static func wireCode(
    for error: LanguageModelSession.GenerationError
  ) -> String {
    switch error {
    case .exceededContextWindowSize: return "exceededContextWindowSize"
    case .assetsUnavailable: return "assetsUnavailable"
    case .guardrailViolation: return "guardrailViolation"
    case .refusal: return "refusal"
    case .unsupportedGuide: return "unsupportedGuide"
    case .unsupportedLanguageOrLocale: return "unsupportedLanguageOrLocale"
    case .decodingFailure: return "decodingFailure"
    case .rateLimited: return "rateLimited"
    case .concurrentRequests: return "concurrentRequests"
    @unknown default: return "unknown"
    }
  }
}
