import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class YouTubeInputDialog extends StatefulWidget {
  final VoidCallback onCancel;
  final Function(String) onPlay;

  const YouTubeInputDialog({
    super.key,
    required this.onCancel,
    required this.onPlay,
  });

  @override
  State<YouTubeInputDialog> createState() => _YouTubeInputDialogState();
}

class _YouTubeInputDialogState extends State<YouTubeInputDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      setState(() {
        _controller.text = data!.text!;
        _errorText = null;
      });
    }
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _errorText = "Please paste a link");
      return;
    }
    // Basic validation
    if (!text.contains('youtube.com') && !text.contains('youtu.be')) {
      setState(() => _errorText = "Not a valid YouTube link");
      return;
    }
    widget.onPlay(text);
  }

  @override
  Widget build(BuildContext context) {
    // 1. Center alignment
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Material(
          type: MaterialType.transparency, // Important to avoid double material
          child: Container(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            // 2. Wrap in ScrollView to prevent "Overflow" error when keyboard opens
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(
                        Icons.play_circle_fill,
                        color: Colors.redAccent,
                        size: 28,
                      ),
                      SizedBox(width: 10),
                      Text(
                        "Watch YouTube",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white),
                    autofocus: true,
                    textInputAction: TextInputAction.go,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      hintText: "Paste YouTube Link...",
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      errorText: _errorText,
                      filled: true,
                      fillColor: const Color(0xFF2C2C2C),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.redAccent),
                      ),
                      // 3. FIXED: Replaced IconButton with InkWell to avoid Tooltip/Overlay crash
                      suffixIcon: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: _pasteFromClipboard,
                          child: const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: Icon(Icons.paste, color: Colors.white70),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: widget.onCancel,
                        child: const Text(
                          "Cancel",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: _submit,
                        child: const Text("Play Video"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
