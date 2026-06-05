import 'package:path/path.dart' as p;

/// A candidate destination folder for a move operation, with [depth] giving the
/// indentation level relative to the library root (root is depth 0).
class MoveDestination {
  final String path;
  final String name;
  final int depth;

  const MoveDestination({
    required this.path,
    required this.name,
    required this.depth,
  });
}

/// Builds the ordered list of valid move destinations for the folder at
/// [sourcePath]. The list always starts with the library root, followed by the
/// organizational folders in [organizationalFolderPaths], sorted so that a
/// parent always precedes its children. The source folder itself and any of
/// its descendants are excluded so a folder can never be moved into itself.
List<MoveDestination> buildMoveDestinations({
  required String libraryPath,
  required List<String> organizationalFolderPaths,
  required String sourcePath,
}) {
  final destinations = <MoveDestination>[
    MoveDestination(
      path: libraryPath,
      name: p.basename(libraryPath),
      depth: 0,
    ),
  ];

  final sorted = [...organizationalFolderPaths]..sort();
  for (final folder in sorted) {
    if (p.equals(folder, sourcePath)) continue;
    if (p.isWithin(sourcePath, folder)) continue;
    if (!p.isWithin(libraryPath, folder)) continue;
    final relative = p.relative(folder, from: libraryPath);
    destinations.add(MoveDestination(
      path: folder,
      name: p.basename(folder),
      depth: p.split(relative).length,
    ));
  }

  return destinations;
}
