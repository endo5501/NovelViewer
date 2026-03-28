// ignore_for_file: prefer_function_declarations_over_variables, overridden_fields

import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/tts/data/tts_engine.dart';
import 'package:novel_viewer/features/tts/data/tts_native_bindings.dart';

/// Mock bindings that track embedding cache-related calls.
class MockEmbeddingBindings extends TtsNativeBindings {
  MockEmbeddingBindings() : super(DynamicLibrary.process());

  // Track calls
  int extractCallCount = 0;
  int synthesizeWithEmbeddingCallCount = 0;
  int synthesizeWithVoiceCallCount = 0;
  int saveCallCount = 0;
  int loadCallCount = 0;
  int freeCallCount = 0;

  // Control behavior
  int extractResult = 0;
  int synthesizeWithEmbeddingResult = 0;
  int saveResult = 0;
  int loadResult = 0;

  // Simulated embedding data (1024 floats)
  static const embeddingSize = 1024;

  // Fake context setup
  Pointer<Void> _fakeCtx = nullptr;
  int _isLoadedResult = 0;

  void setFakeContext(Pointer<Void> ctx, {bool loaded = true}) {
    _fakeCtx = ctx;
    _isLoadedResult = loaded ? 1 : 0;
  }

  @override
  late final Pointer<Void> Function(Pointer<Utf8>, int) init =
      (Pointer<Utf8> modelDir, int nThreads) => _fakeCtx;

  @override
  late final int Function(Pointer<Void>) isLoaded =
      (Pointer<Void> ctx) => _isLoadedResult;

  @override
  late final void Function(Pointer<Void>) free = (Pointer<Void> ctx) {};

  @override
  late final Pointer<Float> Function(Pointer<Void>) getAudio =
      (Pointer<Void> ctx) {
    // Return a small valid audio buffer
    final ptr = calloc<Float>(10);
    for (var i = 0; i < 10; i++) {
      ptr[i] = 0.0;
    }
    return ptr;
  };

  @override
  late final int Function(Pointer<Void>) getAudioLength =
      (Pointer<Void> ctx) => 10;

  @override
  late final int Function(Pointer<Void>) getSampleRate =
      (Pointer<Void> ctx) => 24000;

  @override
  late final Pointer<Utf8> Function(Pointer<Void>) getError =
      (Pointer<Void> ctx) => 'mock error'.toNativeUtf8();

  @override
  late final int Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>)
      synthesizeWithVoice =
      (Pointer<Void> ctx, Pointer<Utf8> text, Pointer<Utf8> wav) {
    synthesizeWithVoiceCallCount++;
    return 0;
  };

  @override
  late final int Function(
    Pointer<Void>,
    Pointer<Utf8>,
    Pointer<Pointer<Float>>,
    Pointer<Int32>,
  ) extractSpeakerEmbedding = (
    Pointer<Void> ctx,
    Pointer<Utf8> path,
    Pointer<Pointer<Float>> outData,
    Pointer<Int32> outSize,
  ) {
    extractCallCount++;
    if (extractResult != 0) return extractResult;
    // Allocate and fill mock embedding
    final ptr = calloc<Float>(embeddingSize);
    for (var i = 0; i < embeddingSize; i++) {
      ptr[i] = (i + 1).toDouble() / embeddingSize;
    }
    outData.value = ptr;
    outSize.value = embeddingSize;
    return 0;
  };

  @override
  late final int Function(Pointer<Void>, Pointer<Utf8>, Pointer<Float>, int)
      synthesizeWithEmbedding = (
    Pointer<Void> ctx,
    Pointer<Utf8> text,
    Pointer<Float> embData,
    int embSize,
  ) {
    synthesizeWithEmbeddingCallCount++;
    return synthesizeWithEmbeddingResult;
  };

  @override
  late final int Function(Pointer<Utf8>, Pointer<Float>, int)
      saveSpeakerEmbedding = (
    Pointer<Utf8> path,
    Pointer<Float> data,
    int size,
  ) {
    saveCallCount++;
    if (saveResult != 0) return saveResult;
    // Actually write the file so cache hit detection works
    final filePath = path.toDartString();
    final bytes = data.cast<Uint8>().asTypedList(size * 4);
    File(filePath).writeAsBytesSync(bytes);
    return 0;
  };

  @override
  late final int Function(
    Pointer<Utf8>,
    Pointer<Pointer<Float>>,
    Pointer<Int32>,
  ) loadSpeakerEmbedding = (
    Pointer<Utf8> path,
    Pointer<Pointer<Float>> outData,
    Pointer<Int32> outSize,
  ) {
    loadCallCount++;
    if (loadResult != 0) return loadResult;
    // Read from actual file (written by save mock)
    final filePath = path.toDartString();
    final file = File(filePath);
    if (!file.existsSync()) return -1;
    final bytes = file.readAsBytesSync();
    if (bytes.length % 4 != 0) return -1;
    final nFloats = bytes.length ~/ 4;
    final ptr = calloc<Float>(nFloats);
    ptr.cast<Uint8>().asTypedList(bytes.length).setAll(0, bytes);
    outData.value = ptr;
    outSize.value = nFloats;
    return 0;
  };

  @override
  late final void Function(Pointer<Float>) freeSpeakerEmbedding =
      (Pointer<Float> data) {
    freeCallCount++;
    calloc.free(data);
  };
}

void main() {
  group('TtsEngine - embedding cache', () {
    late MockEmbeddingBindings mockBindings;
    late TtsEngine engine;
    late Directory tempDir;

    setUp(() {
      mockBindings = MockEmbeddingBindings();
      engine = TtsEngine(mockBindings);

      final fakeCtx = Pointer<Void>.fromAddress(0x1234);
      mockBindings.setFakeContext(fakeCtx);
      engine.loadModel('/fake/model/dir');

      tempDir = Directory.systemTemp.createTempSync('tts_cache_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('cache miss: extracts embedding, saves cache, then synthesizes', () {
      // Create a fake ref audio file
      final refFile = File('${tempDir.path}/voice.wav');
      refFile.writeAsBytesSync(List.filled(100, 0));

      final cacheDir = '${tempDir.path}/cache/embeddings';

      engine.synthesizeWithVoiceCached(
        'hello',
        refFile.path,
        embeddingCacheDir: cacheDir,
      );

      // Should extract (cache miss) then synthesize with embedding
      expect(mockBindings.extractCallCount, 1);
      expect(mockBindings.saveCallCount, 1);
      expect(mockBindings.synthesizeWithEmbeddingCallCount, 1);
      // Should NOT call the old synthesizeWithVoice
      expect(mockBindings.synthesizeWithVoiceCallCount, 0);
      // Cache file should exist
      final cacheFiles = Directory(cacheDir).listSync();
      expect(cacheFiles, hasLength(1));
      expect(cacheFiles.first.path, endsWith('.emb'));
    });

    test('cache hit: loads cached embedding and synthesizes without extraction',
        () {
      final refFile = File('${tempDir.path}/voice.wav');
      refFile.writeAsBytesSync(List.filled(100, 0));
      final cacheDir = '${tempDir.path}/cache/embeddings';

      // First call: cache miss
      engine.synthesizeWithVoiceCached(
        'hello',
        refFile.path,
        embeddingCacheDir: cacheDir,
      );

      // Reset counters
      mockBindings.extractCallCount = 0;
      mockBindings.saveCallCount = 0;
      mockBindings.synthesizeWithEmbeddingCallCount = 0;
      mockBindings.loadCallCount = 0;

      // Second call: cache hit
      engine.synthesizeWithVoiceCached(
        'world',
        refFile.path,
        embeddingCacheDir: cacheDir,
      );

      expect(mockBindings.extractCallCount, 0);
      expect(mockBindings.loadCallCount, 1);
      expect(mockBindings.synthesizeWithEmbeddingCallCount, 1);
      expect(mockBindings.saveCallCount, 0);
    });

    test('corrupted cache file triggers re-extraction', () {
      final refFile = File('${tempDir.path}/voice.wav');
      refFile.writeAsBytesSync(List.filled(100, 0));
      final cacheDir = '${tempDir.path}/cache/embeddings';

      // First call to create cache
      engine.synthesizeWithVoiceCached(
        'hello',
        refFile.path,
        embeddingCacheDir: cacheDir,
      );

      // Corrupt the cache file (wrong size)
      final cacheFiles = Directory(cacheDir).listSync();
      final cacheFile = cacheFiles.first as File;
      cacheFile.writeAsBytesSync(List.filled(100, 0)); // Wrong size

      // Reset counters
      mockBindings.extractCallCount = 0;
      mockBindings.saveCallCount = 0;
      mockBindings.synthesizeWithEmbeddingCallCount = 0;
      mockBindings.loadCallCount = 0;
      // Make load fail (file exists but wrong size)
      mockBindings.loadResult = -1;

      // Should re-extract
      engine.synthesizeWithVoiceCached(
        'hello',
        refFile.path,
        embeddingCacheDir: cacheDir,
      );

      expect(mockBindings.extractCallCount, 1);
      expect(mockBindings.saveCallCount, 1);
      expect(mockBindings.synthesizeWithEmbeddingCallCount, 1);
    });

    test('different ref audio files get different cache keys', () {
      final refFile1 = File('${tempDir.path}/voice1.wav');
      refFile1.writeAsBytesSync(List.filled(100, 1));
      final refFile2 = File('${tempDir.path}/voice2.wav');
      refFile2.writeAsBytesSync(List.filled(100, 2));
      final cacheDir = '${tempDir.path}/cache/embeddings';

      engine.synthesizeWithVoiceCached(
        'hello',
        refFile1.path,
        embeddingCacheDir: cacheDir,
      );
      engine.synthesizeWithVoiceCached(
        'hello',
        refFile2.path,
        embeddingCacheDir: cacheDir,
      );

      // Both should extract (different hashes)
      expect(mockBindings.extractCallCount, 2);
      // Two different cache files
      final cacheFiles = Directory(cacheDir).listSync();
      expect(cacheFiles, hasLength(2));
    });

    test('cache directory is auto-created if it does not exist', () {
      final refFile = File('${tempDir.path}/voice.wav');
      refFile.writeAsBytesSync(List.filled(100, 0));
      final cacheDir = '${tempDir.path}/deep/nested/cache/embeddings';

      expect(Directory(cacheDir).existsSync(), isFalse);

      engine.synthesizeWithVoiceCached(
        'hello',
        refFile.path,
        embeddingCacheDir: cacheDir,
      );

      expect(Directory(cacheDir).existsSync(), isTrue);
    });

    test('changed file content at same path causes cache miss', () {
      final refFile = File('${tempDir.path}/voice.wav');
      refFile.writeAsBytesSync(List.filled(100, 1));
      final cacheDir = '${tempDir.path}/cache/embeddings';

      // First call
      engine.synthesizeWithVoiceCached(
        'hello',
        refFile.path,
        embeddingCacheDir: cacheDir,
      );

      // Change file content
      refFile.writeAsBytesSync(List.filled(100, 2));

      // Reset counters
      mockBindings.extractCallCount = 0;
      mockBindings.saveCallCount = 0;

      // Second call — different content, should be cache miss
      engine.synthesizeWithVoiceCached(
        'hello',
        refFile.path,
        embeddingCacheDir: cacheDir,
      );

      expect(mockBindings.extractCallCount, 1);
      expect(mockBindings.saveCallCount, 1);
    });
  });
}
