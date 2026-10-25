import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation_models_llm/foundation_models_llm.dart';
import 'package:novel_viewer/features/app_update/providers/update_providers.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/llm_summary/providers/on_device_llm_providers.dart';
import 'package:novel_viewer/features/progress_sync/data/oauth/progress_sync_auth.dart';
import 'package:novel_viewer/features/progress_sync/data/progress_sync_service.dart';
import 'package:novel_viewer/features/progress_sync/providers/progress_sync_config_providers.dart';
import 'package:novel_viewer/features/progress_sync/providers/progress_sync_settings_providers.dart';
import 'package:novel_viewer/features/settings/presentation/sections/irodori_settings_section.dart';
import 'package:novel_viewer/features/settings/presentation/sections/piper_settings_section.dart';
import 'package:novel_viewer/features/settings/presentation/sections/voice_reference_section.dart';
import 'package:novel_viewer/features/settings/presentation/settings_dialog.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/tts/providers/irodori_model_download_providers.dart';
import 'package:novel_viewer/features/tts/providers/piper_model_download_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';
import 'package:novel_viewer/shared/platform/platform_capabilities.dart';
import 'package:novel_viewer/shared/providers/platform_capabilities_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/phone_display.dart';
import '../test_utils/flutter_secure_storage_mock.dart';

/// Answers the availability query with a reason the section explains in a
/// paragraph, so the general tab carries its longest LLM content.
class _IntelligenceOffPlugin implements FoundationModelsLlm {
  @override
  Future<OnDeviceModelAvailability> availability() async =>
      OnDeviceModelAvailability.intelligenceNotEnabled;

  @override
  Future<String> generate({
    required String prompt,
    String? schemaFieldName,
    int? maxResponseTokens,
    OnDeviceSampling? sampling,
    String? experimentFieldPattern,
    bool? experimentIncludeSchemaInPrompt,
  }) async => throw UnimplementedError();
}

class _ParkedPiperDownload extends PiperModelDownloadNotifier {
  _ParkedPiperDownload(this._state);
  final PiperModelDownloadState _state;
  @override
  PiperModelDownloadState build() => _state;
}

class _ParkedIrodoriDownload extends IrodoriModelDownloadNotifier {
  _ParkedIrodoriDownload(this._state);
  final IrodoriModelDownloadState _state;
  @override
  IrodoriModelDownloadState build() => _state;
}

/// The settings dialog on the portrait display of an iPhone 16, configured as
/// it is on iOS (spec adaptive-shell-layout: every dialog and every settings
/// tab fits, and the dialog's actions are reachable).
void main() {
  const iOS = PlatformCapabilities.forPlatform(isIOS: true, isMacOS: false);

  // The container path iOS hands the app, which the "downloaded" line shows.
  const iosModelsDir =
      '/var/mobile/Containers/Data/Application/'
      '3F2A9C1E-7B4D-4E8A-9C21-0D5E6F7A8B9C/Documents/NovelViewer/models';
  const longVoiceFile = '朗読用リファレンス音声_落ち着いた女性ナレーター_第三版_二〇二六年十月収録.wav';
  const longEmail =
      'very.long.reader.name.for.progress.sync.testing@example-mail.co.jp';
  const longSyncError =
      'Google ドライブとの通信に失敗しました。ネットワーク接続を確認してから、もう一度お試しください（HTTP 503 Service Unavailable）';
  const longDownloadError =
      'モデルファイルのダウンロードに失敗しました: SocketException: Connection reset by peer '
      '(OS Error: Connection reset by peer, errno = 54), address = huggingface.co, port = 443';

  late SharedPreferences prefs;
  late Directory tempDir;
  late FlutterSecureStorageMock secureStorageMock;
  late AppLocalizations ja;

  setUpAll(() async {
    ja = await AppLocalizations.delegate.load(const Locale('ja'));
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tempDir = Directory.systemTemp.createTempSync('settings_phone_test_');
    Directory(p.join(tempDir.path, 'NovelViewer')).createSync();
    secureStorageMock = FlutterSecureStorageMock();
    secureStorageMock.install();
  });

  tearDown(() {
    secureStorageMock.uninstall();
    tempDir.deleteSync(recursive: true);
  });

  Future<void> openSettings(
    WidgetTester tester, {
    SyncAccountState account = const SyncAccountState.signedOut(),
    SyncRunStatus syncStatus = const SyncRunStatus(),
    PiperModelDownloadState? piperDownload,
    IrodoriModelDownloadState? irodoriDownload,
    IrodoriLegacyAssets? legacyAssets,
  }) async {
    usePhoneDisplay(tester);
    await tester.runAsync(() async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            libraryPathProvider.overrideWithValue(
              p.join(tempDir.path, 'NovelViewer'),
            ),
            platformCapabilitiesProvider.overrideWithValue(iOS),
            foundationModelsLlmProvider.overrideWithValue(
              _IntelligenceOffPlugin(),
            ),
            progressSyncAvailableProvider.overrideWithValue(true),
            syncAccountStateProvider.overrideWithValue(account),
            syncRunStatusProvider.overrideWithValue(syncStatus),
            packageInfoProvider.overrideWithValue(
              PackageInfo(
                appName: 'NovelViewer',
                packageName: 'com.endo5501.novelViewer',
                version: '1.8.4',
                buildNumber: '19',
              ),
            ),
            if (piperDownload != null)
              piperModelDownloadProvider.overrideWith(
                () => _ParkedPiperDownload(piperDownload),
              ),
            if (irodoriDownload != null)
              irodoriModelDownloadProvider.overrideWith(
                () => _ParkedIrodoriDownload(irodoriDownload),
              ),
            if (legacyAssets != null)
              irodoriLegacyAssetsProvider.overrideWithValue(legacyAssets),
          ],
          child: MaterialApp(
            locale: const Locale('ja'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => SettingsDialog.show(context),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Future<void> scrollToEnd(WidgetTester tester) async {
    final scrollables = find.descendant(
      of: find.byType(TabBarView),
      matching: find.byType(Scrollable),
    );
    for (final element in scrollables.evaluate().toList()) {
      final state = (element as StatefulElement).state as ScrollableState;
      if (state.axisDirection != AxisDirection.down) continue;
      state.position.jumpTo(state.position.maxScrollExtent);
      await tester.pumpAndSettle();
    }
  }

  /// Selects [label]'s tab, lets file I/O started by the tab's sections land,
  /// and scrolls the tab to its end so content further down is laid out.
  Future<void> selectTab(WidgetTester tester, String label) async {
    final tab = find.descendant(
      of: find.byType(TabBar),
      matching: find.text(label),
    );
    // The tab bar scrolls on a phone, so a tab can start out of view, where a
    // tap would land on the barrier and close the dialog.
    await tester.ensureVisible(tab);
    await tester.pumpAndSettle();
    await tester.tap(tab);
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
    await scrollToEnd(tester);
  }

  Future<void> selectEngine(WidgetTester tester, String engine) async {
    await tester.ensureVisible(find.text(engine));
    await tester.pumpAndSettle();
    // The voice-reference section lists the voices folder when it mounts;
    // that real file I/O only lands outside the fake clock.
    await tester.runAsync(() async {
      await tester.tap(find.text(engine));
      await tester.pumpAndSettle();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    await scrollToEnd(tester);
  }

  /// The area of the display the reader can reach: inside the safe area.
  const reachable = Rect.fromLTRB(
    0,
    kPhoneTopInset,
    393,
    852 - kPhoneBottomInset,
  );

  void expectCloseReachable(WidgetTester tester) {
    final close = find.widgetWithText(TextButton, ja.common_closeButton);
    expect(close, findsOneWidget);
    final rect = tester.getRect(close);
    expect(
      reachable.contains(rect.topLeft) &&
          reachable.contains(rect.bottomRight - const Offset(0.01, 0.01)),
      isTrue,
      reason: 'the close button at $rect is outside $reachable',
    );
  }

  group('settings dialog on an iPhone', () {
    testWidgets('lists every tab, iOS configuration', (tester) async {
      await openSettings(tester);

      final tabs = tester.widget<TabBar>(find.byType(TabBar)).tabs;
      expect(tabs.length, 4);
    });

    testWidgets('shows every tab label whole', (tester) async {
      await openSettings(tester);

      final tabTexts = find.descendant(
        of: find.byType(TabBar),
        matching: find.byType(Text),
      );
      expect(tabTexts, findsNWidgets(4));
      // A tab label does not wrap; one too long for its tab is faded out at
      // the end, which the paragraph reports as an overflow shader.
      final cutOff = [
        for (final element in tabTexts.evaluate())
          if ((element.renderObject! as RenderParagraph)
                  .debugHasOverflowShader ||
              (element.renderObject! as RenderParagraph).didExceedMaxLines)
            '"${(element.widget as Text).data}" '
                '(${tester.getSize(find.byWidget(element.widget)).width} px wide)',
      ];
      expect(cutOff, isEmpty, reason: 'these tab labels are cut off');
    });

    testWidgets('the dialog fits inside the safe area', (tester) async {
      await openSettings(tester);

      // The AlertDialog spans the whole route, inset padding included; its
      // card is what shows.
      final dialog = tester.getRect(
        find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(
        reachable.contains(dialog.topLeft) &&
            reachable.contains(dialog.bottomRight - const Offset(0.01, 0.01)),
        isTrue,
        reason: 'the dialog at $dialog is outside $reachable',
      );
      expectCloseReachable(tester);
    });

    testWidgets('the general tab fits, scrolled to its end', (tester) async {
      await openSettings(tester);
      await selectTab(tester, ja.settings_generalTabLabel);

      expectCloseReachable(tester);
    });

    testWidgets('the TTS tab fits with Piper', (tester) async {
      await openSettings(tester);
      await selectTab(tester, ja.settings_ttsTabLabel);
      await selectEngine(tester, 'Piper');

      expect(find.byType(PiperSettingsSection), findsOneWidget);
      expectCloseReachable(tester);
    });

    testWidgets('the TTS tab fits with Piper downloaded', (tester) async {
      await openSettings(
        tester,
        piperDownload: const PiperModelDownloadCompleted(
          modelsDir: iosModelsDir,
        ),
      );
      await selectTab(tester, ja.settings_ttsTabLabel);
      await selectEngine(tester, 'Piper');

      expect(find.byType(PiperSettingsSection), findsOneWidget);
    });

    testWidgets('the TTS tab fits with a Piper download error', (tester) async {
      await openSettings(
        tester,
        piperDownload: const PiperModelDownloadError(longDownloadError),
      );
      await selectTab(tester, ja.settings_ttsTabLabel);
      await selectEngine(tester, 'Piper');

      expect(find.text(longDownloadError), findsOneWidget);
    });

    testWidgets('the TTS tab fits with Piper downloading', (tester) async {
      await openSettings(
        tester,
        piperDownload: const PiperModelDownloadDownloading(
          currentFile: 'ja_JP-tsukuyomi-chan-medium-multilingual.onnx',
          progress: 0.42,
        ),
      );
      await selectTab(tester, ja.settings_ttsTabLabel);
      await selectEngine(tester, 'Piper');

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('the TTS tab fits with Irodori-TTS', (tester) async {
      await openSettings(tester);
      await selectTab(tester, ja.settings_ttsTabLabel);
      await selectEngine(tester, 'Irodori-TTS');

      expect(find.byType(IrodoriSettingsSection), findsOneWidget);
      expect(find.byType(VoiceReferenceSection), findsOneWidget);
      expectCloseReachable(tester);
    });

    testWidgets('the TTS tab fits with Irodori-TTS, a long voice file '
        'selected, legacy assets and a download error', (tester) async {
      final voicesDir = Directory(p.join(tempDir.path, 'voices'))..createSync();
      File(p.join(voicesDir.path, longVoiceFile)).writeAsStringSync('');
      await prefs.setString('tts_ref_wav_path', longVoiceFile);

      await openSettings(
        tester,
        irodoriDownload: const IrodoriModelDownloadError(longDownloadError),
        legacyAssets: (present: true, bytes: 2904288926),
      );
      await selectTab(tester, ja.settings_ttsTabLabel);
      await selectEngine(tester, 'Irodori-TTS');

      expect(find.byTooltip(ja.settings_renameFileTooltip), findsOneWidget);
      expect(find.text(longDownloadError), findsOneWidget);
    });

    testWidgets('the TTS tab fits with Irodori-TTS downloaded', (tester) async {
      await openSettings(
        tester,
        irodoriDownload: const IrodoriModelDownloadCompleted(
          modelsDir: iosModelsDir,
        ),
      );
      await selectTab(tester, ja.settings_ttsTabLabel);
      await selectEngine(tester, 'Irodori-TTS');

      expect(find.byType(IrodoriSettingsSection), findsOneWidget);
    });

    testWidgets('the TTS tab fits with Irodori-TTS downloading', (
      tester,
    ) async {
      await openSettings(
        tester,
        irodoriDownload: const IrodoriModelDownloadDownloading(
          currentFile: 'irodori-tts-v4.1-small-mf-f16.gguf',
          progress: 0.73,
        ),
      );
      await selectTab(tester, ja.settings_ttsTabLabel);
      await selectEngine(tester, 'Irodori-TTS');

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('the sync tab fits signed out', (tester) async {
      await openSettings(tester);
      await selectTab(tester, ja.syncSettings_tab);

      expectCloseReachable(tester);
    });

    testWidgets('the sync tab fits signed in with a long account and error', (
      tester,
    ) async {
      await openSettings(
        tester,
        account: const SyncAccountState.signedIn(longEmail),
        syncStatus: SyncRunStatus(
          lastSuccessAt: DateTime(2026, 10, 24, 21, 15),
          lastError: longSyncError,
        ),
      );
      await selectTab(tester, ja.syncSettings_tab);

      expect(find.textContaining(longEmail), findsOneWidget);
      expectCloseReachable(tester);
    });

    testWidgets('the sync tab fits when it needs a new sign-in', (
      tester,
    ) async {
      await openSettings(
        tester,
        account: const SyncAccountState.needsReauth(longEmail),
      );
      await selectTab(tester, ja.syncSettings_tab);

      expect(find.textContaining(longEmail), findsOneWidget);
    });

    testWidgets('every tab fits with the keyboard up', (tester) async {
      await openSettings(tester);
      showPhoneKeyboard(tester);
      await tester.pumpAndSettle();

      for (final label in [
        ja.settings_generalTabLabel,
        ja.settings_ttsTabLabel,
        ja.syncSettings_tab,
        ja.settings_aboutUpdateTab,
      ]) {
        await selectTab(tester, label);
        final close = tester.getRect(
          find.widgetWithText(TextButton, ja.common_closeButton),
        );
        expect(
          close.bottom,
          lessThanOrEqualTo(852 - kPhoneKeyboardHeight),
          reason:
              'on "$label" the close button at $close is under the keyboard',
        );
      }
    });

    testWidgets('the about tab fits', (tester) async {
      await openSettings(tester);
      await selectTab(tester, ja.settings_aboutUpdateTab);

      expectCloseReachable(tester);
    });
  });
}
