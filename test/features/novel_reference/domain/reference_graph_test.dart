import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/novel_reference/domain/reference_graph.dart';

ReferenceRelation _r(String child, String parent) =>
    ReferenceRelation(child: child, parent: parent);

void main() {
  group('resolveAncestors', () {
    test('returns nothing for a novel without reference sources', () {
      expect(resolveAncestors('a', [_r('x', 'y')]), isEmpty);
    });

    test('follows reference sources recursively', () {
      final ancestors = resolveAncestors('part3', [
        _r('part3', 'part2'),
        _r('part2', 'part1'),
      ]);
      expect(ancestors.map((a) => a.folderName), ['part1', 'part2']);
    });

    test('a diamond reaches the shared ancestor once', () {
      final ancestors = resolveAncestors('part3', [
        _r('part3', 'part2'),
        _r('part3', 'part1'),
        _r('part2', 'part1'),
      ]);
      expect(ancestors.map((a) => a.folderName), ['part1', 'part2']);
      final part1 = ancestors.firstWhere((a) => a.folderName == 'part1');
      expect(part1.depth, 1, reason: 'depth is the shortest distance');
    });

    test('does not follow children', () {
      final ancestors = resolveAncestors('part1', [
        _r('gaiden', 'part1'),
        _r('part1', 'wiki'),
      ]);
      expect(ancestors.map((a) => a.folderName), ['wiki']);
    });

    test('never includes the novel itself', () {
      // A cycle cannot be stored, but resolution must still terminate and
      // leave the novel out should one ever reach it.
      final ancestors = resolveAncestors('a', [_r('a', 'b'), _r('b', 'a')]);
      expect(ancestors.map((a) => a.folderName), ['b']);
    });

    test('orders by depth descending, then folder name ascending', () {
      final ancestors = resolveAncestors('c', [
        _r('c', 'zeta'),
        _r('c', 'alpha'),
        _r('alpha', 'root2'),
        _r('zeta', 'root1'),
      ]);
      expect(ancestors.map((a) => a.folderName), [
        'root1',
        'root2',
        'alpha',
        'zeta',
      ]);
    });

    test('the order does not depend on the relation input order', () {
      final relations = [
        _r('c', 'zeta'),
        _r('c', 'alpha'),
        _r('alpha', 'root2'),
        _r('zeta', 'root1'),
      ];
      final forward = resolveAncestors('c', relations);
      final backward = resolveAncestors('c', relations.reversed);
      expect(
        backward.map((a) => a.folderName),
        forward.map((a) => a.folderName),
      );
    });

    test(
      'records the direct reference source each ancestor is reached via',
      () {
        final ancestors = resolveAncestors('part3', [
          _r('part3', 'part2'),
          _r('part2', 'part1'),
          _r('part3', 'wiki'),
        ]);
        final byName = {for (final a in ancestors) a.folderName: a};
        expect(byName['part1']!.via, 'part2');
        expect(byName['part2']!.via, 'part2');
        expect(byName['wiki']!.via, 'wiki');
      },
    );
  });

  group('resolveDescendants', () {
    test('collects every novel that has the novel as an ancestor', () {
      final descendants = resolveDescendants('part1', [
        _r('part2', 'part1'),
        _r('part3', 'part2'),
        _r('other', 'wiki'),
      ]);
      expect(descendants, {'part2', 'part3'});
    });

    test('never includes the novel itself', () {
      expect(resolveDescendants('a', [_r('b', 'a'), _r('a', 'b')]), {'b'});
    });
  });

  group('hasCycle', () {
    test('is false for a chain and a diamond', () {
      expect(hasCycle([_r('c', 'b'), _r('b', 'a'), _r('c', 'a')]), isFalse);
    });

    test('is true for a self reference', () {
      expect(hasCycle([_r('a', 'a')]), isTrue);
    });

    test('is true for a longer loop', () {
      expect(hasCycle([_r('a', 'b'), _r('b', 'c'), _r('c', 'a')]), isTrue);
    });
  });
}
