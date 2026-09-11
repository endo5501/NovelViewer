# foundation_models_llm

Reaches Apple's on-device foundation model from Flutter.

The package exposes two things and nothing else: whether the model can be
used, and how to generate from it. What to generate — the prompts, the
stages, the caching — belongs to the application.

```dart
final plugin = MethodChannelFoundationModelsLlm();

final availability = await plugin.availability();
if (!availability.isAvailable) return; // `availability` says why

final answer = await plugin.generate(
  prompt: '...',
  schemaFieldName: 'facts',   // constrains the answer to {"facts": "..."}
  maxResponseTokens: 1000,
);
```

`availability()` never throws: every failure to get an answer is itself an
answer that the model is unavailable. `generate()` throws
`OnDeviceGenerationException` for every failure, with a named cause —
`guardrailViolation` when the text was refused, `contextWindowExceeded`
when too much was sent, and so on.

## Platforms

iOS and macOS, from version 26 of each, which is where the model framework
arrived. Both compile the same sources under `darwin/`.

The deployment targets are deliberately left where the host application had
them. The Swift is guarded by an availability check and the framework is
weak-linked, so an application embedding this still launches on an older
operating system; there the plugin answers that the platform is
unsupported.
