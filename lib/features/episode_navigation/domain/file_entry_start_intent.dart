/// Hint passed across a file switch indicating where the viewer should start
/// rendering the newly selected file. Consumed exactly once by the text
/// viewer after layout settles.
enum FileEntryStartIntent {
  /// Begin from the start of the content (page 0 / scroll offset 0).
  fromStart,

  /// Begin from the end of the content (last page / maxScrollExtent).
  fromEnd,
}
