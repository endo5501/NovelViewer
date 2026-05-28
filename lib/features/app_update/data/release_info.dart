import 'package:collection/collection.dart';

class ReleaseAsset {
  const ReleaseAsset({required this.name, required this.downloadUrl});

  final String name;
  final String downloadUrl;

  factory ReleaseAsset.fromJson(Map<String, dynamic> json) {
    return ReleaseAsset(
      name: json['name'] as String? ?? '',
      downloadUrl: json['browser_download_url'] as String? ?? '',
    );
  }
}

/// A subset of the GitHub `/releases/latest` payload that the updater needs.
class ReleaseInfo {
  const ReleaseInfo({
    required this.tagName,
    required this.body,
    required this.assets,
  });

  final String tagName;
  final String body;
  final List<ReleaseAsset> assets;

  factory ReleaseInfo.fromJson(Map<String, dynamic> json) {
    final rawAssets = (json['assets'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ReleaseAsset.fromJson)
        .toList(growable: false);
    return ReleaseInfo(
      tagName: json['tag_name'] as String? ?? '',
      body: json['body'] as String? ?? '',
      assets: rawAssets,
    );
  }

  ReleaseAsset? assetByName(String name) =>
      assets.firstWhereOrNull((a) => a.name == name);

  /// The Inno Setup installer EXE (`novel_viewer-setup-v*.exe`), if present.
  ReleaseAsset? installerAsset() => assets.firstWhereOrNull((a) =>
      a.name.startsWith('novel_viewer-setup-') && a.name.endsWith('.exe'));

  /// The SHA256 sidecar matching the chosen installer EXE, so the EXE and its
  /// checksum are always a matched pair even if a release ships several EXEs.
  ReleaseAsset? installerSha256Asset() {
    final exe = installerAsset();
    if (exe == null) return null;
    return assetByName('${exe.name}.sha256');
  }
}
