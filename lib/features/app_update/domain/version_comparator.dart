import 'package:pub_semver/pub_semver.dart';

/// Returns true when [tagName] denotes a stable release strictly newer than
/// [current].
///
/// Tags are SemVer with an optional leading `v`. A tag that cannot be parsed,
/// or that carries a pre-release suffix (we ship stable-only), is treated as
/// "no update" so test/nightly tags never prompt users. Build metadata
/// (`+123`) is ignored per the SemVer spec — `1.2.3+4` is the same release as
/// `1.2.3` and must not prompt an update (pub_semver otherwise ranks build
/// metadata as newer).
bool isNewer({required String current, required String tagName}) {
  final normalizedTag = tagName.startsWith('v') ? tagName.substring(1) : tagName;
  final Version currentVersion;
  final Version tagVersion;
  try {
    currentVersion = _stripBuild(Version.parse(current));
    tagVersion = _stripBuild(Version.parse(normalizedTag));
  } on FormatException {
    return false;
  }
  if (tagVersion.isPreRelease) return false;
  return tagVersion > currentVersion;
}

Version _stripBuild(Version v) => v.build.isEmpty
    ? v
    : Version(v.major, v.minor, v.patch,
        pre: v.preRelease.isEmpty ? null : v.preRelease.join('.'));
