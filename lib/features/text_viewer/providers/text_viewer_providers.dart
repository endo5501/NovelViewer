import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/file_browser/providers/file_browser_providers.dart';
import 'package:novel_viewer/features/text_viewer/data/text_file_reader.dart';
import 'package:novel_viewer/features/text_viewer/data/viewer_selection.dart';

// Re-exported so consumers of the provider get the state type with it.
export 'package:novel_viewer/features/text_viewer/data/viewer_selection.dart';

final textFileReaderProvider = Provider<TextFileReader>((ref) {
  return TextFileReader();
});

/// Holds the current viewer selection, or `null` when nothing is selected.
///
/// Consumers that only need the text read `ref.read(selectedTextProvider)?.text`.
class SelectedTextNotifier extends Notifier<ViewerSelection?> {
  @override
  ViewerSelection? build() => null;

  void setSelection(ViewerSelection? selection) => state = selection;
}

final selectedTextProvider =
    NotifierProvider<SelectedTextNotifier, ViewerSelection?>(
        SelectedTextNotifier.new);

final fileContentProvider = FutureProvider<String?>((ref) async {
  final selectedFile = ref.watch(selectedFileProvider);
  if (selectedFile == null) return null;

  final reader = ref.watch(textFileReaderProvider);
  return reader.readFile(selectedFile.path);
});
