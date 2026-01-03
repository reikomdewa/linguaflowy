import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:linguaflow/blocs/speak/room/room_bloc.dart';
import 'package:linguaflow/blocs/speak/room/room_event.dart';
import 'package:linguaflow/blocs/speak/whiteboard_models.dart';
import 'package:linguaflow/models/speak/room_member.dart';
import 'package:linguaflow/services/speak/whiteboard_service.dart';
import 'package:linguaflow/screens/speak/active_screen/managers/room_global_manager.dart';

// Tool Modes
enum ToolMode { pen, text }

class CollaborativeWhiteboard extends StatefulWidget {
  final RoomGlobalManager manager;

  const CollaborativeWhiteboard({super.key, required this.manager});

  @override
  State<CollaborativeWhiteboard> createState() =>
      _CollaborativeWhiteboardState();
}

class _CollaborativeWhiteboardState extends State<CollaborativeWhiteboard> {
  final WhiteboardService _service = WhiteboardService();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  // State
  ToolMode _currentTool = ToolMode.pen;
  Color _selectedColor = Colors.black;
  double _strokeWidth = 3.0;

  // Local Drawing State (For smooth pen feedback)
  List<DrawPoint> _currentStrokePoints = [];

  bool get _isMyBoard => widget.manager.activeFeatureData == _currentUserId;
  bool get _isHost => widget.manager.roomData?.hostId == _currentUserId;

  // --- PEN LOGIC ---

  void _onPanStart(DragStartDetails details) {
    if (!_isMyBoard || _currentTool != ToolMode.pen) return;
    setState(() {
      _currentStrokePoints = [DrawPoint(offset: details.localPosition)];
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isMyBoard || _currentTool != ToolMode.pen) return;
    setState(() {
      _currentStrokePoints.add(DrawPoint(offset: details.localPosition));
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_isMyBoard || _currentTool != ToolMode.pen) return;

    if (_currentStrokePoints.isNotEmpty) {
      if (widget.manager.roomData == null) return;

      final object = WhiteboardObject(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: WhiteboardItemType.stroke,
        points: List.from(_currentStrokePoints),
        createdAt: DateTime.now(),
        colorValue: _selectedColor.value,
        strokeWidth: _strokeWidth,
      );

      _service.addObject(widget.manager.roomData!.id, _currentUserId, object);

      setState(() {
        _currentStrokePoints.clear();
      });
    }
  }

  // --- TEXT LOGIC ---

  void _onTapUp(TapUpDetails details) {
    if (!_isMyBoard || _currentTool != ToolMode.text) return;
    _showTextInputDialog(details.localPosition);
  }

  void _showTextInputDialog(Offset position) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: const Text("Enter Text", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "Type here...",
            hintStyle: TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                _addTextObject(controller.text, position);
              }
              Navigator.pop(ctx);
            },
            child: const Text("Place"),
          ),
        ],
      ),
    );
  }

  void _addTextObject(String text, Offset pos) {
    if (widget.manager.roomData == null) return;

    final object = WhiteboardObject(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: WhiteboardItemType.text,
      createdAt: DateTime.now(),
      colorValue: _selectedColor.value,
      position: pos,
      text: text,
      fontSize: 24.0,
    );
    _service.addObject(widget.manager.roomData!.id, _currentUserId, object);
  }

  // --- ACTIONS ---

  void _clearMyBoard() {
    if (widget.manager.roomData == null) return;
    _service.clearBoard(widget.manager.roomData!.id, _currentUserId);
  }

  void _closeBoard() {
    if (widget.manager.roomData == null) return;
    context.read<RoomBloc>().add(
      StopBoardSharingEvent(widget.manager.roomData!.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String streamerId = widget.manager.activeFeatureData ?? '';

    // --- CRITICAL FIX: PREVENT CRASH ---
    // Firestore will crash if we pass an empty string as a document ID.
    // We show a loading spinner until the ID is synced.
    if (streamerId.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.black),
      );
    }

    if (widget.manager.roomData == null) {
      return const Center(child: Text("Room data unavailable"));
    }

    return Container(
      color: Colors.white,
      child: Stack(
        children: [
          // 1. STREAM LAYER
          Positioned.fill(
            child: StreamBuilder<List<WhiteboardObject>>(
              stream: _service.streamObjects(
                widget.manager.roomData!.id,
                streamerId,
              ),
              builder: (context, snapshot) {
                // Handle loading state gracefully
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final savedObjects = snapshot.data ?? [];

                return CustomPaint(
                  painter: StreamWhiteboardPainter(
                    objects: savedObjects,
                    currentDraftPoints: _currentStrokePoints,
                    currentDraftColor: _selectedColor,
                    currentDraftWidth: _strokeWidth,
                  ),
                  size: Size.infinite,
                );
              },
            ),
          ),

          // 2. INPUT LAYER
          if (_isMyBoard)
            Positioned.fill(
              child: GestureDetector(
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                onTapUp: _onTapUp,
                child: Container(color: Colors.transparent),
              ),
            ),

          // 3. UI LAYERS
          _buildTopBar(streamerId),

          if (_isMyBoard) _buildTools(),
        ],
      ),
    );
  }

  Widget _buildTopBar(String streamerId) {
    String name = "Whiteboard";
    final member = widget.manager.roomData?.members.firstWhere(
      (m) => m.uid == streamerId,
      orElse: () => RoomMember(
        uid: '',
        displayName: 'Unknown',
        joinedAt: DateTime.now(),
        isHost: false,
        xp: 0,
      ),
    );
    if (member?.uid.isNotEmpty == true) {
      name = "${member!.displayName}'s Board";
    }

    return Positioned(
      top: 10,
      left: 10,
      right: 10,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.edit_note, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            if (_isHost || _isMyBoard)
              GestureDetector(
                onTap: _closeBoard,
                child: const Icon(Icons.close, color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTools() {
    return Positioned(
      bottom: 20,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [const BoxShadow(color: Colors.black26, blurRadius: 10)],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Tools
                _toolBtn(Icons.edit, ToolMode.pen),
                const SizedBox(width: 8),
                _toolBtn(Icons.text_fields, ToolMode.text),

                const SizedBox(width: 16),
                Container(width: 1, height: 24, color: Colors.grey),
                const SizedBox(width: 16),

                // Colors
                _colorBtn(Colors.black),
                const SizedBox(width: 8),
                _colorBtn(Colors.red),
                const SizedBox(width: 8),
                _colorBtn(Colors.blue),
                const SizedBox(width: 8),
                _colorBtn(Colors.green),

                const SizedBox(width: 16),
                Container(width: 1, height: 24, color: Colors.grey),
                const SizedBox(width: 16),

                GestureDetector(
                  onTap: _clearMyBoard,
                  child: const Icon(Icons.delete_outline, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _toolBtn(IconData icon, ToolMode mode) {
    final isSelected = _currentTool == mode;
    return GestureDetector(
      onTap: () => setState(() => _currentTool = mode),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white24 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: isSelected ? Colors.white : Colors.grey),
      ),
    );
  }

  Widget _colorBtn(Color color) {
    bool isSelected = _selectedColor == color;
    return GestureDetector(
      onTap: () => setState(() => _selectedColor = color),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
        ),
      ),
    );
  }
}

class StreamWhiteboardPainter extends CustomPainter {
  final List<WhiteboardObject> objects;
  final List<DrawPoint> currentDraftPoints;
  final Color currentDraftColor;
  final double currentDraftWidth;

  StreamWhiteboardPainter({
    required this.objects,
    required this.currentDraftPoints,
    required this.currentDraftColor,
    required this.currentDraftWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Paint Saved Objects
    for (var obj in objects) {
      if (obj.type == WhiteboardItemType.stroke &&
          obj.points != null &&
          obj.points!.isNotEmpty) {
        final paint = Paint()
          ..color = Color(obj.colorValue)
          ..strokeWidth = obj.strokeWidth
          ..strokeCap = StrokeCap.round
          ..isAntiAlias = true;

        for (int i = 0; i < obj.points!.length - 1; i++) {
          final p1 = obj.points![i].offset;
          final p2 = obj.points![i + 1].offset;
          canvas.drawLine(p1, p2, paint);
        }
      } else if (obj.type == WhiteboardItemType.text && obj.text != null) {
        final textSpan = TextSpan(
          text: obj.text,
          style: TextStyle(
            color: Color(obj.colorValue),
            fontSize: obj.fontSize,
            fontFamily: 'Roboto',
          ),
        );
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout(minWidth: 0, maxWidth: size.width);
        textPainter.paint(canvas, obj.position);
      }
    }

    // 2. Paint Current Local Draft (Stroke only)
    if (currentDraftPoints.isNotEmpty) {
      final paint = Paint()
        ..color = currentDraftColor
        ..strokeWidth = currentDraftWidth
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true;

      for (int i = 0; i < currentDraftPoints.length - 1; i++) {
        final p1 = currentDraftPoints[i].offset;
        final p2 = currentDraftPoints[i + 1].offset;
        canvas.drawLine(p1, p2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
