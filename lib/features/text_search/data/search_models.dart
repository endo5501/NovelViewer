class SearchMatch {
  final int lineNumber;
  final String contextText;
  final String? extendedContext;

  const SearchMatch({
    required this.lineNumber,
    required this.contextText,
    this.extendedContext,
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

class SelectedSearchMatch {
  final String filePath;
  final int lineNumber;
  final String query;

  const SelectedSearchMatch({
    required this.filePath,
    required this.lineNumber,
    required this.query,
  });
}
