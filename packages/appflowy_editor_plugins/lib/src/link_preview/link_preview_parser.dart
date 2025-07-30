import 'package:flutter/rendering.dart';

import 'package:appflowy_editor_plugins/appflowy_editor_plugins.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;

enum LinkPreviewRegex { title, description, image }

class LinkPreviewData {
  factory LinkPreviewData.fromPreviewData(PreviewData data) => LinkPreviewData(
        title: data.title,
        description: data.description,
        imageUrl: data.image?.url,
      );

  factory LinkPreviewData.fromJson(Map<String, dynamic> json) => LinkPreviewData(
        title: json['title'],
        description: json['description'],
        imageUrl: json['imageUrl'],
      );

  const LinkPreviewData({this.title, this.description, this.imageUrl});

  final String? title;
  final String? description;
  final String? imageUrl;

  Map<String, dynamic> toJson() =>
      {'title': title, 'description': description, 'imageUrl': imageUrl};
}

/// Parse the url link to get the title, description, image
class LinkPreviewParser {
  LinkPreviewParser({required this.url, this.cache});

  final String url;
  final LinkPreviewDataCacheInterface? cache;

  LinkPreviewData? metadata;

  /// must call this method before using the other methods
  Future<void> start() async {
    try {
      metadata = await cache?.get(url);
      if (metadata != null) {
        // Refresh the cache on background
        return _fetchPreviewData(url).then(
          (data) => cache?.set(url, data),
        );
      }
      metadata = await _fetchPreviewData(url);
      cache?.set(url, metadata!);
    } catch (e, s) {
      debugPrint('$e\n$s');
      metadata = null;
    }
  }

  /// Fetch preview data for a given URL
  Future<LinkPreviewData> _fetchPreviewData(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final document = parser.parse(response.body);

        // Extract title
        final title = document.querySelector('meta[property="og:title"]')?.attributes['content'] ??
            document.querySelector('title')?.text;

        // Extract description
        final description =
            document.querySelector('meta[property="og:description"]')?.attributes['content'] ??
                document.querySelector('meta[name="description"]')?.attributes['content'];

        // Extract image
        final imageUrl = document.querySelector('meta[property="og:image"]')?.attributes['content'];

        return LinkPreviewData(
          title: title,
          description: description,
          imageUrl: imageUrl,
        );
      }
    } catch (e) {
      debugPrint('Error fetching preview data: $e');
    }

    return const LinkPreviewData();
  }

  String? getContent(LinkPreviewRegex regex) {
    if (metadata == null) {
      return null;
    }

    return switch (regex) {
      LinkPreviewRegex.title => metadata?.title,
      LinkPreviewRegex.description => metadata?.description,
      LinkPreviewRegex.image => metadata?.imageUrl,
    };
  }
}
