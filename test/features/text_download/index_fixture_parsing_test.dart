import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:novel_viewer/features/text_download/data/sites/aozora_site.dart';
import 'package:novel_viewer/features/text_download/data/sites/hameln_site.dart';
import 'package:novel_viewer/features/text_download/data/sites/kakuyomu_site.dart';
import 'package:novel_viewer/features/text_download/data/sites/narou_site.dart';

/// Verifies the sanitized index-page fixtures parse the way the empty-index
/// guard (F118) relies on: valid pages yield episodes (or body), and drifted
/// pages yield an empty episode list AND null bodyContent (the guard's
/// precondition).
void main() {
  String fixture(String name) =>
      File('test/fixtures/text_download/$name').readAsStringSync();

  group('Narou index fixtures', () {
    test('valid index yields title and episodes', () {
      final index = NarouSite().parseIndex(
        fixture('narou_index_valid.html'),
        Uri.parse('https://ncode.syosetu.com/n0000aa/'),
      );
      expect(index.title, 'テスト小説');
      expect(index.episodes, hasLength(2));
      expect(index.episodes[1].updatedAt, '2025/01/03 12:00');
    });

    test('drifted index yields no episodes and no body (guard precondition)',
        () {
      final index = NarouSite().parseIndex(
        fixture('narou_index_drifted.html'),
        Uri.parse('https://ncode.syosetu.com/n0000aa/'),
      );
      expect(index.episodes, isEmpty);
      expect(index.bodyContent, isNull);
    });
  });

  group('Hameln index fixtures', () {
    test('valid index yields title and episodes', () {
      final index = HamelnSite().parseIndex(
        fixture('hameln_index_valid.html'),
        Uri.parse('https://syosetu.org/novel/000000/'),
      );
      expect(index.title, 'テスト小説');
      expect(index.episodes, hasLength(4));
      expect(index.episodes.map((e) => e.index), [1, 2, 3, 4]);
      // The href file number wins over any number the author wrote into the
      // title ("3　運ぶための力" links to 4.html).
      expect(index.episodes[2].url.toString(),
          'https://syosetu.org/novel/000000/4.html');
      expect(index.episodes[2].title, '3　運ぶための力');
      expect(index.episodes[0].updatedAt,
          '2026/02/21 16:20 (2026/03/01 06:05改稿)');
      expect(index.episodes[1].updatedAt, '2026/02/22 04:13');
    });

    test('short story fixture yields body content and no episodes', () {
      final index = HamelnSite().parseIndex(
        fixture('hameln_index_short_story.html'),
        Uri.parse('https://syosetu.org/novel/000000/'),
      );
      expect(index.title, '異世界転生？他所でやれ！！');
      expect(index.episodes, isEmpty);
      expect(index.bodyContent, isNotNull);
      expect(index.bodyContent, contains('これは短編の本文です。'));
    });

    test('episode fixture yields honbun body without maegaki or atogaki', () {
      final text = HamelnSite().parseEpisode(fixture('hameln_episode_valid.html'));
      expect(text, contains('本文の一段落目です。'));
      expect(text, contains('本文の二段落目です。'));
      expect(text, isNot(contains('前書きのテキスト')));
      expect(text, isNot(contains('後書きのテキスト')));
    });

    test('drifted index yields no episodes and no body (guard precondition)',
        () {
      final index = HamelnSite().parseIndex(
        fixture('hameln_index_drifted.html'),
        Uri.parse('https://syosetu.org/novel/000000/'),
      );
      expect(index.episodes, isEmpty);
      expect(index.bodyContent, isNull);
    });

    test('retired table markup yields no episodes and no body', () {
      final index = HamelnSite().parseIndex(
        fixture('hameln_index_legacy_table.html'),
        Uri.parse('https://syosetu.org/novel/000000/'),
      );
      expect(index.episodes, isEmpty);
      expect(index.bodyContent, isNull);
    });
  });

  group('Kakuyomu index fixture', () {
    test('valid index yields episodes from Apollo state', () {
      final index = KakuyomuSite().parseIndex(
        fixture('kakuyomu_index_valid.html'),
        Uri.parse('https://kakuyomu.jp/works/12345'),
      );
      expect(index.title, 'テスト小説');
      expect(index.episodes, hasLength(2));
      expect(index.episodes.map((e) => e.index), [1, 2]);
    });
  });

  group('Aozora index fixture', () {
    test('valid page yields body content with empty episodes (short story)', () {
      final index = AozoraSite().parseIndex(
        fixture('aozora_index_valid.html'),
        Uri.parse('https://www.aozora.gr.jp/cards/000/files/0_0.html'),
      );
      expect(index.episodes, isEmpty);
      expect(index.bodyContent, isNotNull);
      expect(index.bodyContent, contains('一段落目'));
    });
  });
}
