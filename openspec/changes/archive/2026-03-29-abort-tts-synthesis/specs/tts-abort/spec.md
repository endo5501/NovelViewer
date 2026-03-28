## ADDED Requirements

### Requirement: C API for synthesis abort
The C API SHALL provide functions to abort an in-progress synthesis operation from an external thread. `qwen3_tts_abort(ctx)` SHALL set an atomic abort flag on the context, causing the current or next `ggml_backend_sched_graph_compute` call to return `GGML_STATUS_ABORTED`. `qwen3_tts_reset_abort(ctx)` SHALL clear the abort flag. The abort flag SHALL be implemented as `std::atomic<bool>` to guarantee thread safety. When aborted, the synthesis function SHALL return a non-zero error code and `qwen3_tts_get_error` SHALL return an error string indicating abort.

#### Scenario: Abort during active synthesis
- **WHEN** `qwen3_tts_abort` is called on a context that is currently executing `qwen3_tts_synthesize` on another thread
- **THEN** the synthesis operation terminates at the next ggml node boundary and `qwen3_tts_synthesize` returns a non-zero error code

#### Scenario: Abort before synthesis starts
- **WHEN** `qwen3_tts_abort` is called and then `qwen3_tts_synthesize` is called without calling `qwen3_tts_reset_abort`
- **THEN** the synthesis fails immediately with a non-zero error code

#### Scenario: Reset abort flag
- **WHEN** `qwen3_tts_reset_abort` is called after `qwen3_tts_abort`
- **THEN** the abort flag is cleared and subsequent synthesis calls proceed normally

#### Scenario: Abort with null context
- **WHEN** `qwen3_tts_abort` is called with a null context pointer
- **THEN** the function returns without error (no-op)

#### Scenario: Reset abort with null context
- **WHEN** `qwen3_tts_reset_abort` is called with a null context pointer
- **THEN** the function returns without error (no-op)

#### Scenario: Free after abort releases GPU memory
- **WHEN** `qwen3_tts_abort` is called during synthesis, synthesis terminates, and then `qwen3_tts_free` is called
- **THEN** all GPU memory (ggml contexts, Metal/Vulkan buffers) is released

#### Scenario: Abort applies to voice cloning synthesis
- **WHEN** `qwen3_tts_abort` is called during `qwen3_tts_synthesize_with_voice` execution
- **THEN** the voice cloning synthesis terminates at the next ggml node boundary

#### Scenario: Abort applies to embedding synthesis
- **WHEN** `qwen3_tts_abort` is called during `qwen3_tts_synthesize_with_embedding` execution
- **THEN** the embedding synthesis terminates at the next ggml node boundary

### Requirement: Abort callback and code-level abort checks
The qwen3-tts.cpp engine SHALL connect the context's abort flag to both ggml's CPU backend abort callback and C++ code-level checks. The abort callback SHALL be set on the CPU backend via `ggml_backend_cpu_set_abort_callback` at initialization time and re-applied after lazy load/reload of components. Since GPU backends (Vulkan, Metal) do not support ggml abort callbacks, the engine SHALL also check the abort flag at the C++ code level: per-frame in `TTSTransformer::generate()` and between the generate and decode stages in `synthesize_internal()`. Each component (TTSTransformer, AudioTokenizerDecoder, AudioTokenizerEncoder) SHALL store the abort callback and provide an `is_aborted()` method. The stored callback SHALL be re-applied when a component is lazy-loaded or reloaded (e.g., in low-memory mode).

#### Scenario: CPU backend abort callback is set at initialization
- **WHEN** `qwen3_tts_init` successfully loads models
- **THEN** the CPU backend's abort callback is configured on all loaded components to check the context's abort flag

#### Scenario: Abort callback re-applied after lazy load
- **WHEN** a component (transformer, decoder, encoder) is lazy-loaded or reloaded during synthesis
- **THEN** the abort callback is re-applied to the newly loaded component's CPU backend

#### Scenario: Abort detected per-frame in generate loop on GPU backend
- **WHEN** `qwen3_tts_abort` is called while `TTSTransformer::generate()` is running on a Vulkan/GPU backend
- **THEN** the `is_aborted()` check at the start of each frame iteration detects the abort flag and returns false with an error

#### Scenario: Abort detected between generate and decode stages
- **WHEN** `qwen3_tts_abort` is called after code generation completes but before vocoder decoding begins
- **THEN** the `is_aborted()` check in `synthesize_internal()` detects the abort flag and returns without proceeding to decode

#### Scenario: ggml returns ABORTED status on abort (CPU backend)
- **WHEN** the abort callback returns `true` during `ggml_backend_sched_graph_compute` on a CPU backend
- **THEN** the compute function returns `GGML_STATUS_ABORTED` and the synthesis function detects this and returns error

### Requirement: Dart FFI bindings for abort
The Dart FFI bindings SHALL expose `qwen3_tts_abort` and `qwen3_tts_reset_abort` as Dart methods. These bindings SHALL be callable from any Dart Isolate since they only write to an atomic flag and do not require synchronization with the synthesis isolate.

#### Scenario: Call abort via FFI from main isolate
- **WHEN** the main Dart Isolate calls the FFI binding for `qwen3_tts_abort` with a valid context pointer
- **THEN** the atomic abort flag is set on the native context

#### Scenario: Call reset abort via FFI
- **WHEN** the Dart FFI binding for `qwen3_tts_reset_abort` is called
- **THEN** the atomic abort flag is cleared on the native context

### Requirement: TtsEngine abort method
The `TtsEngine` class SHALL provide an `abort()` method that calls the native `qwen3_tts_abort` function. The `abort()` method SHALL be callable even when synthesis is running on another isolate, as it only sets an atomic flag. The `TtsEngine` class SHALL also provide a `resetAbort()` method.

#### Scenario: Abort on loaded engine
- **WHEN** `abort()` is called on a `TtsEngine` with a loaded model
- **THEN** the native `qwen3_tts_abort` is called with the context pointer

#### Scenario: Abort on unloaded engine
- **WHEN** `abort()` is called on a `TtsEngine` that has not loaded a model
- **THEN** the method returns without error (no-op, since ctx is nullptr)

### Requirement: TtsIsolate shared context pointer for abort
The `TtsIsolate` SHALL expose the native context pointer address to the main Isolate after model loading. `ModelLoadedResponse` SHALL include an optional `ctxAddress` field (int) containing the pointer address. The `TtsIsolate` SHALL provide an `abort()` method that uses this pointer to call `qwen3_tts_abort` directly via FFI from the main Isolate, bypassing the worker Isolate's blocked event loop.

#### Scenario: Context pointer returned on model load
- **WHEN** the worker Isolate successfully loads a TTS model
- **THEN** `ModelLoadedResponse` includes the native context pointer address as an integer

#### Scenario: Abort via shared pointer during synthesis
- **WHEN** `TtsIsolate.abort()` is called while the worker Isolate is blocked in a synthesis FFI call
- **THEN** `qwen3_tts_abort` is called with the shared context pointer, setting the abort flag without waiting for the worker Isolate's event loop

#### Scenario: Abort resets flag before next synthesis
- **WHEN** a synthesis is aborted and the next `SynthesizeMessage` is processed by the worker Isolate
- **THEN** `qwen3_tts_reset_abort` is called before starting synthesis, ensuring the abort flag is clear

### Requirement: TtsIsolate dispose waits for abort completion
The `TtsIsolate.dispose()` method SHALL call `abort()` first when the model is loaded, then wait for the synthesis to terminate (indicated by receiving a response or the Isolate becoming responsive to `DisposeMessage`), and then send `DisposeMessage` for graceful cleanup. The timeout for waiting SHALL remain at 2 seconds, but since abort causes rapid termination, force-kill should rarely be needed.

#### Scenario: Dispose during active synthesis
- **WHEN** `dispose()` is called while synthesis is running
- **THEN** `abort()` is called first, the synthesis terminates, the Isolate processes `DisposeMessage`, `qwen3_tts_free` is called, and GPU memory is released

#### Scenario: Dispose when idle
- **WHEN** `dispose()` is called while no synthesis is running
- **THEN** `DisposeMessage` is sent and processed normally (same as current behavior)
