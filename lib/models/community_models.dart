import 'package:cloud_firestore/cloud_firestore.dart';

class ForumPost {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorPhoto;
  final String content;
  final String language; // The language being discussed
  final String? audioUrl; // <--- FUTURE PROOF: For voice notes
  final List<String> imageUrls;
  final int likes;
  final int commentCount;
  final DateTime createdAt;
  final List<String> tags; // e.g. "Grammar", "Pronunciation"

  ForumPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorPhoto,
    required this.content,
    required this.language,
    this.audioUrl,
    this.imageUrls = const [],
    this.likes = 0,
    this.commentCount = 0,
    required this.createdAt,
    this.tags = const [],
  });

  factory ForumPost.fromMap(Map<String, dynamic> map, String id) {
    return ForumPost(
      id: id,
      authorId: map['authorId'] ?? '',
      authorName: map['authorName'] ?? 'Anonymous',
      authorPhoto: map['authorPhoto'],
      content: map['content'] ?? '',
      language: map['language'] ?? 'en',
      audioUrl: map['audioUrl'],
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
      likes: map['likes'] ?? 0,
      commentCount: map['commentCount'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      tags: List<String>.from(map['tags'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'authorId': authorId,
      'authorName': authorName,
      'authorPhoto': authorPhoto,
      'content': content,
      'language': language,
      'audioUrl': audioUrl,
      'imageUrls': imageUrls,
      'likes': likes,
      'commentCount': commentCount,
      'createdAt': FieldValue.serverTimestamp(),
      'tags': tags,
    };
  }
}