import 'dart:async';
import 'dart:convert';
import 'package:livekit_client/livekit_client.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:uuid/uuid.dart';

class ChatService {
  // Singleton pattern (optional, but useful if you want global access)
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  Room? _room;
  final _uuid = const Uuid();
  
  // Stream to feed the UI
  final _messagesController = StreamController<List<types.Message>>.broadcast();
  Stream<List<types.Message>> get messagesStream => _messagesController.stream;

  // Internal state
  final List<types.Message> _messages = [];

  /// Initialize the service when joining a Room
  void connect(Room room) {
    _room = room;
    _messages.clear();
    _messagesController.add([]); // Reset UI

    // Listen for incoming data from LiveKit
    room.events.listen((event) {
      if (event is DataReceivedEvent) {
        _onDataReceived(event);
      }
    });
  }

  /// Clean up when leaving
  void disconnect() {
    _room = null;
    _messages.clear();
    // We don't close the stream controller here so the service can be reused
  }

  /// Send a message to the room
  Future<void> sendMessage(String text) async {
    if (_room == null || _room!.localParticipant == null) return;

    final localParticipant = _room!.localParticipant!;
    final now = DateTime.now().millisecondsSinceEpoch;
    final messageId = _uuid.v4();

    // 1. Create the Local Message Object
    final user = types.User(
      id: localParticipant.identity, // Use LiveKit identity as ID
      firstName: localParticipant.name.isNotEmpty ? localParticipant.name : 'Me',
    );

    final textMessage = types.TextMessage(
      author: user,
      createdAt: now,
      id: messageId,
      text: text,
    );

    // 2. Add to local UI immediately
    _addMessageToUi(textMessage);

    // 3. Prepare payload for network (LiveKit sends bytes)
    final payload = {
      'id': messageId,
      'text': text,
      'senderId': user.id,
      'senderName': user.firstName,
      'createdAt': now,
    };
    
    // 4. Publish to LiveKit Room
    try {
      await localParticipant.publishData(
        utf8.encode(jsonEncode(payload)),
        reliable: true, // Reliable = TCP-like (good for chat)
      );
    } catch (e) {
      print('Error sending message: $e');
      // Optionally mark message as failed in UI
    }
  }

  /// Handle incoming LiveKit data
  void _onDataReceived(DataReceivedEvent event) {
    try {
      final String decoded = utf8.decode(event.data);
      final Map<String, dynamic> payload = jsonDecode(decoded);

      // Create User from sender info
      final senderIdentity = event.participant?.identity ?? payload['senderId'] ?? 'unknown';
      final senderName = event.participant?.name ?? payload['senderName'] ?? 'User';

      final user = types.User(
        id: senderIdentity,
        firstName: senderName,
      );

      final textMessage = types.TextMessage(
        author: user,
        createdAt: payload['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
        id: payload['id'] ?? _uuid.v4(),
        text: payload['text'] ?? '',
      );

      _addMessageToUi(textMessage);
    } catch (e) {
      print('Failed to parse chat message: $e');
    }
  }

  void _addMessageToUi(types.Message message) {
    // flutter_chat_ui expects newest messages at index 0
    _messages.insert(0, message); 
    _messagesController.add(List.from(_messages));
  }
}