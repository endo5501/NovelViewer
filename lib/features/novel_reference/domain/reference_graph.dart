/// One stored reference-source relation: [child] draws on [parent] when it is
/// analyzed. Both are `novels.folder_name` values.
class ReferenceRelation {
  const ReferenceRelation({required this.child, required this.parent});

  final String child;
  final String parent;

  @override
  bool operator ==(Object other) =>
      other is ReferenceRelation &&
      other.child == child &&
      other.parent == parent;

  @override
  int get hashCode => Object.hash(child, parent);
}

/// A novel reached by following reference sources upward from another.
class ResolvedAncestor {
  const ResolvedAncestor({
    required this.folderName,
    required this.depth,
    required this.via,
  });

  final String folderName;

  /// Shortest number of relations between the starting novel and this one;
  /// a direct reference source has depth 1.
  final int depth;

  /// The starting novel's direct reference source this ancestor was first
  /// reached through. A direct reference source is reached via itself.
  final String via;
}

/// Every novel [child] reaches by following reference sources upward, each
/// once, never [child] itself and never in the child direction.
///
/// Ordered by depth descending, then folder name ascending. Farther ancestors
/// come first so that, read in this order, a series runs from its first part
/// towards the novel being analyzed. The order depends only on the relations,
/// not on the order they are given in.
List<ResolvedAncestor> resolveAncestors(
  String child,
  Iterable<ReferenceRelation> relations,
) {
  final parentsOf = _adjacency(relations, (r) => r.child, (r) => r.parent);
  final found = <String, ResolvedAncestor>{};
  var frontier = <(String, String)>[
    for (final parent in parentsOf[child] ?? const <String>[]) (parent, parent),
  ];
  var depth = 1;
  while (frontier.isNotEmpty) {
    final next = <(String, String)>[];
    for (final (folder, via) in frontier) {
      if (folder == child || found.containsKey(folder)) continue;
      found[folder] = ResolvedAncestor(
        folderName: folder,
        depth: depth,
        via: via,
      );
      for (final parent in parentsOf[folder] ?? const <String>[]) {
        next.add((parent, via));
      }
    }
    frontier = next;
    depth++;
  }
  final result = found.values.toList()
    ..sort((a, b) {
      final byDepth = b.depth.compareTo(a.depth);
      return byDepth != 0 ? byDepth : a.folderName.compareTo(b.folderName);
    });
  return result;
}

/// Every novel that has [folder] as an ancestor, never [folder] itself.
Set<String> resolveDescendants(
  String folder,
  Iterable<ReferenceRelation> relations,
) {
  final childrenOf = _adjacency(relations, (r) => r.parent, (r) => r.child);
  final found = <String>{};
  final pending = [...?childrenOf[folder]];
  while (pending.isNotEmpty) {
    final current = pending.removeLast();
    if (current == folder || !found.add(current)) continue;
    pending.addAll(childrenOf[current] ?? const <String>[]);
  }
  return found;
}

/// Whether following reference sources from some novel leads back to it.
bool hasCycle(Iterable<ReferenceRelation> relations) {
  final list = relations.toList();
  for (final r in list) {
    if (r.child == r.parent) return true;
    if (resolveDescendants(r.child, list).contains(r.parent)) return true;
  }
  return false;
}

/// [from] → sorted [to] values, so traversal order is independent of input
/// order.
Map<String, List<String>> _adjacency(
  Iterable<ReferenceRelation> relations,
  String Function(ReferenceRelation) from,
  String Function(ReferenceRelation) to,
) {
  final map = <String, Set<String>>{};
  for (final r in relations) {
    map.putIfAbsent(from(r), () => <String>{}).add(to(r));
  }
  return {for (final e in map.entries) e.key: e.value.toList()..sort()};
}
