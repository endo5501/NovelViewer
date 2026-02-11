class SearchMatch {
  final int lineNumber;
  final String contextText;

  const SearchMatch({
    required this.lineNumber,
    required this.contextText,
  });
}

class SearchResult {
  final String fileName;
  final String filePath;
  final List<SearchMatch> matches;

  const SearchResult({
    required this.fileName,
    required this.filePath,
    required this.matches,
  });
}
