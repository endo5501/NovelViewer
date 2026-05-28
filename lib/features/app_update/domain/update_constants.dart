/// Target GitHub repository for update checks. Hardcoded by design; there is
/// no runtime override.
const repoOwner = 'endo5501';
const repoName = 'NovelViewer';

String latestReleaseApiUrl() =>
    'https://api.github.com/repos/$repoOwner/$repoName/releases/latest';

String releasePageUrl(String tag) =>
    'https://github.com/$repoOwner/$repoName/releases/tag/$tag';

String userAgentFor(String appVersion) =>
    'NovelViewer/$appVersion (https://github.com/$repoOwner/$repoName)';

/// Normalizes a release tag / version string for identity comparisons:
/// strips a leading `v` and any SemVer build metadata (`+123`). Used so the
/// snooze ("Later") check matches [isNewer], which also ignores build metadata.
String normalizeReleaseVersion(String tagOrVersion) {
  var v = tagOrVersion.startsWith('v')
      ? tagOrVersion.substring(1)
      : tagOrVersion;
  final plus = v.indexOf('+');
  if (plus != -1) v = v.substring(0, plus);
  return v;
}
