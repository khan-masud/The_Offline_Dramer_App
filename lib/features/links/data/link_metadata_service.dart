import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class LinkMetadata {
  final String url;
  final String title;
  final String? description;
  final String? imageUrl;
  final String faviconUrl;
  final String domain;
  final String? siteName;

  const LinkMetadata({
    required this.url,
    required this.title,
    this.description,
    this.imageUrl,
    required this.faviconUrl,
    required this.domain,
    this.siteName,
  });
}

class LinkMetadataService {
  static String normalizeUrl(String urlString) {
    var trimmed = urlString.trim();
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      trimmed = 'https://$trimmed';
    }
    return trimmed;
  }

  static String getFaviconUrl(String urlString) {
    try {
      final normalized = normalizeUrl(urlString);
      final uri = Uri.parse(normalized);
      final host = uri.host.isNotEmpty ? uri.host : 'default';
      return 'https://www.google.com/s2/favicons?domain=$host&sz=64';
    } catch (_) {
      return '';
    }
  }

  static Future<LinkMetadata> fetchMetadata(String urlString) async {
    final normalized = normalizeUrl(urlString);
    final uri = Uri.tryParse(normalized);
    final domain = uri?.host ?? '';
    final faviconUrl = getFaviconUrl(normalized);

    String title = '';
    String? description;
    String? imageUrl;
    String? siteName;

    try {
      final response = await http.get(
        Uri.parse(normalized),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        },
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final html = response.body;

        // 1. Title
        title = _extractMetaTag(html, 'og:title') ??
            _extractMetaTag(html, 'twitter:title') ??
            _extractTag(html, 'title') ??
            '';

        // 2. Description
        description = _extractMetaTag(html, 'og:description') ??
            _extractMetaTag(html, 'description') ??
            _extractMetaTag(html, 'twitter:description');

        // 3. Image
        var rawImage = _extractMetaTag(html, 'og:image') ??
            _extractMetaTag(html, 'og:image:secure_url') ??
            _extractMetaTag(html, 'twitter:image') ??
            _extractMetaTag(html, 'twitter:image:src');

        if (rawImage != null && rawImage.isNotEmpty) {
          if (rawImage.startsWith('//')) {
            rawImage = 'https:$rawImage';
          } else if (rawImage.startsWith('/') && uri != null) {
            rawImage = '${uri.scheme}://${uri.host}$rawImage';
          }
          imageUrl = rawImage;
        }

        // 4. Site Name
        siteName = _extractMetaTag(html, 'og:site_name');
      }
    } catch (e) {
      debugPrint('LinkMetadataService fetch error for $normalized: $e');
    }

    if (title.isEmpty) {
      title = domain.isNotEmpty ? domain : normalized;
    }

    return LinkMetadata(
      url: normalized,
      title: _decodeHtmlEntities(title),
      description: description != null ? _decodeHtmlEntities(description) : null,
      imageUrl: imageUrl,
      faviconUrl: faviconUrl,
      domain: domain,
      siteName: siteName,
    );
  }

  static String? _extractMetaTag(String html, String nameOrProperty) {
    // Matches <meta property="og:title" content="..."> or <meta name="description" content="...">
    final regExp = RegExp(
      '<meta[^>]*(?:property|name)=[\'"](?:$nameOrProperty)[\'"][^>]*content=[\'"](.*?)[\'"]',
      caseSensitive: false,
      dotAll: true,
    );
    final match = regExp.firstMatch(html);
    if (match != null && match.group(1) != null) {
      return match.group(1)!.trim();
    }

    // Matches reversed order: <meta content="..." property="og:title">
    final reversedRegExp = RegExp(
      '<meta[^>]*content=[\'"](.*?)[\'"][^>]*(?:property|name)=[\'"](?:$nameOrProperty)[\'"]',
      caseSensitive: false,
      dotAll: true,
    );
    final revMatch = reversedRegExp.firstMatch(html);
    if (revMatch != null && revMatch.group(1) != null) {
      return revMatch.group(1)!.trim();
    }

    return null;
  }

  static String? _extractTag(String html, String tagName) {
    final regExp = RegExp('<$tagName[^>]*>(.*?)</$tagName>', caseSensitive: false, dotAll: true);
    final match = regExp.firstMatch(html);
    if (match != null && match.group(1) != null) {
      return match.group(1)!.trim();
    }
    return null;
  }

  static String _decodeHtmlEntities(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .trim();
  }
}
