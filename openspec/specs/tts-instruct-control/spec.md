## Purpose

TTS instruct control capability - enables speech style control through instruct text, covering tokenization, embedding, generation, C API, Dart FFI bindings, isolate support, and controller propagation.

## Requirements

### Requirement: Instruct text tokenization
The text tokenizer SHALL provide an `encode_instruct` method that tokenizes instruct text into the ChatML `user` role format: `<|im_start|>user\n{instruct}<|im_end|>\n`. The tokenizer SHALL load the `user` token ID from the GGUF vocabulary during initialization, with a fallback to the `Ġuser` variant. The `encode_instruct` method SHALL return an empty vector if the tokenizer is not loaded.

#### Scenario: Tokenize instruct text
- **WHEN** `encode_instruct("怒りの口調で")` is called on a loaded tokenizer
- **THEN** the returned token vector starts with `[151644, user_token_id, 198]`, followed by the BPE-encoded instruct text tokens, and ends with `[151645, 198]`

#### Scenario: Tokenize empty instruct text
- **WHEN** `encode_instruct("")` is called
- **THEN** an empty vector is returned

#### Scenario: User token ID loaded from vocabulary
- **WHEN** the tokenizer loads from a GGUF file containing a BPE vocabulary
- **THEN** the `user_token_id` is resolved from the vocabulary (either "user" or "Ġuser" variant)

### Requirement: Instruct embedding in prefill graph
The TTS transformer's `build_prefill_graph` SHALL accept optional instruct tokens. When instruct tokens are provided, their text-projected embeddings SHALL be placed at the beginning of the prefill sequence, before the text role embed. The instruct embeddings SHALL use `text_projection` only (no codec embedding overlay). When instruct tokens are not provided (nullptr), the prefill graph SHALL be identical to the existing implementation.

#### Scenario: Build prefill with instruct tokens
- **WHEN** `build_prefill_graph` is called with instruct tokens `[im_start, user, \n, inst_0, ..., inst_m, im_end, \n]` and text tokens `[im_start, assistant, \n, text_0, ..., text_n, im_end, \n, im_start, assistant, \n]`
- **THEN** the prefill embedding sequence is `[instruct_proj(all instruct tokens)] [role_embed(3)] [codec_overlay(variable)] [first_text+codec_bos(1)]` followed by trailing text hidden states

#### Scenario: Build prefill without instruct tokens
- **WHEN** `build_prefill_graph` is called with `instruct_tokens=nullptr` and `n_instruct_tokens=0`
- **THEN** the prefill embedding is identical to the existing implementation: `[role_embed(3)] [codec_overlay(variable)] [first_text+codec_bos(1)]`

#### Scenario: Instruct embeddings use text projection only
- **WHEN** instruct tokens are processed in `build_prefill_graph`
- **THEN** each instruct token is passed through `text_projection` (via `project_text_tokens`) without any codec embedding addition or overlay

### Requirement: Instruct parameter in TTS generation
The `generate` method SHALL accept optional instruct token parameters. The `tts_params` struct SHALL include an `instruct` string field. The `synthesize_internal` method SHALL tokenize the instruct text separately from the main text and pass both to the transformer's `generate` method.

#### Scenario: Generate with instruct text
- **WHEN** `synthesize` is called with `params.instruct = "Happy tone"` and text = "Hello world"
- **THEN** the instruct text is tokenized via `encode_instruct`, the main text via `encode_for_tts`, and both token sequences are passed to `generate`

#### Scenario: Generate without instruct text
- **WHEN** `synthesize` is called with `params.instruct = ""` (empty)
- **THEN** no instruct tokens are generated and `generate` is called with `instruct_tokens=nullptr`

### Requirement: C API instruct synthesis functions
The C API SHALL provide two new functions for instruct-based synthesis, maintaining backward compatibility with existing functions. Both functions SHALL accept an `instruct` parameter (C string). When `instruct` is NULL or empty, the behavior SHALL be identical to the non-instruct variants.

#### Scenario: Synthesize text with instruct via C API
- **WHEN** `qwen3_tts_synthesize_with_instruct(ctx, "こんにちは", "怒りの口調で")` is called on a loaded context
- **THEN** audio is generated using the instruct text to control speech style, and the result is accessible via `qwen3_tts_get_audio`

#### Scenario: Synthesize with voice and instruct via C API
- **WHEN** `qwen3_tts_synthesize_with_voice_and_instruct(ctx, "こんにちは", "ref.wav", "優しく話して")` is called
- **THEN** audio is generated using both the reference voice and the instruct text

#### Scenario: Instruct C API with NULL instruct parameter
- **WHEN** `qwen3_tts_synthesize_with_instruct(ctx, "こんにちは", NULL)` is called
- **THEN** the behavior is identical to `qwen3_tts_synthesize(ctx, "こんにちは")`

#### Scenario: Instruct C API with NULL context
- **WHEN** `qwen3_tts_synthesize_with_instruct(NULL, "text", "instruct")` is called
- **THEN** the function returns -1

### Requirement: Dart FFI instruct bindings
The Dart FFI bindings SHALL expose the new C API instruct functions. The `TtsEngine` class SHALL provide `synthesizeWithInstruct` and `synthesizeWithVoiceAndInstruct` methods. These methods SHALL convert Dart strings to native UTF-8, call the C function, and free native memory in a finally block.

#### Scenario: FFI bindings expose instruct functions
- **WHEN** `TtsNativeBindings` is instantiated with a valid shared library
- **THEN** `synthesizeWithInstruct` and `synthesizeWithVoiceAndInstruct` are available as late final fields

#### Scenario: TtsEngine synthesize with instruct
- **WHEN** `engine.synthesizeWithInstruct("text", "instruct")` is called on a loaded engine
- **THEN** the native `qwen3_tts_synthesize_with_instruct` is called and a `TtsSynthesisResult` is returned

#### Scenario: TtsEngine synthesize with instruct on unloaded engine
- **WHEN** `engine.synthesizeWithInstruct("text", "instruct")` is called on an unloaded engine
- **THEN** a `TtsEngineException` is thrown with message 'Model not loaded'

### Requirement: TtsIsolate instruct support
The `SynthesizeMessage` SHALL include an optional `instruct` field. The TtsIsolate SHALL route synthesis to the appropriate engine method based on the combination of `refWavPath` and `instruct` presence. The `synthesize` method on `TtsIsolate` SHALL accept an optional `instruct` parameter.

#### Scenario: Synthesize with instruct in isolate
- **WHEN** `ttsIsolate.synthesize("text", instruct: "Happy")` is called
- **THEN** the isolate sends a `SynthesizeMessage` with `instruct: "Happy"` and calls `engine.synthesizeWithInstruct`

#### Scenario: Synthesize with voice and instruct in isolate
- **WHEN** `ttsIsolate.synthesize("text", refWavPath: "ref.wav", instruct: "Sad")` is called
- **THEN** the isolate calls `engine.synthesizeWithVoiceAndInstruct`

#### Scenario: Synthesize without instruct in isolate (backward compatible)
- **WHEN** `ttsIsolate.synthesize("text")` is called without instruct
- **THEN** the isolate calls `engine.synthesize` as before

### Requirement: Controller instruct propagation
The `TtsStreamingController.start()` and `TtsGenerationController.start()` SHALL accept an optional `instruct` parameter. The instruct text SHALL be passed through to `TtsIsolate.synthesize()` for each segment.

#### Scenario: Streaming controller passes instruct to each segment
- **WHEN** `streamingController.start(text: "...", instruct: "怒りの口調で")` is called
- **THEN** every segment synthesis call includes `instruct: "怒りの口調で"`

#### Scenario: Streaming controller with no instruct
- **WHEN** `streamingController.start(text: "...")` is called without instruct
- **THEN** segment synthesis calls do not include instruct (backward compatible)
