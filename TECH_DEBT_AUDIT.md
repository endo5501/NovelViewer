# Tech Debt Audit — NovelViewer (`lib/`)

Generated: 2026-04-29
Scope: `lib/` only (110 Dart files, ~17,725 LOC). 169 commits in last 6 months; TTS module is by far the highest-churn area (75 of those commits touch `lib/features/tts/`).

## Executive summary

1. **Three near-identical TTS isolate orchestrators** (`TtsStreamingController`, `TtsEditController`, `TtsGenerationController`). `TtsGenerationController` is dead in production — only its own test references it (lib/features/tts/data/tts_generation_controller.dart:10). 225 LOC of unused code with a 250-line test maintained against it.
2. **Engine-specific parameter assembly is copy-pasted ≥3 times** (text_viewer_panel.dart:131-163, tts_edit_dialog.dart:166-194 and 226-259). 25-line if/else, 8 fields each. The next engine added will copy it a 4th time.
3. **Settings UI is a 1,070-line god dialog** (settings_dialog.dart) covering general/LLM/Qwen3/Piper/voice/recording/rename, with 11 instance variables of mixed lifetime. High churn (19 commits in 6 months) — paying real maintenance cost.
4. **`text_viewer_panel.dart` (900 LOC) mixes 7 concerns** in one `State` class — content rendering, TTS streaming lifecycle, scroll/line tracking, audio-state polling, dialog launching, MP3 export, clipboard. Highest-churn file in the repo (44 commits).
5. **`Map<String, Object?>` is the de-facto DTO** between SQLite and controllers (6 files, ~24 unsafe casts). No `TtsEpisode`/`TtsSegment` types — every consumer redoes `row['id'] as int`.
6. **OpenAI API key is stored in plain `SharedPreferences`** (settings_repository.dart:20). Anyone with filesystem access reads it in cleartext. `flutter_secure_storage` exists for exactly this.
7. **Settings dialog hardcodes Japanese strings into a localised app**: `'TTSエンジン'`, `'モデル'`, `'ダウンロード済み'`, `'再試行'`, `'速度 (lengthScale)'`, `'抑揚'`, `'ノイズ'` (settings_dialog.dart:564-715). JA/EN/ZH locales exist; these never translate.
8. **README endpoint URL is wrong by 100** — README.md:33 says `http://localhost:11334`, code defaults to `http://localhost:11434` (settings_dialog.dart:63,319). Users following the README cannot connect to Ollama.
9. **`directoryContentsProvider` opens/closes `TtsAudioDatabase` on every directory change** (file_browser_providers.dart:67-76) and `_checkAudioState` opens it again per file selection (text_viewer_panel.dart:109). DB lifetime should match the screen, not each query.
10. **Silent failures everywhere** — `catch (_) {}` in 10 sites with no logging package configured. Migration failure (novel_library_service.dart:55), per-episode download failure (download_service.dart:332), DB stat read (file_browser_providers.dart:71) all disappear into the void.

## Architectural mental model

Feature-sliced clean architecture with 11 feature modules under `lib/features/<name>/{data,domain,presentation,providers}` and a thin `shared/` layer. Riverpod owns state; `main.dart` wires up overrides for `currentDirectoryProvider`, `libraryPathProvider`, `sharedPreferencesProvider`, `novelDatabaseProvider`. Single screen (`HomeScreen`) with a 3-column layout; no router.

The TTS module is the dominant complexity centre. It runs native ML inference in a dedicated `Isolate` (`TtsIsolate`), backed by FFI bindings to two C++ libraries (`qwen3-tts.cpp`, `piper`). State and lifetime are coordinated through three different controllers depending on intent (streaming playback, edit-screen per-segment regeneration, batch). Audio is segmented sentence-by-sentence (`TextSegmenter`), persisted as WAV BLOBs in a per-novel-folder SQLite DB (`tts_audio.db`), and re-fetched on subsequent plays. There is also a lookup-table `tts_dictionary.db` for pronunciation overrides.

Three other SQLite stores live alongside the TTS DBs: `episode_cache.db` (download skip-list), `tts_dictionary.db`, and a global `novel_metadata.db`. The first three share copy-pasted scaffolding; the global one differs subtly.

Site scrapers are pluggable behind `NovelSite` with three concrete impls (Narou, Kakuyomu via Apollo `__NEXT_DATA__`, Aozora ShiftJIS). Routing is done by `NovelSiteRegistry.findSite(url)`.

The presentation layer for text rendering has two parallel paths — horizontal (a `SelectableText.rich` inside a scroll view) and vertical (custom `Wrap`-based pagination with hand-rolled hit testing). Both render the same `TextSegment` model produced by `RubyTextParser`.

Notable mismatch with the README: the readme advertises Ollama on port `11334`; the code, including the placeholder it inserts when a user enables Ollama, uses `11434`. The README is wrong.

## Findings

| ID | Category | File:Line | Severity | Effort | Description | Recommendation |
|----|----------|-----------|----------|--------|-------------|----------------|
| F001 | Architectural decay | lib/features/tts/data/tts_generation_controller.dart:10 | Critical | S | `TtsGenerationController` (225 LOC) has zero production references — only test/features/tts/data/tts_generation_controller_test.dart imports it. Duplicates ~80% of `TtsStreamingController`'s isolate-orchestration logic. | Delete `TtsGenerationController` and its test. Confirm no plan to revive it; if there is, write that plan into a comment. |
| F002 | Architectural decay | lib/features/text_viewer/presentation/text_viewer_panel.dart:131-163 | High | M | 25-line engine-config (Piper vs Qwen3) `if/else` block duplicated at lib/features/tts/presentation/tts_edit_dialog.dart:166-194 and :226-259. 8 fields each, drifts easily. | Introduce `TtsEngineConfig.resolveFromRef(WidgetRef ref, TtsEngineType)` returning a sealed class with all 8 fields. Replace 3 call sites. |
| F003 | Architectural decay | lib/features/tts/data/tts_audio_database.dart:21-44 | Medium | S | "Open, on failure delete file and retry" boilerplate copy-pasted into lib/features/tts/data/tts_dictionary_database.dart:21-39 and lib/features/episode_cache/data/episode_cache_database.dart:21-39. lib/features/novel_metadata_db/data/novel_database.dart:21-30 deliberately omits this retry — see open question. | Extract `Future<Database> openOrResetDatabase(...)` helper; have all three local-folder DBs call it. |
| F004 | Architectural decay (god file) | lib/features/settings/presentation/settings_dialog.dart:1-1070 | High | L | Single `_SettingsDialogState` covers general/LLM/Ollama-fetch/Qwen3/Piper/voice-files/drag-drop/rename. 11 instance vars, 13 build helpers. Highest-churn UI file (19 commits). | Extract `LlmSettingsSection`, `Qwen3SettingsSection`, `PiperSettingsSection`, `VoiceReferenceSection` as separate `ConsumerStatefulWidget`s. Move Ollama fetch into a Riverpod `FutureProvider.family`. |
| F005 | Architectural decay (god file) | lib/features/text_viewer/presentation/text_viewer_panel.dart:1-900 | High | L | Mixes content rendering, TTS streaming controller lifetime, scroll-line tracking, audio-state polling, MP3 export, dialog coordination, clipboard, vertical/horizontal mode dispatch. 44 commits, the most-modified file in the repo. | Split: `TtsControlsBar` widget owns the streaming controller; `TextContentRenderer` owns scroll/line tracking; `TextViewerPanel` becomes a layout shell. |
| F006 | Architectural decay | lib/features/tts/data/tts_streaming_controller.dart:142-175 | High | M | `_ensureModelLoaded` + `_synthesize` pattern reimplemented in `TtsEditController._ensureModelLoaded` (lib/features/tts/data/tts_edit_controller.dart:182-228) and `_synthesize` (:543-572). Subscriptions, completers, abort wiring all duplicated. Each copy has slightly different cancel semantics. | Pull a `TtsSession` class out that owns `_subscription`, `_modelLoaded`, `_activeSynthesisCompleter`. Both controllers consume it. |
| F007 | Type & contract debt | lib/features/tts/data/tts_audio_repository.dart:70 | High | M | All repository methods return `Map<String, Object?>` / `List<Map<String, Object?>>`. Consumers re-cast `row['id'] as int`, `row['audio_data'] as List<int>`, etc., in 6 files (24+ casts). One typo collapses at runtime. | Define `TtsEpisode` and `TtsSegment` data classes; have the repository return them. Casting collapses to one place. |
| F008 | Type & contract debt | lib/features/text_download/data/sites/novel_site.dart:7,57 | Low | S | `String blockToText(dynamic element)` and `extractParagraphText(dynamic element)` accept `dynamic` instead of `dom.Element`. lib/features/text_download/data/sites/narou_site.dart:154 same. | Type as `dom.Element` from `package:html/dom.dart`. |
| F009 | Type & contract debt | lib/features/text_download/data/sites/kakuyomu_site.dart:39,142 | Low | S | `dynamic decoded`, `Map? _resolveRef(Map apollo, dynamic ref)` — JSON parsing leans on `dynamic` more than required. | `decoded` can be `Object?`; `ref` is `Object?`. The pattern-match is already there. |
| F010 | Test debt | test/features/tts/data/tts_generation_controller_test.dart | Medium | S | Test for dead production code (see F001). Maintenance overhead with zero coverage value. | Delete with F001. |
| F011 | Test debt | lib/features/text_viewer/presentation/text_viewer_panel.dart | Medium | L | The most-changed file in `lib/` has no panel-level integration test. State machine across `TtsAudioState × TtsPlaybackState × isWaiting × engineType` is handled by inline switch — easy to regress. | Add a Riverpod-overridden widget test that walks none→generating→ready→playing→paused→stopped with a fake `TtsAudioPlayer`/`TtsIsolate`. |
| F012 | Error handling | lib/features/text_download/data/download_service.dart:332 | High | S | Per-episode failures are silently swallowed (`} catch (e) { // Skip failed episodes and continue }`). User sees skipped count but cannot tell whether it was "already cached" or "fetch failed". | Track `failedCount` separately; surface it in `DownloadResult`. Pass through to UI snackbar. |
| F013 | Error handling | lib/features/text_download/data/novel_library_service.dart:55 | Medium | S | `migrateFromOldBundleId` swallows the entire migration in `catch (_)`. If 1,000 chapters didn't copy, user has no signal. | At minimum log via a logger adapter. Better: surface a one-shot diagnostic banner. |
| F014 | Error handling | lib/features/tts/data/tts_streaming_controller.dart:439 | Medium | S | `try { ... } catch (_) { }` during `stop()` cleanup with comment "Ignore cleanup errors". Throws from real bugs (e.g. native crash) become invisible. | Log instead of swallow; rethrow only if state-clearing finally already ran. |
| F015 | Error handling / observability | lib/ (repository-wide) | High | M | No logging package in pubspec. `print` is lint-banned (good), but nothing replaces it. Errors that don't reach a SnackBar simply vanish. | Add `package:logging` (or write a 30-LOC `Log` facade); wire to `debugPrint` in debug and a rolling file in release. |
| F016 | Error handling | lib/features/llm_summary/data/llm_summary_pipeline.dart:85 | Low | S | `catch (_) {}` after `jsonDecode` — bad LLM JSON falls back to raw text, no diagnostic. | Log decode failures so the prompt builder can be tuned. |
| F017 | Security | lib/features/settings/data/settings_repository.dart:20,128 | High | S | `_llmApiKeyKey` stores OpenAI/compatible API keys in plain `SharedPreferences` (cleartext file under app data). | Use `flutter_secure_storage` for the API key field; keep other prefs in `SharedPreferences`. |
| F018 | Security | lib/features/settings/data/settings_repository.dart:111-130 | Low | S | `LlmConfig.apiKey` round-trips through normal `LlmConfig` value object — once stored elsewhere as a state, leak surface widens. | Treat `apiKey` as transient; load on demand from secure storage in `LlmClient`. |
| F019 | Performance | lib/features/file_browser/providers/file_browser_providers.dart:67-76 | Medium | S | Every directory change opens `TtsAudioDatabase`, queries `tts_episodes`, then closes. `sqflite` open is hundreds of ms on Windows. UI stalls on first folder click. | Cache the DB instance keyed by folder via a Riverpod `Provider.family`; close on `ref.onDispose`. |
| F020 | Performance | lib/features/text_viewer/presentation/text_viewer_panel.dart:752 | Medium | S | `addPostFrameCallback(_checkAudioState)` runs every build. Short-circuits via `_lastCheckedFileKey`, but the path that runs `TtsAudioDatabase(folderPath)` is taken on every file change even if the file is already known. | Move audio-state into a Riverpod `FutureProvider.family<TtsAudioState, String>` keyed by file path. |
| F021 | Performance | lib/features/tts/data/tts_audio_repository.dart:233 | Medium | S | `deleteEpisode` calls `_database.reclaimSpace()` (`PRAGMA incremental_vacuum(0)`) synchronously after every delete. Slow on >100MB DBs. | Vacuum on app exit or on a debounce, not per-delete. |
| F022 | Performance | lib/features/tts/data/tts_engine.dart:289-293 | Medium | S | `_extractAudio` copies native float buffer one element at a time. `PiperTtsEngine._extractAudio` does `Float32List.fromList(audioPtr.asTypedList(length))` (lib/features/tts/data/piper_tts_engine.dart:95). 5-10× slower for long segments. | Mirror Piper's approach. |
| F023 | Performance | lib/features/text_viewer/presentation/vertical_text_viewer.dart:376-381 | Low | S | `_findPageForOffset` linear-scans `charOffsetPerPage` from end on every TTS highlight tick. Acceptable today (page count typically <50) but called on each segment. | Binary search; trivially correct since list is monotonic. |
| F024 | Consistency rot | lib/features/text_download/data/download_service.dart:50,56 | Low | S | `DownloadService` constructs its own `http.Client` ignoring the global `httpClientProvider` (lib/features/settings/providers/settings_providers.dart:13) used by Ollama. Two HTTP clients with separate lifetimes. | Inject `http.Client` from the provider through download-service factory. |
| F025 | Consistency rot | lib/features/text_download/data/sites/narou_site.dart:114-117 | Low | S | `querySelectorAll('a[href*="?p="]').cast<dynamic>().firstWhere(... orElse: () => null)`. The `cast<dynamic>` is only there to allow `null` from `firstWhere`. | Use `firstWhereOrNull` from `package:collection`. |
| F026 | Consistency rot | lib/features/settings/presentation/settings_dialog.dart:564,594,621,645,664,682,694,706 | High | S | App localizes JA/EN/ZH but Piper section hardcodes `'TTSエンジン'`, `'モデル'`, `'モデルデータダウンロード'`, `'ダウンロード済み'`, `'再試行'`, `'速度 (lengthScale)'`, `'抑揚 (noiseScale)'`, `'ノイズ (noiseW)'`. Never translates. | Add ARB keys; replace literals with `AppLocalizations.of(context)!.<key>`. |
| F027 | Consistency rot | lib/features/tts/data/tts_streaming_controller.dart:42, lib/features/tts/data/tts_edit_controller.dart:41 | Low | S | Each controller instantiates its own `TextSegmenter()`. Behaviour must stay aligned — easy to drift if one is parameterised later. | Inject a shared `TextSegmenter` instance via Riverpod. |
| F028 | Consistency rot | lib/features/text_viewer/presentation/text_viewer_panel.dart:630 | Low | S | `_withTtsControls(child, ttsModelDir, audioState, playbackState, content)` takes 4 unnamed positional args of mostly the same kind. Easy to swap `audioState` and `playbackState`. | Convert to named parameters. |
| F029 | Consistency rot | lib/features/text_viewer/presentation/text_viewer_panel.dart:711-734 | Low | S | `build` mutates state outside `setState`: `_lastViewedFilePath = selectedFile?.path`, then schedules a postFrameCallback. Works because rebuild is benign, but smells. | Move file-change detection into a `ref.listen(selectedFileProvider)` in `initState`. |
| F030 | Documentation drift | README.md:33 | High | S | Ollama endpoint documented as `http://localhost:11334`. Actual default in lib/features/settings/presentation/settings_dialog.dart:63,319 is `http://localhost:11434`. Users following README cannot connect. | Fix README. |
| F031 | Documentation drift | lib/features/tts/data/tts_engine.dart:34 | Low | S | `@Deprecated('Use TtsLanguage.ja.languageId instead') static const int languageJapanese` still exists; no callers in `lib/`. | Remove. |
| F032 | Dependency & config | pubspec.yaml:35 | Medium | S | `intl: any` unconstrained. `flutter_localizations` pins it transitively, but `any` invites surprises on `pub upgrade`. | `intl: ^0.20.0` (or whatever flutter_localizations resolves to today). |
| F033 | Dependency & config | analysis_options.yaml | Low | S | Lint set is small. Missing `discarded_futures`, `unawaited_futures`, `prefer_typing_uninitialized_variables` would catch real bugs given the heavy async/Isolate code. | Add the three lints; fix or `// ignore: ` resulting hits. |
| F034 | Dependency & config | flutter_01.log..flutter_05.log (repo root) | Low | S | Five stale Flutter run logs in repo root. Gitignored (`*.log`), so untracked, but clutter the workspace. | `rm flutter_*.log` and add to a `make clean` script. |
| F035 | Documentation drift | lib/main.dart:18 | Low | S | `JustAudioMediaKit.ensureInitialized()` runs only on Windows. README "対応プラットフォーム" lists macOS, Windows, Linux(未確認). On Linux this skips initialization silently. | Either include Linux explicitly or document that Linux audio is unsupported. |
| F036 | Performance | lib/features/text_download/data/sites/aozora_site.dart:43,57 | Low | S | `parseIndex` parses HTML, then `parseEpisode` parses again. Same in lib/features/text_download/data/sites/narou_site.dart:106. | Either pass the parsed `Document` through, or accept this as cold-path cost. |
| F037 | Architectural decay | lib/features/tts/data/tts_streaming_controller.dart:355-388 | Medium | M | The "play one segment, await completion, pause-not-stop, drain buffer 500ms" sequence is intricate and replicated in `TtsStoredPlayerController` (lib/features/tts/data/tts_stored_player_controller.dart:60-121) and `TtsEditController.playSegment` (lib/features/tts/data/tts_edit_controller.dart:381-411). All three have load-bearing comments about WASAPI buffering. | Extract `SegmentPlayer` that owns this dance; controllers wrap it. |
| F038 | Consistency rot | lib/features/llm_summary/data/ollama_client.dart:6 vs openai_compatible_client.dart:6 | Low | S | Two HTTP clients with parallel constructors; both take optional `http.Client?` and accept it. Slight difference: Ollama's static `fetchModels` takes `httpClient` as required, OpenAI has no equivalent. | Acceptable as-is, but a shared base or mixin would normalise the constructors. |
| F039 | Test debt | test/features (overall) | Medium | M | 115 test files, 26,431 LOC tests vs 17,725 LOC src. Heavy unit testing on `data/` layers, but presentation layer (settings_dialog, text_viewer_panel, tts_edit_dialog) is sparsely tested at widget level. | Add at least one widget test per major dialog/panel covering happy path. |
| F040 | Type & contract debt | lib/features/tts/data/tts_streaming_controller.dart:50-66 | Medium | M | `start()` takes 14 parameters (including 4 `double?` Piper-only ones, 1 `int` Qwen3-only). New engines compound this. | Pass an `EngineParams` discriminated union: `Qwen3Params(refWavPath, languageId, ...)` or `PiperParams(dicDir, lengthScale, ...)`. |
| F041 | Architectural decay | lib/features/tts/providers/tts_settings_providers.dart:26-37 | Low | S | `_SettingStringNotifier` and `_SettingDoubleNotifier` abstract classes have one subclass each per setting (4-line subclasses doing nothing but pointing at getter/setter). Mostly boilerplate. | Either keep as-is or move to `riverpod_generator` annotations. Don't add another abstract class for `int` settings if it shows up. |
| F042 | Performance | lib/features/text_download/data/download_service.dart:194 | Low | S | `Future.delayed(requestDelay)` per-page request — fixed 700ms — even when the next page is on the same host's CDN. Cumulative: a 100-page index waits 70s. | Acceptable for politeness; document the rationale or make it host-configurable. |
| F043 | Architectural decay | lib/home_screen.dart:166-184 | Low | S | Hardcoded panel widths (`width: 250`, `width: 300`). Not user-resizable; doesn't react to window width. | `LayoutBuilder` + a stored ratio in settings, or `MultiSplitView` package. |
| F044 | Documentation drift | lib/features/tts/data/tts_engine.dart:34-37 | Low | S | Comment block describes `_maxAudioTokensCap = 2048`, `_tokensPerChar = 15`, `_tokensMargin = 50` magic numbers without rationale. They drive a multi-second feature (max tokens guard). | One sentence each: where the constants come from. |
| F045 | Consistency rot | lib/features/tts/data/tts_audio_database.dart:8 vs lib/features/tts/data/tts_dictionary_database.dart:8 vs lib/features/episode_cache/data/episode_cache_database.dart:8 | Low | S | DBs use snake_case file names, no shared base, but identical `_databaseName`/`_databaseVersion` private static pattern. Cosmetic. | Settle on one DB-base class (see F003). |
| F046 | Architectural decay | lib/features/text_viewer/presentation/text_viewer_panel.dart:177 | Low | S | `ProviderScope.containerOf(context)` inside `_startStreaming` is used because `TtsStreamingController.ref` is typed `ProviderContainer`, not `WidgetRef`. Forces the controller to take the parent container. | Refactor `TtsStreamingController` to take a `Reader = T Function<T>(ProviderListenable<T>)` instead of the container. |
| F047 | Performance | lib/features/text_viewer/presentation/vertical_text_page.dart:90-102 | Low | S | `_rebuildEntries` clears and re-fills `_entryKeys` on every segments update; each entry gets a fresh `GlobalKey`. Creates pressure if pagination changes mid-frame. | Reuse keys for unchanged indices, or switch to `ValueKey`. |
| F048 | Type & contract debt | lib/features/tts/data/tts_streaming_controller.dart:285-297 | Medium | S | `synthRefWavPath` resolution buries the "null vs '' vs path" tri-state in a nested ternary. Same logic appears in lib/features/tts/data/tts_edit_controller.dart:355-359 as a `switch`. | Use the `switch` form in both, or extract `resolveRefWav(stored, fallback, resolver)`. |
| F049 | Documentation drift | README.md:78-90 | Low | S | Build instructions list `scripts/build_piper_macos.sh` / `_windows.bat` but `pubspec.yaml`/CLAUDE.md only mention `build_tts_*` and `build_lame_*`. Verify Piper script exists; CLAUDE.md disagrees with README. | Reconcile. |
| F050 | Consistency rot | lib/features/tts/data/tts_engine.dart:140-143 vs :217-220 | Low | S | "ignore" comments on `FileSystemException` deletes (`// ignore`) — same intent, different commentary style. | Keep one wording; both are fine to suppress, but pick one. |
| F051 | Architectural decay | lib/features/text_viewer/data/parsed_segments_cache.dart (referenced from text_viewer_panel.dart:760) | Low | S | `_segmentsCache` is a per-widget instance cache; pagination/styling computes off it but it's bound to widget lifetime. If two viewers ever share the screen they double-parse. | Hoist into a Riverpod `Provider<ParsedSegmentsCache>` keyed by content hash. |
| F052 | Error handling | lib/features/file_browser/providers/file_browser_providers.dart:71-74 | Low | S | DB read failure for TTS statuses falls through to empty map. Silent. | Log; otherwise the user wonders why the green "TTS-ready" badge stops appearing. |
| F053 | Type & contract debt | lib/features/text_viewer/presentation/text_viewer_panel.dart:115 | Low | S | `episode?['status'] as String?` casts inside the call site. Replicated in :383 (`'sample_rate' as int? ?? 24000`). With F007 these disappear. | Fold into the `TtsEpisode` data class. |
| F054 | Architectural decay | lib/features/tts/data/tts_isolate.dart:78,84 | Low | S | `_responseController` is a broadcast `StreamController`. Each consumer calls `responses.listen` and unsubscribes manually — five places. Without backpressure, a slow listener doesn't get pushback. | Acceptable; document the contract that consumers must filter response-type tags themselves. |
| F055 | Architectural decay | lib/features/tts/data/tts_audio_database.dart:147 | Low | S | `close()` does not null-check whether `database` getter has run; if `_database` is null, awaits a `null?.close()` which is fine. Trivial. | None; noted for completeness. |
| F056 | Architectural decay | lib/features/novel_metadata_db/data/novel_database.dart:117-119 | Low | S | `void setDatabase(Database db)` exists "for testing" — public API leak for tests. Other DB classes don't have this. | Use `@visibleForTesting`. |
| F057 | Documentation drift | lib/features/text_viewer/presentation/text_viewer_panel.dart:76-83 | Low | S | `didRequestAppExit` documents only the macOS Metal scenario. Same code path matters on Windows (Vulkan). | Note Vulkan as well. |
| F058 | Consistency rot | lib/features/tts/data/tts_audio_database.dart:32 vs lib/features/novel_metadata_db/data/novel_database.dart:21 | Medium | S | The local-folder DBs delete the file on open failure; the global novel DB does not. If `novel_metadata.db` ever corrupts on a user's machine, the app cannot recover. | Decide one strategy. Delete-and-retry is fine here because contents are reproducible; if `novel_metadata.db` isn't reproducible, document why. |

## Top 5 — if you fix nothing else

### 1. Delete `TtsGenerationController` and its test (F001, F010)
225 LOC of dead production code with a 250-LOC test that runs on every CI invocation. No production caller. Sketch:

```bash
git rm lib/features/tts/data/tts_generation_controller.dart \
       test/features/tts/data/tts_generation_controller_test.dart
fvm flutter analyze && fvm flutter test
```

If something still references it via spec docs, this is the moment to find out.

### 2. Type the TTS DTOs (F007, F053, F048)
Replace `Map<String, Object?>` with `TtsEpisode` and `TtsSegment`. Sketch:

```dart
// lib/features/tts/data/tts_episode.dart
class TtsEpisode {
  final int id;
  final String fileName;
  final int sampleRate;
  final TtsEpisodeStatus status;
  final String? refWavPath;
  final String? textHash;

  factory TtsEpisode.fromRow(Map<String, Object?> row) =>
      TtsEpisode(
        id: row['id'] as int,
        fileName: row['file_name'] as String,
        sampleRate: row['sample_rate'] as int,
        status: TtsEpisodeStatus.fromDbStatus(row['status'] as String?),
        refWavPath: row['ref_wav_path'] as String?,
        textHash: row['text_hash'] as String?,
      );
}
```

`TtsAudioRepository.findEpisodeByFileName` returns `TtsEpisode?`; controllers stop spelling out cast strings. Removes 24+ unsafe casts and constrains the schema in one place.

### 3. Unify the engine-config builder (F002, F040)
A `TtsEngineConfig.resolveFromRef(ref, engineType)` returning a sealed type collapses three identical 25-line `if/else` blocks:

```dart
sealed class TtsEngineConfig {
  String get modelDir;
  static TtsEngineConfig resolveFromRef(WidgetRef ref, TtsEngineType type) {
    if (type == TtsEngineType.piper) {
      // ...build Piper variant
    }
    // ...build Qwen3 variant
  }
}
class Qwen3Config extends TtsEngineConfig { ... }
class PiperConfig extends TtsEngineConfig { ... }
```

`TtsStreamingController.start` then takes `TtsEngineConfig` instead of 14 positional/named parameters.

### 4. Move the OpenAI API key to `flutter_secure_storage` (F017, F018)
Add `flutter_secure_storage: ^9.0.0` to pubspec. Replace in `SettingsRepository`:

```dart
final _secure = const FlutterSecureStorage();

Future<String> getApiKey() async => await _secure.read(key: 'llm_api_key') ?? '';
Future<void> setApiKey(String key) async {
  if (key.isEmpty) await _secure.delete(key: 'llm_api_key');
  else await _secure.write(key: 'llm_api_key', value: key);
}
```

`getLlmConfig`/`setLlmConfig` become async on the apiKey field. The settings dialog already runs `_saveLlmConfig` from a text-field `onChanged`, so the migration is mostly about awaiting it.

### 5. Cache the local-folder SQLite DBs (F019, F020)
Replace ad-hoc open/close with a Riverpod provider:

```dart
final ttsAudioDbProvider = Provider.family<TtsAudioDatabase, String>(
  (ref, folderPath) {
    final db = TtsAudioDatabase(folderPath);
    ref.onDispose(() => db.close());
    return db;
  },
);
```

Then `text_viewer_panel.dart`, `file_browser_providers.dart`, and `tts_edit_dialog.dart` consume it. `_lastCheckedFileKey` and the `try/finally close` ceremony go away. UI stops stalling on the first folder click.

## Quick wins

- [ ] **F001/F010** — Delete `TtsGenerationController` + its test.
- [ ] **F030** — Fix README.md:33 Ollama port (`11334` → `11434`).
- [ ] **F031** — Remove `@Deprecated languageJapanese` constant in `tts_engine.dart:34`.
- [ ] **F034** — Delete `flutter_01.log..flutter_05.log` from repo root.
- [ ] **F022** — Replace `for (var i = 0; i < length; i++)` audio copy in `tts_engine.dart:289-293` with `Float32List.fromList(audioPtr.asTypedList(length))`.
- [ ] **F025** — Replace `cast<dynamic>().firstWhere(... orElse: () => null)` in `narou_site.dart:114` with `firstWhereOrNull`.
- [ ] **F026** — Move 8 hardcoded JA strings in `settings_dialog.dart` (Piper section) into ARB files.
- [ ] **F032** — Pin `intl:` to a `^x.y.z` range.
- [ ] **F056** — Tag `NovelDatabase.setDatabase` with `@visibleForTesting`.

## Things that look bad but are actually fine

- **`catch (_)` in `tts_audio_database.dart:32`** — looks like classic error-swallow. It is not. The pattern is "if the DB file is corrupt (rare, but happens after disk-full / power-loss), delete it and recreate". Audio data is reproducible from text, so this is a deliberate self-heal. The same wouldn't be acceptable for `NovelDatabase` (see F058 — open question whether that's why it was omitted there).
- **`setFilePath` before `playerStateStream.listen`** in `tts_streaming_controller.dart:346-354`. Looks racy. The comment block correctly explains this is forced by `just_audio`'s `playerStateStream` being a `BehaviorSubject` that replays the last `completed` state — listening first would immediately fire and skip the next segment. Don't reorder.
- **`unawaited(_audioPlayer.play().catchError(...))`** in `tts_streaming_controller.dart:365-367`. The play future is intentionally not awaited because completion is signalled via `playerStateStream`. The `catchError` ensures errors propagate to the completer.
- **Three `TextSegmenter()` instances** across the TTS controllers (F027). Looks duplicative; in practice the segmenter is stateless and tiny. Listed because consistency drift would be a real risk if it ever takes parameters; if not, leave it.
- **`ProviderScope.containerOf(context)`** in `text_viewer_panel.dart:176`. Looks like an antipattern. It is a deliberate handoff: the streaming controller outlives any single `WidgetRef` lifecycle, so it needs a long-lived `ProviderContainer`. The cleanup in `dispose()`/`stop()` is correct.
- **`JustAudioMediaKit.ensureInitialized()` only on Windows** in `main.dart:18`. Asymmetric, but `just_audio_media_kit` is the Windows backend; macOS uses CoreAudio via `just_audio` directly. Platform-correct.
- **`broadcast` `StreamController` in `TtsIsolate`** with `_responseController.stream` consumed by every controller. Looks fragile (no per-call request/response correlation) but each consumer matches by message subtype and only one synthesis is in-flight at a time per isolate.
- **`@visibleForTesting computeCharOffsetPerPage` in `vertical_text_viewer.dart:9`** — exposing pagination internals. Pagination is the trickiest correctness story in the app; the test surface is justified.
- **`_isolateEntryPoint` static function in `tts_isolate.dart:185`** — `Isolate.spawn` requires a top-level/static entry, so this is forced.
- **`abort()` calling FFI directly from main isolate while worker isolate is busy** (`tts_isolate.dart:140-145`). Looks dangerous. Comment explains: the abort flag is the *only* atomic-safe way to interrupt synthesis since the worker's event loop is blocked. `_ctxAddress` is read-only after model load, freed atomically in dispose.

## Open questions for the maintainer

1. **`TtsGenerationController` (F001)** — was this a pre-streaming batch path that should be revived as an "offline export everything" feature, or is it stale?
2. **`NovelDatabase` lacks the delete-and-retry on open failure** that `TtsAudioDatabase`/`TtsDictionaryDatabase`/`EpisodeCacheDatabase` have (F003, F058). Intentional because the metadata DB is non-reproducible (can't delete user's bookmark history)? If so, what's the recovery story when it does corrupt?
3. **Hardcoded JA strings in Piper UI** (F026, settings_dialog.dart:564-715). Pending l10n that's slated, or intentionally untranslated because Piper is JA-only currently?
4. **`flutter_01.log..flutter_05.log` in repo root** (F034) — leftover from a debugging session, or part of a workflow you intend to formalize (e.g. piping `flutter run` output)?
5. **`tmp/` and `memo/` directories** (`analysis_options.yaml:5`) — analyzer-excluded. What lives there? Are they intentionally out of CI?
6. **Two HTTP clients** (F024) — `httpClientProvider` for Ollama and a self-constructed one for downloads. Was the separation intentional (different timeouts/auth)? If yes, document; if no, unify.
7. **`request_delay = 700ms`** in `download_service.dart:55` (F042). This is tuned for Narou/Kakuyomu robots-policy politeness. Is there a per-site budget that should differ for Aozora (a static archive)?
8. **`_legacyPiperModelName` migration** in `settings_repository.dart:178-185` — when can this fallback be deleted? After how many app versions?
9. **`MaterialApp.home` instead of a router** — single-screen by design, or pending a router introduction once novel-detail and settings get deep links?
10. **Two text-display modes** (horizontal `SelectableText.rich` vs vertical custom `Wrap`) maintained in parallel. Vertical does its own selection/hit-testing. Plan to converge, or accept the duplication?
