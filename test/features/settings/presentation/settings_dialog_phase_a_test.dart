import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/settings/presentation/settings_dialog.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:novel_viewer/features/tts/data/tts_engine_type.dart';
import 'package:novel_viewer/features/tts/providers/tts_settings_providers.dart';
import 'package:novel_viewer/l10n/app_localizations.dart';

import '../../../test_utils/flutter_secure_storage_mock.dart';

/// Phase A baseline tests covering behaviors not asserted by the existing
/// settings widget tests: engine SegmentedButton, Piper section, drag-drop
/// file ingestion.
void main() {
  late SharedPreferences prefs;
  late Directory tempDir;
  late FlutterSecureStorageMock secureStorageMock;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tempDir = Directory.systemTemp.createTempSync('settings_phase_a_');
    Directory(p.join(tempDir.path, 'NovelViewer')).createSync();
    secureStorageMock = FlutterSecureStorageMock();
    secureStorageMock.install();
  });

  tearDown(() {
    secureStorageMock.uninstall();
    tempDir.deleteSync(recursive: true);
  });

  Widget buildTestWidget() {
    final libraryPath = p.join(tempDir.path, 'NovelViewer');
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        libraryPathProvider.overrideWithValue(libraryPath),
      ],
      child: const MaterialApp(
        locale: Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(width: 800, height: 600, child: SettingsDialog()),
        ),
      ),
    );
  }

  Future<void> openTtsTab(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.runAsync(() async {
      await tester.pumpWidget(buildTestWidget());
    });
    await tester.pumpAndSettle();
    await tester.tap(find.text('読み上げ'));
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();
  }

  group('Engine selector (Phase A 2.8)', () {
    testWidgets('shows SegmentedButton with Qwen3 and Piper segments',
        (tester) async {
      await openTtsTab(tester);

      expect(find.byType(SegmentedButton<TtsEngineType>), findsOneWidget);
      expect(find.text('Qwen3-TTS'), findsOneWidget);
      expect(find.text('Piper'), findsOneWidget);
    });

    testWidgets('switching to Piper updates the provider', (tester) async {
      await openTtsTab(tester);

      await tester.tap(find.text('Piper'));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(SettingsDialog)),
      );
      expect(container.read(ttsEngineTypeProvider), TtsEngineType.piper);
    });
  });

  group('Piper section (Phase A 2.10)', () {
    Future<void> selectPiperEngine(WidgetTester tester) async {
      await openTtsTab(tester);
      await tester.tap(find.text('Piper'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows model dropdown when Piper is selected', (tester) async {
      await selectPiperEngine(tester);

      // The Piper model dropdown should be visible
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
      // Model label - currently a Japanese literal (will be migrated in Phase B)
      expect(find.text('モデル'), findsOneWidget);
    });

    testWidgets('shows three synthesis-parameter sliders', (tester) async {
      await selectPiperEngine(tester);

      // Three sliders for lengthScale / noiseScale / noiseW
      expect(find.byType(Slider), findsNWidgets(3));
      expect(find.textContaining('速度'), findsOneWidget);
      expect(find.textContaining('抑揚'), findsOneWidget);
      expect(find.textContaining('ノイズ'), findsOneWidget);
    });

    testWidgets('shows download button in idle state', (tester) async {
      await selectPiperEngine(tester);

      expect(find.text('モデルデータダウンロード'), findsOneWidget);
    });
  });

  group('Drag-drop ingestion (Phase A 2.12)', () {
    testWidgets('dropping audio files into voice reference target ingests them',
        (tester) async {
      await openTtsTab(tester);

      // Prepare a source audio file outside the voices dir
      final src = File(p.join(tempDir.path, 'dropped.wav'));
      src.writeAsStringSync('fake-audio');

      // Locate the DropTarget and dispatch the drop event
      final dropTarget = find.byType(DropTarget);
      expect(dropTarget, findsOneWidget);
      final widget = tester.widget<DropTarget>(dropTarget);
      await tester.runAsync(() async {
        widget.onDragDone?.call(
          DropDoneDetails(
            files: [DropItemFile(src.path)],
            localPosition: Offset.zero,
            globalPosition: Offset.zero,
          ),
        );
        await Future.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle();

      final voicesDir = Directory(p.join(tempDir.path, 'voices'));
      final ingested = File(p.join(voicesDir.path, 'dropped.wav'));
      expect(ingested.existsSync(), isTrue,
          reason: 'dropped audio file should be copied into the voices dir');
    });
  });
}
