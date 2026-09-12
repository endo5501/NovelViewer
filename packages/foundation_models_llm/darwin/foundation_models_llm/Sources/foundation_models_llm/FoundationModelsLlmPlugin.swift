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

  /// The model every request in this plugin is made against.
  ///
  /// Built with the framework's permissive content-transformation guardrails
  /// rather than its default ones. Summarising a passage of a novel is a
  /// content transformation, which is the case the permissive setting exists
  /// for; the default setting judges the model's own output and refuses a
  /// summary that characterises a character unfavourably, which is a routine
  /// thing for a novel to contain and for a summary to say.
  ///
  /// Measured against the same passages, the permissive setting refused no
  /// more often than the default one and returned the fuller answer where both
  /// succeeded, so it is used for every request rather than only for one being
  /// retried.
  ///
  /// The setting arrived with the rest of the framework, so this sits inside
  /// the availability check the plugin already had and raises no deployment
  /// target.
  ///
  /// One instance rather than one per access. The availability the plugin
  /// reports and the model it generates against are then the same object, so
  /// they cannot drift apart; the guardrails do not bear on availability — it
  /// is a fact about the device and the system, and every way of asking agrees
  /// on a machine where the model is available — but a second construction
  /// site would let a later change make them disagree silently.
  ///
  /// Stored rather than computed because an analysis run reaches this several
  /// times per chunk, and what stood here before was the framework's own
  /// shared instance. Building an observable object on each access, twice per
  /// request, would be work the previous code did not do.
  @available(iOS 26.0, macOS 26.0, *)
  private static let model = SystemLanguageModel(
    useCase: .general, guardrails: .permissiveContentTransformations)

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
    switch model.availability {
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
    guard Self.model.availability == .available else {
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
    let sampling = arguments["sampling"] as? String

    // `result` has to be called back on the platform thread, which is where
    // this hop lands.
    Task { @MainActor in
      do {
        let text = try await Self.generate(
          prompt: prompt,
          schemaFieldName: schemaFieldName,
          maxResponseTokens: maxResponseTokens,
          sampling: sampling)
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
    maxResponseTokens: Int?,
    sampling: String?
  ) async throws -> String {
    // A session per request. The prompts a run issues do not depend on one
    // another, and the model's window is shared between prompt and response,
    // so carrying a transcript forward would spend that window on text
    // nothing later needs.
    let session = LanguageModelSession(model: model)
    let options = GenerationOptions(
      sampling: samplingMode(named: sampling),
      maximumResponseTokens: maxResponseTokens)

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

  /// The sampling mode Dart named, or nil to leave the framework its default.
  ///
  /// A name this version does not know is read as no name at all, for the same
  /// reason Dart reads an availability answer it does not know as "unknown"
  /// rather than throwing: a sampling mode is a preference, and failing a
  /// generation over one would turn a preference into a requirement.
  @available(iOS 26.0, macOS 26.0, *)
  private static func samplingMode(named name: String?) -> GenerationOptions.SamplingMode? {
    switch name {
    case "greedy": return .greedy
    default: return nil
    }
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
