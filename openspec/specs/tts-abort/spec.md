## Purpose

Cross-isolate abort for in-progress TTS synthesis: native atomic abort flag + ggml CPU callback + per-frame C++ checks (for GPU backends without callback support), Dart FFI bindings callable from any isolate, `TtsEngine.abort()` / `TtsIsolate.abort()` using a shared context-pointer address, and dispose-waits-for-abort cleanup.
## Requirements
### Requirement: C API for synthesis abort
The C API SHALL provide functions to abort an in-progress synthesis operation from an external thread, operating on a dedicated abort handle rather than the synthesis context. `qwen3_tts_abort(handle)` SHALL set the atomic abort flag held by the handle, causing the current or next `ggml_backend_sched_graph_compute` call to return `GGML_STATUS_ABORTED`. `qwen3_tts_reset_abort(handle)` SHALL clear the abort flag. The abort flag SHALL be implemented as `std::atomic<bool>` to guarantee thread safety. When aborted, the synthesis function SHALL return a non-zero error code and `qwen3_tts_get_error` SHALL return an error string indicating abort.

#### Scenario: Abort during active synthesis
- **WHEN** `qwen3_tts_abort` is called on a handle whose associated context is currently executing `qwen3_tts_synthesize` on another thread
- **THEN** the synthesis operation terminates at the next ggml node boundary and `qwen3_tts_synthesize` returns a non-zero error code

#### Scenario: Abort before synthesis starts
- **WHEN** `qwen3_tts_abort` is called on a handle and then `qwen3_tts_synthesize` is called without calling `qwen3_tts_reset_abort`
- **THEN** the synthesis fails immediately with a non-zero error code

#### Scenario: Reset abort flag
- **WHEN** `qwen3_tts_reset_abort` is called on a handle after `qwen3_tts_abort`
- **THEN** the abort flag is cleared and subsequent synthesis calls using that handle proceed normally

#### Scenario: Free context after abort releases GPU memory
- **WHEN** `qwen3_tts_abort` is called during synthesis, synthesis terminates, and then `qwen3_tts_free` is called on the context
- **THEN** all GPU memory (ggml contexts, Metal/Vulkan buffers) is released, and the abort handle remains valid until separately freed

#### Scenario: Abort applies to voice cloning synthesis
- **WHEN** `qwen3_tts_abort` is called on the handle during `qwen3_tts_synthesize_with_voice` execution
- **THEN** the voice cloning synthesis terminates at the next ggml node boundary

#### Scenario: Abort applies to embedding synthesis
- **WHEN** `qwen3_tts_abort` is called on the handle during `qwen3_tts_synthesize_with_embedding` execution
- **THEN** the embedding synthesis terminates at the next ggml node boundary

### Requirement: Abort callback and code-level abort checks
The qwen3-tts.cpp engine SHALL connect the abort handle's flag to both ggml's CPU backend abort callback and C++ code-level checks. At initialization the abort callback SHALL be installed with the abort handle as its callback data (not the context), and SHALL be set on the CPU backend via `ggml_backend_cpu_set_abort_callback` and re-applied after lazy load/reload of components. Since GPU backends (Vulkan, Metal) do not support ggml abort callbacks, the engine SHALL also check the abort flag at the C++ code level: per-frame in `TTSTransformer::generate()` and between the generate and decode stages in `synthesize_internal()`. Each component (TTSTransformer, AudioTokenizerDecoder, AudioTokenizerEncoder) SHALL store the abort callback and provide an `is_aborted()` method. The stored callback SHALL be re-applied when a component is lazy-loaded or reloaded (e.g., in low-memory mode).

#### Scenario: CPU backend abort callback is set at initialization
- **WHEN** `qwen3_tts_init` successfully loads models with an abort handle
- **THEN** the CPU backend's abort callback is configured on all loaded components to check the abort handle's flag

#### Scenario: Abort callback re-applied after lazy load
- **WHEN** a component (transformer, decoder, encoder) is lazy-loaded or reloaded during synthesis
- **THEN** the abort callback is re-applied to the newly loaded component's CPU backend, still reading the same abort handle

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
The Dart FFI bindings SHALL expose `qwen3_tts_create_abort_handle`, `qwen3_tts_free_abort_handle`, `qwen3_tts_abort`, and `qwen3_tts_reset_abort`. The `abort` and `reset_abort` bindings SHALL operate on an abort handle pointer/address. These bindings SHALL be callable from any Dart Isolate since they only allocate/free a small atomic flag or write to it, and do not require synchronization with the synthesis isolate.

#### Scenario: Create and free abort handle via FFI
- **WHEN** the main Dart Isolate calls the FFI binding for `qwen3_tts_create_abort_handle` and later `qwen3_tts_free_abort_handle`
- **THEN** a native abort handle is allocated and subsequently released

#### Scenario: Call abort via FFI from main isolate
- **WHEN** the main Dart Isolate calls the FFI binding for `qwen3_tts_abort` with a valid abort handle address
- **THEN** the atomic abort flag is set on the native handle

#### Scenario: Call reset abort via FFI
- **WHEN** the Dart FFI binding for `qwen3_tts_reset_abort` is called with a valid abort handle address
- **THEN** the atomic abort flag is cleared on the native handle

### Requirement: TtsEngine abort method
The `TtsEngine` class SHALL associate an abort handle when a model is loaded and SHALL provide `resetAbort()` (and MAY provide `abort()`) that operate on that abort handle, never dereferencing the synthesis context pointer. These methods SHALL be callable even when synthesis is running on another isolate, as they only access an atomic flag, and SHALL be memory-safe whether or not a context is currently loaded.

#### Scenario: Reset abort on loaded engine
- **WHEN** `resetAbort()` is called on a `TtsEngine` whose model was loaded with an abort handle
- **THEN** the native `qwen3_tts_reset_abort` is called with the abort handle address

#### Scenario: Abort-related call on unloaded engine
- **WHEN** an abort-related method is called on a `TtsEngine` that has no associated abort handle
- **THEN** the method returns without error (no-op) and does not dereference the synthesis context

### Requirement: TtsIsolate dispose waits for abort completion
The `TtsIsolate.dispose()` method SHALL call `abort()` first when the model is loaded, then wait for the synthesis to terminate (indicated by receiving a response or the Isolate becoming responsive to `DisposeMessage`), then send `DisposeMessage` for graceful cleanup, and finally free the abort handle after the worker Isolate has terminated. The timeout for waiting SHALL remain at 2 seconds, but since abort causes rapid termination, force-kill should rarely be needed.

#### Scenario: Dispose during active synthesis
- **WHEN** `dispose()` is called while synthesis is running
- **THEN** `abort()` is called first (writing to the abort handle), the synthesis terminates, the Isolate processes `DisposeMessage`, `qwen3_tts_free` is called, GPU memory is released, and the abort handle is freed after the worker exits

#### Scenario: Dispose when idle
- **WHEN** `dispose()` is called while no synthesis is running
- **THEN** `DisposeMessage` is sent and processed normally, and the abort handle is freed after the worker exits

### Requirement: Abort handle with model-reload-independent lifetime
The C API SHALL provide a dedicated abort handle (`qwen3_tts_abort_handle`) that holds the atomic abort flag, allocated independently of any synthesis context (`qwen3_tts_ctx`). `qwen3_tts_create_abort_handle()` SHALL allocate and return a handle whose flag is initialized to `false`. `qwen3_tts_free_abort_handle(handle)` SHALL release it. The handle's lifetime SHALL be independent of `qwen3_tts_init` / `qwen3_tts_free`: loading, reloading, or freeing a synthesis context SHALL NOT invalidate an abort handle. Calling `qwen3_tts_abort` / `qwen3_tts_reset_abort` on a live handle SHALL be memory-safe regardless of whether any context is currently loaded, mid-reload, or already freed. The synthesis context SHALL NOT own the abort flag.

#### Scenario: Handle outlives context free and reload
- **WHEN** an abort handle is created, a context is initialized with it, the context is freed via `qwen3_tts_free`, and a new context is initialized with the same handle
- **THEN** the handle remains valid throughout and `qwen3_tts_abort(handle)` writes only to the handle's own memory (never to the freed context)

#### Scenario: Abort during the model-reload window is memory-safe
- **WHEN** `qwen3_tts_abort(handle)` is called in the window between freeing the old context and the new context becoming ready
- **THEN** the call touches only the independently-allocated handle and performs no use-after-free access

#### Scenario: Abort and reset on null handle are no-ops
- **WHEN** `qwen3_tts_abort(null)` or `qwen3_tts_reset_abort(null)` is called
- **THEN** the function returns without error and without dereferencing the pointer

### Requirement: TtsIsolate owns the abort handle lifecycle
The `TtsIsolate` SHALL create exactly one abort handle when it spawns its worker Isolate, expose the handle's stable native address to the main Isolate, and free the handle only after the worker Isolate has terminated. `TtsIsolate.abort()` SHALL signal abort by writing to this handle (via FFI from the main Isolate), never by dereferencing a synthesis context pointer. The handle's address SHALL remain constant across any number of `loadModel` calls.

#### Scenario: Handle created once at spawn
- **WHEN** `TtsIsolate.spawn()` completes
- **THEN** exactly one abort handle has been created and its native address is available to the main Isolate before any model is loaded

#### Scenario: Abort target is stable across model reloads
- **WHEN** `loadModel` is called multiple times (including engine/model switches) on the same `TtsIsolate`
- **THEN** the address used by `TtsIsolate.abort()` is unchanged and always points to the live abort handle

#### Scenario: Abort before any model is loaded is memory-safe
- **WHEN** `TtsIsolate.abort()` is called after `spawn()` but before any successful `loadModel`
- **THEN** the call writes to the existing abort handle and performs no invalid memory access

#### Scenario: Handle freed after worker termination on dispose
- **WHEN** `TtsIsolate.dispose()` runs and the worker Isolate exits (gracefully or via force-kill on timeout)
- **THEN** `qwen3_tts_free_abort_handle` is called only after the worker has terminated, so no isolate reads the flag after it is freed

