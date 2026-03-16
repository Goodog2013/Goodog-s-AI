import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../models/web_search_result.dart';

class WebSearchClient {
  WebSearchClient({
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;
  static const Map<String, String> _defaultHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
  };
  static const int _maxFetchChars = 15000;

  Future<WebSearchResult?> fetchPagePreview(String rawText) async {
    final url = _extractFirstUrl(rawText);
    if (url == null) {
      return null;
    }

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return _errorResult(
        url: url,
        title: 'Некорректная ссылка',
        message: 'Некорректная ссылка.',
      );
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return _errorResult(
        url: uri.toString(),
        title: 'Неподдерживаемый протокол',
        message: 'Поддерживаются только ссылки http:// и https://',
      );
    }

    try {
      if (_isYouTubeUrl(uri)) {
        try {
          final youtubePreview = await _fetchYouTubeOEmbed(uri);
          if (youtubePreview != null) {
            return youtubePreview;
          }
        } on TimeoutException {
          // Fall back to plain HTML parsing below.
        } on SocketException {
          // Fall back to plain HTML parsing below.
        } on http.ClientException {
          // Fall back to plain HTML parsing below.
        } on FormatException {
          // Fall back to plain HTML parsing below.
        }
      }

      final response = await _client
          .get(uri, headers: _defaultHeaders)
          .timeout(timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _errorResult(
          url: response.request?.url.toString() ?? uri.toString(),
          title: 'Ошибка загрузки страницы',
          message: 'Сайт вернул HTTP ${response.statusCode}.',
        );
      }

      final finalUrl = response.request?.url.toString() ?? uri.toString();
      final contentType = (response.headers['content-type'] ?? '')
          .toLowerCase();
      if (contentType.contains('text/html')) {
        return _htmlPreview(
          html: response.body,
          finalUrl: finalUrl,
          fallbackTitle: uri.host,
        );
      }

      if (_isPlainTextResponse(contentType)) {
        final text = response.body.trim();
        if (text.isEmpty) {
          return _errorResult(
            url: finalUrl,
            title: 'Пустой текстовый ответ',
            message: 'Сайт вернул пустой текстовый ответ.',
          );
        }
        return WebSearchResult(
          title: 'Текстовый ресурс',
          url: finalUrl,
          snippet:
              'URL: $finalUrl\nCONTENT:\n${_truncate(text, _maxFetchChars)}',
        );
      }

      return _errorResult(
        url: finalUrl,
        title: 'Неподдерживаемый формат',
        message:
            'Неподдерживаемый тип содержимого для текстового чтения: ${contentType.isEmpty ? 'unknown' : contentType}.',
      );
    } on FormatException {
      return _errorResult(
        url: uri.toString(),
        title: 'Ошибка формата',
        message: 'Не удалось разобрать ответ сайта.',
      );
    } on TimeoutException {
      return _errorResult(
        url: uri.toString(),
        title: 'Таймаут',
        message: 'Превышено время ожидания ответа сайта.',
      );
    } on SocketException {
      return _errorResult(
        url: uri.toString(),
        title: 'Нет соединения',
        message: 'Нет подключения к интернету или сайт недоступен.',
      );
    } on http.ClientException {
      return _errorResult(
        url: uri.toString(),
        title: 'Ошибка HTTP-клиента',
        message: 'Ошибка HTTP-клиента при обращении к сайту.',
      );
    }
  }

  Future<List<WebSearchResult>> search({
    required String query,
    int maxResults = 4,
  }) async {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      return const [];
    }

    try {
      final htmlResults = await _searchHtml(
        query: normalized,
        maxResults: maxResults,
      );
      if (htmlResults.isNotEmpty) {
        return htmlResults;
      }

      return await _searchInstantApi(query: normalized, maxResults: maxResults);
    } on TimeoutException {
      throw const WebSearchException('Превышено время ожидания веб-поиска.');
    } on SocketException {
      throw const WebSearchException(
        'Нет подключения к интернету для веб-поиска.',
      );
    } on http.ClientException {
      throw const WebSearchException(
        'Ошибка HTTP-клиента во время веб-поиска.',
      );
    } on FormatException {
      throw const WebSearchException(
        'Сервер веб-поиска вернул неожиданный формат ответа.',
      );
    }
  }

  Future<List<WebSearchResult>> _searchHtml({
    required String query,
    required int maxResults,
  }) async {
    final uri = Uri.https('duckduckgo.com', '/html/', {
      'q': query,
      'kl': 'ru-ru',
    });

    final response = await _client
        .get(uri, headers: _defaultHeaders)
        .timeout(timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WebSearchException(
        'Сервис веб-поиска вернул HTTP ${response.statusCode}.',
      );
    }

    final matches = RegExp(
      r'<a[^>]*class="result__a"[^>]*href="([^"]+)"[^>]*>(.*?)<\/a>',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(response.body);

    final snippetMatches = RegExp(
      r'<a[^>]*class="result__snippet"[^>]*>(.*?)<\/a>|<div[^>]*class="result__snippet"[^>]*>(.*?)<\/div>',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(response.body).toList();

    final results = <WebSearchResult>[];
    final seen = <String>{};

    for (var i = 0; i < matches.length && results.length < maxResults; i++) {
      final match = matches.elementAt(i);
      final rawHref = match.group(1) ?? '';
      final rawTitle = match.group(2) ?? '';
      final url = _normalizeSearchUrl(rawHref);
      if (url.isEmpty || seen.contains(url)) {
        continue;
      }
      seen.add(url);

      final snippetRaw = i < snippetMatches.length
          ? (snippetMatches[i].group(1) ?? snippetMatches[i].group(2) ?? '')
          : '';
      final title = _normalizeText(rawTitle);
      final snippet = _normalizeText(snippetRaw);
      if (title.isEmpty) {
        continue;
      }

      results.add(WebSearchResult(title: title, url: url, snippet: snippet));
    }

    return results;
  }

  Future<List<WebSearchResult>> _searchInstantApi({
    required String query,
    required int maxResults,
  }) async {
    final uri = Uri.https('api.duckduckgo.com', '/', {
      'q': query,
      'format': 'json',
      'no_html': '1',
      'skip_disambig': '1',
    });

    final response = await _client.get(uri).timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WebSearchException(
        'Сервис веб-поиска вернул HTTP ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid search payload.');
    }

    final results = <WebSearchResult>[];
    final seen = <String>{};

    final abstractText = (decoded['AbstractText'] as String?)?.trim() ?? '';
    final abstractUrl = (decoded['AbstractURL'] as String?)?.trim() ?? '';
    final heading = (decoded['Heading'] as String?)?.trim() ?? '';
    if (abstractText.isNotEmpty && abstractUrl.isNotEmpty) {
      results.add(
        WebSearchResult(
          title: heading.isEmpty ? query : heading,
          url: abstractUrl,
          snippet: abstractText,
        ),
      );
      seen.add(abstractUrl);
    }

    final related = decoded['RelatedTopics'];
    if (related is List) {
      for (final item in related) {
        if (results.length >= maxResults) {
          break;
        }
        if (item is Map<String, dynamic>) {
          final topics = item['Topics'];
          if (topics is List) {
            for (final topic in topics) {
              if (results.length >= maxResults) {
                break;
              }
              _appendRelatedTopic(result: topic, output: results, seen: seen);
            }
          } else {
            _appendRelatedTopic(result: item, output: results, seen: seen);
          }
        }
      }
    }

    return results.take(maxResults).toList(growable: false);
  }

  void _appendRelatedTopic({
    required Object? result,
    required List<WebSearchResult> output,
    required Set<String> seen,
  }) {
    if (result is! Map<String, dynamic>) {
      return;
    }
    final text = (result['Text'] as String?)?.trim() ?? '';
    final url = (result['FirstURL'] as String?)?.trim() ?? '';
    if (text.isEmpty || url.isEmpty || seen.contains(url)) {
      return;
    }

    seen.add(url);
    output.add(
      WebSearchResult(title: _extractTitle(text), url: url, snippet: text),
    );
  }

  String _extractTitle(String text) {
    final separator = text.indexOf(' - ');
    if (separator > 0) {
      return text.substring(0, separator).trim();
    }
    return text.length <= 80 ? text : '${text.substring(0, 80)}...';
  }

  String? _extractFirstUrl(String text) {
    final match = RegExp(r'https?:\/\/\S+').firstMatch(text);
    if (match == null) {
      return null;
    }

    final raw = match.group(0)?.trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return raw.replaceAll(RegExp(r'[\)\]\}\>\,\.;]+$'), '').trim();
  }

  String _normalizeSearchUrl(String href) {
    final decodedHref = href.replaceAll('&amp;', '&').trim();
    if (decodedHref.isEmpty) {
      return '';
    }

    final withScheme = decodedHref.startsWith('//')
        ? 'https:$decodedHref'
        : decodedHref;
    final withHost = withScheme.startsWith('/')
        ? 'https://duckduckgo.com$withScheme'
        : withScheme;

    final uri = Uri.tryParse(withHost);
    if (uri == null) {
      return '';
    }

    final uddg = uri.queryParameters['uddg'];
    if (uddg != null && uddg.isNotEmpty) {
      return Uri.decodeFull(uddg);
    }
    return withHost;
  }

  WebSearchResult _htmlPreview({
    required String html,
    required String finalUrl,
    required String fallbackTitle,
  }) {
    final ogTitle = _extractMetaContent(
      html,
      properties: const ['og:title', 'twitter:title'],
    );
    final ogDescription = _extractMetaContent(
      html,
      properties: const ['og:description', 'twitter:description'],
      names: const ['description'],
    );
    final titleMatch = RegExp(
      r'<title[^>]*>(.*?)<\/title>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);

    final rawTitle = ogTitle ?? titleMatch?.group(1) ?? fallbackTitle;
    final title = _normalizeText(rawTitle).isEmpty
        ? fallbackTitle
        : _normalizeText(rawTitle);
    final cleaned = _cleanHtml(html);
    final intro = _normalizeText(ogDescription ?? '');

    final content = intro.isNotEmpty
        ? '$intro\n\n$cleaned'.trim()
        : cleaned.trim();
    if (content.isEmpty) {
      return _errorResult(
        url: finalUrl,
        title: title,
        message: 'Страница открылась, но текст не извлечён.',
      );
    }

    return WebSearchResult(
      title: title,
      url: finalUrl,
      snippet:
          'URL: $finalUrl\nTITLE: $title\nCONTENT:\n${_truncate(content, _maxFetchChars)}',
    );
  }

  bool _isPlainTextResponse(String contentType) {
    return contentType.contains('application/json') ||
        contentType.contains('text/') ||
        contentType.contains('xml');
  }

  String _cleanHtml(String html) {
    var text = html
        .replaceAll(
          RegExp(r'<script[\s\S]*?<\/script>', caseSensitive: false),
          ' ',
        )
        .replaceAll(
          RegExp(r'<style[\s\S]*?<\/style>', caseSensitive: false),
          ' ',
        )
        .replaceAll(
          RegExp(r'<noscript[\s\S]*?<\/noscript>', caseSensitive: false),
          ' ',
        )
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</div>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</li>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), ' ');

    text = _decodeHtmlEntities(text);
    text = text
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r' *\n *'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    return text;
  }

  String _truncate(String text, int maxChars) {
    if (text.length <= maxChars) {
      return text;
    }
    return '${text.substring(0, maxChars)}...';
  }

  WebSearchResult _errorResult({
    required String url,
    required String title,
    required String message,
  }) {
    return WebSearchResult(
      title: title,
      url: url,
      snippet: 'URL: $url\nERROR: $message',
      isError: true,
    );
  }

  String _decodeHtmlEntities(String input) {
    var text = input;
    const htmlEntities = <String, String>{
      '&quot;': '"',
      '&#34;': '"',
      '&amp;': '&',
      '&#38;': '&',
      '&lt;': '<',
      '&#60;': '<',
      '&gt;': '>',
      '&#62;': '>',
      '&nbsp;': ' ',
      '&#160;': ' ',
      '&ndash;': '-',
      '&#8211;': '-',
      '&mdash;': '-',
      '&#8212;': '-',
      '&apos;': '\'',
      '&#39;': '\'',
      '&laquo;': '«',
      '&raquo;': '»',
      '&hellip;': '...',
    };
    htmlEntities.forEach((entity, replacement) {
      text = text.replaceAll(entity, replacement);
    });
    return text;
  }

  String _normalizeText(String input) {
    var text = _decodeHtmlEntities(
      input,
    ).replaceAll(RegExp('<[^>]+>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    return text;
  }

  bool _isYouTubeUrl(Uri uri) {
    final host = uri.host.toLowerCase();
    return host == 'youtu.be' ||
        host.endsWith('.youtu.be') ||
        host == 'youtube.com' ||
        host.endsWith('.youtube.com');
  }

  Future<WebSearchResult?> _fetchYouTubeOEmbed(Uri videoUri) async {
    final oEmbedUri = Uri.https('www.youtube.com', '/oembed', {
      'url': videoUri.toString(),
      'format': 'json',
    });

    final response = await _client
        .get(oEmbedUri, headers: _defaultHeaders)
        .timeout(timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final title = (decoded['title'] as String?)?.trim() ?? '';
    final authorName = (decoded['author_name'] as String?)?.trim() ?? '';
    final authorUrl = (decoded['author_url'] as String?)?.trim() ?? '';
    final thumbnailUrl = (decoded['thumbnail_url'] as String?)?.trim() ?? '';

    final snippetParts = <String>[
      if (authorName.isNotEmpty) 'Канал: $authorName.',
      if (authorUrl.isNotEmpty) 'Страница канала: $authorUrl.',
      if (thumbnailUrl.isNotEmpty) 'Превью: $thumbnailUrl.',
      'Источник: YouTube oEmbed.',
    ];
    final titleSafe = title.isEmpty ? 'Видео YouTube' : title;

    return WebSearchResult(
      title: titleSafe,
      url: videoUri.toString(),
      snippet:
          'URL: ${videoUri.toString()}\nTITLE: $titleSafe\nCONTENT:\n${snippetParts.join(' ')}',
    );
  }

  String? _extractMetaContent(
    String html, {
    List<String> properties = const [],
    List<String> names = const [],
  }) {
    for (final property in properties) {
      final content = _extractMetaAttribute(
        html,
        attrName: 'property',
        attrValue: property,
      );
      if (content != null && content.isNotEmpty) {
        return content;
      }
    }

    for (final name in names) {
      final content = _extractMetaAttribute(
        html,
        attrName: 'name',
        attrValue: name,
      );
      if (content != null && content.isNotEmpty) {
        return content;
      }
    }

    return null;
  }

  String? _extractMetaAttribute(
    String html, {
    required String attrName,
    required String attrValue,
  }) {
    final escapedValue = RegExp.escape(attrValue);
    final patterns = <RegExp>[
      RegExp(
        '<meta[^>]*$attrName=["\']$escapedValue["\'][^>]*content=["\'](.*?)["\'][^>]*>',
        caseSensitive: false,
        dotAll: true,
      ),
      RegExp(
        '<meta[^>]*content=["\'](.*?)["\'][^>]*$attrName=["\']$escapedValue["\'][^>]*>',
        caseSensitive: false,
        dotAll: true,
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(html);
      if (match == null) {
        continue;
      }
      final value = _normalizeText(match.group(1) ?? '');
      if (value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  void dispose() {
    _client.close();
  }
}

class WebSearchException implements Exception {
  const WebSearchException(this.message);

  final String message;

  @override
  String toString() => message;
}
