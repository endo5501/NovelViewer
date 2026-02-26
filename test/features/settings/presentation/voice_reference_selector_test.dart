import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/settings/presentation/settings_dialog.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:path/path.dart' as p;

void main() {
  late SharedPreferences prefs;
  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tempDir = Directory.systemTemp.createTempSync('voice_ref_ui_test_');
    Directory(p.join(tempDir.path, 'NovelViewer')).createSync();
  });

  tearDown(() {
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
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: SettingsDialog(),
          ),
        ),
      ),
    );
  }

  Future<void> navigateToTtsTab(WidgetTester tester) async {
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
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
  }

  group('Voice reference selector', () {
    testWidgets('displays voice reference dropdown on TTS tab', (tester) async {
      await navigateToTtsTab(tester);

      expect(find.text('リファレンス音声ファイル'), findsOneWidget);
      expect(find.text('なし（デフォルト音声）'), findsOneWidget);
    });

    testWidgets('shows hint when voices directory is empty', (tester) async {
      await navigateToTtsTab(tester);

      expect(find.text('なし（デフォルト音声）'), findsOneWidget);
    });

    testWidgets('lists audio files from voices directory', (tester) async {
      final voicesDir = Directory(p.join(tempDir.path, 'voices'));
      voicesDir.createSync();
      File(p.join(voicesDir.path, 'narrator.mp3')).writeAsStringSync('');
      File(p.join(voicesDir.path, 'sample.wav')).writeAsStringSync('');

      await navigateToTtsTab(tester);

      // Open dropdown - tap the current value text to open
      final dropdown = find.byType(DropdownButtonFormField<String>);
      expect(dropdown, findsOneWidget);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();

      // Dropdown items appear in an overlay
      expect(find.text('narrator.mp3'), findsWidgets);
      expect(find.text('sample.wav'), findsWidgets);
    });

    testWidgets('displays folder open and refresh buttons', (tester) async {
      await navigateToTtsTab(tester);

      expect(find.byTooltip('voicesフォルダを開く'), findsOneWidget);
      expect(find.byTooltip('ファイル一覧を更新'), findsOneWidget);
    });

    testWidgets('refresh button rescans voices directory', (tester) async {
      await navigateToTtsTab(tester);

      // Add a file to voices dir
      final voicesDir = Directory(p.join(tempDir.path, 'voices'));
      if (!voicesDir.existsSync()) voicesDir.createSync();
      File(p.join(voicesDir.path, 'test_voice.wav')).writeAsStringSync('');

      // Tap refresh inside runAsync so file I/O completes
      await tester.runAsync(() async {
        await tester.tap(find.byTooltip('ファイル一覧を更新'));
        await tester.pump();
        await Future.delayed(const Duration(milliseconds: 200));
      });
      await tester.pumpAndSettle();

      // Open dropdown
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      expect(find.text('test_voice.wav'), findsWidgets);
    });

    testWidgets('selecting a file persists the file name', (tester) async {
      final voicesDir = Directory(p.join(tempDir.path, 'voices'));
      voicesDir.createSync();
      File(p.join(voicesDir.path, 'my_voice.wav')).writeAsStringSync('');

      await navigateToTtsTab(tester);

      // Open dropdown and select file
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('my_voice.wav').last);
      await tester.pumpAndSettle();

      expect(prefs.getString('tts_ref_wav_path'), 'my_voice.wav');
    });

    testWidgets('shows default when saved file no longer exists',
        (tester) async {
      await prefs.setString('tts_ref_wav_path', 'deleted_file.wav');
      Directory(p.join(tempDir.path, 'voices')).createSync();

      await navigateToTtsTab(tester);

      expect(find.text('なし（デフォルト音声）'), findsOneWidget);
    });
  });
}
