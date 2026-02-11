import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/text_viewer/data/text_file_reader.dart';

final textFileReaderProvider = Provider<TextFileReader>((ref) {
  return TextFileReader();
});

final fileContentProvider = FutureProvider<String?>((ref) async {
  final selectedFile = ref.watch(selectedFileProvider);
  if (selectedFile == null) return null;

  final reader = ref.watch(textFileReaderProvider);
  return reader.readFile(selectedFile.path);
});
