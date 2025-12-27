import 'dart:async';
import 'dart:convert';
import 'package:livekit_client/livekit_client.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:uuid/uuid.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  Room? _room;
  EventsListener<RoomEvent>? _listener;
  
  // 1. Internal List to keep messages in memory
  final List<types.Message> _messages = [];
  
  final _messagesController = StreamController<List<types.Message>>.broadcast();
  Stream<List<types.Message>> get messagesStream => _messagesController.stream;

  // 2. IMPORTANT FIX: Expose current list for the UI's initialData
  List<types.Message> get currentMessages => List.unmodifiable(_messages);

  void connect(Room room) {
    // 3. FIX: If same room, don't clear messages.
    if (_room != null && _room!.name == room.name) {
      _messagesController.add(List.from(_messages));
      return;
    }

    _room = room;
    _messages.clear();
    _messagesController.add([]); 

    _listener?.dispose();
    _listener = room.createListener();
    _listener!.on<DataReceivedEvent>(_onDataReceived);
  }

  void dispose() {
    _listener?.dispose();
  }

  Future<void> sendMessage(String text) async {
    if (_room == null || _room!.localParticipant == null) return;

    final localParticipant = _room!.localParticipant!;
    final now = DateTime.now().millisecondsSinceEpoch;
    final messageId = const Uuid().v4();

    final user = types.User(
      id: localParticipant.identity, 
      firstName: localParticipant.name.isNotEmpty ? localParticipant.name : 'Me',
    );

    final textMessage = types.TextMessage(
      author: user,
      createdAt: now,
      id: messageId,
      text: text,
    );

    _addMessageToUi(textMessage);

    final payload = {
      'id': messageId,
      'text': text,
      'senderId': user.id,
      'senderName': user.firstName,
      'createdAt': now,
    };
    
    try {
      await localParticipant.publishData(
        utf8.encode(jsonEncode(payload)),
        reliable: true, 
         topic: 'chat',
      );
    } catch (e) {
      print('Error sending message: $e');
    }
  }

  void _onDataReceived(DataReceivedEvent event) {
    try {
      final String decoded = utf8.decode(event.data);
      final Map<String, dynamic> payload = jsonDecode(decoded);

      final senderIdentity = event.participant?.identity ?? payload['senderId'] ?? 'unknown';
      final senderName = event.participant?.name ?? payload['senderName'] ?? 'User';

      final user = types.User(
        id: senderIdentity,
        firstName: senderName,
      );

      final textMessage = types.TextMessage(
        author: user,
        createdAt: payload['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
        id: payload['id'] ?? const Uuid().v4(),
        text: payload['text'] ?? '',
      );

      _addMessageToUi(textMessage);
    } catch (e) {
      print('Failed to parse chat message: $e');
    }
  }

  void _addMessageToUi(types.Message message) {
    _messages.insert(0, message); 
    _messagesController.add(List.from(_messages));
  }
}