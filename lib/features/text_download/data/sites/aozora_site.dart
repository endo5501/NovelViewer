import 'package:euc/jis.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:novel_viewer/features/text_download/data/sites/novel_site.dart';

class AozoraSite extends NovelSite {
  @override
  String get siteType => 'aozora';

  static final _filePattern = RegExp(r'/cards/\d+/files/(.+)\.html$');

  @override
  bool canHandle(Uri url) {
    return url.host == 'www.aozora.gr.jp' && _filePattern.hasMatch(url.path);
  }

  @override
  String extractNovelId(Uri url) {
    final match = _filePattern.firstMatch(url.path);
    if (match == null) {
      throw ArgumentError('Cannot extract novel ID from URL: $url');
    }
    return match.group(1)!;
  }

  static final _shiftJis = ShiftJIS();

  @override
  String decodeBody(http.Response response) {
    return _shiftJis.decode(response.bodyBytes);
  }

  @override
  NovelIndex parseIndex(String html, Uri baseUrl) {
    final document = html_parser.parse(html);

    final titleElement = document.querySelector('title');
    final title = titleElement?.text.trim() ?? '';

    String? bodyContent;
    final mainText = document.querySelector('.main_text');
    if (mainText != null) {
      final text = parseEpisode(html);
      if (text.isNotEmpty) {
        bodyContent = text;
      }
    }

    return NovelIndex(
      title: title,
      episodes: const [],
      bodyContent: bodyContent,
    );
  }

  @override
  String parseEpisode(String html) {
    final document = html_parser.parse(html);

    final element = document.querySelector('.main_text');
    if (element == null) return '';

    return extractParagraphText(element);
  }
}
