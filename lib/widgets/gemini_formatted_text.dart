import 'package:flutter/material.dart';

class GeminiFormattedText extends StatelessWidget {
  final String text;
  const GeminiFormattedText({Key? key, required this.text}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.grey[300] : Colors.grey[800];
    final headerColor = isDark ? Colors.white : Colors.black87;

    final cleanText = text.replaceAll('|', '');
    List<Widget> children = [];
    List<String> lines = cleanText.split('\n');

    for (String line in lines) {
      String trimmed = line.trim();
      if (trimmed.isEmpty) {
        children.add(SizedBox(height: 8));
        continue;
      }
      
      if (trimmed.startsWith('* ') || trimmed.startsWith('- ') || trimmed.startsWith('• ')) {
        String content = trimmed.substring(2).trim();
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6.0, left: 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "• ",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    height: 1.4,
                    color: Colors.purple[300],
                  ),
                ),
                Expanded(child: _parseRichText(content, textColor!)),
              ],
            ),
          ),
        );
      } 
      else if (trimmed.startsWith('#')) {
         String content = trimmed.replaceAll('#', '').trim();
         children.add(
           Padding(
             padding: const EdgeInsets.only(top: 12.0, bottom: 6.0),
             child: Text(
               content,
               style: TextStyle(
                 fontWeight: FontWeight.bold,
                 fontSize: 16,
                 color: headerColor,
               ),
             ),
           )
         );
      }
      else {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: _parseRichText(trimmed, textColor!),
          ),
        );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _parseRichText(String text, Color textColor) {
    List<TextSpan> spans = [];
    List<String> parts = text.split('**');
    
    for (int i = 0; i < parts.length; i++) {
      bool isBold = (i % 2 != 0);
      String part = parts[i];
      part = part.replaceAll('*', ''); 

      if (part.isNotEmpty) {
        spans.add(
          TextSpan(
            text: part,
            style: TextStyle(
              color: textColor,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.normal,
              fontSize: 15,
              height: 1.5,
            ),
          ),
        );
      }
    }
    return RichText(text: TextSpan(children: spans));
  }
}