import 'tts_dictionary_database.dart';

class TtsDictionaryEntry {
  const TtsDictionaryEntry({
    required this.id,
    required this.surface,
    required this.reading,
  });

  final int id;
  final String surface;
  final String reading;
}

class TtsDictionaryRepository {
  final TtsDictionaryDatabase _database;

  TtsDictionaryRepository(this._database);

  Future<int> addEntry(String surface, String reading) async {
    if (surface.isEmpty) throw ArgumentError('surface must not be empty');
    if (reading.isEmpty) throw ArgumentError('reading must not be empty');
    final db = await _database.database;
    return db.insert('tts_dictionary', {
      'surface': surface,
      'reading': reading,
    });
  }

  Future<List<TtsDictionaryEntry>> getAllEntries() async {
    final db = await _database.database;
    final rows = await db.query('tts_dictionary', orderBy: 'id ASC');
    return rows
        .map((row) => TtsDictionaryEntry(
              id: row['id'] as int,
              surface: row['surface'] as String,
              reading: row['reading'] as String,
            ))
        .toList();
  }

  /// Returns all entries sorted by surface length descending (longest first).
  /// Use this when applying the dictionary to multiple texts to avoid repeated sorting.
  Future<List<TtsDictionaryEntry>> getEntriesSortedByLength() async {
    final db = await _database.database;
    final rows = await db.query(
      'tts_dictionary',
      orderBy: 'LENGTH(surface) DESC, id ASC',
    );
    return rows
        .map((row) => TtsDictionaryEntry(
              id: row['id'] as int,
              surface: row['surface'] as String,
              reading: row['reading'] as String,
            ))
        .toList();
  }

  Future<void> updateEntry(int id, String surface, String reading) async {
    if (surface.isEmpty) throw ArgumentError('surface must not be empty');
    if (reading.isEmpty) throw ArgumentError('reading must not be empty');
    final db = await _database.database;
    await db.update(
      'tts_dictionary',
      {'surface': surface, 'reading': reading},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteEntry(int id) async {
    final db = await _database.database;
    await db.delete(
      'tts_dictionary',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Apply dictionary substitutions to [text].
  ///
  /// Entries are matched longest-surface-first to prevent shorter entries
  /// from shadowing longer ones (e.g. "山田" should not match before "山田太郎").
  ///
  /// For batch use (e.g. multiple segments), prefer pre-loading entries once
  /// via [getEntriesSortedByLength] and calling [applyDictionaryWithEntries]
  /// to avoid repeated DB queries.
  Future<String> applyDictionary(String text) async {
    final entries = await getEntriesSortedByLength();
    return applyDictionaryWithEntries(entries, text);
  }

  /// Apply dictionary substitutions using pre-loaded [entries] (sync).
  ///
  /// [entries] must already be sorted by surface length descending.
  static String applyDictionaryWithEntries(
      List<TtsDictionaryEntry> entries, String text) {
    if (entries.isEmpty) return text;

    final buffer = StringBuffer();
    int i = 0;
    while (i < text.length) {
      bool matched = false;
      for (final entry in entries) {
        final surface = entry.surface;
        if (surface.isEmpty) continue;
        if (i + surface.length <= text.length &&
            text.startsWith(surface, i)) {
          buffer.write(entry.reading);
          i += surface.length;
          matched = true;
          break;
        }
      }
      if (!matched) {
        buffer.writeCharCode(text.codeUnitAt(i));
        i++;
      }
    }
    return buffer.toString();
  }
}
