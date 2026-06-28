# Traceability

<!-- auto-generated: 2026-06-28T00:07:20.309213+00:00 | source: trace.json -->

## MECE check result

- Total extracted source units: **488**
- Covered by the spec: **488 (100.0%)**
- Explicitly excluded: **0**
- Uncovered: **0** ✅ PASSED

## Chapter → Source mapping

### 01-overview.md

- **起動時の構成** — SRC-0009 (`app.dart:1-48`), SRC-0239 (`app_test.dart:1-57`)
- **主要機能** — SRC-0195 (`home_screen.dart:1-357`)
- **UIの全体像** — SRC-0195 (`home_screen.dart:1-357`)
- **システム概要** — SRC-0200 (`main.dart:1-77`)

### 02-architecture.md

- **モジュール** — SRC-0010 (`selected_file_progress_title_provider.dart:1-27`), SRC-0011 (`startup_migrations.dart:1-16`), SRC-0027 (`update_providers.dart:1-91`), SRC-0032 (`bookmark_providers.dart:1-115`), SRC-0037 (`adjacent_files_provider.dart:1-46`), SRC-0038 (`episode_navigation_controller.dart:1-41`), SRC-0049 (`file_browser_providers.dart:1-252`), SRC-0088 (`llm_summary_providers.dart:1-98`), SRC-0100 (`reading_progress_providers.dart:1-144`), SRC-0121 (`text_download_providers.dart:1-410`), SRC-0125 (`text_search_providers.dart:1-113`), SRC-0192 (`tts_playback_providers.dart:1-94`), SRC-0193 (`tts_settings_providers.dart:1-205`), SRC-0194 (`vacuum_lifecycle_provider.dart:1-92`), SRC-0210 (`episode_resolver.dart:1-130`), SRC-0218 (`novel_id_resolver.dart:1-62`)
- **アクション境界** — SRC-0011 (`startup_migrations.dart:1-16`), SRC-0038 (`episode_navigation_controller.dart:1-41`), SRC-0100 (`reading_progress_providers.dart:1-144`), SRC-0194 (`vacuum_lifecycle_provider.dart:1-92`), SRC-0210 (`episode_resolver.dart:1-130`), SRC-0263 (`episode_navigation_controller_test.dart:1-131`)
- **データと依存性** — SRC-0027 (`update_providers.dart:1-91`), SRC-0032 (`bookmark_providers.dart:1-115`), SRC-0049 (`file_browser_providers.dart:1-252`), SRC-0056 (`keyboard_shortcut_providers.dart:1-60`), SRC-0088 (`llm_summary_providers.dart:1-98`), SRC-0097 (`novel_metadata_providers.dart:1-17`), SRC-0188 (`tts_audio_state_provider.dart:1-52`), SRC-0193 (`tts_settings_providers.dart:1-205`)
- **主要エンティティ／状態** — SRC-0037 (`adjacent_files_provider.dart:1-46`), SRC-0039 (`pending_file_entry_intent_provider.dart:1-19`), SRC-0049 (`file_browser_providers.dart:1-252`), SRC-0085 (`hover_popup_provider.dart:1-160`), SRC-0121 (`text_download_providers.dart:1-410`), SRC-0188 (`tts_audio_state_provider.dart:1-52`), SRC-0192 (`tts_playback_providers.dart:1-94`), SRC-0215 (`cancellation_token.dart:1-53`)
- **章のスコープ** — SRC-0049 (`file_browser_providers.dart:1-252`)
- **モジュール依存図** — SRC-0088 (`llm_summary_providers.dart:1-98`), SRC-0121 (`text_download_providers.dart:1-410`)
- **Detail questions raised in this chapter** — SRC-0097 (`novel_metadata_providers.dart:1-17`), SRC-0121 (`text_download_providers.dart:1-410`), SRC-0194 (`vacuum_lifecycle_provider.dart:1-92`)
- **代表シーケンス：読書位置の自動復元** — SRC-0100 (`reading_progress_providers.dart:1-144`)
- **状態遷移：ダウンロード** — SRC-0121 (`text_download_providers.dart:1-410`)
- **割当インベントリ網羅表** — SRC-0121 (`text_download_providers.dart:1-410`), SRC-0240 (`reading_progress_wiring_test.dart:1-183`), SRC-0241 (`selected_file_progress_title_provider_test.dart:1-156`), SRC-0242 (`startup_migrations_test.dart:1-64`), SRC-0254 (`bookmark_providers_test.dart:1-307`), SRC-0262 (`adjacent_files_provider_test.dart:1-149`), SRC-0278 (`directory_contents_title_mapping_test.dart:1-86`), SRC-0281 (`folder_switch_handle_release_test.dart:1-73`), SRC-0289 (`keyboard_shortcut_providers_test.dart:1-94`), SRC-0318 (`llm_summary_providers_test.dart:1-228`), SRC-0334 (`reading_progress_listeners_test.dart:1-636`), SRC-0335 (`reading_progress_providers_test.dart:1-53`), SRC-0380 (`text_search_providers_test.dart:1-242`), SRC-0457 (`text_segmenter_provider_test.dart:1-20`), SRC-0462 (`tts_settings_providers_test.dart:1-316`), SRC-0477 (`episode_resolver_test.dart:1-189`), SRC-0483 (`novel_id_resolver_test.dart:1-101`)

### 03-screens.md

- **画面モジュール** — SRC-0025 (`update_badge.dart:1-27`), SRC-0026 (`update_dialog.dart:1-193`), SRC-0030 (`bookmark_list_panel.dart:1-131`), SRC-0031 (`left_column_panel.dart:1-56`), SRC-0045 (`file_browser_panel.dart:1-812`), SRC-0075 (`analysis_runner.dart:1-273`), SRC-0078 (`hover_popup_widget.dart:1-314`), SRC-0081 (`llm_summary_history_panel.dart:1-175`), SRC-0120 (`download_dialog.dart:1-461`), SRC-0124 (`search_results_panel.dart:1-196`), SRC-0138 (`text_viewer_panel.dart:1-49`), SRC-0140 (`vertical_text_page.dart:1-760`), SRC-0141 (`vertical_text_viewer.dart:1-1177`), SRC-0142 (`text_content_renderer.dart:1-909`), SRC-0143 (`tts_controls_bar.dart:1-580`), SRC-0182 (`tts_dictionary_dialog.dart:1-199`), SRC-0183 (`tts_edit_dialog.dart:1-694`), SRC-0184 (`voice_recording_dialog.dart:1-385`), SRC-0195 (`home_screen.dart:1-357`)
- **主要画面遷移** — SRC-0025 (`update_badge.dart:1-27`), SRC-0030 (`bookmark_list_panel.dart:1-131`), SRC-0045 (`file_browser_panel.dart:1-812`), SRC-0120 (`download_dialog.dart:1-461`), SRC-0124 (`search_results_panel.dart:1-196`), SRC-0142 (`text_content_renderer.dart:1-909`), SRC-0143 (`tts_controls_bar.dart:1-580`), SRC-0195 (`home_screen.dart:1-357`)
- **Deep-dive candidates (refer to them by ID)** — SRC-0045 (`file_browser_panel.dart:1-812`), SRC-0078 (`hover_popup_widget.dart:1-314`), SRC-0141 (`vertical_text_viewer.dart:1-1177`), SRC-0142 (`text_content_renderer.dart:1-909`), SRC-0143 (`tts_controls_bar.dart:1-580`)
- **章のスコープ** — SRC-0195 (`home_screen.dart:1-357`)
- **表示状態とエッジケース** — SRC-0273 (`file_browser_panel_test.dart:1-1140`), SRC-0379 (`search_results_panel_test.dart:1-630`), SRC-0393 (`text_viewer_panel_test.dart:1-575`), SRC-0398 (`tts_highlight_horizontal_test.dart:1-105`), SRC-0399 (`tts_highlight_page_offset_test.dart:1-230`), SRC-0400 (`tts_highlight_vertical_test.dart:1-152`), SRC-0408 (`vertical_text_viewer_episode_nav_test.dart:1-399`), SRC-0413 (`vertical_text_viewer_swipe_test.dart:1-327`), SRC-0415 (`vertical_text_viewer_wheel_test.dart:1-199`), SRC-0469 (`home_screen_test.dart:1-656`)
- **Detail questions raised in this chapter** — SRC-0469 (`home_screen_test.dart:1-656`)

### 04-features.md

- **機能モジュール一覧** — SRC-0012 (`distribution_detector.dart:1-44`), SRC-0015 (`installer_updater.dart:1-91`), SRC-0040 (`file_system_service.dart:1-300`), SRC-0052 (`shortcut_action.dart:1-14`), SRC-0054 (`shortcut_intents.dart:1-52`), SRC-0062 (`llm_summary_pipeline.dart:1-192`), SRC-0064 (`llm_summary_service.dart:1-234`), SRC-0093 (`novel_data_migrator.dart:1-189`), SRC-0112 (`download_service.dart:1-923`), SRC-0122 (`search_models.dart:1-35`), SRC-0150 (`piper_tts_engine.dart:1-99`), SRC-0161 (`tts_engine.dart:1-300`), SRC-0169 (`tts_session.dart:1-205`), SRC-0265 (`download_destination_folders_test.dart:1-119`), SRC-0321 (`novel_delete_order_test.dart:1-133`), SRC-0322 (`novel_delete_service_test.dart:1-220`), SRC-0378 (`text_search_service_test.dart:1-187`)
- **割当インベントリの網羅** — SRC-0012 (`distribution_detector.dart:1-44`), SRC-0014 (`installer_downloader.dart:1-118`), SRC-0015 (`installer_updater.dart:1-91`), SRC-0016 (`installer_verifier.dart:1-37`), SRC-0017 (`process_starter.dart:1-21`), SRC-0018 (`registry_reader.dart:1-35`), SRC-0019 (`release_info.dart:1-55`), SRC-0020 (`update_preferences.dart:1-32`), SRC-0040 (`file_system_service.dart:1-300`), SRC-0050 (`focus_utils.dart:1-16`), SRC-0051 (`key_binding_label.dart:1-23`), SRC-0052 (`shortcut_action.dart:1-14`), SRC-0053 (`shortcut_bindings.dart:1-141`), SRC-0054 (`shortcut_intents.dart:1-52`), SRC-0057 (`context_chunker.dart:1-34`), SRC-0060 (`llm_prompt_builder.dart:1-56`), SRC-0061 (`llm_response_format_exception.dart:1-28`), SRC-0062 (`llm_summary_pipeline.dart:1-192`), SRC-0064 (`llm_summary_service.dart:1-234`), SRC-0091 (`novel_delete_service.dart:1-59`), SRC-0093 (`novel_data_migrator.dart:1-189`), SRC-0112 (`download_service.dart:1-923`), SRC-0113 (`novel_library_service.dart:1-81`), SRC-0122 (`search_models.dart:1-35`), SRC-0123 (`text_search_service.dart:1-100`), SRC-0150 (`piper_tts_engine.dart:1-99`), SRC-0151 (`segment_player.dart:1-131`), SRC-0152 (`text_segmenter.dart:1-218`), SRC-0153 (`tts_adapters.dart:1-37`), SRC-0155 (`tts_audio_export_service.dart:1-204`), SRC-0159 (`tts_edit_controller.dart:1-472`), SRC-0160 (`tts_edit_segment.dart:1-62`), SRC-0161 (`tts_engine.dart:1-300`), SRC-0162 (`tts_engine_type.dart:1-8`), SRC-0163 (`tts_isolate.dart:1-541`), SRC-0164 (`tts_language.dart:1-22`), SRC-0166 (`tts_model_size.dart:1-14`), SRC-0168 (`tts_playback_controller.dart:1-12`), SRC-0169 (`tts_session.dart:1-205`), SRC-0170 (`tts_streaming_controller.dart:1-389`), SRC-0171 (`tts_toggle.dart:1-27`), SRC-0172 (`voice_recording_service.dart:1-65`), SRC-0173 (`voice_reference_service.dart:1-105`), SRC-0174 (`wav_writer.dart:1-80`), SRC-0243 (`distribution_detector_test.dart:1-104`), SRC-0245 (`installer_downloader_test.dart:1-68`), SRC-0246 (`installer_updater_test.dart:1-197`), SRC-0247 (`installer_verifier_test.dart:1-124`), SRC-0248 (`registry_reader_test.dart:1-47`), SRC-0249 (`update_preferences_test.dart:1-53`) ... and 60 more
- **Deep-dive candidates (refer to them by ID)** — SRC-0015 (`installer_updater.dart:1-91`), SRC-0062 (`llm_summary_pipeline.dart:1-192`), SRC-0091 (`novel_delete_service.dart:1-59`), SRC-0112 (`download_service.dart:1-923`), SRC-0152 (`text_segmenter.dart:1-218`), SRC-0159 (`tts_edit_controller.dart:1-472`), SRC-0163 (`tts_isolate.dart:1-541`), SRC-0170 (`tts_streaming_controller.dart:1-389`), SRC-0173 (`voice_reference_service.dart:1-105`), SRC-0359 (`episode_filename_pad_migration_test.dart:1-297`), SRC-0366 (`index_fixture_parsing_test.dart:1-83`), SRC-0367 (`index_truncated_test.dart:1-148`), SRC-0375 (`url_validation_test.dart:1-133`)
- **ダウンロードの業務ルール** — SRC-0112 (`download_service.dart:1-923`), SRC-0348 (`aozora_site_test.dart:1-252`), SRC-0350 (`download_cancellation_test.dart:1-143`), SRC-0357 (`empty_index_guard_test.dart:1-109`), SRC-0359 (`episode_filename_pad_migration_test.dart:1-297`), SRC-0361 (`file_naming_test.dart:1-55`), SRC-0363 (`hameln_site_test.dart:1-420`), SRC-0367 (`index_truncated_test.dart:1-148`), SRC-0368 (`kakuyomu_site_test.dart:1-685`), SRC-0369 (`narou_site_test.dart:1-523`), SRC-0370 (`novel_library_service_test.dart:1-59`), SRC-0371 (`novel_site_test.dart:1-137`), SRC-0374 (`transient_retry_test.dart:1-323`), SRC-0376 (`user_agent_precedence_test.dart:1-52`)
- **主要アクション** — SRC-0123 (`text_search_service.dart:1-100`), SRC-0155 (`tts_audio_export_service.dart:1-204`), SRC-0246 (`installer_updater_test.dart:1-197`), SRC-0266 (`file_system_service_test.dart:1-409`), SRC-0291 (`context_chunker_test.dart:1-60`), SRC-0295 (`llm_summary_pipeline_per_file_test.dart:1-323`), SRC-0322 (`novel_delete_service_test.dart:1-220`), SRC-0349 (`collection_download_test.dart:1-300`), SRC-0358 (`empty_parse_failure_test.dart:1-206`), SRC-0365 (`incremental_download_test.dart:1-929`), SRC-0378 (`text_search_service_test.dart:1-187`), SRC-0432 (`tts_audio_export_service_test.dart:1-178`), SRC-0435 (`tts_edit_controller_test.dart:1-2328`), SRC-0445 (`tts_streaming_controller_test.dart:1-1586`)
- **TTSの状態とデータフロー** — SRC-0161 (`tts_engine.dart:1-300`), SRC-0163 (`tts_isolate.dart:1-541`), SRC-0427 (`piper_tts_engine_test.dart:1-205`), SRC-0428 (`segment_player_test.dart:1-206`), SRC-0429 (`text_segmenter_test.dart:1-472`), SRC-0436 (`tts_edit_segment_test.dart:1-158`), SRC-0444 (`tts_session_test.dart:1-587`), SRC-0446 (`tts_toggle_test.dart:1-48`), SRC-0447 (`voice_recording_service_test.dart:1-166`), SRC-0448 (`voice_reference_service_test.dart:1-307`), SRC-0449 (`wav_writer_test.dart:1-117`)
- **Q-006** — SRC-0371 (`novel_site_test.dart:1-137`)

### 05-data-model.md

- **Entities** — SRC-0021 (`distribution_type.dart:1-5`), SRC-0022 (`update_check_service.dart:1-97`), SRC-0029 (`bookmark.dart:1-34`), SRC-0035 (`episode_cache.dart:1-35`), SRC-0041 (`move_destination.dart:1-49`), SRC-0044 (`reading_progress_badge.dart:1-43`), SRC-0067 (`analysis_progress.dart:1-40`), SRC-0068 (`fact_cache_entry.dart:1-49`), SRC-0070 (`history_entry.dart:1-64`), SRC-0071 (`hover_token.dart:1-11`), SRC-0072 (`llm_config.dart:1-15`), SRC-0073 (`llm_summary_result.dart:1-50`), SRC-0074 (`mark_matcher.dart:1-88`), SRC-0096 (`novel_metadata.dart:1-53`), SRC-0099 (`reading_progress.dart:1-27`), SRC-0175 (`_row_helpers.dart:1-13`), SRC-0176 (`tts_engine_config.dart:1-167`), SRC-0177 (`tts_episode.dart:1-40`), SRC-0180 (`tts_segment.dart:1-56`)
- **Modules** — SRC-0028 (`bookmark_repository.dart:1-99`), SRC-0033 (`episode_cache_database.dart:1-47`), SRC-0058 (`fact_cache_repository.dart:1-107`), SRC-0094 (`novel_database.dart:1-601`), SRC-0098 (`reading_progress_repository.dart:1-57`), SRC-0099 (`reading_progress.dart:1-27`), SRC-0128 (`parsed_segments_cache.dart:1-36`), SRC-0154 (`tts_audio_database.dart:1-138`), SRC-0157 (`tts_dictionary_database.dart:1-45`), SRC-0206 (`novel_data_database.dart:1-107`), SRC-0208 (`per_folder_db_registry.dart:1-164`)
- **Actions** — SRC-0028 (`bookmark_repository.dart:1-99`), SRC-0058 (`fact_cache_repository.dart:1-107`), SRC-0063 (`llm_summary_repository.dart:1-99`), SRC-0095 (`novel_repository.dart:1-90`), SRC-0098 (`reading_progress_repository.dart:1-57`), SRC-0128 (`parsed_segments_cache.dart:1-36`), SRC-0156 (`tts_audio_repository.dart:1-228`), SRC-0158 (`tts_dictionary_repository.dart:1-122`), SRC-0202 (`database_opener.dart:1-63`)
- **Data** — SRC-0028 (`bookmark_repository.dart:1-99`), SRC-0033 (`episode_cache_database.dart:1-47`), SRC-0094 (`novel_database.dart:1-601`), SRC-0154 (`tts_audio_database.dart:1-138`), SRC-0157 (`tts_dictionary_database.dart:1-45`), SRC-0206 (`novel_data_database.dart:1-107`)
- **Dependencies** — SRC-0033 (`episode_cache_database.dart:1-47`), SRC-0068 (`fact_cache_entry.dart:1-49`), SRC-0128 (`parsed_segments_cache.dart:1-36`), SRC-0187 (`tts_audio_database_provider.dart:1-27`), SRC-0202 (`database_opener.dart:1-63`), SRC-0205 (`folder_db_key.dart:1-21`), SRC-0207 (`novel_data_database_provider.dart:1-16`)
- **章の要約** — SRC-0094 (`novel_database.dart:1-601`), SRC-0203 (`db_connection_gate.dart:1-91`), SRC-0206 (`novel_data_database.dart:1-107`), SRC-0208 (`per_folder_db_registry.dart:1-164`)
- **移行・整合性・障害時動作** — SRC-0094 (`novel_database.dart:1-601`), SRC-0154 (`tts_audio_database.dart:1-138`), SRC-0202 (`database_opener.dart:1-63`), SRC-0203 (`db_connection_gate.dart:1-91`), SRC-0206 (`novel_data_database.dart:1-107`)
- **不確実性** — SRC-0094 (`novel_database.dart:1-601`), SRC-0206 (`novel_data_database.dart:1-107`)
- **状態遷移とデータフロー** — SRC-0178 (`tts_episode_status.dart:1-15`), SRC-0433 (`tts_audio_repository_test.dart:1-689`)
- **割当インベントリ網羅性** — SRC-0323 (`novel_database_migration_full_chain_test.dart:1-101`), SRC-0472 (`db_connection_gate_test.dart:1-144`), SRC-0475 (`novel_data_database_test.dart:1-176`)

### 06-settings-security.md

- **アクセス・認証境界** — SRC-0009 (`app.dart:1-48`), SRC-0102 (`settings_repository.dart:1-287`), SRC-0200 (`main.dart:1-77`)
- **エンティティ** — SRC-0101 (`font_family.dart:1-57`), SRC-0102 (`settings_repository.dart:1-287`), SRC-0103 (`text_display_mode.dart:1-4`), SRC-0111 (`settings_providers.dart:1-137`), SRC-0212 (`file_log_sink.dart:1-97`), SRC-0213 (`log_sink.dart:1-9`)
- **割当インベントリ網羅表** — SRC-0101 (`font_family.dart:1-57`), SRC-0102 (`settings_repository.dart:1-287`), SRC-0103 (`text_display_mode.dart:1-4`), SRC-0104 (`about_and_update_section.dart:1-123`), SRC-0105 (`general_settings_section.dart:1-145`), SRC-0106 (`llm_settings_section.dart:1-284`), SRC-0107 (`piper_settings_section.dart:1-181`), SRC-0108 (`qwen3_settings_section.dart:1-175`), SRC-0109 (`voice_reference_section.dart:1-310`), SRC-0110 (`settings_dialog.dart:1-166`), SRC-0111 (`settings_providers.dart:1-137`), SRC-0196 (`app_localizations.dart:1-1728`), SRC-0197 (`app_localizations_en.dart:1-903`), SRC-0198 (`app_localizations_ja.dart:1-886`), SRC-0199 (`app_localizations_zh.dart:1-884`), SRC-0211 (`app_logger.dart:1-83`), SRC-0212 (`file_log_sink.dart:1-97`), SRC-0213 (`log_sink.dart:1-9`), SRC-0336 (`font_family_test.dart:1-109`), SRC-0337 (`settings_repository_shortcuts_test.dart:1-57`), SRC-0338 (`settings_repository_test.dart:1-388`), SRC-0339 (`llm_settings_test.dart:1-278`), SRC-0340 (`settings_dialog_phase_a_test.dart:1-166`), SRC-0341 (`settings_dialog_tabs_test.dart:1-139`), SRC-0342 (`settings_dialog_test.dart:1-170`), SRC-0343 (`settings_piper_l10n_test.dart:1-56`), SRC-0344 (`settings_test.dart:1-50`), SRC-0345 (`tts_model_download_ui_test.dart:1-164`), SRC-0346 (`voice_reference_selector_test.dart:1-306`), SRC-0347 (`settings_providers_test.dart:1-227`), SRC-0478 (`app_logger_test.dart:1-165`), SRC-0479 (`file_log_sink_test.dart:1-139`), SRC-0485 (`flutter_secure_storage_mock.dart:1-65`)
- **章の要約** — SRC-0102 (`settings_repository.dart:1-287`), SRC-0110 (`settings_dialog.dart:1-166`), SRC-0211 (`app_logger.dart:1-83`)
- **モジュール** — SRC-0102 (`settings_repository.dart:1-287`), SRC-0109 (`voice_reference_section.dart:1-310`), SRC-0110 (`settings_dialog.dart:1-166`), SRC-0111 (`settings_providers.dart:1-137`), SRC-0196 (`app_localizations.dart:1-1728`), SRC-0211 (`app_logger.dart:1-83`), SRC-0212 (`file_log_sink.dart:1-97`)
- **アクション** — SRC-0102 (`settings_repository.dart:1-287`), SRC-0106 (`llm_settings_section.dart:1-284`), SRC-0109 (`voice_reference_section.dart:1-310`), SRC-0211 (`app_logger.dart:1-83`), SRC-0212 (`file_log_sink.dart:1-97`)
- **永続データ** — SRC-0102 (`settings_repository.dart:1-287`), SRC-0109 (`voice_reference_section.dart:1-310`), SRC-0211 (`app_logger.dart:1-83`), SRC-0212 (`file_log_sink.dart:1-97`)
- **依存関係** — SRC-0102 (`settings_repository.dart:1-287`), SRC-0111 (`settings_providers.dart:1-137`), SRC-0196 (`app_localizations.dart:1-1728`)
- **セキュリティ境界** — SRC-0102 (`settings_repository.dart:1-287`), SRC-0106 (`llm_settings_section.dart:1-284`), SRC-0212 (`file_log_sink.dart:1-97`), SRC-0338 (`settings_repository_test.dart:1-388`)
- **Deep-dive candidates (refer to them by ID)** — SRC-0102 (`settings_repository.dart:1-287`), SRC-0104 (`about_and_update_section.dart:1-123`), SRC-0109 (`voice_reference_section.dart:1-310`), SRC-0212 (`file_log_sink.dart:1-97`)
- **ローカライズ** — SRC-0196 (`app_localizations.dart:1-1728`), SRC-0197 (`app_localizations_en.dart:1-903`), SRC-0198 (`app_localizations_ja.dart:1-886`), SRC-0199 (`app_localizations_zh.dart:1-884`)

### 07-external-integrations.md

- **連携モジュール** — SRC-0013 (`github_release_client.dart:1-57`), SRC-0059 (`llm_client.dart:1-5`), SRC-0065 (`ollama_client.dart:1-96`), SRC-0066 (`openai_compatible_client.dart:1-72`), SRC-0114 (`aozora_site.dart:1-74`), SRC-0115 (`generic_web_site.dart:1-239`), SRC-0116 (`hameln_site.dart:1-200`), SRC-0117 (`kakuyomu_site.dart:1-162`), SRC-0118 (`narou_site.dart:1-191`), SRC-0119 (`novel_site.dart:1-103`), SRC-0146 (`lame_enc_bindings.dart:1-62`), SRC-0147 (`model_download_utils.dart:1-57`), SRC-0148 (`piper_model_download_service.dart:1-146`), SRC-0149 (`piper_native_bindings.dart:1-95`), SRC-0165 (`tts_model_download_service.dart:1-102`), SRC-0167 (`tts_native_bindings.dart:1-230`), SRC-0185 (`piper_model_download_providers.dart:1-111`), SRC-0191 (`tts_model_download_providers.dart:1-107`)
- **外部HTTP依存** — SRC-0013 (`github_release_client.dart:1-57`), SRC-0065 (`ollama_client.dart:1-96`), SRC-0066 (`openai_compatible_client.dart:1-72`), SRC-0114 (`aozora_site.dart:1-74`), SRC-0115 (`generic_web_site.dart:1-239`), SRC-0119 (`novel_site.dart:1-103`), SRC-0147 (`model_download_utils.dart:1-57`), SRC-0148 (`piper_model_download_service.dart:1-146`), SRC-0165 (`tts_model_download_service.dart:1-102`)
- **Deep-dive candidates (refer to them by ID)** — SRC-0065 (`ollama_client.dart:1-96`), SRC-0066 (`openai_compatible_client.dart:1-72`), SRC-0115 (`generic_web_site.dart:1-239`), SRC-0119 (`novel_site.dart:1-103`), SRC-0165 (`tts_model_download_service.dart:1-102`), SRC-0167 (`tts_native_bindings.dart:1-230`), SRC-0185 (`piper_model_download_providers.dart:1-111`)
- **ネイティブライブラリ境界** — SRC-0146 (`lame_enc_bindings.dart:1-62`), SRC-0149 (`piper_native_bindings.dart:1-95`), SRC-0167 (`tts_native_bindings.dart:1-230`)
- **代表シーケンス** — SRC-0147 (`model_download_utils.dart:1-57`), SRC-0165 (`tts_model_download_service.dart:1-102`), SRC-0191 (`tts_model_download_providers.dart:1-107`)
- **検証証拠** — SRC-0244 (`github_release_client_test.dart:1-128`), SRC-0293 (`llm_client_test.dart:1-541`), SRC-0425 (`lame_enc_bindings_test.dart:1-107`), SRC-0426 (`piper_model_download_service_test.dart:1-76`), SRC-0441 (`tts_model_download_service_test.dart:1-377`), SRC-0443 (`tts_native_bindings_test.dart:1-46`), SRC-0460 (`tts_model_download_providers_test.dart:1-209`)

### 08-operations.md

- **章の要約** — SRC-0001 (`.fvmrc:1-3`), SRC-0002 (`release.yml:1-171`), SRC-0003 (`test.yml:1-38`)
- **モジュール** — SRC-0001 (`.fvmrc:1-3`), SRC-0002 (`release.yml:1-171`), SRC-0003 (`test.yml:1-38`), SRC-0005 (`analysis_options.yaml:1-16`), SRC-0006 (`build.gradle.kts:1-44`), SRC-0007 (`AppDelegate.swift:1-13`), SRC-0008 (`l10n.yaml:1-3`), SRC-0220 (`CMakeLists.txt:1-128`), SRC-0221 (`main.cc:1-6`), SRC-0222 (`AppDelegate.swift:1-13`), SRC-0223 (`pubspec.yaml:1-127`), SRC-0225 (`build_lame_macos.sh:1-30`), SRC-0226 (`build_lame_windows.bat:1-23`), SRC-0227 (`build_piper_macos.sh:1-53`), SRC-0228 (`build_piper_windows.bat:1-36`), SRC-0229 (`build_tts_macos.sh:1-44`), SRC-0230 (`build_tts_windows.bat:1-36`), SRC-0233 (`release.ps1:1-91`), SRC-0234 (`release.sh:1-92`), SRC-0487 (`CMakeLists.txt:1-113`), SRC-0488 (`main.cpp:1-43`)
- **依存関係** — SRC-0001 (`.fvmrc:1-3`), SRC-0002 (`release.yml:1-171`), SRC-0220 (`CMakeLists.txt:1-128`), SRC-0223 (`pubspec.yaml:1-127`), SRC-0487 (`CMakeLists.txt:1-113`)
- **割当インベントリ網羅表** — SRC-0001 (`.fvmrc:1-3`), SRC-0002 (`release.yml:1-171`), SRC-0003 (`test.yml:1-38`), SRC-0004 (`.metadata:1-42`), SRC-0005 (`analysis_options.yaml:1-16`), SRC-0006 (`build.gradle.kts:1-44`), SRC-0007 (`AppDelegate.swift:1-13`), SRC-0008 (`l10n.yaml:1-3`), SRC-0220 (`CMakeLists.txt:1-128`), SRC-0221 (`main.cc:1-6`), SRC-0222 (`AppDelegate.swift:1-13`), SRC-0223 (`pubspec.yaml:1-127`), SRC-0224 (`benchmark_tts.sh:1-289`), SRC-0225 (`build_lame_macos.sh:1-30`), SRC-0226 (`build_lame_windows.bat:1-23`), SRC-0227 (`build_piper_macos.sh:1-53`), SRC-0228 (`build_piper_windows.bat:1-36`), SRC-0229 (`build_tts_macos.sh:1-44`), SRC-0230 (`build_tts_windows.bat:1-36`), SRC-0231 (`clean.bat:1-12`), SRC-0232 (`clean.sh:1-8`), SRC-0233 (`release.ps1:1-91`), SRC-0234 (`release.sh:1-92`), SRC-0235 (`release_test.ps1:1-107`), SRC-0236 (`release_test.sh:1-88`), SRC-0237 (`verify_release_version_test.sh:1-43`), SRC-0238 (`verify_release_version.sh:1-46`), SRC-0487 (`CMakeLists.txt:1-113`), SRC-0488 (`main.cpp:1-43`)
- **アクション** — SRC-0002 (`release.yml:1-171`), SRC-0003 (`test.yml:1-38`), SRC-0224 (`benchmark_tts.sh:1-289`), SRC-0231 (`clean.bat:1-12`), SRC-0232 (`clean.sh:1-8`), SRC-0234 (`release.sh:1-92`), SRC-0238 (`verify_release_version.sh:1-46`)
- **データ・成果物** — SRC-0002 (`release.yml:1-171`), SRC-0220 (`CMakeLists.txt:1-128`), SRC-0223 (`pubspec.yaml:1-127`), SRC-0224 (`benchmark_tts.sh:1-289`), SRC-0226 (`build_lame_windows.bat:1-23`), SRC-0228 (`build_piper_windows.bat:1-36`), SRC-0230 (`build_tts_windows.bat:1-36`), SRC-0487 (`CMakeLists.txt:1-113`)
- **CI・リリースフロー** — SRC-0002 (`release.yml:1-171`), SRC-0003 (`test.yml:1-38`)
- **プラットフォーム別運用** — SRC-0002 (`release.yml:1-171`), SRC-0006 (`build.gradle.kts:1-44`), SRC-0007 (`AppDelegate.swift:1-13`), SRC-0220 (`CMakeLists.txt:1-128`), SRC-0225 (`build_lame_macos.sh:1-30`), SRC-0227 (`build_piper_macos.sh:1-53`), SRC-0229 (`build_tts_macos.sh:1-44`), SRC-0487 (`CMakeLists.txt:1-113`), SRC-0488 (`main.cpp:1-43`)
- **品質・安全ゲート** — SRC-0002 (`release.yml:1-171`), SRC-0006 (`build.gradle.kts:1-44`), SRC-0233 (`release.ps1:1-91`), SRC-0234 (`release.sh:1-92`), SRC-0235 (`release_test.ps1:1-107`), SRC-0236 (`release_test.sh:1-88`), SRC-0237 (`verify_release_version_test.sh:1-43`)
- **Deep-dive candidates (refer to them by ID)** — SRC-0002 (`release.yml:1-171`), SRC-0003 (`test.yml:1-38`), SRC-0004 (`.metadata:1-42`), SRC-0006 (`build.gradle.kts:1-44`), SRC-0226 (`build_lame_windows.bat:1-23`), SRC-0228 (`build_piper_windows.bat:1-36`), SRC-0229 (`build_tts_macos.sh:1-44`), SRC-0230 (`build_tts_windows.bat:1-36`)

### 09-constraints.md

- **技術制約** — SRC-0002 (`release.yml:1-171`), SRC-0065 (`ollama_client.dart:1-96`), SRC-0066 (`openai_compatible_client.dart:1-72`), SRC-0115 (`generic_web_site.dart:1-239`), SRC-0167 (`tts_native_bindings.dart:1-230`), SRC-0200 (`main.dart:1-77`), SRC-0223 (`pubspec.yaml:1-127`)
- **ビルド・品質保証制約** — SRC-0002 (`release.yml:1-171`), SRC-0003 (`test.yml:1-38`), SRC-0005 (`analysis_options.yaml:1-16`)
- **配布・運用制約** — SRC-0002 (`release.yml:1-171`), SRC-0212 (`file_log_sink.dart:1-97`)
- **Deep-dive candidates (refer to them by ID)** — SRC-0003 (`test.yml:1-38`), SRC-0094 (`novel_database.dart:1-601`), SRC-0115 (`generic_web_site.dart:1-239`), SRC-0167 (`tts_native_bindings.dart:1-230`), SRC-0194 (`vacuum_lifecycle_provider.dart:1-92`), SRC-0212 (`file_log_sink.dart:1-97`)
- **既存の未解決事項** — SRC-0094 (`novel_database.dart:1-601`), SRC-0097 (`novel_metadata_providers.dart:1-17`), SRC-0102 (`settings_repository.dart:1-287`), SRC-0121 (`text_download_providers.dart:1-410`), SRC-0194 (`vacuum_lifecycle_provider.dart:1-92`), SRC-0212 (`file_log_sink.dart:1-97`), SRC-0371 (`novel_site_test.dart:1-137`), SRC-0469 (`home_screen_test.dart:1-656`)
- **Q-013** — SRC-0167 (`tts_native_bindings.dart:1-230`), SRC-0200 (`main.dart:1-77`)

### traceability.md

- **Inventory source reference index** — SRC-0001 (`.fvmrc:1-3`), SRC-0002 (`release.yml:1-171`), SRC-0003 (`test.yml:1-38`), SRC-0004 (`.metadata:1-42`), SRC-0005 (`analysis_options.yaml:1-16`), SRC-0006 (`build.gradle.kts:1-44`), SRC-0007 (`AppDelegate.swift:1-13`), SRC-0008 (`l10n.yaml:1-3`), SRC-0009 (`app.dart:1-48`), SRC-0010 (`selected_file_progress_title_provider.dart:1-27`), SRC-0011 (`startup_migrations.dart:1-16`), SRC-0012 (`distribution_detector.dart:1-44`), SRC-0013 (`github_release_client.dart:1-57`), SRC-0014 (`installer_downloader.dart:1-118`), SRC-0015 (`installer_updater.dart:1-91`), SRC-0016 (`installer_verifier.dart:1-37`), SRC-0017 (`process_starter.dart:1-21`), SRC-0018 (`registry_reader.dart:1-35`), SRC-0019 (`release_info.dart:1-55`), SRC-0020 (`update_preferences.dart:1-32`), SRC-0021 (`distribution_type.dart:1-5`), SRC-0022 (`update_check_service.dart:1-97`), SRC-0023 (`update_constants.dart:1-25`), SRC-0024 (`version_comparator.dart:1-29`), SRC-0025 (`update_badge.dart:1-27`), SRC-0026 (`update_dialog.dart:1-193`), SRC-0027 (`update_providers.dart:1-91`), SRC-0028 (`bookmark_repository.dart:1-99`), SRC-0029 (`bookmark.dart:1-34`), SRC-0030 (`bookmark_list_panel.dart:1-131`), SRC-0031 (`left_column_panel.dart:1-56`), SRC-0032 (`bookmark_providers.dart:1-115`), SRC-0033 (`episode_cache_database.dart:1-47`), SRC-0034 (`episode_cache_repository.dart:1-38`), SRC-0035 (`episode_cache.dart:1-35`), SRC-0036 (`file_entry_start_intent.dart:1-10`), SRC-0037 (`adjacent_files_provider.dart:1-46`), SRC-0038 (`episode_navigation_controller.dart:1-41`), SRC-0039 (`pending_file_entry_intent_provider.dart:1-19`), SRC-0040 (`file_system_service.dart:1-300`), SRC-0041 (`move_destination.dart:1-49`), SRC-0042 (`move_follow.dart:1-22`), SRC-0043 (`novel_folder_classifier.dart:1-9`), SRC-0044 (`reading_progress_badge.dart:1-43`), SRC-0045 (`file_browser_panel.dart:1-812`), SRC-0046 (`move_destination_dialog.dart:1-52`), SRC-0047 (`new_folder_dialog.dart:1-84`), SRC-0048 (`rename_title_dialog.dart:1-64`), SRC-0049 (`file_browser_providers.dart:1-252`), SRC-0050 (`focus_utils.dart:1-16`) ... and 438 more

## Source → Chapter mapping (by file)

### `.fvmrc`

- **SRC-0001** (configuration `.fvmrc` lines 1-3) → 08-operations.md §章の要約, 08-operations.md §モジュール, 08-operations.md §依存関係, 08-operations.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `.github/workflows/release.yml`

- **SRC-0002** (workflow `release.yml` lines 1-171) → 08-operations.md §章の要約, 08-operations.md §モジュール, 08-operations.md §アクション, 08-operations.md §データ・成果物, 08-operations.md §依存関係 (and 9 more)

### `.github/workflows/test.yml`

- **SRC-0003** (workflow `test.yml` lines 1-38) → 08-operations.md §章の要約, 08-operations.md §モジュール, 08-operations.md §アクション, 08-operations.md §CI・リリースフロー, 08-operations.md §割当インベントリ網羅表 (and 4 more)

### `.metadata`

- **SRC-0004** (configuration `.metadata` lines 1-42) → 08-operations.md §割当インベントリ網羅表, 08-operations.md §Deep-dive candidates (refer to them by ID), traceability.md §Inventory source reference index

### `analysis_options.yaml`

- **SRC-0005** (configuration `analysis_options.yaml` lines 1-16) → 08-operations.md §モジュール, 08-operations.md §割当インベントリ網羅表, 09-constraints.md §ビルド・品質保証制約, traceability.md §Inventory source reference index

### `android/app/build.gradle.kts`

- **SRC-0006** (other `build.gradle.kts` lines 1-44) → 08-operations.md §モジュール, 08-operations.md §プラットフォーム別運用, 08-operations.md §品質・安全ゲート, 08-operations.md §割当インベントリ網羅表, 08-operations.md §Deep-dive candidates (refer to them by ID) (and 1 more)

### `ios/Runner/AppDelegate.swift`

- **SRC-0007** (other `AppDelegate.swift` lines 1-13) → 08-operations.md §モジュール, 08-operations.md §プラットフォーム別運用, 08-operations.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `l10n.yaml`

- **SRC-0008** (configuration `l10n.yaml` lines 1-3) → 08-operations.md §モジュール, 08-operations.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `lib/app.dart`

- **SRC-0009** (module `app.dart` lines 1-48) → 01-overview.md §起動時の構成, 06-settings-security.md §アクセス・認証境界, traceability.md §Inventory source reference index

### `lib/app/selected_file_progress_title_provider.dart`

- **SRC-0010** (provider `selected_file_progress_title_provider.dart` lines 1-27) → 02-architecture.md §モジュール, traceability.md §Inventory source reference index

### `lib/app/startup_migrations.dart`

- **SRC-0011** (module `startup_migrations.dart` lines 1-16) → 02-architecture.md §モジュール, 02-architecture.md §アクション境界, traceability.md §Inventory source reference index

### `lib/features/app_update/data/distribution_detector.dart`

- **SRC-0012** (module `distribution_detector.dart` lines 1-44) → 04-features.md §機能モジュール一覧, 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `lib/features/app_update/data/github_release_client.dart`

- **SRC-0013** (integration `github_release_client.dart` lines 1-57) → 07-external-integrations.md §連携モジュール, 07-external-integrations.md §外部HTTP依存, traceability.md §Inventory source reference index

### `lib/features/app_update/data/installer_downloader.dart`

- **SRC-0014** (integration `installer_downloader.dart` lines 1-118) → 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `lib/features/app_update/data/installer_updater.dart`

- **SRC-0015** (module `installer_updater.dart` lines 1-91) → 04-features.md §機能モジュール一覧, 04-features.md §Deep-dive candidates (refer to them by ID), 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `lib/features/app_update/data/installer_verifier.dart`

- **SRC-0016** (module `installer_verifier.dart` lines 1-37) → 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `lib/features/app_update/data/process_starter.dart`

- **SRC-0017** (module `process_starter.dart` lines 1-21) → 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `lib/features/app_update/data/registry_reader.dart`

- **SRC-0018** (module `registry_reader.dart` lines 1-35) → 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `lib/features/app_update/data/release_info.dart`

- **SRC-0019** (module `release_info.dart` lines 1-55) → 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `lib/features/app_update/data/update_preferences.dart`

- **SRC-0020** (module `update_preferences.dart` lines 1-32) → 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `lib/features/app_update/domain/distribution_type.dart`

- **SRC-0021** (domain_type `distribution_type.dart` lines 1-5) → 05-data-model.md §Entities, traceability.md §Inventory source reference index

### `lib/features/app_update/domain/update_check_service.dart`

- **SRC-0022** (domain_type `update_check_service.dart` lines 1-97) → 05-data-model.md §Entities, traceability.md §Inventory source reference index

### `lib/features/app_update/domain/update_constants.dart`

- **SRC-0023** (domain_type `update_constants.dart` lines 1-25) → traceability.md §Inventory source reference index

### `lib/features/app_update/domain/version_comparator.dart`

- **SRC-0024** (domain_type `version_comparator.dart` lines 1-29) → traceability.md §Inventory source reference index

### `lib/features/app_update/presentation/update_badge.dart`

- **SRC-0025** (view `update_badge.dart` lines 1-27) → 03-screens.md §画面モジュール, 03-screens.md §主要画面遷移, traceability.md §Inventory source reference index

### `lib/features/app_update/presentation/update_dialog.dart`

- **SRC-0026** (view `update_dialog.dart` lines 1-193) → 03-screens.md §画面モジュール, traceability.md §Inventory source reference index

### `lib/features/app_update/providers/update_providers.dart`

- **SRC-0027** (provider `update_providers.dart` lines 1-91) → 02-architecture.md §モジュール, 02-architecture.md §データと依存性, traceability.md §Inventory source reference index

### `lib/features/bookmark/data/bookmark_repository.dart`

- **SRC-0028** (repository `bookmark_repository.dart` lines 1-99) → 05-data-model.md §Modules, 05-data-model.md §Actions, 05-data-model.md §Data, traceability.md §Inventory source reference index

### `lib/features/bookmark/domain/bookmark.dart`

- **SRC-0029** (domain_type `bookmark.dart` lines 1-34) → 05-data-model.md §Entities, traceability.md §Inventory source reference index

### `lib/features/bookmark/presentation/bookmark_list_panel.dart`

- **SRC-0030** (view `bookmark_list_panel.dart` lines 1-131) → 03-screens.md §画面モジュール, 03-screens.md §主要画面遷移, traceability.md §Inventory source reference index

### `lib/features/bookmark/presentation/left_column_panel.dart`

- **SRC-0031** (view `left_column_panel.dart` lines 1-56) → 03-screens.md §画面モジュール, traceability.md §Inventory source reference index

### `lib/features/bookmark/providers/bookmark_providers.dart`

- **SRC-0032** (provider `bookmark_providers.dart` lines 1-115) → 02-architecture.md §モジュール, 02-architecture.md §データと依存性, traceability.md §Inventory source reference index

### `lib/features/episode_cache/data/episode_cache_database.dart`

- **SRC-0033** (persistence `episode_cache_database.dart` lines 1-47) → 05-data-model.md §Modules, 05-data-model.md §Data, 05-data-model.md §Dependencies, traceability.md §Inventory source reference index

### `lib/features/episode_cache/data/episode_cache_repository.dart`

- **SRC-0034** (repository `episode_cache_repository.dart` lines 1-38) → traceability.md §Inventory source reference index

### `lib/features/episode_cache/domain/episode_cache.dart`

- **SRC-0035** (domain_type `episode_cache.dart` lines 1-35) → 05-data-model.md §Entities, traceability.md §Inventory source reference index

### `lib/features/episode_navigation/domain/file_entry_start_intent.dart`

- **SRC-0036** (domain_type `file_entry_start_intent.dart` lines 1-10) → traceability.md §Inventory source reference index

### `lib/features/episode_navigation/providers/adjacent_files_provider.dart`

- **SRC-0037** (provider `adjacent_files_provider.dart` lines 1-46) → 02-architecture.md §モジュール, 02-architecture.md §主要エンティティ／状態, traceability.md §Inventory source reference index

### `lib/features/episode_navigation/providers/episode_navigation_controller.dart`

- **SRC-0038** (provider `episode_navigation_controller.dart` lines 1-41) → 02-architecture.md §モジュール, 02-architecture.md §アクション境界, traceability.md §Inventory source reference index

### `lib/features/episode_navigation/providers/pending_file_entry_intent_provider.dart`

- **SRC-0039** (provider `pending_file_entry_intent_provider.dart` lines 1-19) → 02-architecture.md §主要エンティティ／状態, traceability.md §Inventory source reference index

### `lib/features/file_browser/data/file_system_service.dart`

- **SRC-0040** (module `file_system_service.dart` lines 1-300) → 04-features.md §機能モジュール一覧, 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `lib/features/file_browser/domain/move_destination.dart`

- **SRC-0041** (domain_type `move_destination.dart` lines 1-49) → 05-data-model.md §Entities, traceability.md §Inventory source reference index

### `lib/features/file_browser/domain/move_follow.dart`

- **SRC-0042** (domain_type `move_follow.dart` lines 1-22) → traceability.md §Inventory source reference index

### `lib/features/file_browser/domain/novel_folder_classifier.dart`

- **SRC-0043** (domain_type `novel_folder_classifier.dart` lines 1-9) → traceability.md §Inventory source reference index

### `lib/features/file_browser/domain/reading_progress_badge.dart`

- **SRC-0044** (domain_type `reading_progress_badge.dart` lines 1-43) → 05-data-model.md §Entities, traceability.md §Inventory source reference index

### `lib/features/file_browser/presentation/file_browser_panel.dart`

- **SRC-0045** (view `file_browser_panel.dart` lines 1-812) → 03-screens.md §画面モジュール, 03-screens.md §主要画面遷移, 03-screens.md §Deep-dive candidates (refer to them by ID), traceability.md §Inventory source reference index

### `lib/features/file_browser/presentation/move_destination_dialog.dart`

- **SRC-0046** (view `move_destination_dialog.dart` lines 1-52) → traceability.md §Inventory source reference index

### `lib/features/file_browser/presentation/new_folder_dialog.dart`

- **SRC-0047** (view `new_folder_dialog.dart` lines 1-84) → traceability.md §Inventory source reference index

### `lib/features/file_browser/presentation/rename_title_dialog.dart`

- **SRC-0048** (view `rename_title_dialog.dart` lines 1-64) → traceability.md §Inventory source reference index

### `lib/features/file_browser/providers/file_browser_providers.dart`

- **SRC-0049** (provider `file_browser_providers.dart` lines 1-252) → 02-architecture.md §章のスコープ, 02-architecture.md §モジュール, 02-architecture.md §主要エンティティ／状態, 02-architecture.md §データと依存性, traceability.md §Inventory source reference index

### `lib/features/keyboard_shortcuts/data/focus_utils.dart`

- **SRC-0050** (module `focus_utils.dart` lines 1-16) → 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `lib/features/keyboard_shortcuts/data/key_binding_label.dart`

- **SRC-0051** (module `key_binding_label.dart` lines 1-23) → 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `lib/features/keyboard_shortcuts/data/shortcut_action.dart`

- **SRC-0052** (module `shortcut_action.dart` lines 1-14) → 04-features.md §機能モジュール一覧, 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `lib/features/keyboard_shortcuts/data/shortcut_bindings.dart`

- **SRC-0053** (module `shortcut_bindings.dart` lines 1-141) → 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `lib/features/keyboard_shortcuts/data/shortcut_intents.dart`

- **SRC-0054** (module `shortcut_intents.dart` lines 1-52) → 04-features.md §機能モジュール一覧, 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `lib/features/keyboard_shortcuts/presentation/shortcut_settings_section.dart`

- **SRC-0055** (view `shortcut_settings_section.dart` lines 1-172) → traceability.md §Inventory source reference index

### `lib/features/keyboard_shortcuts/providers/keyboard_shortcut_providers.dart`

- **SRC-0056** (provider `keyboard_shortcut_providers.dart` lines 1-60) → 02-architecture.md §データと依存性, traceability.md §Inventory source reference index

### `lib/features/llm_summary/data/context_chunker.dart`

- **SRC-0057** (module `context_chunker.dart` lines 1-34) → 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `lib/features/llm_summary/data/fact_cache_repository.dart`

- **SRC-0058** (repository `fact_cache_repository.dart` lines 1-107) → 05-data-model.md §Modules, 05-data-model.md §Actions, traceability.md §Inventory source reference index

### `lib/features/llm_summary/data/llm_client.dart`

- **SRC-0059** (integration `llm_client.dart` lines 1-5) → 07-external-integrations.md §連携モジュール, traceability.md §Inventory source reference index

### `lib/features/llm_summary/data/llm_prompt_builder.dart`

- **SRC-0060** (module `llm_prompt_builder.dart` lines 1-56) → 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `lib/features/llm_summary/data/llm_response_format_exception.dart`

- **SRC-0061** (module `llm_response_format_exception.dart` lines 1-28) → 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `lib/features/llm_summary/data/llm_summary_pipeline.dart`

- **SRC-0062** (module `llm_summary_pipeline.dart` lines 1-192) → 04-features.md §機能モジュール一覧, 04-features.md §Deep-dive candidates (refer to them by ID), 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `lib/features/llm_summary/data/llm_summary_repository.dart`

- **SRC-0063** (repository `llm_summary_repository.dart` lines 1-99) → 05-data-model.md §Actions, traceability.md §Inventory source reference index

### `lib/features/llm_summary/data/llm_summary_service.dart`

- **SRC-0064** (module `llm_summary_service.dart` lines 1-234) → 04-features.md §機能モジュール一覧, 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `lib/features/llm_summary/data/ollama_client.dart`

- **SRC-0065** (integration `ollama_client.dart` lines 1-96) → 07-external-integrations.md §連携モジュール, 07-external-integrations.md §外部HTTP依存, 07-external-integrations.md §Deep-dive candidates (refer to them by ID), 09-constraints.md §技術制約, traceability.md §Inventory source reference index

### `lib/features/llm_summary/data/openai_compatible_client.dart`

- **SRC-0066** (integration `openai_compatible_client.dart` lines 1-72) → 07-external-integrations.md §連携モジュール, 07-external-integrations.md §外部HTTP依存, 07-external-integrations.md §Deep-dive candidates (refer to them by ID), 09-constraints.md §技術制約, traceability.md §Inventory source reference index

### `lib/features/llm_summary/domain/analysis_progress.dart`

- **SRC-0067** (domain_type `analysis_progress.dart` lines 1-40) → 05-data-model.md §Entities, traceability.md §Inventory source reference index

### `lib/features/llm_summary/domain/fact_cache_entry.dart`

- **SRC-0068** (domain_type `fact_cache_entry.dart` lines 1-49) → 05-data-model.md §Entities, 05-data-model.md §Dependencies, traceability.md §Inventory source reference index

### `lib/features/llm_summary/domain/first_line_containing.dart`

- **SRC-0069** (domain_type `first_line_containing.dart` lines 1-20) → traceability.md §Inventory source reference index

### `lib/features/llm_summary/domain/history_entry.dart`

- **SRC-0070** (domain_type `history_entry.dart` lines 1-64) → 05-data-model.md §Entities, traceability.md §Inventory source reference index

### `lib/features/llm_summary/domain/hover_token.dart`

- **SRC-0071** (domain_type `hover_token.dart` lines 1-11) → 05-data-model.md §Entities, traceability.md §Inventory source reference index

### `lib/features/llm_summary/domain/llm_config.dart`

- **SRC-0072** (domain_type `llm_config.dart` lines 1-15) → 05-data-model.md §Entities, traceability.md §Inventory source reference index

### `lib/features/llm_summary/domain/llm_summary_result.dart`

- **SRC-0073** (domain_type `llm_summary_result.dart` lines 1-50) → 05-data-model.md §Entities, traceability.md §Inventory source reference index

### `lib/features/llm_summary/domain/mark_matcher.dart`

- **SRC-0074** (domain_type `mark_matcher.dart` lines 1-88) → 05-data-model.md §Entities, traceability.md §Inventory source reference index

### `lib/features/llm_summary/presentation/analysis_runner.dart`

- **SRC-0075** (view `analysis_runner.dart` lines 1-273) → 03-screens.md §画面モジュール, traceability.md §Inventory source reference index

### `lib/features/llm_summary/presentation/hover_popup_anchor.dart`

- **SRC-0076** (view `hover_popup_anchor.dart` lines 1-70) → traceability.md §Inventory source reference index

### `lib/features/llm_summary/presentation/hover_popup_host.dart`

- **SRC-0077** (view `hover_popup_host.dart` lines 1-114) → traceability.md §Inventory source reference index

### `lib/features/llm_summary/presentation/hover_popup_widget.dart`

- **SRC-0078** (view `hover_popup_widget.dart` lines 1-314) → 03-screens.md §画面モジュール, 03-screens.md §Deep-dive candidates (refer to them by ID), traceability.md §Inventory source reference index

### `lib/features/llm_summary/presentation/llm_summary_detail_dialog.dart`

- **SRC-0079** (view `llm_summary_detail_dialog.dart` lines 1-202) → traceability.md §Inventory source reference index

### `lib/features/llm_summary/presentation/llm_summary_history_menu.dart`

- **SRC-0080** (view `llm_summary_history_menu.dart` lines 1-102) → traceability.md §Inventory source reference index

### `lib/features/llm_summary/presentation/llm_summary_history_panel.dart`

- **SRC-0081** (view `llm_summary_history_panel.dart` lines 1-175) → 03-screens.md §画面モジュール, traceability.md §Inventory source reference index

### `lib/features/llm_summary/presentation/outlined_text_badge.dart`

- **SRC-0082** (view `outlined_text_badge.dart` lines 1-26) → traceability.md §Inventory source reference index

### `lib/features/llm_summary/presentation/summary_snapshot_view.dart`

- **SRC-0083** (view `summary_snapshot_view.dart` lines 1-149) → traceability.md §Inventory source reference index

### `lib/features/llm_summary/providers/hover_popup_cache_provider.dart`

- **SRC-0084** (provider `hover_popup_cache_provider.dart` lines 1-40) → traceability.md §Inventory source reference index

### `lib/features/llm_summary/providers/hover_popup_provider.dart`

- **SRC-0085** (provider `hover_popup_provider.dart` lines 1-160) → 02-architecture.md §主要エンティティ／状態, traceability.md §Inventory source reference index

### `lib/features/llm_summary/providers/llm_summary_detail_provider.dart`

- **SRC-0086** (provider `llm_summary_detail_provider.dart` lines 1-23) → traceability.md §Inventory source reference index

### `lib/features/llm_summary/providers/llm_summary_history_provider.dart`

- **SRC-0087** (provider `llm_summary_history_provider.dart` lines 1-89) → traceability.md §Inventory source reference index

### `lib/features/llm_summary/providers/llm_summary_providers.dart`

- **SRC-0088** (provider `llm_summary_providers.dart` lines 1-98) → 02-architecture.md §モジュール, 02-architecture.md §データと依存性, 02-architecture.md §モジュール依存図, traceability.md §Inventory source reference index

### `lib/features/llm_summary/providers/marked_words_provider.dart`

- **SRC-0089** (provider `marked_words_provider.dart` lines 1-18) → traceability.md §Inventory source reference index

### `lib/features/llm_summary/providers/ollama_model_list_provider.dart`

- **SRC-0090** (provider `ollama_model_list_provider.dart` lines 1-20) → traceability.md §Inventory source reference index

### `lib/features/novel_delete/data/novel_delete_service.dart`

- **SRC-0091** (module `novel_delete_service.dart` lines 1-59) → 04-features.md §Deep-dive candidates (refer to them by ID), 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `lib/features/novel_delete/providers/novel_delete_providers.dart`

- **SRC-0092** (provider `novel_delete_providers.dart` lines 1-32) → traceability.md §Inventory source reference index

### `lib/features/novel_metadata_db/data/novel_data_migrator.dart`

- **SRC-0093** (module `novel_data_migrator.dart` lines 1-189) → 04-features.md §機能モジュール一覧, 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `lib/features/novel_metadata_db/data/novel_database.dart`

- **SRC-0094** (persistence `novel_database.dart` lines 1-601) → 05-data-model.md §章の要約, 05-data-model.md §Modules, 05-data-model.md §Data, 05-data-model.md §移行・整合性・障害時動作, 05-data-model.md §不確実性 (and 3 more)

### `lib/features/novel_metadata_db/data/novel_repository.dart`

- **SRC-0095** (repository `novel_repository.dart` lines 1-90) → 05-data-model.md §Actions, traceability.md §Inventory source reference index

### `lib/features/novel_metadata_db/domain/novel_metadata.dart`

- **SRC-0096** (domain_type `novel_metadata.dart` lines 1-53) → 05-data-model.md §Entities, traceability.md §Inventory source reference index

### `lib/features/novel_metadata_db/providers/novel_metadata_providers.dart`

- **SRC-0097** (provider `novel_metadata_providers.dart` lines 1-17) → 02-architecture.md §データと依存性, 02-architecture.md §Detail questions raised in this chapter, 09-constraints.md §既存の未解決事項, traceability.md §Inventory source reference index

### `lib/features/reading_progress/data/reading_progress_repository.dart`

- **SRC-0098** (repository `reading_progress_repository.dart` lines 1-57) → 05-data-model.md §Modules, 05-data-model.md §Actions, traceability.md §Inventory source reference index

### `lib/features/reading_progress/domain/reading_progress.dart`

- **SRC-0099** (domain_type `reading_progress.dart` lines 1-27) → 05-data-model.md §Modules, 05-data-model.md §Entities, traceability.md §Inventory source reference index

### `lib/features/reading_progress/providers/reading_progress_providers.dart`

- **SRC-0100** (provider `reading_progress_providers.dart` lines 1-144) → 02-architecture.md §モジュール, 02-architecture.md §アクション境界, 02-architecture.md §代表シーケンス：読書位置の自動復元, traceability.md §Inventory source reference index

### `lib/features/settings/data/font_family.dart`

- **SRC-0101** (module `font_family.dart` lines 1-57) → 06-settings-security.md §エンティティ, 06-settings-security.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `lib/features/settings/data/settings_repository.dart`

- **SRC-0102** (repository `settings_repository.dart` lines 1-287) → 06-settings-security.md §章の要約, 06-settings-security.md §アクセス・認証境界, 06-settings-security.md §モジュール, 06-settings-security.md §エンティティ, 06-settings-security.md §アクション (and 7 more)

### `lib/features/settings/data/text_display_mode.dart`

- **SRC-0103** (module `text_display_mode.dart` lines 1-4) → 06-settings-security.md §エンティティ, 06-settings-security.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `lib/features/settings/presentation/sections/about_and_update_section.dart`

- **SRC-0104** (view `about_and_update_section.dart` lines 1-123) → 06-settings-security.md §割当インベントリ網羅表, 06-settings-security.md §Deep-dive candidates (refer to them by ID), traceability.md §Inventory source reference index

### `lib/features/settings/presentation/sections/general_settings_section.dart`

- **SRC-0105** (view `general_settings_section.dart` lines 1-145) → 06-settings-security.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `lib/features/settings/presentation/sections/llm_settings_section.dart`

- **SRC-0106** (view `llm_settings_section.dart` lines 1-284) → 06-settings-security.md §アクション, 06-settings-security.md §セキュリティ境界, 06-settings-security.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `lib/features/settings/presentation/sections/piper_settings_section.dart`

- **SRC-0107** (view `piper_settings_section.dart` lines 1-181) → 06-settings-security.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `lib/features/settings/presentation/sections/qwen3_settings_section.dart`

- **SRC-0108** (view `qwen3_settings_section.dart` lines 1-175) → 06-settings-security.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `lib/features/settings/presentation/sections/voice_reference_section.dart`

- **SRC-0109** (view `voice_reference_section.dart` lines 1-310) → 06-settings-security.md §モジュール, 06-settings-security.md §アクション, 06-settings-security.md §永続データ, 06-settings-security.md §割当インベントリ網羅表, 06-settings-security.md §Deep-dive candidates (refer to them by ID) (and 1 more)

### `lib/features/settings/presentation/settings_dialog.dart`

- **SRC-0110** (view `settings_dialog.dart` lines 1-166) → 06-settings-security.md §章の要約, 06-settings-security.md §モジュール, 06-settings-security.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `lib/features/settings/providers/settings_providers.dart`

- **SRC-0111** (provider `settings_providers.dart` lines 1-137) → 06-settings-security.md §モジュール, 06-settings-security.md §エンティティ, 06-settings-security.md §依存関係, 06-settings-security.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `lib/features/text_download/data/download_service.dart`

- **SRC-0112** (integration `download_service.dart` lines 1-923) → 04-features.md §機能モジュール一覧, 04-features.md §Deep-dive candidates (refer to them by ID), 04-features.md §ダウンロードの業務ルール, 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `lib/features/text_download/data/novel_library_service.dart`

- **SRC-0113** (integration `novel_library_service.dart` lines 1-81) → 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `lib/features/text_download/data/sites/aozora_site.dart`

- **SRC-0114** (integration `aozora_site.dart` lines 1-74) → 07-external-integrations.md §連携モジュール, 07-external-integrations.md §外部HTTP依存, traceability.md §Inventory source reference index

### `lib/features/text_download/data/sites/generic_web_site.dart`

- **SRC-0115** (integration `generic_web_site.dart` lines 1-239) → 07-external-integrations.md §連携モジュール, 07-external-integrations.md §Deep-dive candidates (refer to them by ID), 07-external-integrations.md §外部HTTP依存, 09-constraints.md §技術制約, 09-constraints.md §Deep-dive candidates (refer to them by ID) (and 1 more)

### `lib/features/text_download/data/sites/hameln_site.dart`

- **SRC-0116** (integration `hameln_site.dart` lines 1-200) → 07-external-integrations.md §連携モジュール, traceability.md §Inventory source reference index

### `lib/features/text_download/data/sites/kakuyomu_site.dart`

- **SRC-0117** (integration `kakuyomu_site.dart` lines 1-162) → 07-external-integrations.md §連携モジュール, traceability.md §Inventory source reference index

### `lib/features/text_download/data/sites/narou_site.dart`

- **SRC-0118** (integration `narou_site.dart` lines 1-191) → 07-external-integrations.md §連携モジュール, traceability.md §Inventory source reference index

### `lib/features/text_download/data/sites/novel_site.dart`

- **SRC-0119** (integration `novel_site.dart` lines 1-103) → 07-external-integrations.md §連携モジュール, 07-external-integrations.md §Deep-dive candidates (refer to them by ID), 07-external-integrations.md §外部HTTP依存, traceability.md §Inventory source reference index

### `lib/features/text_download/presentation/download_dialog.dart`

- **SRC-0120** (view `download_dialog.dart` lines 1-461) → 03-screens.md §画面モジュール, 03-screens.md §主要画面遷移, traceability.md §Inventory source reference index

### `lib/features/text_download/providers/text_download_providers.dart`

- **SRC-0121** (provider `text_download_providers.dart` lines 1-410) → 02-architecture.md §モジュール, 02-architecture.md §主要エンティティ／状態, 02-architecture.md §モジュール依存図, 02-architecture.md §状態遷移：ダウンロード, 02-architecture.md §割当インベントリ網羅表 (and 3 more)

### `lib/features/text_search/data/search_models.dart`

- **SRC-0122** (module `search_models.dart` lines 1-35) → 04-features.md §機能モジュール一覧, 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `lib/features/text_search/data/text_search_service.dart`

- **SRC-0123** (module `text_search_service.dart` lines 1-100) → 04-features.md §主要アクション, 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `lib/features/text_search/presentation/search_results_panel.dart`

- **SRC-0124** (view `search_results_panel.dart` lines 1-196) → 03-screens.md §画面モジュール, 03-screens.md §主要画面遷移, traceability.md §Inventory source reference index

### `lib/features/text_search/providers/text_search_providers.dart`

- **SRC-0125** (provider `text_search_providers.dart` lines 1-113) → 02-architecture.md §モジュール, traceability.md §Inventory source reference index

### `lib/features/text_viewer/data/column_splitter.dart`

- **SRC-0126** (view `column_splitter.dart` lines 1-152) → traceability.md §Inventory source reference index

### `lib/features/text_viewer/data/kinsoku.dart`

- **SRC-0127** (view `kinsoku.dart` lines 1-34) → traceability.md §Inventory source reference index

### `lib/features/text_viewer/data/parsed_segments_cache.dart`

- **SRC-0128** (view `parsed_segments_cache.dart` lines 1-36) → 05-data-model.md §Modules, 05-data-model.md §Actions, 05-data-model.md §Dependencies, traceability.md §Inventory source reference index

### `lib/features/text_viewer/data/parsed_segments_cache_provider.dart`

- **SRC-0129** (view `parsed_segments_cache_provider.dart` lines 1-6) → traceability.md §Inventory source reference index

### `lib/features/text_viewer/data/ruby_text_parser.dart`

- **SRC-0130** (view `ruby_text_parser.dart` lines 1-89) → traceability.md §Inventory source reference index

### `lib/features/text_viewer/data/swipe_detection.dart`

- **SRC-0131** (view `swipe_detection.dart` lines 1-46) → traceability.md §Inventory source reference index

### `lib/features/text_viewer/data/text_file_reader.dart`

- **SRC-0132** (view `text_file_reader.dart` lines 1-8) → traceability.md §Inventory source reference index

### `lib/features/text_viewer/data/text_segment.dart`

- **SRC-0133** (view `text_segment.dart` lines 1-38) → traceability.md §Inventory source reference index

### `lib/features/text_viewer/data/vertical_char_map.dart`

- **SRC-0134** (view `vertical_char_map.dart` lines 1-136) → traceability.md §Inventory source reference index

### `lib/features/text_viewer/data/vertical_marked_ranges.dart`

- **SRC-0135** (view `vertical_marked_ranges.dart` lines 1-104) → traceability.md §Inventory source reference index

### `lib/features/text_viewer/data/vertical_text_layout.dart`

- **SRC-0136** (view `vertical_text_layout.dart` lines 1-139) → traceability.md §Inventory source reference index

### `lib/features/text_viewer/presentation/ruby_text_builder.dart`

- **SRC-0137** (view `ruby_text_builder.dart` lines 1-377) → traceability.md §Inventory source reference index

### `lib/features/text_viewer/presentation/text_viewer_panel.dart`

- **SRC-0138** (view `text_viewer_panel.dart` lines 1-49) → 03-screens.md §画面モジュール, traceability.md §Inventory source reference index

### `lib/features/text_viewer/presentation/vertical_ruby_text_widget.dart`

- **SRC-0139** (view `vertical_ruby_text_widget.dart` lines 1-134) → traceability.md §Inventory source reference index

### `lib/features/text_viewer/presentation/vertical_text_page.dart`

- **SRC-0140** (view `vertical_text_page.dart` lines 1-760) → 03-screens.md §画面モジュール, traceability.md §Inventory source reference index

### `lib/features/text_viewer/presentation/vertical_text_viewer.dart`

- **SRC-0141** (view `vertical_text_viewer.dart` lines 1-1177) → 03-screens.md §画面モジュール, 03-screens.md §Deep-dive candidates (refer to them by ID), traceability.md §Inventory source reference index

### `lib/features/text_viewer/presentation/widgets/text_content_renderer.dart`

- **SRC-0142** (view `text_content_renderer.dart` lines 1-909) → 03-screens.md §画面モジュール, 03-screens.md §主要画面遷移, 03-screens.md §Deep-dive candidates (refer to them by ID), traceability.md §Inventory source reference index

### `lib/features/text_viewer/presentation/widgets/tts_controls_bar.dart`

- **SRC-0143** (view `tts_controls_bar.dart` lines 1-580) → 03-screens.md §画面モジュール, 03-screens.md §主要画面遷移, 03-screens.md §Deep-dive candidates (refer to them by ID), traceability.md §Inventory source reference index

### `lib/features/text_viewer/presentation/widgets/vertical_context_menu.dart`

- **SRC-0144** (view `vertical_context_menu.dart` lines 1-58) → traceability.md §Inventory source reference index

### `lib/features/text_viewer/providers/text_viewer_providers.dart`

- **SRC-0145** (view `text_viewer_providers.dart` lines 1-25) → traceability.md §Inventory source reference index

### `lib/features/tts/data/lame_enc_bindings.dart`

- **SRC-0146** (module `lame_enc_bindings.dart` lines 1-62) → 07-external-integrations.md §連携モジュール, 07-external-integrations.md §ネイティブライブラリ境界, traceability.md §Inventory source reference index

### `lib/features/tts/data/model_download_utils.dart`

- **SRC-0147** (integration `model_download_utils.dart` lines 1-57) → 07-external-integrations.md §連携モジュール, 07-external-integrations.md §外部HTTP依存, 07-external-integrations.md §代表シーケンス, traceability.md §Inventory source reference index

### `lib/features/tts/data/piper_model_download_service.dart`

- **SRC-0148** (integration `piper_model_download_service.dart` lines 1-146) → 07-external-integrations.md §連携モジュール, 07-external-integrations.md §外部HTTP依存, traceability.md §Inventory source reference index

### `lib/features/tts/data/piper_native_bindings.dart`

- **SRC-0149** (integration `piper_native_bindings.dart` lines 1-95) → 07-external-integrations.md §連携モジュール, 07-external-integrations.md §ネイティブライブラリ境界, traceability.md §Inventory source reference index

### `lib/features/tts/data/piper_tts_engine.dart`

- **SRC-0150** (module `piper_tts_engine.dart` lines 1-99) → 04-features.md §機能モジュール一覧, 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `lib/features/tts/data/segment_player.dart`

- **SRC-0151** (module `segment_player.dart` lines 1-131) → 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `lib/features/tts/data/text_segmenter.dart`

- **SRC-0152** (module `text_segmenter.dart` lines 1-218) → 04-features.md §Deep-dive candidates (refer to them by ID), 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `lib/features/tts/data/tts_adapters.dart`

- **SRC-0153** (module `tts_adapters.dart` lines 1-37) → 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `lib/features/tts/data/tts_audio_database.dart`

- **SRC-0154** (persistence `tts_audio_database.dart` lines 1-138) → 05-data-model.md §Modules, 05-data-model.md §Data, 05-data-model.md §移行・整合性・障害時動作, traceability.md §Inventory source reference index

### `lib/features/tts/data/tts_audio_export_service.dart`

- **SRC-0155** (module `tts_audio_export_service.dart` lines 1-204) → 04-features.md §主要アクション, 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `lib/features/tts/data/tts_audio_repository.dart`

- **SRC-0156** (repository `tts_audio_repository.dart` lines 1-228) → 05-data-model.md §Actions, traceability.md §Inventory source reference index

### `lib/features/tts/data/tts_dictionary_database.dart`

- **SRC-0157** (persistence `tts_dictionary_database.dart` lines 1-45) → 05-data-model.md §Modules, 05-data-model.md §Data, traceability.md §Inventory source reference index

### `lib/features/tts/data/tts_dictionary_repository.dart`

- **SRC-0158** (repository `tts_dictionary_repository.dart` lines 1-122) → 05-data-model.md §Actions, traceability.md §Inventory source reference index

### `lib/features/tts/data/tts_edit_controller.dart`

- **SRC-0159** (module `tts_edit_controller.dart` lines 1-472) → 04-features.md §Deep-dive candidates (refer to them by ID), 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `lib/features/tts/data/tts_edit_segment.dart`

- **SRC-0160** (module `tts_edit_segment.dart` lines 1-62) → 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `lib/features/tts/data/tts_engine.dart`

- **SRC-0161** (module `tts_engine.dart` lines 1-300) → 04-features.md §機能モジュール一覧, 04-features.md §TTSの状態とデータフロー, 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `lib/features/tts/data/tts_engine_type.dart`

- **SRC-0162** (module `tts_engine_type.dart` lines 1-8) → 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `lib/features/tts/data/tts_isolate.dart`

- **SRC-0163** (module `tts_isolate.dart` lines 1-541) → 04-features.md §TTSの状態とデータフロー, 04-features.md §Deep-dive candidates (refer to them by ID), 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `lib/features/tts/data/tts_language.dart`

- **SRC-0164** (module `tts_language.dart` lines 1-22) → 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `lib/features/tts/data/tts_model_download_service.dart`

- **SRC-0165** (integration `tts_model_download_service.dart` lines 1-102) → 07-external-integrations.md §連携モジュール, 07-external-integrations.md §外部HTTP依存, 07-external-integrations.md §Deep-dive candidates (refer to them by ID), 07-external-integrations.md §代表シーケンス, traceability.md §Inventory source reference index

### `lib/features/tts/data/tts_model_size.dart`

- **SRC-0166** (module `tts_model_size.dart` lines 1-14) → 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `lib/features/tts/data/tts_native_bindings.dart`

- **SRC-0167** (integration `tts_native_bindings.dart` lines 1-230) → 07-external-integrations.md §連携モジュール, 07-external-integrations.md §Deep-dive candidates (refer to them by ID), 07-external-integrations.md §ネイティブライブラリ境界, 09-constraints.md §技術制約, 09-constraints.md §Deep-dive candidates (refer to them by ID) (and 2 more)

### `lib/features/tts/data/tts_playback_controller.dart`

- **SRC-0168** (module `tts_playback_controller.dart` lines 1-12) → 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `lib/features/tts/data/tts_session.dart`

- **SRC-0169** (module `tts_session.dart` lines 1-205) → 04-features.md §機能モジュール一覧, 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `lib/features/tts/data/tts_streaming_controller.dart`

- **SRC-0170** (module `tts_streaming_controller.dart` lines 1-389) → 04-features.md §Deep-dive candidates (refer to them by ID), 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `lib/features/tts/data/tts_toggle.dart`

- **SRC-0171** (module `tts_toggle.dart` lines 1-27) → 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `lib/features/tts/data/voice_recording_service.dart`

- **SRC-0172** (module `voice_recording_service.dart` lines 1-65) → 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `lib/features/tts/data/voice_reference_service.dart`

- **SRC-0173** (module `voice_reference_service.dart` lines 1-105) → 04-features.md §Deep-dive candidates (refer to them by ID), 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `lib/features/tts/data/wav_writer.dart`

- **SRC-0174** (module `wav_writer.dart` lines 1-80) → 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `lib/features/tts/domain/_row_helpers.dart`

- **SRC-0175** (domain_type `_row_helpers.dart` lines 1-13) → 05-data-model.md §Entities, traceability.md §Inventory source reference index

### `lib/features/tts/domain/tts_engine_config.dart`

- **SRC-0176** (domain_type `tts_engine_config.dart` lines 1-167) → 05-data-model.md §Entities, traceability.md §Inventory source reference index

### `lib/features/tts/domain/tts_episode.dart`

- **SRC-0177** (domain_type `tts_episode.dart` lines 1-40) → 05-data-model.md §Entities, traceability.md §Inventory source reference index

### `lib/features/tts/domain/tts_episode_status.dart`

- **SRC-0178** (domain_type `tts_episode_status.dart` lines 1-15) → 05-data-model.md §状態遷移とデータフロー, traceability.md §Inventory source reference index

### `lib/features/tts/domain/tts_ref_wav_resolver.dart`

- **SRC-0179** (domain_type `tts_ref_wav_resolver.dart` lines 1-19) → traceability.md §Inventory source reference index

### `lib/features/tts/domain/tts_segment.dart`

- **SRC-0180** (domain_type `tts_segment.dart` lines 1-56) → 05-data-model.md §Entities, traceability.md §Inventory source reference index

### `lib/features/tts/presentation/dictionary_context_menu.dart`

- **SRC-0181** (view `dictionary_context_menu.dart` lines 1-81) → traceability.md §Inventory source reference index

### `lib/features/tts/presentation/tts_dictionary_dialog.dart`

- **SRC-0182** (view `tts_dictionary_dialog.dart` lines 1-199) → 03-screens.md §画面モジュール, traceability.md §Inventory source reference index

### `lib/features/tts/presentation/tts_edit_dialog.dart`

- **SRC-0183** (view `tts_edit_dialog.dart` lines 1-694) → 03-screens.md §画面モジュール, traceability.md §Inventory source reference index

### `lib/features/tts/presentation/voice_recording_dialog.dart`

- **SRC-0184** (view `voice_recording_dialog.dart` lines 1-385) → 03-screens.md §画面モジュール, traceability.md §Inventory source reference index

### `lib/features/tts/providers/piper_model_download_providers.dart`

- **SRC-0185** (provider `piper_model_download_providers.dart` lines 1-111) → 07-external-integrations.md §連携モジュール, 07-external-integrations.md §Deep-dive candidates (refer to them by ID), traceability.md §Inventory source reference index

### `lib/features/tts/providers/text_segmenter_provider.dart`

- **SRC-0186** (provider `text_segmenter_provider.dart` lines 1-12) → traceability.md §Inventory source reference index

### `lib/features/tts/providers/tts_audio_database_provider.dart`

- **SRC-0187** (persistence `tts_audio_database_provider.dart` lines 1-27) → 05-data-model.md §Dependencies, traceability.md §Inventory source reference index

### `lib/features/tts/providers/tts_audio_state_provider.dart`

- **SRC-0188** (provider `tts_audio_state_provider.dart` lines 1-52) → 02-architecture.md §主要エンティティ／状態, 02-architecture.md §データと依存性, traceability.md §Inventory source reference index

### `lib/features/tts/providers/tts_edit_providers.dart`

- **SRC-0189** (provider `tts_edit_providers.dart` lines 1-73) → traceability.md §Inventory source reference index

### `lib/features/tts/providers/tts_export_providers.dart`

- **SRC-0190** (provider `tts_export_providers.dart` lines 1-96) → traceability.md §Inventory source reference index

### `lib/features/tts/providers/tts_model_download_providers.dart`

- **SRC-0191** (provider `tts_model_download_providers.dart` lines 1-107) → 07-external-integrations.md §連携モジュール, 07-external-integrations.md §代表シーケンス, traceability.md §Inventory source reference index

### `lib/features/tts/providers/tts_playback_providers.dart`

- **SRC-0192** (provider `tts_playback_providers.dart` lines 1-94) → 02-architecture.md §モジュール, 02-architecture.md §主要エンティティ／状態, traceability.md §Inventory source reference index

### `lib/features/tts/providers/tts_settings_providers.dart`

- **SRC-0193** (provider `tts_settings_providers.dart` lines 1-205) → 02-architecture.md §モジュール, 02-architecture.md §データと依存性, traceability.md §Inventory source reference index

### `lib/features/tts/providers/vacuum_lifecycle_provider.dart`

- **SRC-0194** (provider `vacuum_lifecycle_provider.dart` lines 1-92) → 02-architecture.md §モジュール, 02-architecture.md §アクション境界, 02-architecture.md §Detail questions raised in this chapter, 09-constraints.md §既存の未解決事項, 09-constraints.md §Deep-dive candidates (refer to them by ID) (and 1 more)

### `lib/home_screen.dart`

- **SRC-0195** (view `home_screen.dart` lines 1-357) → 01-overview.md §主要機能, 01-overview.md §UIの全体像, 03-screens.md §章のスコープ, 03-screens.md §画面モジュール, 03-screens.md §主要画面遷移 (and 1 more)

### `lib/l10n/app_localizations.dart`

- **SRC-0196** (module `app_localizations.dart` lines 1-1728) → 06-settings-security.md §モジュール, 06-settings-security.md §依存関係, 06-settings-security.md §ローカライズ, 06-settings-security.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `lib/l10n/app_localizations_en.dart`

- **SRC-0197** (module `app_localizations_en.dart` lines 1-903) → 06-settings-security.md §ローカライズ, 06-settings-security.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `lib/l10n/app_localizations_ja.dart`

- **SRC-0198** (module `app_localizations_ja.dart` lines 1-886) → 06-settings-security.md §ローカライズ, 06-settings-security.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `lib/l10n/app_localizations_zh.dart`

- **SRC-0199** (module `app_localizations_zh.dart` lines 1-884) → 06-settings-security.md §ローカライズ, 06-settings-security.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `lib/main.dart`

- **SRC-0200** (module `main.dart` lines 1-77) → 01-overview.md §システム概要, 06-settings-security.md §アクセス・認証境界, 09-constraints.md §技術制約, 09-constraints.md §Q-013, traceability.md §Inventory source reference index

### `lib/shared/database/database_closing_exception.dart`

- **SRC-0201** (persistence `database_closing_exception.dart` lines 1-15) → traceability.md §Inventory source reference index

### `lib/shared/database/database_opener.dart`

- **SRC-0202** (persistence `database_opener.dart` lines 1-63) → 05-data-model.md §Actions, 05-data-model.md §Dependencies, 05-data-model.md §移行・整合性・障害時動作, traceability.md §Inventory source reference index

### `lib/shared/database/db_connection_gate.dart`

- **SRC-0203** (persistence `db_connection_gate.dart` lines 1-91) → 05-data-model.md §章の要約, 05-data-model.md §移行・整合性・障害時動作, traceability.md §Inventory source reference index

### `lib/shared/database/folder_db_handles.dart`

- **SRC-0204** (persistence `folder_db_handles.dart` lines 1-37) → traceability.md §Inventory source reference index

### `lib/shared/database/folder_db_key.dart`

- **SRC-0205** (persistence `folder_db_key.dart` lines 1-21) → 05-data-model.md §Dependencies, traceability.md §Inventory source reference index

### `lib/shared/database/novel_data_database.dart`

- **SRC-0206** (persistence `novel_data_database.dart` lines 1-107) → 05-data-model.md §章の要約, 05-data-model.md §Modules, 05-data-model.md §Data, 05-data-model.md §移行・整合性・障害時動作, 05-data-model.md §不確実性 (and 1 more)

### `lib/shared/database/novel_data_database_provider.dart`

- **SRC-0207** (persistence `novel_data_database_provider.dart` lines 1-16) → 05-data-model.md §Dependencies, traceability.md §Inventory source reference index

### `lib/shared/database/per_folder_db_registry.dart`

- **SRC-0208** (persistence `per_folder_db_registry.dart` lines 1-164) → 05-data-model.md §章の要約, 05-data-model.md §Modules, traceability.md §Inventory source reference index

### `lib/shared/database/per_folder_db_registry_provider.dart`

- **SRC-0209** (persistence `per_folder_db_registry_provider.dart` lines 1-12) → traceability.md §Inventory source reference index

### `lib/shared/episode/episode_resolver.dart`

- **SRC-0210** (module `episode_resolver.dart` lines 1-130) → 02-architecture.md §モジュール, 02-architecture.md §アクション境界, traceability.md §Inventory source reference index

### `lib/shared/logging/app_logger.dart`

- **SRC-0211** (module `app_logger.dart` lines 1-83) → 06-settings-security.md §章の要約, 06-settings-security.md §モジュール, 06-settings-security.md §アクション, 06-settings-security.md §永続データ, 06-settings-security.md §割当インベントリ網羅表 (and 1 more)

### `lib/shared/logging/file_log_sink.dart`

- **SRC-0212** (module `file_log_sink.dart` lines 1-97) → 06-settings-security.md §モジュール, 06-settings-security.md §エンティティ, 06-settings-security.md §アクション, 06-settings-security.md §永続データ, 06-settings-security.md §セキュリティ境界 (and 6 more)

### `lib/shared/logging/log_sink.dart`

- **SRC-0213** (module `log_sink.dart` lines 1-9) → 06-settings-security.md §エンティティ, 06-settings-security.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `lib/shared/providers/layout_providers.dart`

- **SRC-0214** (provider `layout_providers.dart` lines 1-13) → traceability.md §Inventory source reference index

### `lib/shared/utils/cancellation_token.dart`

- **SRC-0215** (module `cancellation_token.dart` lines 1-53) → 02-architecture.md §主要エンティティ／状態, traceability.md §Inventory source reference index

### `lib/shared/utils/content_hash.dart`

- **SRC-0216** (module `content_hash.dart` lines 1-6) → traceability.md §Inventory source reference index

### `lib/shared/utils/file_name_utils.dart`

- **SRC-0217** (module `file_name_utils.dart` lines 1-25) → traceability.md §Inventory source reference index

### `lib/shared/utils/novel_id_resolver.dart`

- **SRC-0218** (module `novel_id_resolver.dart` lines 1-62) → 02-architecture.md §モジュール, traceability.md §Inventory source reference index

### `lib/shared/utils/temp_directory_utils.dart`

- **SRC-0219** (module `temp_directory_utils.dart` lines 1-17) → traceability.md §Inventory source reference index

### `linux/CMakeLists.txt`

- **SRC-0220** (other `CMakeLists.txt` lines 1-128) → 08-operations.md §モジュール, 08-operations.md §データ・成果物, 08-operations.md §依存関係, 08-operations.md §プラットフォーム別運用, 08-operations.md §割当インベントリ網羅表 (and 1 more)

### `linux/runner/main.cc`

- **SRC-0221** (other `main.cc` lines 1-6) → 08-operations.md §モジュール, 08-operations.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `macos/Runner/AppDelegate.swift`

- **SRC-0222** (other `AppDelegate.swift` lines 1-13) → 08-operations.md §モジュール, 08-operations.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `pubspec.yaml`

- **SRC-0223** (configuration `pubspec.yaml` lines 1-127) → 08-operations.md §モジュール, 08-operations.md §データ・成果物, 08-operations.md §依存関係, 08-operations.md §割当インベントリ網羅表, 09-constraints.md §技術制約 (and 1 more)

### `scripts/benchmark_tts.sh`

- **SRC-0224** (script `benchmark_tts.sh` lines 1-289) → 08-operations.md §アクション, 08-operations.md §データ・成果物, 08-operations.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `scripts/build_lame_macos.sh`

- **SRC-0225** (script `build_lame_macos.sh` lines 1-30) → 08-operations.md §モジュール, 08-operations.md §プラットフォーム別運用, 08-operations.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `scripts/build_lame_windows.bat`

- **SRC-0226** (script `build_lame_windows.bat` lines 1-23) → 08-operations.md §モジュール, 08-operations.md §データ・成果物, 08-operations.md §割当インベントリ網羅表, 08-operations.md §Deep-dive candidates (refer to them by ID), traceability.md §Inventory source reference index

### `scripts/build_piper_macos.sh`

- **SRC-0227** (script `build_piper_macos.sh` lines 1-53) → 08-operations.md §モジュール, 08-operations.md §プラットフォーム別運用, 08-operations.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `scripts/build_piper_windows.bat`

- **SRC-0228** (script `build_piper_windows.bat` lines 1-36) → 08-operations.md §モジュール, 08-operations.md §データ・成果物, 08-operations.md §割当インベントリ網羅表, 08-operations.md §Deep-dive candidates (refer to them by ID), traceability.md §Inventory source reference index

### `scripts/build_tts_macos.sh`

- **SRC-0229** (script `build_tts_macos.sh` lines 1-44) → 08-operations.md §モジュール, 08-operations.md §プラットフォーム別運用, 08-operations.md §割当インベントリ網羅表, 08-operations.md §Deep-dive candidates (refer to them by ID), traceability.md §Inventory source reference index

### `scripts/build_tts_windows.bat`

- **SRC-0230** (script `build_tts_windows.bat` lines 1-36) → 08-operations.md §モジュール, 08-operations.md §データ・成果物, 08-operations.md §割当インベントリ網羅表, 08-operations.md §Deep-dive candidates (refer to them by ID), traceability.md §Inventory source reference index

### `scripts/clean.bat`

- **SRC-0231** (script `clean.bat` lines 1-12) → 08-operations.md §アクション, 08-operations.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `scripts/clean.sh`

- **SRC-0232** (script `clean.sh` lines 1-8) → 08-operations.md §アクション, 08-operations.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `scripts/release.ps1`

- **SRC-0233** (script `release.ps1` lines 1-91) → 08-operations.md §モジュール, 08-operations.md §品質・安全ゲート, 08-operations.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `scripts/release.sh`

- **SRC-0234** (script `release.sh` lines 1-92) → 08-operations.md §モジュール, 08-operations.md §アクション, 08-operations.md §品質・安全ゲート, 08-operations.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `scripts/test/release_test.ps1`

- **SRC-0235** (script `release_test.ps1` lines 1-107) → 08-operations.md §品質・安全ゲート, 08-operations.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `scripts/test/release_test.sh`

- **SRC-0236** (script `release_test.sh` lines 1-88) → 08-operations.md §品質・安全ゲート, 08-operations.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `scripts/test/verify_release_version_test.sh`

- **SRC-0237** (script `verify_release_version_test.sh` lines 1-43) → 08-operations.md §品質・安全ゲート, 08-operations.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `scripts/verify_release_version.sh`

- **SRC-0238** (script `verify_release_version.sh` lines 1-46) → 08-operations.md §アクション, 08-operations.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `test/app/reading_progress_wiring_test.dart`

- **SRC-0240** (test `reading_progress_wiring_test.dart` lines 1-183) → 02-architecture.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `test/app/selected_file_progress_title_provider_test.dart`

- **SRC-0241** (test `selected_file_progress_title_provider_test.dart` lines 1-156) → 02-architecture.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `test/app/startup_migrations_test.dart`

- **SRC-0242** (test `startup_migrations_test.dart` lines 1-64) → 02-architecture.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `test/app_test.dart`

- **SRC-0239** (test `app_test.dart` lines 1-57) → 01-overview.md §起動時の構成, traceability.md §Inventory source reference index

### `test/features/app_update/data/distribution_detector_test.dart`

- **SRC-0243** (test `distribution_detector_test.dart` lines 1-104) → 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/app_update/data/github_release_client_test.dart`

- **SRC-0244** (test `github_release_client_test.dart` lines 1-128) → 07-external-integrations.md §検証証拠, traceability.md §Inventory source reference index

### `test/features/app_update/data/installer_downloader_test.dart`

- **SRC-0245** (test `installer_downloader_test.dart` lines 1-68) → 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/app_update/data/installer_updater_test.dart`

- **SRC-0246** (test `installer_updater_test.dart` lines 1-197) → 04-features.md §主要アクション, 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/app_update/data/installer_verifier_test.dart`

- **SRC-0247** (test `installer_verifier_test.dart` lines 1-124) → 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/app_update/data/registry_reader_test.dart`

- **SRC-0248** (test `registry_reader_test.dart` lines 1-47) → 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/app_update/data/update_preferences_test.dart`

- **SRC-0249** (test `update_preferences_test.dart` lines 1-53) → 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/app_update/domain/update_check_service_test.dart`

- **SRC-0250** (test `update_check_service_test.dart` lines 1-167) → traceability.md §Inventory source reference index

### `test/features/app_update/domain/version_comparator_test.dart`

- **SRC-0251** (test `version_comparator_test.dart` lines 1-41) → traceability.md §Inventory source reference index

### `test/features/app_update/presentation/update_badge_test.dart`

- **SRC-0252** (test `update_badge_test.dart` lines 1-44) → traceability.md §Inventory source reference index

### `test/features/app_update/presentation/update_dialog_test.dart`

- **SRC-0253** (test `update_dialog_test.dart` lines 1-156) → traceability.md §Inventory source reference index

### `test/features/bookmark/bookmark_providers_test.dart`

- **SRC-0254** (test `bookmark_providers_test.dart` lines 1-307) → 02-architecture.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `test/features/bookmark/bookmark_repository_test.dart`

- **SRC-0255** (test `bookmark_repository_test.dart` lines 1-211) → traceability.md §Inventory source reference index

### `test/features/bookmark/presentation/bookmark_appbar_test.dart`

- **SRC-0256** (test `bookmark_appbar_test.dart` lines 1-202) → traceability.md §Inventory source reference index

### `test/features/bookmark/presentation/bookmark_list_panel_test.dart`

- **SRC-0257** (test `bookmark_list_panel_test.dart` lines 1-317) → traceability.md §Inventory source reference index

### `test/features/bookmark/presentation/left_column_panel_test.dart`

- **SRC-0258** (test `left_column_panel_test.dart` lines 1-152) → traceability.md §Inventory source reference index

### `test/features/episode_cache/data/episode_cache_database_test.dart`

- **SRC-0259** (test `episode_cache_database_test.dart` lines 1-92) → traceability.md §Inventory source reference index

### `test/features/episode_cache/data/episode_cache_repository_test.dart`

- **SRC-0260** (test `episode_cache_repository_test.dart` lines 1-143) → traceability.md §Inventory source reference index

### `test/features/episode_cache/domain/episode_cache_test.dart`

- **SRC-0261** (test `episode_cache_test.dart` lines 1-74) → traceability.md §Inventory source reference index

### `test/features/episode_navigation/providers/adjacent_files_provider_test.dart`

- **SRC-0262** (test `adjacent_files_provider_test.dart` lines 1-149) → 02-architecture.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `test/features/episode_navigation/providers/episode_navigation_controller_test.dart`

- **SRC-0263** (test `episode_navigation_controller_test.dart` lines 1-131) → 02-architecture.md §アクション境界, traceability.md §Inventory source reference index

### `test/features/episode_navigation/providers/pending_file_entry_intent_provider_test.dart`

- **SRC-0264** (test `pending_file_entry_intent_provider_test.dart` lines 1-58) → traceability.md §Inventory source reference index

### `test/features/file_browser/data/download_destination_folders_test.dart`

- **SRC-0265** (test `download_destination_folders_test.dart` lines 1-119) → 04-features.md §機能モジュール一覧, 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/file_browser/data/file_system_service_test.dart`

- **SRC-0266** (test `file_system_service_test.dart` lines 1-409) → 04-features.md §主要アクション, 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/file_browser/domain/move_destination_test.dart`

- **SRC-0267** (test `move_destination_test.dart` lines 1-82) → traceability.md §Inventory source reference index

### `test/features/file_browser/domain/move_follow_test.dart`

- **SRC-0268** (test `move_follow_test.dart` lines 1-47) → traceability.md §Inventory source reference index

### `test/features/file_browser/domain/novel_folder_classifier_test.dart`

- **SRC-0269** (test `novel_folder_classifier_test.dart` lines 1-30) → traceability.md §Inventory source reference index

### `test/features/file_browser/domain/reading_progress_badge_test.dart`

- **SRC-0270** (test `reading_progress_badge_test.dart` lines 1-69) → traceability.md §Inventory source reference index

### `test/features/file_browser/presentation/file_browser_folder_ops_test.dart`

- **SRC-0271** (test `file_browser_folder_ops_test.dart` lines 1-318) → traceability.md §Inventory source reference index

### `test/features/file_browser/presentation/file_browser_handle_release_order_test.dart`

- **SRC-0272** (test `file_browser_handle_release_order_test.dart` lines 1-251) → traceability.md §Inventory source reference index

### `test/features/file_browser/presentation/file_browser_panel_test.dart`

- **SRC-0273** (test `file_browser_panel_test.dart` lines 1-1140) → 03-screens.md §表示状態とエッジケース, traceability.md §Inventory source reference index

### `test/features/file_browser/presentation/move_destination_dialog_test.dart`

- **SRC-0274** (test `move_destination_dialog_test.dart` lines 1-88) → traceability.md §Inventory source reference index

### `test/features/file_browser/presentation/refresh_invalidate_test.dart`

- **SRC-0275** (test `refresh_invalidate_test.dart` lines 1-86) → traceability.md §Inventory source reference index

### `test/features/file_browser/presentation/refresh_progress_dialog_test.dart`

- **SRC-0276** (test `refresh_progress_dialog_test.dart` lines 1-157) → traceability.md §Inventory source reference index

### `test/features/file_browser/presentation/rename_title_dialog_test.dart`

- **SRC-0277** (test `rename_title_dialog_test.dart` lines 1-204) → traceability.md §Inventory source reference index

### `test/features/file_browser/providers/directory_contents_title_mapping_test.dart`

- **SRC-0278** (test `directory_contents_title_mapping_test.dart` lines 1-86) → 02-architecture.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `test/features/file_browser/providers/directory_contents_tts_status_test.dart`

- **SRC-0279** (test `directory_contents_tts_status_test.dart` lines 1-125) → traceability.md §Inventory source reference index

### `test/features/file_browser/providers/download_destination_folders_provider_test.dart`

- **SRC-0280** (test `download_destination_folders_provider_test.dart` lines 1-104) → traceability.md §Inventory source reference index

### `test/features/file_browser/providers/folder_switch_handle_release_test.dart`

- **SRC-0281** (test `folder_switch_handle_release_test.dart` lines 1-73) → 02-architecture.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `test/features/file_browser/providers/reading_progress_badge_provider_test.dart`

- **SRC-0282** (test `reading_progress_badge_provider_test.dart` lines 1-157) → traceability.md §Inventory source reference index

### `test/features/file_browser/providers/selected_novel_title_provider_test.dart`

- **SRC-0283** (test `selected_novel_title_provider_test.dart` lines 1-155) → traceability.md §Inventory source reference index

### `test/features/keyboard_shortcuts/data/focus_utils_test.dart`

- **SRC-0284** (test `focus_utils_test.dart` lines 1-43) → 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/keyboard_shortcuts/data/key_binding_label_test.dart`

- **SRC-0285** (test `key_binding_label_test.dart` lines 1-30) → 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/keyboard_shortcuts/data/shortcut_action_test.dart`

- **SRC-0286** (test `shortcut_action_test.dart` lines 1-53) → 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/keyboard_shortcuts/data/shortcut_bindings_test.dart`

- **SRC-0287** (test `shortcut_bindings_test.dart` lines 1-114) → 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/keyboard_shortcuts/presentation/shortcut_settings_section_test.dart`

- **SRC-0288** (test `shortcut_settings_section_test.dart` lines 1-153) → traceability.md §Inventory source reference index

### `test/features/keyboard_shortcuts/providers/keyboard_shortcut_providers_test.dart`

- **SRC-0289** (test `keyboard_shortcut_providers_test.dart` lines 1-94) → 02-architecture.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `test/features/llm_summary/data/analysis_write_after_close_test.dart`

- **SRC-0290** (test `analysis_write_after_close_test.dart` lines 1-53) → 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/llm_summary/data/context_chunker_test.dart`

- **SRC-0291** (test `context_chunker_test.dart` lines 1-60) → 04-features.md §主要アクション, 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/llm_summary/data/fact_cache_repository_test.dart`

- **SRC-0292** (test `fact_cache_repository_test.dart` lines 1-168) → traceability.md §Inventory source reference index

### `test/features/llm_summary/data/llm_client_test.dart`

- **SRC-0293** (test `llm_client_test.dart` lines 1-541) → 07-external-integrations.md §検証証拠, traceability.md §Inventory source reference index

### `test/features/llm_summary/data/llm_prompt_builder_test.dart`

- **SRC-0294** (test `llm_prompt_builder_test.dart` lines 1-136) → 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/llm_summary/data/llm_summary_pipeline_per_file_test.dart`

- **SRC-0295** (test `llm_summary_pipeline_per_file_test.dart` lines 1-323) → 04-features.md §主要アクション, 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/llm_summary/data/llm_summary_repository_test.dart`

- **SRC-0296** (test `llm_summary_repository_test.dart` lines 1-281) → traceability.md §Inventory source reference index

### `test/features/llm_summary/data/llm_summary_service_cache_test.dart`

- **SRC-0297** (test `llm_summary_service_cache_test.dart` lines 1-342) → traceability.md §Inventory source reference index

### `test/features/llm_summary/data/llm_summary_service_test.dart`

- **SRC-0298** (test `llm_summary_service_test.dart` lines 1-427) → 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/llm_summary/data/v5_migration_test.dart`

- **SRC-0299** (test `v5_migration_test.dart` lines 1-317) → 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/llm_summary/domain/analysis_progress_test.dart`

- **SRC-0300** (test `analysis_progress_test.dart` lines 1-53) → traceability.md §Inventory source reference index

### `test/features/llm_summary/domain/fact_cache_validity_test.dart`

- **SRC-0301** (test `fact_cache_validity_test.dart` lines 1-92) → traceability.md §Inventory source reference index

### `test/features/llm_summary/domain/first_line_containing_test.dart`

- **SRC-0302** (test `first_line_containing_test.dart` lines 1-55) → traceability.md §Inventory source reference index

### `test/features/llm_summary/domain/history_entry_test.dart`

- **SRC-0303** (test `history_entry_test.dart` lines 1-235) → traceability.md §Inventory source reference index

### `test/features/llm_summary/domain/llm_config_test.dart`

- **SRC-0304** (test `llm_config_test.dart` lines 1-80) → traceability.md §Inventory source reference index

### `test/features/llm_summary/domain/llm_summary_result_test.dart`

- **SRC-0305** (test `llm_summary_result_test.dart` lines 1-106) → traceability.md §Inventory source reference index

### `test/features/llm_summary/domain/mark_matcher_test.dart`

- **SRC-0306** (test `mark_matcher_test.dart` lines 1-120) → traceability.md §Inventory source reference index

### `test/features/llm_summary/presentation/analysis_runner_test.dart`

- **SRC-0307** (test `analysis_runner_test.dart` lines 1-638) → traceability.md §Inventory source reference index

### `test/features/llm_summary/presentation/hover_popup_anchor_test.dart`

- **SRC-0308** (test `hover_popup_anchor_test.dart` lines 1-146) → traceability.md §Inventory source reference index

### `test/features/llm_summary/presentation/hover_popup_e2e_test.dart`

- **SRC-0309** (test `hover_popup_e2e_test.dart` lines 1-61) → traceability.md §Inventory source reference index

### `test/features/llm_summary/presentation/hover_popup_host_test.dart`

- **SRC-0310** (test `hover_popup_host_test.dart` lines 1-204) → traceability.md §Inventory source reference index

### `test/features/llm_summary/presentation/hover_popup_widget_test.dart`

- **SRC-0311** (test `hover_popup_widget_test.dart` lines 1-320) → traceability.md §Inventory source reference index

### `test/features/llm_summary/presentation/llm_summary_detail_dialog_test.dart`

- **SRC-0312** (test `llm_summary_detail_dialog_test.dart` lines 1-213) → traceability.md §Inventory source reference index

### `test/features/llm_summary/presentation/llm_summary_history_menu_test.dart`

- **SRC-0313** (test `llm_summary_history_menu_test.dart` lines 1-172) → traceability.md §Inventory source reference index

### `test/features/llm_summary/presentation/llm_summary_history_panel_test.dart`

- **SRC-0314** (test `llm_summary_history_panel_test.dart` lines 1-132) → traceability.md §Inventory source reference index

### `test/features/llm_summary/providers/hover_popup_cache_provider_test.dart`

- **SRC-0315** (test `hover_popup_cache_provider_test.dart` lines 1-136) → traceability.md §Inventory source reference index

### `test/features/llm_summary/providers/hover_popup_provider_test.dart`

- **SRC-0316** (test `hover_popup_provider_test.dart` lines 1-429) → traceability.md §Inventory source reference index

### `test/features/llm_summary/providers/llm_summary_history_provider_test.dart`

- **SRC-0317** (test `llm_summary_history_provider_test.dart` lines 1-393) → traceability.md §Inventory source reference index

### `test/features/llm_summary/providers/llm_summary_providers_test.dart`

- **SRC-0318** (test `llm_summary_providers_test.dart` lines 1-228) → 02-architecture.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `test/features/llm_summary/providers/marked_words_provider_test.dart`

- **SRC-0319** (test `marked_words_provider_test.dart` lines 1-101) → traceability.md §Inventory source reference index

### `test/features/llm_summary/providers/ollama_model_list_provider_test.dart`

- **SRC-0320** (test `ollama_model_list_provider_test.dart` lines 1-161) → traceability.md §Inventory source reference index

### `test/features/novel_delete/data/novel_delete_order_test.dart`

- **SRC-0321** (test `novel_delete_order_test.dart` lines 1-133) → 04-features.md §機能モジュール一覧, 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/novel_delete/data/novel_delete_service_test.dart`

- **SRC-0322** (test `novel_delete_service_test.dart` lines 1-220) → 04-features.md §機能モジュール一覧, 04-features.md §主要アクション, 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/novel_metadata_db/data/novel_database_migration_full_chain_test.dart`

- **SRC-0323** (test `novel_database_migration_full_chain_test.dart` lines 1-101) → 05-data-model.md §割当インベントリ網羅性, traceability.md §Inventory source reference index

### `test/features/novel_metadata_db/data/novel_database_migration_v4_test.dart`

- **SRC-0324** (test `novel_database_migration_v4_test.dart` lines 1-169) → traceability.md §Inventory source reference index

### `test/features/novel_metadata_db/data/novel_database_migration_v6_test.dart`

- **SRC-0325** (test `novel_database_migration_v6_test.dart` lines 1-179) → traceability.md §Inventory source reference index

### `test/features/novel_metadata_db/data/novel_database_migration_v7_test.dart`

- **SRC-0326** (test `novel_database_migration_v7_test.dart` lines 1-149) → traceability.md §Inventory source reference index

### `test/features/novel_metadata_db/data/novel_database_migration_v8_test.dart`

- **SRC-0327** (test `novel_database_migration_v8_test.dart` lines 1-348) → traceability.md §Inventory source reference index

### `test/features/novel_metadata_db/data/novel_database_migration_v9_test.dart`

- **SRC-0328** (test `novel_database_migration_v9_test.dart` lines 1-284) → traceability.md §Inventory source reference index

### `test/features/novel_metadata_db/data/schema_fidelity_test.dart`

- **SRC-0329** (test `schema_fidelity_test.dart` lines 1-69) → 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/novel_metadata_db/novel_database_test.dart`

- **SRC-0330** (test `novel_database_test.dart` lines 1-49) → traceability.md §Inventory source reference index

### `test/features/novel_metadata_db/novel_repository_test.dart`

- **SRC-0331** (test `novel_repository_test.dart` lines 1-195) → traceability.md §Inventory source reference index

### `test/features/reading_progress/data/reading_progress_repository_test.dart`

- **SRC-0332** (test `reading_progress_repository_test.dart` lines 1-207) → traceability.md §Inventory source reference index

### `test/features/reading_progress/domain/reading_progress_test.dart`

- **SRC-0333** (test `reading_progress_test.dart` lines 1-58) → traceability.md §Inventory source reference index

### `test/features/reading_progress/providers/reading_progress_listeners_test.dart`

- **SRC-0334** (test `reading_progress_listeners_test.dart` lines 1-636) → 02-architecture.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `test/features/reading_progress/providers/reading_progress_providers_test.dart`

- **SRC-0335** (test `reading_progress_providers_test.dart` lines 1-53) → 02-architecture.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `test/features/settings/data/font_family_test.dart`

- **SRC-0336** (test `font_family_test.dart` lines 1-109) → 06-settings-security.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `test/features/settings/data/settings_repository_shortcuts_test.dart`

- **SRC-0337** (test `settings_repository_shortcuts_test.dart` lines 1-57) → 06-settings-security.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `test/features/settings/data/settings_repository_test.dart`

- **SRC-0338** (test `settings_repository_test.dart` lines 1-388) → 06-settings-security.md §セキュリティ境界, 06-settings-security.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `test/features/settings/presentation/llm_settings_test.dart`

- **SRC-0339** (test `llm_settings_test.dart` lines 1-278) → 06-settings-security.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `test/features/settings/presentation/settings_dialog_phase_a_test.dart`

- **SRC-0340** (test `settings_dialog_phase_a_test.dart` lines 1-166) → 06-settings-security.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `test/features/settings/presentation/settings_dialog_tabs_test.dart`

- **SRC-0341** (test `settings_dialog_tabs_test.dart` lines 1-139) → 06-settings-security.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `test/features/settings/presentation/settings_dialog_test.dart`

- **SRC-0342** (test `settings_dialog_test.dart` lines 1-170) → 06-settings-security.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `test/features/settings/presentation/settings_piper_l10n_test.dart`

- **SRC-0343** (test `settings_piper_l10n_test.dart` lines 1-56) → 06-settings-security.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `test/features/settings/presentation/settings_test.dart`

- **SRC-0344** (test `settings_test.dart` lines 1-50) → 06-settings-security.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `test/features/settings/presentation/tts_model_download_ui_test.dart`

- **SRC-0345** (test `tts_model_download_ui_test.dart` lines 1-164) → 06-settings-security.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `test/features/settings/presentation/voice_reference_selector_test.dart`

- **SRC-0346** (test `voice_reference_selector_test.dart` lines 1-306) → 06-settings-security.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `test/features/settings/providers/settings_providers_test.dart`

- **SRC-0347** (test `settings_providers_test.dart` lines 1-227) → 06-settings-security.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `test/features/text_download/aozora_site_test.dart`

- **SRC-0348** (test `aozora_site_test.dart` lines 1-252) → 04-features.md §ダウンロードの業務ルール, 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/text_download/collection_download_test.dart`

- **SRC-0349** (test `collection_download_test.dart` lines 1-300) → 04-features.md §主要アクション, 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/text_download/download_cancellation_test.dart`

- **SRC-0350** (test `download_cancellation_test.dart` lines 1-143) → 04-features.md §ダウンロードの業務ルール, 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/text_download/download_dialog_cancel_truncate_test.dart`

- **SRC-0351** (test `download_dialog_cancel_truncate_test.dart` lines 1-120) → traceability.md §Inventory source reference index

### `test/features/text_download/download_dialog_destination_test.dart`

- **SRC-0352** (test `download_dialog_destination_test.dart` lines 1-134) → traceability.md §Inventory source reference index

### `test/features/text_download/download_dialog_test.dart`

- **SRC-0353** (test `download_dialog_test.dart` lines 1-273) → traceability.md §Inventory source reference index

### `test/features/text_download/download_provider_state_test.dart`

- **SRC-0354** (test `download_provider_state_test.dart` lines 1-354) → 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/text_download/download_release_handle_test.dart`

- **SRC-0355** (test `download_release_handle_test.dart` lines 1-122) → 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/text_download/download_service_test.dart`

- **SRC-0356** (test `download_service_test.dart` lines 1-207) → 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/text_download/empty_index_guard_test.dart`

- **SRC-0357** (test `empty_index_guard_test.dart` lines 1-109) → 04-features.md §ダウンロードの業務ルール, 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/text_download/empty_parse_failure_test.dart`

- **SRC-0358** (test `empty_parse_failure_test.dart` lines 1-206) → 04-features.md §主要アクション, 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/text_download/episode_filename_pad_migration_test.dart`

- **SRC-0359** (test `episode_filename_pad_migration_test.dart` lines 1-297) → 04-features.md §ダウンロードの業務ルール, 04-features.md §Deep-dive candidates (refer to them by ID), 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/text_download/file_browser_refresh_test.dart`

- **SRC-0360** (test `file_browser_refresh_test.dart` lines 1-62) → 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/text_download/file_naming_test.dart`

- **SRC-0361** (test `file_naming_test.dart` lines 1-55) → 04-features.md §ダウンロードの業務ルール, 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/text_download/generic_web_site_test.dart`

- **SRC-0362** (test `generic_web_site_test.dart` lines 1-277) → 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/text_download/hameln_site_test.dart`

- **SRC-0363** (test `hameln_site_test.dart` lines 1-420) → 04-features.md §ダウンロードの業務ルール, 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/text_download/helpers/download_test_helpers.dart`

- **SRC-0364** (test `download_test_helpers.dart` lines 1-278) → 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/text_download/incremental_download_test.dart`

- **SRC-0365** (test `incremental_download_test.dart` lines 1-929) → 04-features.md §主要アクション, 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/text_download/index_fixture_parsing_test.dart`

- **SRC-0366** (test `index_fixture_parsing_test.dart` lines 1-83) → 04-features.md §Deep-dive candidates (refer to them by ID), 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/text_download/index_truncated_test.dart`

- **SRC-0367** (test `index_truncated_test.dart` lines 1-148) → 04-features.md §ダウンロードの業務ルール, 04-features.md §Deep-dive candidates (refer to them by ID), 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/text_download/kakuyomu_site_test.dart`

- **SRC-0368** (test `kakuyomu_site_test.dart` lines 1-685) → 04-features.md §ダウンロードの業務ルール, 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/text_download/narou_site_test.dart`

- **SRC-0369** (test `narou_site_test.dart` lines 1-523) → 04-features.md §ダウンロードの業務ルール, 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/text_download/novel_library_service_test.dart`

- **SRC-0370** (test `novel_library_service_test.dart` lines 1-59) → 04-features.md §ダウンロードの業務ルール, 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/text_download/novel_site_test.dart`

- **SRC-0371** (test `novel_site_test.dart` lines 1-137) → 04-features.md §ダウンロードの業務ルール, 04-features.md §割当インベントリの網羅, 04-features.md §Q-006, 09-constraints.md §既存の未解決事項, traceability.md §Inventory source reference index

### `test/features/text_download/refresh_novel_test.dart`

- **SRC-0372** (test `refresh_novel_test.dart` lines 1-178) → 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/text_download/request_timeout_test.dart`

- **SRC-0373** (test `request_timeout_test.dart` lines 1-81) → 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/text_download/transient_retry_test.dart`

- **SRC-0374** (test `transient_retry_test.dart` lines 1-323) → 04-features.md §ダウンロードの業務ルール, 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/text_download/url_validation_test.dart`

- **SRC-0375** (test `url_validation_test.dart` lines 1-133) → 04-features.md §Deep-dive candidates (refer to them by ID), 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/text_download/user_agent_precedence_test.dart`

- **SRC-0376** (test `user_agent_precedence_test.dart` lines 1-52) → 04-features.md §ダウンロードの業務ルール, 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/text_search/data/search_models_test.dart`

- **SRC-0377** (test `search_models_test.dart` lines 1-43) → 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/text_search/data/text_search_service_test.dart`

- **SRC-0378** (test `text_search_service_test.dart` lines 1-187) → 04-features.md §機能モジュール一覧, 04-features.md §主要アクション, 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/text_search/presentation/search_results_panel_test.dart`

- **SRC-0379** (test `search_results_panel_test.dart` lines 1-630) → 03-screens.md §表示状態とエッジケース, traceability.md §Inventory source reference index

### `test/features/text_search/providers/text_search_providers_test.dart`

- **SRC-0380** (test `text_search_providers_test.dart` lines 1-242) → 02-architecture.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `test/features/text_viewer/data/column_splitter_test.dart`

- **SRC-0381** (test `column_splitter_test.dart` lines 1-251) → traceability.md §Inventory source reference index

### `test/features/text_viewer/data/kinsoku_test.dart`

- **SRC-0382** (test `kinsoku_test.dart` lines 1-136) → traceability.md §Inventory source reference index

### `test/features/text_viewer/data/parsed_segments_cache_test.dart`

- **SRC-0383** (test `parsed_segments_cache_test.dart` lines 1-93) → traceability.md §Inventory source reference index

### `test/features/text_viewer/data/swipe_detection_test.dart`

- **SRC-0384** (test `swipe_detection_test.dart` lines 1-64) → traceability.md §Inventory source reference index

### `test/features/text_viewer/data/text_file_reader_test.dart`

- **SRC-0385** (test `text_file_reader_test.dart` lines 1-46) → traceability.md §Inventory source reference index

### `test/features/text_viewer/data/vertical_char_map_test.dart`

- **SRC-0386** (test `vertical_char_map_test.dart` lines 1-156) → traceability.md §Inventory source reference index

### `test/features/text_viewer/data/vertical_marked_ranges_test.dart`

- **SRC-0387** (test `vertical_marked_ranges_test.dart` lines 1-346) → traceability.md §Inventory source reference index

### `test/features/text_viewer/data/vertical_text_layout_test.dart`

- **SRC-0388** (test `vertical_text_layout_test.dart` lines 1-242) → traceability.md §Inventory source reference index

### `test/features/text_viewer/presentation/horizontal_edge_episode_nav_test.dart`

- **SRC-0389** (test `horizontal_edge_episode_nav_test.dart` lines 1-334) → traceability.md §Inventory source reference index

### `test/features/text_viewer/presentation/horizontal_page_scroll_test.dart`

- **SRC-0390** (test `horizontal_page_scroll_test.dart` lines 1-74) → traceability.md §Inventory source reference index

### `test/features/text_viewer/presentation/resolve_viewer_effects_test.dart`

- **SRC-0391** (test `resolve_viewer_effects_test.dart` lines 1-220) → traceability.md §Inventory source reference index

### `test/features/text_viewer/presentation/text_viewer_font_test.dart`

- **SRC-0392** (test `text_viewer_font_test.dart` lines 1-159) → traceability.md §Inventory source reference index

### `test/features/text_viewer/presentation/text_viewer_panel_test.dart`

- **SRC-0393** (test `text_viewer_panel_test.dart` lines 1-575) → 03-screens.md §表示状態とエッジケース, traceability.md §Inventory source reference index

### `test/features/text_viewer/presentation/text_viewer_tts_delete_confirmation_test.dart`

- **SRC-0394** (test `text_viewer_tts_delete_confirmation_test.dart` lines 1-153) → traceability.md §Inventory source reference index

### `test/features/text_viewer/presentation/tts_auto_page_test.dart`

- **SRC-0395** (test `tts_auto_page_test.dart` lines 1-89) → traceability.md §Inventory source reference index

### `test/features/text_viewer/presentation/tts_auto_scroll_test.dart`

- **SRC-0396** (test `tts_auto_scroll_test.dart` lines 1-63) → traceability.md §Inventory source reference index

### `test/features/text_viewer/presentation/tts_export_button_test.dart`

- **SRC-0397** (test `tts_export_button_test.dart` lines 1-195) → traceability.md §Inventory source reference index

### `test/features/text_viewer/presentation/tts_highlight_horizontal_test.dart`

- **SRC-0398** (test `tts_highlight_horizontal_test.dart` lines 1-105) → 03-screens.md §表示状態とエッジケース, traceability.md §Inventory source reference index

### `test/features/text_viewer/presentation/tts_highlight_page_offset_test.dart`

- **SRC-0399** (test `tts_highlight_page_offset_test.dart` lines 1-230) → 03-screens.md §表示状態とエッジケース, traceability.md §Inventory source reference index

### `test/features/text_viewer/presentation/tts_highlight_vertical_test.dart`

- **SRC-0400** (test `tts_highlight_vertical_test.dart` lines 1-152) → 03-screens.md §表示状態とエッジケース, traceability.md §Inventory source reference index

### `test/features/text_viewer/presentation/vertical_ruby_text_widget_test.dart`

- **SRC-0401** (test `vertical_ruby_text_widget_test.dart` lines 1-222) → traceability.md §Inventory source reference index

### `test/features/text_viewer/presentation/vertical_text_page_hover_test.dart`

- **SRC-0402** (test `vertical_text_page_hover_test.dart` lines 1-407) → traceability.md §Inventory source reference index

### `test/features/text_viewer/presentation/vertical_text_page_mark_scan_test.dart`

- **SRC-0403** (test `vertical_text_page_mark_scan_test.dart` lines 1-59) → traceability.md §Inventory source reference index

### `test/features/text_viewer/presentation/vertical_text_page_memoization_test.dart`

- **SRC-0404** (test `vertical_text_page_memoization_test.dart` lines 1-167) → traceability.md §Inventory source reference index

### `test/features/text_viewer/presentation/vertical_text_page_test.dart`

- **SRC-0405** (test `vertical_text_page_test.dart` lines 1-571) → traceability.md §Inventory source reference index

### `test/features/text_viewer/presentation/vertical_text_pagination_font_test.dart`

- **SRC-0406** (test `vertical_text_pagination_font_test.dart` lines 1-505) → traceability.md §Inventory source reference index

### `test/features/text_viewer/presentation/vertical_text_viewer_animation_test.dart`

- **SRC-0407** (test `vertical_text_viewer_animation_test.dart` lines 1-355) → traceability.md §Inventory source reference index

### `test/features/text_viewer/presentation/vertical_text_viewer_episode_nav_test.dart`

- **SRC-0408** (test `vertical_text_viewer_episode_nav_test.dart` lines 1-399) → 03-screens.md §表示状態とエッジケース, traceability.md §Inventory source reference index

### `test/features/text_viewer/presentation/vertical_text_viewer_hover_test.dart`

- **SRC-0409** (test `vertical_text_viewer_hover_test.dart` lines 1-188) → traceability.md §Inventory source reference index

### `test/features/text_viewer/presentation/vertical_text_viewer_initial_page_test.dart`

- **SRC-0410** (test `vertical_text_viewer_initial_page_test.dart` lines 1-146) → traceability.md §Inventory source reference index

### `test/features/text_viewer/presentation/vertical_text_viewer_memoization_test.dart`

- **SRC-0411** (test `vertical_text_viewer_memoization_test.dart` lines 1-194) → traceability.md §Inventory source reference index

### `test/features/text_viewer/presentation/vertical_text_viewer_pagination_test.dart`

- **SRC-0412** (test `vertical_text_viewer_pagination_test.dart` lines 1-198) → traceability.md §Inventory source reference index

### `test/features/text_viewer/presentation/vertical_text_viewer_swipe_test.dart`

- **SRC-0413** (test `vertical_text_viewer_swipe_test.dart` lines 1-327) → 03-screens.md §表示状態とエッジケース, traceability.md §Inventory source reference index

### `test/features/text_viewer/presentation/vertical_text_viewer_test.dart`

- **SRC-0414** (test `vertical_text_viewer_test.dart` lines 1-149) → traceability.md §Inventory source reference index

### `test/features/text_viewer/presentation/vertical_text_viewer_wheel_test.dart`

- **SRC-0415** (test `vertical_text_viewer_wheel_test.dart` lines 1-199) → 03-screens.md §表示状態とエッジケース, traceability.md §Inventory source reference index

### `test/features/text_viewer/presentation/widgets/text_content_renderer_intent_test.dart`

- **SRC-0416** (test `text_content_renderer_intent_test.dart` lines 1-334) → traceability.md §Inventory source reference index

### `test/features/text_viewer/presentation/widgets/text_content_renderer_test.dart`

- **SRC-0417** (test `text_content_renderer_test.dart` lines 1-582) → traceability.md §Inventory source reference index

### `test/features/text_viewer/presentation/widgets/tts_controls_bar_test.dart`

- **SRC-0418** (test `tts_controls_bar_test.dart` lines 1-218) → traceability.md §Inventory source reference index

### `test/features/text_viewer/presentation/widgets/vertical_context_menu_test.dart`

- **SRC-0419** (test `vertical_context_menu_test.dart` lines 1-116) → traceability.md §Inventory source reference index

### `test/features/text_viewer/providers/selected_text_provider_test.dart`

- **SRC-0420** (test `selected_text_provider_test.dart` lines 1-43) → traceability.md §Inventory source reference index

### `test/features/text_viewer/ruby_text_parser_test.dart`

- **SRC-0421** (test `ruby_text_parser_test.dart` lines 1-237) → traceability.md §Inventory source reference index

### `test/features/text_viewer/ruby_text_spans_hover_test.dart`

- **SRC-0422** (test `ruby_text_spans_hover_test.dart` lines 1-155) → traceability.md §Inventory source reference index

### `test/features/text_viewer/ruby_text_spans_test.dart`

- **SRC-0423** (test `ruby_text_spans_test.dart` lines 1-313) → traceability.md §Inventory source reference index

### `test/features/text_viewer/text_segment_test.dart`

- **SRC-0424** (test `text_segment_test.dart` lines 1-62) → traceability.md §Inventory source reference index

### `test/features/tts/data/lame_enc_bindings_test.dart`

- **SRC-0425** (test `lame_enc_bindings_test.dart` lines 1-107) → 07-external-integrations.md §検証証拠, traceability.md §Inventory source reference index

### `test/features/tts/data/piper_model_download_service_test.dart`

- **SRC-0426** (test `piper_model_download_service_test.dart` lines 1-76) → 07-external-integrations.md §検証証拠, traceability.md §Inventory source reference index

### `test/features/tts/data/piper_tts_engine_test.dart`

- **SRC-0427** (test `piper_tts_engine_test.dart` lines 1-205) → 04-features.md §TTSの状態とデータフロー, 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/tts/data/segment_player_test.dart`

- **SRC-0428** (test `segment_player_test.dart` lines 1-206) → 04-features.md §TTSの状態とデータフロー, 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/tts/data/text_segmenter_test.dart`

- **SRC-0429** (test `text_segmenter_test.dart` lines 1-472) → 04-features.md §TTSの状態とデータフロー, 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/tts/data/tts_adapters_test.dart`

- **SRC-0430** (test `tts_adapters_test.dart` lines 1-12) → 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/tts/data/tts_audio_database_test.dart`

- **SRC-0431** (test `tts_audio_database_test.dart` lines 1-624) → traceability.md §Inventory source reference index

### `test/features/tts/data/tts_audio_export_service_test.dart`

- **SRC-0432** (test `tts_audio_export_service_test.dart` lines 1-178) → 04-features.md §主要アクション, 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/tts/data/tts_audio_repository_test.dart`

- **SRC-0433** (test `tts_audio_repository_test.dart` lines 1-689) → 05-data-model.md §状態遷移とデータフロー, traceability.md §Inventory source reference index

### `test/features/tts/data/tts_dictionary_repository_test.dart`

- **SRC-0434** (test `tts_dictionary_repository_test.dart` lines 1-169) → traceability.md §Inventory source reference index

### `test/features/tts/data/tts_edit_controller_test.dart`

- **SRC-0435** (test `tts_edit_controller_test.dart` lines 1-2328) → 04-features.md §主要アクション, 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/tts/data/tts_edit_segment_test.dart`

- **SRC-0436** (test `tts_edit_segment_test.dart` lines 1-158) → 04-features.md §TTSの状態とデータフロー, 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/tts/data/tts_engine_embedding_cache_test.dart`

- **SRC-0437** (test `tts_engine_embedding_cache_test.dart` lines 1-361) → traceability.md §Inventory source reference index

### `test/features/tts/data/tts_engine_test.dart`

- **SRC-0438** (test `tts_engine_test.dart` lines 1-293) → 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/tts/data/tts_isolate_test.dart`

- **SRC-0439** (test `tts_isolate_test.dart` lines 1-329) → 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/tts/data/tts_language_test.dart`

- **SRC-0440** (test `tts_language_test.dart` lines 1-36) → 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/tts/data/tts_model_download_service_test.dart`

- **SRC-0441** (test `tts_model_download_service_test.dart` lines 1-377) → 07-external-integrations.md §検証証拠, traceability.md §Inventory source reference index

### `test/features/tts/data/tts_model_size_test.dart`

- **SRC-0442** (test `tts_model_size_test.dart` lines 1-34) → 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/tts/data/tts_native_bindings_test.dart`

- **SRC-0443** (test `tts_native_bindings_test.dart` lines 1-46) → 07-external-integrations.md §検証証拠, traceability.md §Inventory source reference index

### `test/features/tts/data/tts_session_test.dart`

- **SRC-0444** (test `tts_session_test.dart` lines 1-587) → 04-features.md §TTSの状態とデータフロー, 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/tts/data/tts_streaming_controller_test.dart`

- **SRC-0445** (test `tts_streaming_controller_test.dart` lines 1-1586) → 04-features.md §主要アクション, 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/tts/data/tts_toggle_test.dart`

- **SRC-0446** (test `tts_toggle_test.dart` lines 1-48) → 04-features.md §TTSの状態とデータフロー, 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/tts/data/voice_recording_service_test.dart`

- **SRC-0447** (test `voice_recording_service_test.dart` lines 1-166) → 04-features.md §TTSの状態とデータフロー, 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/tts/data/voice_reference_service_test.dart`

- **SRC-0448** (test `voice_reference_service_test.dart` lines 1-307) → 04-features.md §TTSの状態とデータフロー, 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/tts/data/wav_writer_test.dart`

- **SRC-0449** (test `wav_writer_test.dart` lines 1-117) → 04-features.md §TTSの状態とデータフロー, 04-features.md §割当インベントリの網羅, traceability.md §Inventory source reference index

### `test/features/tts/domain/tts_engine_config_test.dart`

- **SRC-0450** (test `tts_engine_config_test.dart` lines 1-192) → traceability.md §Inventory source reference index

### `test/features/tts/domain/tts_episode_status_test.dart`

- **SRC-0451** (test `tts_episode_status_test.dart` lines 1-53) → traceability.md §Inventory source reference index

### `test/features/tts/domain/tts_episode_test.dart`

- **SRC-0452** (test `tts_episode_test.dart` lines 1-104) → traceability.md §Inventory source reference index

### `test/features/tts/domain/tts_ref_wav_resolver_test.dart`

- **SRC-0453** (test `tts_ref_wav_resolver_test.dart` lines 1-65) → traceability.md §Inventory source reference index

### `test/features/tts/domain/tts_segment_test.dart`

- **SRC-0454** (test `tts_segment_test.dart` lines 1-98) → traceability.md §Inventory source reference index

### `test/features/tts/presentation/dictionary_context_menu_test.dart`

- **SRC-0455** (test `dictionary_context_menu_test.dart` lines 1-334) → traceability.md §Inventory source reference index

### `test/features/tts/presentation/tts_dictionary_dialog_test.dart`

- **SRC-0456** (test `tts_dictionary_dialog_test.dart` lines 1-103) → traceability.md §Inventory source reference index

### `test/features/tts/providers/text_segmenter_provider_test.dart`

- **SRC-0457** (test `text_segmenter_provider_test.dart` lines 1-20) → 02-architecture.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `test/features/tts/providers/tts_audio_database_provider_test.dart`

- **SRC-0458** (test `tts_audio_database_provider_test.dart` lines 1-100) → traceability.md §Inventory source reference index

### `test/features/tts/providers/tts_audio_state_provider_test.dart`

- **SRC-0459** (test `tts_audio_state_provider_test.dart` lines 1-126) → traceability.md §Inventory source reference index

### `test/features/tts/providers/tts_model_download_providers_test.dart`

- **SRC-0460** (test `tts_model_download_providers_test.dart` lines 1-209) → 07-external-integrations.md §検証証拠, traceability.md §Inventory source reference index

### `test/features/tts/providers/tts_playback_state_test.dart`

- **SRC-0461** (test `tts_playback_state_test.dart` lines 1-139) → traceability.md §Inventory source reference index

### `test/features/tts/providers/tts_settings_providers_test.dart`

- **SRC-0462** (test `tts_settings_providers_test.dart` lines 1-316) → 02-architecture.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `test/features/tts/providers/vacuum_lifecycle_provider_test.dart`

- **SRC-0463** (test `vacuum_lifecycle_provider_test.dart` lines 1-94) → traceability.md §Inventory source reference index

### `test/helpers/localized_material_app.dart`

- **SRC-0464** (test `localized_material_app.dart` lines 1-23) → traceability.md §Inventory source reference index

### `test/helpers/novel_data_db_fixture.dart`

- **SRC-0465** (test `novel_data_db_fixture.dart` lines 1-26) → traceability.md §Inventory source reference index

### `test/helpers/novel_metadata_db_fixture.dart`

- **SRC-0466** (test `novel_metadata_db_fixture.dart` lines 1-36) → traceability.md §Inventory source reference index

### `test/home_screen_dynamic_shortcuts_test.dart`

- **SRC-0467** (test `home_screen_dynamic_shortcuts_test.dart` lines 1-65) → traceability.md §Inventory source reference index

### `test/home_screen_pane_focus_test.dart`

- **SRC-0468** (test `home_screen_pane_focus_test.dart` lines 1-95) → traceability.md §Inventory source reference index

### `test/home_screen_test.dart`

- **SRC-0469** (test `home_screen_test.dart` lines 1-656) → 03-screens.md §表示状態とエッジケース, 03-screens.md §Detail questions raised in this chapter, 09-constraints.md §既存の未解決事項, traceability.md §Inventory source reference index

### `test/home_screen_tts_shortcut_test.dart`

- **SRC-0470** (test `home_screen_tts_shortcut_test.dart` lines 1-123) → traceability.md §Inventory source reference index

### `test/shared/database/database_opener_test.dart`

- **SRC-0471** (test `database_opener_test.dart` lines 1-130) → traceability.md §Inventory source reference index

### `test/shared/database/db_connection_gate_test.dart`

- **SRC-0472** (test `db_connection_gate_test.dart` lines 1-144) → 05-data-model.md §割当インベントリ網羅性, traceability.md §Inventory source reference index

### `test/shared/database/folder_db_handles_test.dart`

- **SRC-0473** (test `folder_db_handles_test.dart` lines 1-135) → traceability.md §Inventory source reference index

### `test/shared/database/folder_db_key_test.dart`

- **SRC-0474** (test `folder_db_key_test.dart` lines 1-46) → traceability.md §Inventory source reference index

### `test/shared/database/novel_data_database_test.dart`

- **SRC-0475** (test `novel_data_database_test.dart` lines 1-176) → 05-data-model.md §割当インベントリ網羅性, traceability.md §Inventory source reference index

### `test/shared/database/per_folder_db_registry_test.dart`

- **SRC-0476** (test `per_folder_db_registry_test.dart` lines 1-243) → traceability.md §Inventory source reference index

### `test/shared/episode/episode_resolver_test.dart`

- **SRC-0477** (test `episode_resolver_test.dart` lines 1-189) → 02-architecture.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `test/shared/logging/app_logger_test.dart`

- **SRC-0478** (test `app_logger_test.dart` lines 1-165) → 06-settings-security.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `test/shared/logging/file_log_sink_test.dart`

- **SRC-0479** (test `file_log_sink_test.dart` lines 1-139) → 06-settings-security.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `test/shared/providers/layout_providers_test.dart`

- **SRC-0480** (test `layout_providers_test.dart` lines 1-31) → traceability.md §Inventory source reference index

### `test/shared/utils/cancellation_token_test.dart`

- **SRC-0481** (test `cancellation_token_test.dart` lines 1-42) → traceability.md §Inventory source reference index

### `test/shared/utils/content_hash_test.dart`

- **SRC-0482** (test `content_hash_test.dart` lines 1-21) → traceability.md §Inventory source reference index

### `test/shared/utils/novel_id_resolver_test.dart`

- **SRC-0483** (test `novel_id_resolver_test.dart` lines 1-101) → 02-architecture.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `test/shared/utils/temp_directory_utils_test.dart`

- **SRC-0484** (test `temp_directory_utils_test.dart` lines 1-64) → traceability.md §Inventory source reference index

### `test/test_utils/flutter_secure_storage_mock.dart`

- **SRC-0485** (test `flutter_secure_storage_mock.dart` lines 1-65) → 06-settings-security.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

### `test/widget_test.dart`

- **SRC-0486** (test `widget_test.dart` lines 1-31) → traceability.md §Inventory source reference index

### `windows/CMakeLists.txt`

- **SRC-0487** (other `CMakeLists.txt` lines 1-113) → 08-operations.md §モジュール, 08-operations.md §データ・成果物, 08-operations.md §依存関係, 08-operations.md §プラットフォーム別運用, 08-operations.md §割当インベントリ網羅表 (and 1 more)

### `windows/runner/main.cpp`

- **SRC-0488** (other `main.cpp` lines 1-43) → 08-operations.md §モジュール, 08-operations.md §プラットフォーム別運用, 08-operations.md §割当インベントリ網羅表, traceability.md §Inventory source reference index

## Inventory source reference index

- INV-0001: [REF: .fvmrc:1-3]
- INV-0002: [REF: .github/workflows/release.yml:1-171]
- INV-0003: [REF: .github/workflows/test.yml:1-38]
- INV-0004: [REF: .metadata:1-42]
- INV-0005: [REF: analysis_options.yaml:1-16]
- INV-0006: [REF: android/app/build.gradle.kts:1-44]
- INV-0007: [REF: ios/Runner/AppDelegate.swift:1-13]
- INV-0008: [REF: l10n.yaml:1-3]
- INV-0009: [REF: lib/app.dart:1-48]
- INV-0010: [REF: lib/app/selected_file_progress_title_provider.dart:1-27]
- INV-0011: [REF: lib/app/startup_migrations.dart:1-16]
- INV-0012: [REF: lib/features/app_update/data/distribution_detector.dart:1-44]
- INV-0013: [REF: lib/features/app_update/data/github_release_client.dart:1-57]
- INV-0014: [REF: lib/features/app_update/data/installer_downloader.dart:1-118]
- INV-0015: [REF: lib/features/app_update/data/installer_updater.dart:1-91]
- INV-0016: [REF: lib/features/app_update/data/installer_verifier.dart:1-37]
- INV-0017: [REF: lib/features/app_update/data/process_starter.dart:1-21]
- INV-0018: [REF: lib/features/app_update/data/registry_reader.dart:1-35]
- INV-0019: [REF: lib/features/app_update/data/release_info.dart:1-55]
- INV-0020: [REF: lib/features/app_update/data/update_preferences.dart:1-32]
- INV-0021: [REF: lib/features/app_update/domain/distribution_type.dart:1-5]
- INV-0022: [REF: lib/features/app_update/domain/update_check_service.dart:1-97]
- INV-0023: [REF: lib/features/app_update/domain/update_constants.dart:1-25]
- INV-0024: [REF: lib/features/app_update/domain/version_comparator.dart:1-29]
- INV-0025: [REF: lib/features/app_update/presentation/update_badge.dart:1-27]
- INV-0026: [REF: lib/features/app_update/presentation/update_dialog.dart:1-193]
- INV-0027: [REF: lib/features/app_update/providers/update_providers.dart:1-91]
- INV-0028: [REF: lib/features/bookmark/data/bookmark_repository.dart:1-99]
- INV-0029: [REF: lib/features/bookmark/domain/bookmark.dart:1-34]
- INV-0030: [REF: lib/features/bookmark/presentation/bookmark_list_panel.dart:1-131]
- INV-0031: [REF: lib/features/bookmark/presentation/left_column_panel.dart:1-56]
- INV-0032: [REF: lib/features/bookmark/providers/bookmark_providers.dart:1-115]
- INV-0033: [REF: lib/features/episode_cache/data/episode_cache_database.dart:1-47]
- INV-0034: [REF: lib/features/episode_cache/data/episode_cache_repository.dart:1-38]
- INV-0035: [REF: lib/features/episode_cache/domain/episode_cache.dart:1-35]
- INV-0036: [REF: lib/features/episode_navigation/domain/file_entry_start_intent.dart:1-10]
- INV-0037: [REF: lib/features/episode_navigation/providers/adjacent_files_provider.dart:1-46]
- INV-0038: [REF: lib/features/episode_navigation/providers/episode_navigation_controller.dart:1-41]
- INV-0039: [REF: lib/features/episode_navigation/providers/pending_file_entry_intent_provider.dart:1-19]
- INV-0040: [REF: lib/features/file_browser/data/file_system_service.dart:1-300]
- INV-0041: [REF: lib/features/file_browser/domain/move_destination.dart:1-49]
- INV-0042: [REF: lib/features/file_browser/domain/move_follow.dart:1-22]
- INV-0043: [REF: lib/features/file_browser/domain/novel_folder_classifier.dart:1-9]
- INV-0044: [REF: lib/features/file_browser/domain/reading_progress_badge.dart:1-43]
- INV-0045: [REF: lib/features/file_browser/presentation/file_browser_panel.dart:1-812]
- INV-0046: [REF: lib/features/file_browser/presentation/move_destination_dialog.dart:1-52]
- INV-0047: [REF: lib/features/file_browser/presentation/new_folder_dialog.dart:1-84]
- INV-0048: [REF: lib/features/file_browser/presentation/rename_title_dialog.dart:1-64]
- INV-0049: [REF: lib/features/file_browser/providers/file_browser_providers.dart:1-252]
- INV-0050: [REF: lib/features/keyboard_shortcuts/data/focus_utils.dart:1-16]
- INV-0051: [REF: lib/features/keyboard_shortcuts/data/key_binding_label.dart:1-23]
- INV-0052: [REF: lib/features/keyboard_shortcuts/data/shortcut_action.dart:1-14]
- INV-0053: [REF: lib/features/keyboard_shortcuts/data/shortcut_bindings.dart:1-141]
- INV-0054: [REF: lib/features/keyboard_shortcuts/data/shortcut_intents.dart:1-52]
- INV-0055: [REF: lib/features/keyboard_shortcuts/presentation/shortcut_settings_section.dart:1-172]
- INV-0056: [REF: lib/features/keyboard_shortcuts/providers/keyboard_shortcut_providers.dart:1-60]
- INV-0057: [REF: lib/features/llm_summary/data/context_chunker.dart:1-34]
- INV-0058: [REF: lib/features/llm_summary/data/fact_cache_repository.dart:1-107]
- INV-0059: [REF: lib/features/llm_summary/data/llm_client.dart:1-5]
- INV-0060: [REF: lib/features/llm_summary/data/llm_prompt_builder.dart:1-56]
- INV-0061: [REF: lib/features/llm_summary/data/llm_response_format_exception.dart:1-28]
- INV-0062: [REF: lib/features/llm_summary/data/llm_summary_pipeline.dart:1-192]
- INV-0063: [REF: lib/features/llm_summary/data/llm_summary_repository.dart:1-99]
- INV-0064: [REF: lib/features/llm_summary/data/llm_summary_service.dart:1-234]
- INV-0065: [REF: lib/features/llm_summary/data/ollama_client.dart:1-96]
- INV-0066: [REF: lib/features/llm_summary/data/openai_compatible_client.dart:1-72]
- INV-0067: [REF: lib/features/llm_summary/domain/analysis_progress.dart:1-40]
- INV-0068: [REF: lib/features/llm_summary/domain/fact_cache_entry.dart:1-49]
- INV-0069: [REF: lib/features/llm_summary/domain/first_line_containing.dart:1-20]
- INV-0070: [REF: lib/features/llm_summary/domain/history_entry.dart:1-64]
- INV-0071: [REF: lib/features/llm_summary/domain/hover_token.dart:1-11]
- INV-0072: [REF: lib/features/llm_summary/domain/llm_config.dart:1-15]
- INV-0073: [REF: lib/features/llm_summary/domain/llm_summary_result.dart:1-50]
- INV-0074: [REF: lib/features/llm_summary/domain/mark_matcher.dart:1-88]
- INV-0075: [REF: lib/features/llm_summary/presentation/analysis_runner.dart:1-273]
- INV-0076: [REF: lib/features/llm_summary/presentation/hover_popup_anchor.dart:1-70]
- INV-0077: [REF: lib/features/llm_summary/presentation/hover_popup_host.dart:1-114]
- INV-0078: [REF: lib/features/llm_summary/presentation/hover_popup_widget.dart:1-314]
- INV-0079: [REF: lib/features/llm_summary/presentation/llm_summary_detail_dialog.dart:1-202]
- INV-0080: [REF: lib/features/llm_summary/presentation/llm_summary_history_menu.dart:1-102]
- INV-0081: [REF: lib/features/llm_summary/presentation/llm_summary_history_panel.dart:1-175]
- INV-0082: [REF: lib/features/llm_summary/presentation/outlined_text_badge.dart:1-26]
- INV-0083: [REF: lib/features/llm_summary/presentation/summary_snapshot_view.dart:1-149]
- INV-0084: [REF: lib/features/llm_summary/providers/hover_popup_cache_provider.dart:1-40]
- INV-0085: [REF: lib/features/llm_summary/providers/hover_popup_provider.dart:1-160]
- INV-0086: [REF: lib/features/llm_summary/providers/llm_summary_detail_provider.dart:1-23]
- INV-0087: [REF: lib/features/llm_summary/providers/llm_summary_history_provider.dart:1-89]
- INV-0088: [REF: lib/features/llm_summary/providers/llm_summary_providers.dart:1-98]
- INV-0089: [REF: lib/features/llm_summary/providers/marked_words_provider.dart:1-18]
- INV-0090: [REF: lib/features/llm_summary/providers/ollama_model_list_provider.dart:1-20]
- INV-0091: [REF: lib/features/novel_delete/data/novel_delete_service.dart:1-59]
- INV-0092: [REF: lib/features/novel_delete/providers/novel_delete_providers.dart:1-32]
- INV-0093: [REF: lib/features/novel_metadata_db/data/novel_data_migrator.dart:1-189]
- INV-0094: [REF: lib/features/novel_metadata_db/data/novel_database.dart:1-601]
- INV-0095: [REF: lib/features/novel_metadata_db/data/novel_repository.dart:1-90]
- INV-0096: [REF: lib/features/novel_metadata_db/domain/novel_metadata.dart:1-53]
- INV-0097: [REF: lib/features/novel_metadata_db/providers/novel_metadata_providers.dart:1-17]
- INV-0098: [REF: lib/features/reading_progress/data/reading_progress_repository.dart:1-57]
- INV-0099: [REF: lib/features/reading_progress/domain/reading_progress.dart:1-27]
- INV-0100: [REF: lib/features/reading_progress/providers/reading_progress_providers.dart:1-144]
- INV-0101: [REF: lib/features/settings/data/font_family.dart:1-57]
- INV-0102: [REF: lib/features/settings/data/settings_repository.dart:1-287]
- INV-0103: [REF: lib/features/settings/data/text_display_mode.dart:1-4]
- INV-0104: [REF: lib/features/settings/presentation/sections/about_and_update_section.dart:1-123]
- INV-0105: [REF: lib/features/settings/presentation/sections/general_settings_section.dart:1-145]
- INV-0106: [REF: lib/features/settings/presentation/sections/llm_settings_section.dart:1-284]
- INV-0107: [REF: lib/features/settings/presentation/sections/piper_settings_section.dart:1-181]
- INV-0108: [REF: lib/features/settings/presentation/sections/qwen3_settings_section.dart:1-175]
- INV-0109: [REF: lib/features/settings/presentation/sections/voice_reference_section.dart:1-310]
- INV-0110: [REF: lib/features/settings/presentation/settings_dialog.dart:1-166]
- INV-0111: [REF: lib/features/settings/providers/settings_providers.dart:1-137]
- INV-0112: [REF: lib/features/text_download/data/download_service.dart:1-923]
- INV-0113: [REF: lib/features/text_download/data/novel_library_service.dart:1-81]
- INV-0114: [REF: lib/features/text_download/data/sites/aozora_site.dart:1-74]
- INV-0115: [REF: lib/features/text_download/data/sites/generic_web_site.dart:1-239]
- INV-0116: [REF: lib/features/text_download/data/sites/hameln_site.dart:1-200]
- INV-0117: [REF: lib/features/text_download/data/sites/kakuyomu_site.dart:1-162]
- INV-0118: [REF: lib/features/text_download/data/sites/narou_site.dart:1-191]
- INV-0119: [REF: lib/features/text_download/data/sites/novel_site.dart:1-103]
- INV-0120: [REF: lib/features/text_download/presentation/download_dialog.dart:1-461]
- INV-0121: [REF: lib/features/text_download/providers/text_download_providers.dart:1-410]
- INV-0122: [REF: lib/features/text_search/data/search_models.dart:1-35]
- INV-0123: [REF: lib/features/text_search/data/text_search_service.dart:1-100]
- INV-0124: [REF: lib/features/text_search/presentation/search_results_panel.dart:1-196]
- INV-0125: [REF: lib/features/text_search/providers/text_search_providers.dart:1-113]
- INV-0126: [REF: lib/features/text_viewer/data/column_splitter.dart:1-152]
- INV-0127: [REF: lib/features/text_viewer/data/kinsoku.dart:1-34]
- INV-0128: [REF: lib/features/text_viewer/data/parsed_segments_cache.dart:1-36]
- INV-0129: [REF: lib/features/text_viewer/data/parsed_segments_cache_provider.dart:1-6]
- INV-0130: [REF: lib/features/text_viewer/data/ruby_text_parser.dart:1-89]
- INV-0131: [REF: lib/features/text_viewer/data/swipe_detection.dart:1-46]
- INV-0132: [REF: lib/features/text_viewer/data/text_file_reader.dart:1-8]
- INV-0133: [REF: lib/features/text_viewer/data/text_segment.dart:1-38]
- INV-0134: [REF: lib/features/text_viewer/data/vertical_char_map.dart:1-136]
- INV-0135: [REF: lib/features/text_viewer/data/vertical_marked_ranges.dart:1-104]
- INV-0136: [REF: lib/features/text_viewer/data/vertical_text_layout.dart:1-139]
- INV-0137: [REF: lib/features/text_viewer/presentation/ruby_text_builder.dart:1-377]
- INV-0138: [REF: lib/features/text_viewer/presentation/text_viewer_panel.dart:1-49]
- INV-0139: [REF: lib/features/text_viewer/presentation/vertical_ruby_text_widget.dart:1-134]
- INV-0140: [REF: lib/features/text_viewer/presentation/vertical_text_page.dart:1-760]
- INV-0141: [REF: lib/features/text_viewer/presentation/vertical_text_viewer.dart:1-1177]
- INV-0142: [REF: lib/features/text_viewer/presentation/widgets/text_content_renderer.dart:1-909]
- INV-0143: [REF: lib/features/text_viewer/presentation/widgets/tts_controls_bar.dart:1-580]
- INV-0144: [REF: lib/features/text_viewer/presentation/widgets/vertical_context_menu.dart:1-58]
- INV-0145: [REF: lib/features/text_viewer/providers/text_viewer_providers.dart:1-25]
- INV-0146: [REF: lib/features/tts/data/lame_enc_bindings.dart:1-62]
- INV-0147: [REF: lib/features/tts/data/model_download_utils.dart:1-57]
- INV-0148: [REF: lib/features/tts/data/piper_model_download_service.dart:1-146]
- INV-0149: [REF: lib/features/tts/data/piper_native_bindings.dart:1-95]
- INV-0150: [REF: lib/features/tts/data/piper_tts_engine.dart:1-99]
- INV-0151: [REF: lib/features/tts/data/segment_player.dart:1-131]
- INV-0152: [REF: lib/features/tts/data/text_segmenter.dart:1-218]
- INV-0153: [REF: lib/features/tts/data/tts_adapters.dart:1-37]
- INV-0154: [REF: lib/features/tts/data/tts_audio_database.dart:1-138]
- INV-0155: [REF: lib/features/tts/data/tts_audio_export_service.dart:1-204]
- INV-0156: [REF: lib/features/tts/data/tts_audio_repository.dart:1-228]
- INV-0157: [REF: lib/features/tts/data/tts_dictionary_database.dart:1-45]
- INV-0158: [REF: lib/features/tts/data/tts_dictionary_repository.dart:1-122]
- INV-0159: [REF: lib/features/tts/data/tts_edit_controller.dart:1-472]
- INV-0160: [REF: lib/features/tts/data/tts_edit_segment.dart:1-62]
- INV-0161: [REF: lib/features/tts/data/tts_engine.dart:1-300]
- INV-0162: [REF: lib/features/tts/data/tts_engine_type.dart:1-8]
- INV-0163: [REF: lib/features/tts/data/tts_isolate.dart:1-541]
- INV-0164: [REF: lib/features/tts/data/tts_language.dart:1-22]
- INV-0165: [REF: lib/features/tts/data/tts_model_download_service.dart:1-102]
- INV-0166: [REF: lib/features/tts/data/tts_model_size.dart:1-14]
- INV-0167: [REF: lib/features/tts/data/tts_native_bindings.dart:1-230]
- INV-0168: [REF: lib/features/tts/data/tts_playback_controller.dart:1-12]
- INV-0169: [REF: lib/features/tts/data/tts_session.dart:1-205]
- INV-0170: [REF: lib/features/tts/data/tts_streaming_controller.dart:1-389]
- INV-0171: [REF: lib/features/tts/data/tts_toggle.dart:1-27]
- INV-0172: [REF: lib/features/tts/data/voice_recording_service.dart:1-65]
- INV-0173: [REF: lib/features/tts/data/voice_reference_service.dart:1-105]
- INV-0174: [REF: lib/features/tts/data/wav_writer.dart:1-80]
- INV-0175: [REF: lib/features/tts/domain/_row_helpers.dart:1-13]
- INV-0176: [REF: lib/features/tts/domain/tts_engine_config.dart:1-167]
- INV-0177: [REF: lib/features/tts/domain/tts_episode.dart:1-40]
- INV-0178: [REF: lib/features/tts/domain/tts_episode_status.dart:1-15]
- INV-0179: [REF: lib/features/tts/domain/tts_ref_wav_resolver.dart:1-19]
- INV-0180: [REF: lib/features/tts/domain/tts_segment.dart:1-56]
- INV-0181: [REF: lib/features/tts/presentation/dictionary_context_menu.dart:1-81]
- INV-0182: [REF: lib/features/tts/presentation/tts_dictionary_dialog.dart:1-199]
- INV-0183: [REF: lib/features/tts/presentation/tts_edit_dialog.dart:1-694]
- INV-0184: [REF: lib/features/tts/presentation/voice_recording_dialog.dart:1-385]
- INV-0185: [REF: lib/features/tts/providers/piper_model_download_providers.dart:1-111]
- INV-0186: [REF: lib/features/tts/providers/text_segmenter_provider.dart:1-12]
- INV-0187: [REF: lib/features/tts/providers/tts_audio_database_provider.dart:1-27]
- INV-0188: [REF: lib/features/tts/providers/tts_audio_state_provider.dart:1-52]
- INV-0189: [REF: lib/features/tts/providers/tts_edit_providers.dart:1-73]
- INV-0190: [REF: lib/features/tts/providers/tts_export_providers.dart:1-96]
- INV-0191: [REF: lib/features/tts/providers/tts_model_download_providers.dart:1-107]
- INV-0192: [REF: lib/features/tts/providers/tts_playback_providers.dart:1-94]
- INV-0193: [REF: lib/features/tts/providers/tts_settings_providers.dart:1-205]
- INV-0194: [REF: lib/features/tts/providers/vacuum_lifecycle_provider.dart:1-92]
- INV-0195: [REF: lib/home_screen.dart:1-357]
- INV-0196: [REF: lib/l10n/app_localizations.dart:1-1728]
- INV-0197: [REF: lib/l10n/app_localizations_en.dart:1-903]
- INV-0198: [REF: lib/l10n/app_localizations_ja.dart:1-886]
- INV-0199: [REF: lib/l10n/app_localizations_zh.dart:1-884]
- INV-0200: [REF: lib/main.dart:1-77]
- INV-0201: [REF: lib/shared/database/database_closing_exception.dart:1-15]
- INV-0202: [REF: lib/shared/database/database_opener.dart:1-63]
- INV-0203: [REF: lib/shared/database/db_connection_gate.dart:1-91]
- INV-0204: [REF: lib/shared/database/folder_db_handles.dart:1-37]
- INV-0205: [REF: lib/shared/database/folder_db_key.dart:1-21]
- INV-0206: [REF: lib/shared/database/novel_data_database.dart:1-107]
- INV-0207: [REF: lib/shared/database/novel_data_database_provider.dart:1-16]
- INV-0208: [REF: lib/shared/database/per_folder_db_registry.dart:1-164]
- INV-0209: [REF: lib/shared/database/per_folder_db_registry_provider.dart:1-12]
- INV-0210: [REF: lib/shared/episode/episode_resolver.dart:1-130]
- INV-0211: [REF: lib/shared/logging/app_logger.dart:1-83]
- INV-0212: [REF: lib/shared/logging/file_log_sink.dart:1-97]
- INV-0213: [REF: lib/shared/logging/log_sink.dart:1-9]
- INV-0214: [REF: lib/shared/providers/layout_providers.dart:1-13]
- INV-0215: [REF: lib/shared/utils/cancellation_token.dart:1-53]
- INV-0216: [REF: lib/shared/utils/content_hash.dart:1-6]
- INV-0217: [REF: lib/shared/utils/file_name_utils.dart:1-25]
- INV-0218: [REF: lib/shared/utils/novel_id_resolver.dart:1-62]
- INV-0219: [REF: lib/shared/utils/temp_directory_utils.dart:1-17]
- INV-0220: [REF: linux/CMakeLists.txt:1-128]
- INV-0221: [REF: linux/runner/main.cc:1-6]
- INV-0222: [REF: macos/Runner/AppDelegate.swift:1-13]
- INV-0223: [REF: pubspec.yaml:1-127]
- INV-0224: [REF: scripts/benchmark_tts.sh:1-289]
- INV-0225: [REF: scripts/build_lame_macos.sh:1-30]
- INV-0226: [REF: scripts/build_lame_windows.bat:1-23]
- INV-0227: [REF: scripts/build_piper_macos.sh:1-53]
- INV-0228: [REF: scripts/build_piper_windows.bat:1-36]
- INV-0229: [REF: scripts/build_tts_macos.sh:1-44]
- INV-0230: [REF: scripts/build_tts_windows.bat:1-36]
- INV-0231: [REF: scripts/clean.bat:1-12]
- INV-0232: [REF: scripts/clean.sh:1-8]
- INV-0233: [REF: scripts/release.ps1:1-91]
- INV-0234: [REF: scripts/release.sh:1-92]
- INV-0235: [REF: scripts/test/release_test.ps1:1-107]
- INV-0236: [REF: scripts/test/release_test.sh:1-88]
- INV-0237: [REF: scripts/test/verify_release_version_test.sh:1-43]
- INV-0238: [REF: scripts/verify_release_version.sh:1-46]
- INV-0239: [REF: test/app_test.dart:1-57]
- INV-0240: [REF: test/app/reading_progress_wiring_test.dart:1-183]
- INV-0241: [REF: test/app/selected_file_progress_title_provider_test.dart:1-156]
- INV-0242: [REF: test/app/startup_migrations_test.dart:1-64]
- INV-0243: [REF: test/features/app_update/data/distribution_detector_test.dart:1-104]
- INV-0244: [REF: test/features/app_update/data/github_release_client_test.dart:1-128]
- INV-0245: [REF: test/features/app_update/data/installer_downloader_test.dart:1-68]
- INV-0246: [REF: test/features/app_update/data/installer_updater_test.dart:1-197]
- INV-0247: [REF: test/features/app_update/data/installer_verifier_test.dart:1-124]
- INV-0248: [REF: test/features/app_update/data/registry_reader_test.dart:1-47]
- INV-0249: [REF: test/features/app_update/data/update_preferences_test.dart:1-53]
- INV-0250: [REF: test/features/app_update/domain/update_check_service_test.dart:1-167]
- INV-0251: [REF: test/features/app_update/domain/version_comparator_test.dart:1-41]
- INV-0252: [REF: test/features/app_update/presentation/update_badge_test.dart:1-44]
- INV-0253: [REF: test/features/app_update/presentation/update_dialog_test.dart:1-156]
- INV-0254: [REF: test/features/bookmark/bookmark_providers_test.dart:1-307]
- INV-0255: [REF: test/features/bookmark/bookmark_repository_test.dart:1-211]
- INV-0256: [REF: test/features/bookmark/presentation/bookmark_appbar_test.dart:1-202]
- INV-0257: [REF: test/features/bookmark/presentation/bookmark_list_panel_test.dart:1-317]
- INV-0258: [REF: test/features/bookmark/presentation/left_column_panel_test.dart:1-152]
- INV-0259: [REF: test/features/episode_cache/data/episode_cache_database_test.dart:1-92]
- INV-0260: [REF: test/features/episode_cache/data/episode_cache_repository_test.dart:1-143]
- INV-0261: [REF: test/features/episode_cache/domain/episode_cache_test.dart:1-74]
- INV-0262: [REF: test/features/episode_navigation/providers/adjacent_files_provider_test.dart:1-149]
- INV-0263: [REF: test/features/episode_navigation/providers/episode_navigation_controller_test.dart:1-131]
- INV-0264: [REF: test/features/episode_navigation/providers/pending_file_entry_intent_provider_test.dart:1-58]
- INV-0265: [REF: test/features/file_browser/data/download_destination_folders_test.dart:1-119]
- INV-0266: [REF: test/features/file_browser/data/file_system_service_test.dart:1-409]
- INV-0267: [REF: test/features/file_browser/domain/move_destination_test.dart:1-82]
- INV-0268: [REF: test/features/file_browser/domain/move_follow_test.dart:1-47]
- INV-0269: [REF: test/features/file_browser/domain/novel_folder_classifier_test.dart:1-30]
- INV-0270: [REF: test/features/file_browser/domain/reading_progress_badge_test.dart:1-69]
- INV-0271: [REF: test/features/file_browser/presentation/file_browser_folder_ops_test.dart:1-318]
- INV-0272: [REF: test/features/file_browser/presentation/file_browser_handle_release_order_test.dart:1-251]
- INV-0273: [REF: test/features/file_browser/presentation/file_browser_panel_test.dart:1-1140]
- INV-0274: [REF: test/features/file_browser/presentation/move_destination_dialog_test.dart:1-88]
- INV-0275: [REF: test/features/file_browser/presentation/refresh_invalidate_test.dart:1-86]
- INV-0276: [REF: test/features/file_browser/presentation/refresh_progress_dialog_test.dart:1-157]
- INV-0277: [REF: test/features/file_browser/presentation/rename_title_dialog_test.dart:1-204]
- INV-0278: [REF: test/features/file_browser/providers/directory_contents_title_mapping_test.dart:1-86]
- INV-0279: [REF: test/features/file_browser/providers/directory_contents_tts_status_test.dart:1-125]
- INV-0280: [REF: test/features/file_browser/providers/download_destination_folders_provider_test.dart:1-104]
- INV-0281: [REF: test/features/file_browser/providers/folder_switch_handle_release_test.dart:1-73]
- INV-0282: [REF: test/features/file_browser/providers/reading_progress_badge_provider_test.dart:1-157]
- INV-0283: [REF: test/features/file_browser/providers/selected_novel_title_provider_test.dart:1-155]
- INV-0284: [REF: test/features/keyboard_shortcuts/data/focus_utils_test.dart:1-43]
- INV-0285: [REF: test/features/keyboard_shortcuts/data/key_binding_label_test.dart:1-30]
- INV-0286: [REF: test/features/keyboard_shortcuts/data/shortcut_action_test.dart:1-53]
- INV-0287: [REF: test/features/keyboard_shortcuts/data/shortcut_bindings_test.dart:1-114]
- INV-0288: [REF: test/features/keyboard_shortcuts/presentation/shortcut_settings_section_test.dart:1-153]
- INV-0289: [REF: test/features/keyboard_shortcuts/providers/keyboard_shortcut_providers_test.dart:1-94]
- INV-0290: [REF: test/features/llm_summary/data/analysis_write_after_close_test.dart:1-53]
- INV-0291: [REF: test/features/llm_summary/data/context_chunker_test.dart:1-60]
- INV-0292: [REF: test/features/llm_summary/data/fact_cache_repository_test.dart:1-168]
- INV-0293: [REF: test/features/llm_summary/data/llm_client_test.dart:1-541]
- INV-0294: [REF: test/features/llm_summary/data/llm_prompt_builder_test.dart:1-136]
- INV-0295: [REF: test/features/llm_summary/data/llm_summary_pipeline_per_file_test.dart:1-323]
- INV-0296: [REF: test/features/llm_summary/data/llm_summary_repository_test.dart:1-281]
- INV-0297: [REF: test/features/llm_summary/data/llm_summary_service_cache_test.dart:1-342]
- INV-0298: [REF: test/features/llm_summary/data/llm_summary_service_test.dart:1-427]
- INV-0299: [REF: test/features/llm_summary/data/v5_migration_test.dart:1-317]
- INV-0300: [REF: test/features/llm_summary/domain/analysis_progress_test.dart:1-53]
- INV-0301: [REF: test/features/llm_summary/domain/fact_cache_validity_test.dart:1-92]
- INV-0302: [REF: test/features/llm_summary/domain/first_line_containing_test.dart:1-55]
- INV-0303: [REF: test/features/llm_summary/domain/history_entry_test.dart:1-235]
- INV-0304: [REF: test/features/llm_summary/domain/llm_config_test.dart:1-80]
- INV-0305: [REF: test/features/llm_summary/domain/llm_summary_result_test.dart:1-106]
- INV-0306: [REF: test/features/llm_summary/domain/mark_matcher_test.dart:1-120]
- INV-0307: [REF: test/features/llm_summary/presentation/analysis_runner_test.dart:1-638]
- INV-0308: [REF: test/features/llm_summary/presentation/hover_popup_anchor_test.dart:1-146]
- INV-0309: [REF: test/features/llm_summary/presentation/hover_popup_e2e_test.dart:1-61]
- INV-0310: [REF: test/features/llm_summary/presentation/hover_popup_host_test.dart:1-204]
- INV-0311: [REF: test/features/llm_summary/presentation/hover_popup_widget_test.dart:1-320]
- INV-0312: [REF: test/features/llm_summary/presentation/llm_summary_detail_dialog_test.dart:1-213]
- INV-0313: [REF: test/features/llm_summary/presentation/llm_summary_history_menu_test.dart:1-172]
- INV-0314: [REF: test/features/llm_summary/presentation/llm_summary_history_panel_test.dart:1-132]
- INV-0315: [REF: test/features/llm_summary/providers/hover_popup_cache_provider_test.dart:1-136]
- INV-0316: [REF: test/features/llm_summary/providers/hover_popup_provider_test.dart:1-429]
- INV-0317: [REF: test/features/llm_summary/providers/llm_summary_history_provider_test.dart:1-393]
- INV-0318: [REF: test/features/llm_summary/providers/llm_summary_providers_test.dart:1-228]
- INV-0319: [REF: test/features/llm_summary/providers/marked_words_provider_test.dart:1-101]
- INV-0320: [REF: test/features/llm_summary/providers/ollama_model_list_provider_test.dart:1-161]
- INV-0321: [REF: test/features/novel_delete/data/novel_delete_order_test.dart:1-133]
- INV-0322: [REF: test/features/novel_delete/data/novel_delete_service_test.dart:1-220]
- INV-0323: [REF: test/features/novel_metadata_db/data/novel_database_migration_full_chain_test.dart:1-101]
- INV-0324: [REF: test/features/novel_metadata_db/data/novel_database_migration_v4_test.dart:1-169]
- INV-0325: [REF: test/features/novel_metadata_db/data/novel_database_migration_v6_test.dart:1-179]
- INV-0326: [REF: test/features/novel_metadata_db/data/novel_database_migration_v7_test.dart:1-149]
- INV-0327: [REF: test/features/novel_metadata_db/data/novel_database_migration_v8_test.dart:1-348]
- INV-0328: [REF: test/features/novel_metadata_db/data/novel_database_migration_v9_test.dart:1-284]
- INV-0329: [REF: test/features/novel_metadata_db/data/schema_fidelity_test.dart:1-69]
- INV-0330: [REF: test/features/novel_metadata_db/novel_database_test.dart:1-49]
- INV-0331: [REF: test/features/novel_metadata_db/novel_repository_test.dart:1-195]
- INV-0332: [REF: test/features/reading_progress/data/reading_progress_repository_test.dart:1-207]
- INV-0333: [REF: test/features/reading_progress/domain/reading_progress_test.dart:1-58]
- INV-0334: [REF: test/features/reading_progress/providers/reading_progress_listeners_test.dart:1-636]
- INV-0335: [REF: test/features/reading_progress/providers/reading_progress_providers_test.dart:1-53]
- INV-0336: [REF: test/features/settings/data/font_family_test.dart:1-109]
- INV-0337: [REF: test/features/settings/data/settings_repository_shortcuts_test.dart:1-57]
- INV-0338: [REF: test/features/settings/data/settings_repository_test.dart:1-388]
- INV-0339: [REF: test/features/settings/presentation/llm_settings_test.dart:1-278]
- INV-0340: [REF: test/features/settings/presentation/settings_dialog_phase_a_test.dart:1-166]
- INV-0341: [REF: test/features/settings/presentation/settings_dialog_tabs_test.dart:1-139]
- INV-0342: [REF: test/features/settings/presentation/settings_dialog_test.dart:1-170]
- INV-0343: [REF: test/features/settings/presentation/settings_piper_l10n_test.dart:1-56]
- INV-0344: [REF: test/features/settings/presentation/settings_test.dart:1-50]
- INV-0345: [REF: test/features/settings/presentation/tts_model_download_ui_test.dart:1-164]
- INV-0346: [REF: test/features/settings/presentation/voice_reference_selector_test.dart:1-306]
- INV-0347: [REF: test/features/settings/providers/settings_providers_test.dart:1-227]
- INV-0348: [REF: test/features/text_download/aozora_site_test.dart:1-252]
- INV-0349: [REF: test/features/text_download/collection_download_test.dart:1-300]
- INV-0350: [REF: test/features/text_download/download_cancellation_test.dart:1-143]
- INV-0351: [REF: test/features/text_download/download_dialog_cancel_truncate_test.dart:1-120]
- INV-0352: [REF: test/features/text_download/download_dialog_destination_test.dart:1-134]
- INV-0353: [REF: test/features/text_download/download_dialog_test.dart:1-273]
- INV-0354: [REF: test/features/text_download/download_provider_state_test.dart:1-354]
- INV-0355: [REF: test/features/text_download/download_release_handle_test.dart:1-122]
- INV-0356: [REF: test/features/text_download/download_service_test.dart:1-207]
- INV-0357: [REF: test/features/text_download/empty_index_guard_test.dart:1-109]
- INV-0358: [REF: test/features/text_download/empty_parse_failure_test.dart:1-206]
- INV-0359: [REF: test/features/text_download/episode_filename_pad_migration_test.dart:1-297]
- INV-0360: [REF: test/features/text_download/file_browser_refresh_test.dart:1-62]
- INV-0361: [REF: test/features/text_download/file_naming_test.dart:1-55]
- INV-0362: [REF: test/features/text_download/generic_web_site_test.dart:1-277]
- INV-0363: [REF: test/features/text_download/hameln_site_test.dart:1-420]
- INV-0364: [REF: test/features/text_download/helpers/download_test_helpers.dart:1-278]
- INV-0365: [REF: test/features/text_download/incremental_download_test.dart:1-929]
- INV-0366: [REF: test/features/text_download/index_fixture_parsing_test.dart:1-83]
- INV-0367: [REF: test/features/text_download/index_truncated_test.dart:1-148]
- INV-0368: [REF: test/features/text_download/kakuyomu_site_test.dart:1-685]
- INV-0369: [REF: test/features/text_download/narou_site_test.dart:1-523]
- INV-0370: [REF: test/features/text_download/novel_library_service_test.dart:1-59]
- INV-0371: [REF: test/features/text_download/novel_site_test.dart:1-137]
- INV-0372: [REF: test/features/text_download/refresh_novel_test.dart:1-178]
- INV-0373: [REF: test/features/text_download/request_timeout_test.dart:1-81]
- INV-0374: [REF: test/features/text_download/transient_retry_test.dart:1-323]
- INV-0375: [REF: test/features/text_download/url_validation_test.dart:1-133]
- INV-0376: [REF: test/features/text_download/user_agent_precedence_test.dart:1-52]
- INV-0377: [REF: test/features/text_search/data/search_models_test.dart:1-43]
- INV-0378: [REF: test/features/text_search/data/text_search_service_test.dart:1-187]
- INV-0379: [REF: test/features/text_search/presentation/search_results_panel_test.dart:1-630]
- INV-0380: [REF: test/features/text_search/providers/text_search_providers_test.dart:1-242]
- INV-0381: [REF: test/features/text_viewer/data/column_splitter_test.dart:1-251]
- INV-0382: [REF: test/features/text_viewer/data/kinsoku_test.dart:1-136]
- INV-0383: [REF: test/features/text_viewer/data/parsed_segments_cache_test.dart:1-93]
- INV-0384: [REF: test/features/text_viewer/data/swipe_detection_test.dart:1-64]
- INV-0385: [REF: test/features/text_viewer/data/text_file_reader_test.dart:1-46]
- INV-0386: [REF: test/features/text_viewer/data/vertical_char_map_test.dart:1-156]
- INV-0387: [REF: test/features/text_viewer/data/vertical_marked_ranges_test.dart:1-346]
- INV-0388: [REF: test/features/text_viewer/data/vertical_text_layout_test.dart:1-242]
- INV-0389: [REF: test/features/text_viewer/presentation/horizontal_edge_episode_nav_test.dart:1-334]
- INV-0390: [REF: test/features/text_viewer/presentation/horizontal_page_scroll_test.dart:1-74]
- INV-0391: [REF: test/features/text_viewer/presentation/resolve_viewer_effects_test.dart:1-220]
- INV-0392: [REF: test/features/text_viewer/presentation/text_viewer_font_test.dart:1-159]
- INV-0393: [REF: test/features/text_viewer/presentation/text_viewer_panel_test.dart:1-575]
- INV-0394: [REF: test/features/text_viewer/presentation/text_viewer_tts_delete_confirmation_test.dart:1-153]
- INV-0395: [REF: test/features/text_viewer/presentation/tts_auto_page_test.dart:1-89]
- INV-0396: [REF: test/features/text_viewer/presentation/tts_auto_scroll_test.dart:1-63]
- INV-0397: [REF: test/features/text_viewer/presentation/tts_export_button_test.dart:1-195]
- INV-0398: [REF: test/features/text_viewer/presentation/tts_highlight_horizontal_test.dart:1-105]
- INV-0399: [REF: test/features/text_viewer/presentation/tts_highlight_page_offset_test.dart:1-230]
- INV-0400: [REF: test/features/text_viewer/presentation/tts_highlight_vertical_test.dart:1-152]
- INV-0401: [REF: test/features/text_viewer/presentation/vertical_ruby_text_widget_test.dart:1-222]
- INV-0402: [REF: test/features/text_viewer/presentation/vertical_text_page_hover_test.dart:1-407]
- INV-0403: [REF: test/features/text_viewer/presentation/vertical_text_page_mark_scan_test.dart:1-59]
- INV-0404: [REF: test/features/text_viewer/presentation/vertical_text_page_memoization_test.dart:1-167]
- INV-0405: [REF: test/features/text_viewer/presentation/vertical_text_page_test.dart:1-571]
- INV-0406: [REF: test/features/text_viewer/presentation/vertical_text_pagination_font_test.dart:1-505]
- INV-0407: [REF: test/features/text_viewer/presentation/vertical_text_viewer_animation_test.dart:1-355]
- INV-0408: [REF: test/features/text_viewer/presentation/vertical_text_viewer_episode_nav_test.dart:1-399]
- INV-0409: [REF: test/features/text_viewer/presentation/vertical_text_viewer_hover_test.dart:1-188]
- INV-0410: [REF: test/features/text_viewer/presentation/vertical_text_viewer_initial_page_test.dart:1-146]
- INV-0411: [REF: test/features/text_viewer/presentation/vertical_text_viewer_memoization_test.dart:1-194]
- INV-0412: [REF: test/features/text_viewer/presentation/vertical_text_viewer_pagination_test.dart:1-198]
- INV-0413: [REF: test/features/text_viewer/presentation/vertical_text_viewer_swipe_test.dart:1-327]
- INV-0414: [REF: test/features/text_viewer/presentation/vertical_text_viewer_test.dart:1-149]
- INV-0415: [REF: test/features/text_viewer/presentation/vertical_text_viewer_wheel_test.dart:1-199]
- INV-0416: [REF: test/features/text_viewer/presentation/widgets/text_content_renderer_intent_test.dart:1-334]
- INV-0417: [REF: test/features/text_viewer/presentation/widgets/text_content_renderer_test.dart:1-582]
- INV-0418: [REF: test/features/text_viewer/presentation/widgets/tts_controls_bar_test.dart:1-218]
- INV-0419: [REF: test/features/text_viewer/presentation/widgets/vertical_context_menu_test.dart:1-116]
- INV-0420: [REF: test/features/text_viewer/providers/selected_text_provider_test.dart:1-43]
- INV-0421: [REF: test/features/text_viewer/ruby_text_parser_test.dart:1-237]
- INV-0422: [REF: test/features/text_viewer/ruby_text_spans_hover_test.dart:1-155]
- INV-0423: [REF: test/features/text_viewer/ruby_text_spans_test.dart:1-313]
- INV-0424: [REF: test/features/text_viewer/text_segment_test.dart:1-62]
- INV-0425: [REF: test/features/tts/data/lame_enc_bindings_test.dart:1-107]
- INV-0426: [REF: test/features/tts/data/piper_model_download_service_test.dart:1-76]
- INV-0427: [REF: test/features/tts/data/piper_tts_engine_test.dart:1-205]
- INV-0428: [REF: test/features/tts/data/segment_player_test.dart:1-206]
- INV-0429: [REF: test/features/tts/data/text_segmenter_test.dart:1-472]
- INV-0430: [REF: test/features/tts/data/tts_adapters_test.dart:1-12]
- INV-0431: [REF: test/features/tts/data/tts_audio_database_test.dart:1-624]
- INV-0432: [REF: test/features/tts/data/tts_audio_export_service_test.dart:1-178]
- INV-0433: [REF: test/features/tts/data/tts_audio_repository_test.dart:1-689]
- INV-0434: [REF: test/features/tts/data/tts_dictionary_repository_test.dart:1-169]
- INV-0435: [REF: test/features/tts/data/tts_edit_controller_test.dart:1-2328]
- INV-0436: [REF: test/features/tts/data/tts_edit_segment_test.dart:1-158]
- INV-0437: [REF: test/features/tts/data/tts_engine_embedding_cache_test.dart:1-361]
- INV-0438: [REF: test/features/tts/data/tts_engine_test.dart:1-293]
- INV-0439: [REF: test/features/tts/data/tts_isolate_test.dart:1-329]
- INV-0440: [REF: test/features/tts/data/tts_language_test.dart:1-36]
- INV-0441: [REF: test/features/tts/data/tts_model_download_service_test.dart:1-377]
- INV-0442: [REF: test/features/tts/data/tts_model_size_test.dart:1-34]
- INV-0443: [REF: test/features/tts/data/tts_native_bindings_test.dart:1-46]
- INV-0444: [REF: test/features/tts/data/tts_session_test.dart:1-587]
- INV-0445: [REF: test/features/tts/data/tts_streaming_controller_test.dart:1-1586]
- INV-0446: [REF: test/features/tts/data/tts_toggle_test.dart:1-48]
- INV-0447: [REF: test/features/tts/data/voice_recording_service_test.dart:1-166]
- INV-0448: [REF: test/features/tts/data/voice_reference_service_test.dart:1-307]
- INV-0449: [REF: test/features/tts/data/wav_writer_test.dart:1-117]
- INV-0450: [REF: test/features/tts/domain/tts_engine_config_test.dart:1-192]
- INV-0451: [REF: test/features/tts/domain/tts_episode_status_test.dart:1-53]
- INV-0452: [REF: test/features/tts/domain/tts_episode_test.dart:1-104]
- INV-0453: [REF: test/features/tts/domain/tts_ref_wav_resolver_test.dart:1-65]
- INV-0454: [REF: test/features/tts/domain/tts_segment_test.dart:1-98]
- INV-0455: [REF: test/features/tts/presentation/dictionary_context_menu_test.dart:1-334]
- INV-0456: [REF: test/features/tts/presentation/tts_dictionary_dialog_test.dart:1-103]
- INV-0457: [REF: test/features/tts/providers/text_segmenter_provider_test.dart:1-20]
- INV-0458: [REF: test/features/tts/providers/tts_audio_database_provider_test.dart:1-100]
- INV-0459: [REF: test/features/tts/providers/tts_audio_state_provider_test.dart:1-126]
- INV-0460: [REF: test/features/tts/providers/tts_model_download_providers_test.dart:1-209]
- INV-0461: [REF: test/features/tts/providers/tts_playback_state_test.dart:1-139]
- INV-0462: [REF: test/features/tts/providers/tts_settings_providers_test.dart:1-316]
- INV-0463: [REF: test/features/tts/providers/vacuum_lifecycle_provider_test.dart:1-94]
- INV-0464: [REF: test/helpers/localized_material_app.dart:1-23]
- INV-0465: [REF: test/helpers/novel_data_db_fixture.dart:1-26]
- INV-0466: [REF: test/helpers/novel_metadata_db_fixture.dart:1-36]
- INV-0467: [REF: test/home_screen_dynamic_shortcuts_test.dart:1-65]
- INV-0468: [REF: test/home_screen_pane_focus_test.dart:1-95]
- INV-0469: [REF: test/home_screen_test.dart:1-656]
- INV-0470: [REF: test/home_screen_tts_shortcut_test.dart:1-123]
- INV-0471: [REF: test/shared/database/database_opener_test.dart:1-130]
- INV-0472: [REF: test/shared/database/db_connection_gate_test.dart:1-144]
- INV-0473: [REF: test/shared/database/folder_db_handles_test.dart:1-135]
- INV-0474: [REF: test/shared/database/folder_db_key_test.dart:1-46]
- INV-0475: [REF: test/shared/database/novel_data_database_test.dart:1-176]
- INV-0476: [REF: test/shared/database/per_folder_db_registry_test.dart:1-243]
- INV-0477: [REF: test/shared/episode/episode_resolver_test.dart:1-189]
- INV-0478: [REF: test/shared/logging/app_logger_test.dart:1-165]
- INV-0479: [REF: test/shared/logging/file_log_sink_test.dart:1-139]
- INV-0480: [REF: test/shared/providers/layout_providers_test.dart:1-31]
- INV-0481: [REF: test/shared/utils/cancellation_token_test.dart:1-42]
- INV-0482: [REF: test/shared/utils/content_hash_test.dart:1-21]
- INV-0483: [REF: test/shared/utils/novel_id_resolver_test.dart:1-101]
- INV-0484: [REF: test/shared/utils/temp_directory_utils_test.dart:1-64]
- INV-0485: [REF: test/test_utils/flutter_secure_storage_mock.dart:1-65]
- INV-0486: [REF: test/widget_test.dart:1-31]
- INV-0487: [REF: windows/CMakeLists.txt:1-113]
- INV-0488: [REF: windows/runner/main.cpp:1-43]

## Detail questions raised in this chapter

- None

## Sources Read

- `../inventory.json`
- `../source-map.json`
- `../wbs.json`
