import 'package:novel_viewer/features/novel_metadata_db/data/novel_repository.dart';
import 'package:novel_viewer/features/llm_summary/data/llm_summary_repository.dart';
import 'package:novel_viewer/features/file_browser/data/file_system_service.dart';

class NovelDeleteService {
  final NovelRepository novelRepository;
  final LlmSummaryRepository summaryRepository;
  final FileSystemService fileSystemService;

  NovelDeleteService({
    required this.novelRepository,
    required this.summaryRepository,
    required this.fileSystemService,
  });

  Future<void> delete(String folderName, String directoryPath) async {
    await novelRepository.deleteByFolderName(folderName);
    await summaryRepository.deleteByFolderName(folderName);
    await fileSystemService.deleteDirectory(directoryPath);
  }
}
