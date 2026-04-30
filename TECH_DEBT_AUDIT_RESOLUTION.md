# Tech Debt Audit — Resolution Status (post Sprint 5)

Companion to `TECH_DEBT_AUDIT.md`. Tracks the disposition of every F-numbered
finding through Sprints 0-5. Generated 2026-04-30 at the close of
`refactor-text-viewer-panel`.

Statuses:

- ✅ **Resolved** — fixed in the named sprint; the underlying smell is gone.
- ⏭️ **Deferred** — intentionally not addressed; covered by future work or
  judged "looks bad but is actually fine" per the audit's own callout.
- 🚫 **Won't fix** — current state is the deliberate choice; rationale below.

## Resolved

| ID | Sprint | Where it landed |
|----|--------|-----------------|
| F017 | Sprint 0 | Initial planning / quick wins |
| F030 | Sprint 0 | Initial planning / quick wins |
| F001 | Sprint 1 | `TtsGenerationController` deletion |
| F010 | Sprint 1 | Sprint 1 cleanup |
| F015 | Sprint 1 | Sprint 1 cleanup |
| F022 | Sprint 1 | Sprint 1 cleanup |
| F025 | Sprint 1 | Sprint 1 cleanup |
| F031 | Sprint 1 | Sprint 1 cleanup |
| F032 | Sprint 1 | Sprint 1 cleanup |
| F034 | Sprint 1 | Sprint 1 cleanup |
| F056 | Sprint 1 | Sprint 1 cleanup |
| F003 | Sprint 2 | `type-tts-dtos-and-cache-databases` |
| F007 | Sprint 2 | `TtsEpisode` / `TtsSegment` DTOs |
| F012 | Sprint 2 | DTO migration |
| F013 | Sprint 2 | DTO migration |
| F014 | Sprint 2 | DTO migration |
| F016 | Sprint 2 | DTO migration |
| F019 | Sprint 2 | Riverpod-managed DB family |
| F020 | Sprint 2 | Riverpod-managed DB family |
| F048 | Sprint 2 | Sprint 2 |
| F052 | Sprint 2 | Sprint 2 |
| F053 | Sprint 2 | Sprint 2 |
| F058 | Sprint 2 | DB open-and-retry consolidation |
| F002 | Sprint 3 | `refactor-tts-internals` (`TtsEngineConfig.resolveFromRef`) |
| F006 | Sprint 3 | `TtsSession` extraction |
| F021 | Sprint 3 | Internal refactor |
| F027 | Sprint 3 | Singleton `TextSegmenter` |
| F037 | Sprint 3 | `SegmentPlayer` extraction |
| F040 | Sprint 3 | Internal refactor |
| F004 | Sprint 4 | `refactor-settings-dialog` (sections extracted into `ConsumerWidget`s) |
| F026 | Sprint 4 | Piper section ARB migration |
| F005 | Sprint 5 | `text_viewer_panel.dart` 900 → 47 LOC; `TtsControlsBar` + `TextContentRenderer` extracted |
| F011 | Sprint 5 | Phase A panel-level integration test (`text_viewer_panel_test.dart` + `tts_controls_bar_test.dart`) |
| F028 | Sprint 5 | `_withTtsControls(...)` helper consumed by `TtsControlsBar` extraction |
| F029 | Sprint 5 | `build`-time mutation removed; `ref.listenManual(selectedFileProvider)` in `initState` |
| F046 | Sprint 5 | `TtsStreamingController` accepts `Reader` typedef instead of `ProviderContainer`; no more `ProviderScope.containerOf(context)` in `text_viewer/` |
| F051 | Sprint 5 | `ParsedSegmentsCache` is hash-keyed LRU (max 50 entries) behind `parsedSegmentsCacheProvider`; hash util shared with `TtsEpisode.textHash` via `lib/shared/utils/content_hash.dart` |

## Deferred

| ID | Why deferred |
|----|--------------|
| F008 | Low severity; addressed when nearby code is touched. |
| F009 | Same. |
| F018 (partial) | Bulk DB-cache cleanup landed in Sprint 2; remainder is touch-when-nearby. |
| F023 | Touch-when-nearby. |
| F024 | Two HTTP clients — needs maintainer answer (open question 6). |
| F033 | Touch-when-nearby. |
| F035 | Touch-when-nearby. |
| F036 | Touch-when-nearby. |
| F038 | Touch-when-nearby. |
| F041 | Touch-when-nearby. |
| F042 | Per-site polite-delay tuning — needs maintainer answer (open question 7). |
| F043 | Touch-when-nearby. |
| F044 | Touch-when-nearby. |
| F045 | Touch-when-nearby. |
| F047 | Touch-when-nearby. |
| F049 | Touch-when-nearby. |
| F050 | Touch-when-nearby. |
| F054 | Touch-when-nearby. |
| F055 | Touch-when-nearby. |
| F057 | Touch-when-nearby. |

If a deferred item ever blocks meaningful work, file a fresh OpenSpec change
(e.g. `cleanup-low-severity-rest`) rather than chaining onto an unrelated
sprint.

## Won't fix

None this round — the audit's "Things that look bad but are actually fine"
list (e.g. `_isolateEntryPoint` static, broadcast `StreamController` in
`TtsIsolate`) is preserved as-is and is documented in
`TECH_DEBT_AUDIT.md`.
