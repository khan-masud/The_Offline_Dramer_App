import 'dart:convert';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

class DailyInfo {
  final String quote;
  final String author;
  final String historicalEvent;
  
  DailyInfo({required this.quote, required this.author, required this.historicalEvent});
}

final dailyInfoProvider = FutureProvider<DailyInfo?>((ref) async {
  try {
    // 1. Fetch Quote
    String quote = "Believe you can and you're halfway there.";
    String author = "Theodore Roosevelt";
    final quoteRes = await http.get(Uri.parse('https://dummyjson.com/quotes/random')).timeout(const Duration(seconds: 4));
    if (quoteRes.statusCode == 200) {
      final json = jsonDecode(utf8.decode(quoteRes.bodyBytes));
      quote = json['quote'] ?? quote;
      author = json['author'] ?? author;
    }

    // 2. Fetch History (Wikipedia on-this-day)
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    
    String historyEvent = "Many great things happened in history today!";
    final historyRes = await http.get(
      Uri.parse('https://en.wikipedia.org/api/rest_v1/feed/onthisday/all/$month/$day'),
      headers: {
        'accept': 'application/json',
        'User-Agent': 'OfflineDreamerApp/1.0 (info@offline.dreamer)'
      }
    ).timeout(const Duration(seconds: 4));
    
    if (historyRes.statusCode == 200) {
      final json = jsonDecode(utf8.decode(historyRes.bodyBytes));
      final events = json['events'] as List?;
      final births = json['births'] as List?;
      
      final random = Random();
      
      String factText = "";
      if (events != null && events.isNotEmpty) {
        // limit to max 120 chars if possible by finding a shorter event
        dynamic bestEv = events[0];
        for (var i=0; i<10; i++) {
          final ev = events[random.nextInt(events.length)];
          if ((ev['text'] as String).length < 150) {
            bestEv = ev;
            break;
          }
        }
        factText += "In ${bestEv['year']}, ${bestEv['text']}";
      }
      
      if (births != null && births.isNotEmpty) {
        dynamic bestB = births[0];
        for (var i=0; i<10; i++) {
          final b = births[random.nextInt(births.length)];
          if ((b['text'] as String).length < 100) {
            bestB = b;
            break;
          }
        }
        if (factText.isNotEmpty) factText += "\n\n";
        factText += "Also born today in ${bestB['year']}: ${bestB['text']}.";
      }
      
      if (factText.isNotEmpty) {
        historyEvent = factText;
      }
    }
    
    return DailyInfo(quote: quote, author: author, historicalEvent: historyEvent);
  } catch (e) {
    // Fallback if no internet
    return null;
  }
});
