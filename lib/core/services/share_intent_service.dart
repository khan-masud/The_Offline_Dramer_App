import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:share_handler/share_handler.dart';

class ShareIntentService {
  static final ShareIntentService _instance = ShareIntentService._internal();
  factory ShareIntentService() => _instance;
  ShareIntentService._internal();

  StreamSubscription<SharedMedia>? _intentDataStreamSubscription;
  SharedMedia? initialSharedMedia;
  
  // Callback when a URL is shared
  Function(String url, String? text)? onUrlShared;

  Future<void> init() async {
    // Avoid missing plugin crash on Web/Desktop
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS) {
      return;
    }
    // For sharing images coming from outside the app while the app is in the memory
    _intentDataStreamSubscription = ShareHandlerPlatform.instance.sharedMediaStream.listen((SharedMedia media) {
      _processSharedMedia(media);
    });

    // For sharing images coming from outside the app while the app is closed
    initialSharedMedia = await ShareHandlerPlatform.instance.getInitialSharedMedia();
    if (initialSharedMedia != null) {
      _processSharedMedia(initialSharedMedia!);
    }
  }

  void _processSharedMedia(SharedMedia media) {
    String? sharedText = media.content;
    if (sharedText != null && sharedText.isNotEmpty) {
      // Very basic URL extraction
      final urlRegExp = RegExp(r"https?:\/\/[^\s]+", caseSensitive: false);
      final match = urlRegExp.firstMatch(sharedText);
      if (match != null) {
        final url = match.group(0)!;
        debugPrint('Received shared URL: $url');
        onUrlShared?.call(url, sharedText);
      }
    }
  }

  void dispose() {
    _intentDataStreamSubscription?.cancel();
  }
}
