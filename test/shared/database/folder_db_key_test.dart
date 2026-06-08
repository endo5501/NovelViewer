import 'dart:io' show Platform;

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:novel_viewer/shared/database/folder_db_key.dart';

void main() {
  group('folderDbKey', () {
    test('p.join and forward-slash spellings collapse to one key', () {
      // The download path historically used '/'手結合 while the file browser
      // derives paths with the platform separator. These must resolve to one
      // family key so the DB handle stays reachable for release.
      final viaSlash = folderDbKey('lib/sub/narou_n1');
      final viaJoin = folderDbKey(p.join('lib', 'sub', 'narou_n1'));

      expect(viaJoin, viaSlash);
    });

    test('on Windows, backslash and forward-slash spellings collapse', () {
      // The actual regression is Windows-only: the same folder spelled with
      // '\' (browser) vs '/' (download) produced distinct family keys.
      if (!Platform.isWindows) return;
      expect(folderDbKey(r'C:\lib\narou_n1'), folderDbKey('C:/lib/narou_n1'));
    });

    test('is idempotent', () {
      const raw = '/lib/narou_n1';
      final once = folderDbKey(raw);
      expect(folderDbKey(once), once);
    });

    test('collapses redundant . and .. segments', () {
      final a = folderDbKey('/lib/narou_n1');
      final b = folderDbKey('/lib/sub/../narou_n1');
      final c = folderDbKey('/lib/./narou_n1');
      expect(b, a);
      expect(c, a);
    });

    test('p.join-built path matches a manually slash-joined path', () {
      const base = '/lib';
      const folder = 'narou_n1';
      expect(folderDbKey(p.join(base, folder)), folderDbKey('$base/$folder'));
    });
  });
}
