import 'package:path/path.dart' as p;

/// Canonicalizes a folder path for use as a per-folder database family key
/// (e.g. for `episodeCacheDatabaseProvider`, `ttsAudioDatabaseProvider`,
/// `ttsDictionaryDatabaseProvider`).
///
/// Riverpod `family` providers are keyed by the exact argument string, so the
/// same folder spelled with different separators resolves to *different*
/// cached handles. That is the root cause of the "novel cannot be deleted"
/// bug: the download flow opened `episode_cache.db` under a forward-slash path
/// (`'$outputPath/$folderName'`) while the file browser releases handles using
/// the platform (backslash) path. The two keys never matched, so the open
/// SQLite connection was never closed and kept the file locked on Windows.
///
/// Uses the platform path context: on Windows `p.normalize` treats both `/`
/// and `\` as separators and canonicalizes to `\`, so the download's
/// forward-slash path and the browser's backslash path collapse to one key. On
/// POSIX it normalizes `/` paths as usual (a `\` is a legal filename character
/// there, so it is deliberately NOT treated as a separator). The result is a
/// native path, safe to hand back to `p.join`/file APIs.
String folderDbKey(String folderPath) => p.normalize(folderPath);
