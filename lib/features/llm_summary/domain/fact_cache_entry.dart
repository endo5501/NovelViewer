/// One cached Stage-1 fact-extraction result for a single
/// `(word, file, model)` inside a novel's `novel_data.db`. The novel identity
/// is conveyed by which folder's database the row lives in, so no
/// `folder_name` column is stored. Reused on later analyses by the same model
/// when still valid (see `isFactCacheValid`).
///
/// The model belongs in the key rather than only in the validity check, so
/// each model keeps its own shelf: a reader moving between an on-device model
/// and a server one finds the earlier extractions still there on returning,
/// and no run ever assembles facts from two models at once.
class FactCacheEntry {
  final String word;
  final String fileName;
  final String facts;
  final String contentHash;
  final int promptVersion;

  /// Names the model that produced [facts]. Part of the row's key, so a row
  /// written by another model is not a stale entry to refresh but a row on a
  /// different shelf.
  final String modelId;

  final DateTime updatedAt;

  const FactCacheEntry({
    required this.word,
    required this.fileName,
    required this.facts,
    required this.contentHash,
    required this.promptVersion,
    required this.modelId,
    required this.updatedAt,
  });

  factory FactCacheEntry.fromMap(Map<String, Object?> map) {
    return FactCacheEntry(
      word: map['word'] as String,
      fileName: map['file_name'] as String,
      facts: map['facts'] as String,
      contentHash: map['content_hash'] as String,
      promptVersion: map['prompt_version'] as int,
      modelId: map['model_id'] as String,
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}

/// A cache row is reusable only when it exists, carries a non-sentinel hash
/// that equals the file's current content hash, and was produced by the
/// current extraction-prompt version. Any other case is a miss, forcing a
/// fresh extraction. The empty-string sentinel is rejected up-front so an
/// unreadable file (whose `currentHash` may also be empty) never yields a hit.
bool isFactCacheValid(
  FactCacheEntry? entry, {
  required String currentHash,
  required int currentPromptVersion,
}) {
  if (entry == null) return false;
  if (entry.contentHash.isEmpty) return false;
  if (entry.contentHash != currentHash) return false;
  if (entry.promptVersion != currentPromptVersion) return false;
  return true;
}
