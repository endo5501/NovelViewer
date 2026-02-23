import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/tts_engine.dart';
import 'package:novel_viewer/features/tts/data/tts_isolate.dart';
import 'package:novel_viewer/features/tts/data/tts_playback_controller.dart';
import 'package:novel_viewer/features/tts/providers/tts_playback_providers.dart';
import 'package:novel_viewer/features/tts/providers/tts_settings_providers.dart';
import 'package:novel_viewer/features/text_viewer/presentation/text_viewer_panel.dart';
import 'package:novel_viewer/features/text_viewer/providers/text_viewer_providers.dart';
import 'package:novel_viewer/features/settings/providers/settings_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Fake TtsIsolate for testing
class _FakeTtsIsolate implements TtsIsolate {
  final _responseController =
      StreamController<TtsIsolateResponse>.broadcast();

  @override
  Stream<TtsIsolateResponse> get responses => _responseController.stream;

  @override
  Future<void> spawn() async {}

  @override
  void loadModel(String modelDir, {int nThreads = 4, int languageId = TtsEngine.languageJapanese}) {
    Future.microtask(() {
      _responseController.add(ModelLoadedResponse(success: true));
    });
  }

  @override
  void synthesize(String text, {String? refWavPath}) {
    Future.microtask(() {
      _responseController.add(SynthesisResultResponse(
        audio: Float32List.fromList([0.1, 0.2, 0.3]),
        sampleRate: 24000,
      ));
    });
  }

  @override
  Future<void> dispose() async {
    _responseController.close();
  }
}

class _FakeAudioPlayer implements TtsAudioPlayer {
  final _stateController = StreamController<TtsPlayerState>.broadcast();

  @override
  Stream<TtsPlayerState> get playerStateStream => _stateController.stream;

  @override
  Future<void> setFilePath(String path) async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {
    await _stateController.close();
  }
}

class _FakeWavWriter implements TtsWavWriter {
  @override
  Future<void> write({
    required String path,
    required Float32List audio,
    required int sampleRate,
  }) async {}
}

class _FakeFileCleaner implements TtsFileCleaner {
  @override
  Future<void> deleteFile(String path) async {}
}

class _FixedStringNotifier extends TtsModelDirNotifier {
  _FixedStringNotifier(this._value);
  final String _value;

  @override
  String build() => _value;
}

Future<TtsPlaybackController> _fakeControllerFactory(
    ProviderContainer container) async {
  return TtsPlaybackController(
    ref: container,
    ttsIsolate: _FakeTtsIsolate(),
    audioPlayer: _FakeAudioPlayer(),
    wavWriter: _FakeWavWriter(),
    fileCleaner: _FakeFileCleaner(),
    tempDirPath: '/tmp/tts_test',
  );
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        fileContentProvider.overrideWith((ref) async => 'テスト文章です。'),
        ttsModelDirProvider
            .overrideWith(() => _FixedStringNotifier('/models')),
        ttsControllerFactoryProvider
            .overrideWithValue(_fakeControllerFactory),
      ],
      child: const MaterialApp(home: Scaffold(body: TextViewerPanel())),
    );
  }

  group('TTS button wiring', () {
    testWidgets('play button tap changes state to loading or playing',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Use runAsync to handle the async _startTts chain
      await tester.runAsync(() async {
        await tester.tap(find.byIcon(Icons.play_arrow));
        // Allow async chain to complete
        await Future.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      final element = tester.element(find.byType(TextViewerPanel));
      final container = ProviderScope.containerOf(element);
      final state = container.read(ttsPlaybackStateProvider);
      expect(state, isNot(TtsPlaybackState.stopped));
    });

    testWidgets('stop button tap stops active playback', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Start playback first
      await tester.runAsync(() async {
        await tester.tap(find.byIcon(Icons.play_arrow));
        await Future.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      final element = tester.element(find.byType(TextViewerPanel));
      final container = ProviderScope.containerOf(element);
      expect(container.read(ttsPlaybackStateProvider),
          isNot(TtsPlaybackState.stopped));

      // Now tap stop
      await tester.runAsync(() async {
        await tester.tap(find.byIcon(Icons.stop));
        await Future.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      expect(container.read(ttsPlaybackStateProvider),
          TtsPlaybackState.stopped);
      expect(container.read(ttsHighlightRangeProvider), isNull);
    });

    testWidgets('stop button works even without active controller',
        (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Manually set state to playing (no controller created)
      final element = tester.element(find.byType(TextViewerPanel));
      final container = ProviderScope.containerOf(element);
      container
          .read(ttsPlaybackStateProvider.notifier)
          .set(TtsPlaybackState.playing);
      await tester.pump();

      // Tap the stop button
      await tester.runAsync(() async {
        await tester.tap(find.byIcon(Icons.stop));
        await Future.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      expect(container.read(ttsPlaybackStateProvider),
          TtsPlaybackState.stopped);
    });
  });
}
