import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';

final fileSystemServiceProvider = Provider<FileSystemService>((ref) {
  return FileSystemService();
});

class CurrentDirectoryNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setDirectory(String path) => state = path;
}

final currentDirectoryProvider =
    NotifierProvider<CurrentDirectoryNotifier, String?>(
        CurrentDirectoryNotifier.new);

final directoryContentsProvider =
    FutureProvider<DirectoryContents>((ref) async {
  final dirPath = ref.watch(currentDirectoryProvider);
  if (dirPath == null) {
    return DirectoryContents.empty();
  }

  final service = ref.watch(fileSystemServiceProvider);
  final files = await service.listTextFiles(dirPath);
  final sortedFiles = service.sortByNumericPrefix(files);
  final subdirectories = await service.listSubdirectories(dirPath);

  return DirectoryContents(
    files: sortedFiles,
    subdirectories: subdirectories,
  );
});

class SelectedFileNotifier extends Notifier<FileEntry?> {
  @override
  FileEntry? build() => null;

  void selectFile(FileEntry file) => state = file;
  void clear() => state = null;
}

final selectedFileProvider =
    NotifierProvider<SelectedFileNotifier, FileEntry?>(
        SelectedFileNotifier.new);

class DirectoryContents {
  final List<FileEntry> files;
  final List<DirectoryEntry> subdirectories;

  const DirectoryContents({
    required this.files,
    required this.subdirectories,
  });

  factory DirectoryContents.empty() =>
      const DirectoryContents(files: [], subdirectories: []);

  bool get isEmpty => files.isEmpty && subdirectories.isEmpty;
}
