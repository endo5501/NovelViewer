/// Reaches Apple's on-device foundation model.
///
/// The package exposes two things and nothing else: whether the model can be
/// used, and how to generate from it. Everything about what to generate — the
/// prompts, the two stages, the caching — belongs to the application.
library;

export 'src/foundation_models_llm.dart';
export 'src/on_device_model_availability.dart';
