import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ContentCMSTab extends StatefulWidget {
  const ContentCMSTab({super.key});

  @override
  State<ContentCMSTab> createState() => _ContentCMSTabState();
}

class _ContentCMSTabState extends State<ContentCMSTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchText = "";
  
  // Open the Editor Dialog
  void _openEditor(BuildContext context, [DocumentSnapshot? doc]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _LessonEditorDialog(doc: doc),
    );
  }

  void _deleteLesson(String docId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Lesson?"),
        content: const Text("This cannot be undone."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              FirebaseFirestore.instance
                  .collection('lessons')
                  .doc(docId)
                  .delete();
              Navigator.pop(ctx);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SEARCH LOGIC
  // ---------------------------------------------------------------------------

  // 1. Dynamic Stream based on Search Text
  Stream<QuerySnapshot> _getStream() {
    CollectionReference lessonsRef = FirebaseFirestore.instance.collection('lessons');

    if (_searchText.isEmpty) {
      // DEFAULT: Show latest 50 created
      return lessonsRef
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots();
    } else {
      // SEARCH: Find titles starting with _searchText
      // Note: Firestore is Case Sensitive! "Can" != "can"
      return lessonsRef
          .orderBy('title')
          .startAt([_searchText])
          .endAt(['$_searchText\uf8ff'])
          .snapshots();
    }
  }

  // 2. Exact ID Search (Because you can't query ID and Title in the same stream easily)
  Future<void> _searchById() async {
    if (_searchCtrl.text.isEmpty) return;
    
    // Clear the stream list so we don't show confusing data while fetching
    setState(() => _searchText = "___ID_SEARCH_MODE___"); 

    final docRef = FirebaseFirestore.instance.collection('lessons').doc(_searchCtrl.text.trim());
    final snapshot = await docRef.get();

    if (!mounted) return;

    if (snapshot.exists) {
      // If found, immediately open the editor
      _openEditor(context, snapshot);
      // Reset search so the list comes back
      _searchCtrl.clear();
      setState(() => _searchText = "");
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No lesson found with that exact ID.")),
      );
      // Go back to normal list
      _searchCtrl.clear();
      setState(() => _searchText = "");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        backgroundColor: Colors.amber,
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text("Add Lesson", style: TextStyle(color: Colors.black)),
      ),
      body: Column(
        children: [
          // -------------------------------------------------------------------
          // SEARCH BAR
          // -------------------------------------------------------------------
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: "Search Title (Case Sensitive)...",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_searchText.isNotEmpty && _searchText != "___ID_SEARCH_MODE___")
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchText = "");
                        },
                      ),
                    // Specific ID Search Button
                    Tooltip(
                      message: "Find by Exact ID",
                      child: IconButton(
                        icon: const Icon(Icons.tag, color: Colors.blue),
                        onPressed: _searchById,
                      ),
                    ),
                  ],
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: isDark ? Colors.white10 : Colors.grey[100],
              ),
              onChanged: (val) {
                setState(() {
                  _searchText = val;
                });
              },
            ),
          ),

          // -------------------------------------------------------------------
          // RESULT LIST
          // -------------------------------------------------------------------
          Expanded(
            child: _searchText == "___ID_SEARCH_MODE___" 
            ? const Center(child: CircularProgressIndicator()) 
            : StreamBuilder<QuerySnapshot>(
              stream: _getStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off, size: 48, color: Colors.grey),
                        const SizedBox(height: 10),
                        Text(
                          _searchText.isEmpty 
                              ? "No lessons found." 
                              : "No matches for '$_searchText'",
                          style: const TextStyle(color: Colors.grey),
                        ),
                        if (_searchText.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: const Text(
                              "Tip: Search is Case Sensitive.\nTry capitalizing the first letter.",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          )
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final title = data['title'] ?? 'Untitled';
                    final lang = data['language'] ?? '??';
                    final diff = data['difficulty'] ?? 'unknown';

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.grey[200],
                          child: Text(lang.toString().toUpperCase(),
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black)),
                        ),
                        title: Text(title,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: SelectableText("$diff • ${doc.id}", 
                            maxLines: 1),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _openEditor(context, doc),
                            ),
                            IconButton(
                              icon:
                                  const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _deleteLesson(doc.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// EDITOR DIALOG
// -----------------------------------------------------------------------------
class _LessonEditorDialog extends StatefulWidget {
  final DocumentSnapshot? doc;
  const _LessonEditorDialog({this.doc});

  @override
  State<_LessonEditorDialog> createState() => _LessonEditorDialogState();
}

class _LessonEditorDialogState extends State<_LessonEditorDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleCtrl;
  late TextEditingController _contentCtrl;
  late TextEditingController _videoUrlCtrl;
  late TextEditingController _imageUrlCtrl;
  late TextEditingController _jsonTranscriptCtrl;

  String _language = 'fr';
  String _difficulty = 'intermediate';

  @override
  void initState() {
    super.initState();
    final data = widget.doc?.data() as Map<String, dynamic>?;

    _titleCtrl = TextEditingController(text: data?['title'] ?? '');
    _contentCtrl = TextEditingController(text: data?['content'] ?? '');
    _videoUrlCtrl = TextEditingController(text: data?['videoUrl'] ?? '');
    _imageUrlCtrl = TextEditingController(text: data?['imageUrl'] ?? '');
    _language = data?['language'] ?? 'fr';
    _difficulty = data?['difficulty'] ?? 'intermediate';

    // Handle Transcript (Convert List<dynamic> to formatted JSON string for editing)
    if (data != null &&
        data['transcript'] != null &&
        data['transcript'] is List) {
      try {
        const encoder = JsonEncoder.withIndent('  ');
        _jsonTranscriptCtrl =
            TextEditingController(text: encoder.convert(data['transcript']));
      } catch (e) {
        _jsonTranscriptCtrl = TextEditingController(text: "[]");
      }
    } else {
      _jsonTranscriptCtrl = TextEditingController(text: "[]");
    }
  }

  // ---------------------------------------------------------------------------
  // SUBTITLE PARSER LOGIC
  // ---------------------------------------------------------------------------
  void _convertSubtitleFormat() {
    final text = _jsonTranscriptCtrl.text;
    if (text.isEmpty) return;

    try {
      final List<Map<String, dynamic>> parsed = [];

      // Regex to find timestamps: 00:00:23,859 or 00:00:23.859
      // Group 1: Start Time, Group 2: End Time
      final RegExp timeReg = RegExp(
          r'(\d{2}:\d{2}:\d{2}[,.]\d{3})\s*-->\s*(\d{2}:\d{2}:\d{2}[,.]\d{3})');

      // Split by double newlines (standard block separator in SRT/VTT)
      final blocks = text.split(RegExp(r'\n\s*\n'));

      for (var block in blocks) {
        final match = timeReg.firstMatch(block);
        if (match != null) {
          final startStr = match.group(1)!;
          final endStr = match.group(2)!;

          // Get text: Everything after the timestamp line
          // We split the block by newlines, find the line with -->, take everything after
          final lines = block.split('\n');
          String content = "";
          bool foundTime = false;

          for (var line in lines) {
            if (line.contains('-->')) {
              foundTime = true;
              continue;
            }
            if (foundTime) {
              // Remove HTML tags often found in VTT like <b> or <c>
              String cleanLine =
                  line.replaceAll(RegExp(r'<[^>]*>'), '').trim();
              if (cleanLine.isNotEmpty &&
                  !RegExp(r'^\d+$').hasMatch(cleanLine)) {
                content += "$cleanLine ";
              }
            }
          }

          if (content.isNotEmpty) {
            parsed.add({
              "start": _parseTime(startStr),
              "end": _parseTime(endStr),
              "text": content.trim(),
            });
          }
        }
      }

      if (parsed.isNotEmpty) {
        const encoder = JsonEncoder.withIndent('  ');
        setState(() {
          _jsonTranscriptCtrl.text = encoder.convert(parsed);
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("Converted ${parsed.length} lines to JSON!")));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Could not find SRT/VTT timestamps.")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error parsing: $e")));
    }
  }

  // Helper: 00:00:23,859 -> 23.859 (double)
  double _parseTime(String timeStr) {
    // Replace comma with dot for standardized parsing
    timeStr = timeStr.replaceAll(',', '.');
    final parts = timeStr.split(':');
    final hours = double.parse(parts[0]);
    final minutes = double.parse(parts[1]);
    final seconds = double.parse(parts[2]);
    return (hours * 3600) + (minutes * 60) + seconds;
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    // 1. Auto-generate sentences from Content
    List<String> sentences = _contentCtrl.text
        .split(RegExp(r'(?<=[.!?])\s+')) // Split by punctuation
        .where((s) => s.trim().isNotEmpty)
        .toList();

    // 2. Parse Transcript JSON
    List<dynamic> transcriptList = [];
    try {
      transcriptList = jsonDecode(_jsonTranscriptCtrl.text);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Invalid JSON. Click 'Convert' if you pasted SRT.")));
      return;
    }

    // 3. Prepare Data
    final Map<String, dynamic> data = {
      'title': _titleCtrl.text.trim(),
      'content': _contentCtrl.text.trim(),
      'videoUrl':
          _videoUrlCtrl.text.trim().isEmpty ? null : _videoUrlCtrl.text.trim(),
      'imageUrl':
          _imageUrlCtrl.text.trim().isEmpty ? null : _imageUrlCtrl.text.trim(),
      'language': _language,
      'difficulty': _difficulty,
      'sentences': sentences,
      'transcript': transcriptList,
      'isFavorite': false,
      'progress': 0,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (widget.doc == null) {
      // New Doc
      data['createdAt'] = FieldValue.serverTimestamp();
      data['userId'] = 'admin';

      // Try to determine Custom ID from YouTube URL
      String? customId;
      if (_videoUrlCtrl.text.contains("youtube.com") ||
          _videoUrlCtrl.text.contains("youtu.be")) {
        try {
          String? videoId;
          if (_videoUrlCtrl.text.contains("v=")) {
            videoId = _videoUrlCtrl.text.split('v=')[1].split('&')[0];
          } else if (_videoUrlCtrl.text.contains("youtu.be/")) {
            videoId = _videoUrlCtrl.text.split('youtu.be/')[1];
          }
          if (videoId != null) customId = "yt_$videoId";
        } catch (_) {}
      }

      if (customId != null) {
        await FirebaseFirestore.instance
            .collection('lessons')
            .doc(customId)
            .set(data);
      } else {
        await FirebaseFirestore.instance.collection('lessons').add(data);
      }
    } else {
      // Update Existing
      await widget.doc!.reference.update(data);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      insetPadding: const EdgeInsets.all(10),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(widget.doc == null ? "Add Lesson" : "Edit Lesson",
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close))
                ],
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: TextFormField(
                                controller: _titleCtrl,
                                decoration: const InputDecoration(
                                    labelText: "Title",
                                    border: OutlineInputBorder()),
                                validator: (v) =>
                                    v!.isEmpty ? 'Required' : null)),
                        const SizedBox(width: 10),
                        DropdownButton<String>(
                          value: _language,
                          items: ['fr', 'en', 'ja', 'es', 'de', 'it']
                              .map((l) => DropdownMenuItem(
                                  value: l, child: Text(l.toUpperCase())))
                              .toList(),
                          onChanged: (v) => setState(() => _language = v!),
                        )
                      ],
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(
                            child: TextFormField(
                                controller: _videoUrlCtrl,
                                decoration: const InputDecoration(
                                    labelText: "YouTube URL (Optional)",
                                    border: OutlineInputBorder(),
                                    hintText: "https://youtu.be/..."))),
                        const SizedBox(width: 10),
                        DropdownButton<String>(
                          value: _difficulty,
                          items: ['beginner', 'intermediate', 'advanced']
                              .map((l) => DropdownMenuItem(
                                  value: l, child: Text(l)))
                              .toList(),
                          onChanged: (v) => setState(() => _difficulty = v!),
                        )
                      ],
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                        controller: _imageUrlCtrl,
                        decoration: const InputDecoration(
                            labelText: "Image URL (Optional)",
                            border: OutlineInputBorder())),
                    const SizedBox(height: 15),
                    const Text("Full Content / Story",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    TextFormField(
                      controller: _contentCtrl,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText:
                            "Paste full story text here (for 'sentences' array).",
                      ),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 20),
                    // ---------------------------------------------------------
                    // TRANSCRIPT SECTION WITH CONVERT BUTTON
                    // ---------------------------------------------------------
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Transcript",
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        TextButton.icon(
                          onPressed: _convertSubtitleFormat,
                          icon: const Icon(Icons.auto_fix_high, size: 16),
                          label: const Text("Convert SRT/VTT to JSON"),
                          style: TextButton.styleFrom(
                              foregroundColor: Colors.blue),
                        )
                      ],
                    ),
                    const SizedBox(height: 5),
                    Container(
                      color: isDark ? Colors.black26 : Colors.grey[100],
                      child: TextFormField(
                        controller: _jsonTranscriptCtrl,
                        maxLines: 8,
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 12),
                        decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText:
                                "1\n00:00:01,000 --> 00:00:04,000\nPaste SRT here and click Convert..."),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black),
                  child: const Text("Save Lesson"),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}