import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart';

class WebScraperService {
  
  /// Returns a Map with 'title' and 'content', or null if failed
  static Future<Map<String, String>?> scrapeUrl(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode != 200) return null;

      var document = parser.parse(response.body);

      // 1. Extract Title
      String title = document.head?.querySelector('title')?.text ?? "Imported Article";
      
      // 2. Extract Content (Best Effort Strategy)
      // Look for article tags first, then main, then fall back to body
      Element? mainElement = document.querySelector('article') 
                          ?? document.querySelector('main')
                          ?? document.querySelector('.post-content')
                          ?? document.body;

      if (mainElement == null) return null;

      // Extract all paragraphs
      List<String> paragraphs = [];
      var pTags = mainElement.querySelectorAll('p');
      
      for (var p in pTags) {
        String text = p.text.trim();
        // Filter out short junk text (like "Share this", "Advertisement")
        if (text.length > 20) {
          paragraphs.add(text);
        }
      }

      String cleanContent = paragraphs.join("\n\n");

      if (cleanContent.isEmpty) return null;

      return {
        'title': title.trim(),
        'content': cleanContent,
      };

    } catch (e) {
      return null;
    }
  }
}