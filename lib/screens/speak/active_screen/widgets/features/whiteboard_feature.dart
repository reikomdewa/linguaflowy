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
enum ToolMode { pen, text, eraser }

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

  // -- Drawing State --
  List<DrawPoint> _currentStrokePoints = [];

  // -- Text Input State --
  Offset? _typingPosition;
  final TextEditingController _textController = TextEditingController();

  // -- Dragging State --
  String? _draggedObjectId;
  Offset _dragOffset =
      Offset.zero; // Difference between touch point and object origin

  // -- OPTIMISTIC UI STATE --
  final List<WhiteboardObject> _optimisticObjects = [];

  // -- UNDO HISTORY --
  final List<String> _myActionHistoryIds = [];

  // Stores current list for Hit Testing
  List<WhiteboardObject> _hitTestableObjects = [];

  bool get _isMyBoard => widget.manager.activeFeatureData == _currentUserId;
  bool get _isHost => widget.manager.roomData?.hostId == _currentUserId;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  // --- UNDO LOGIC ---
  void _undoLastAction() {
    if (_myActionHistoryIds.isEmpty || widget.manager.roomData == null) return;

    final lastId = _myActionHistoryIds.removeLast();

    setState(() {
      _optimisticObjects.removeWhere((obj) => obj.id == lastId);
    });

    _service.deleteObject(widget.manager.roomData!.id, _currentUserId, lastId);
  }

  // --- PAN LOGIC (Pen & Eraser) ---
  void _onPanStart(DragStartDetails details) {
    if (!_isMyBoard) return;
    if (_typingPosition != null) _finalizeText();

    if (_currentTool == ToolMode.pen) {
      setState(() {
        _currentStrokePoints = [DrawPoint(offset: details.localPosition)];
      });
    } else if (_currentTool == ToolMode.eraser) {
      _checkEraserHit(details.localPosition);
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isMyBoard) return;

    if (_currentTool == ToolMode.pen) {
      setState(() {
        _currentStrokePoints.add(DrawPoint(offset: details.localPosition));
      });
    } else if (_currentTool == ToolMode.eraser) {
      _checkEraserHit(details.localPosition);
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_isMyBoard) return;

    if (_currentTool == ToolMode.pen && _currentStrokePoints.isNotEmpty) {
      if (widget.manager.roomData == null) return;

      final object = WhiteboardObject(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: WhiteboardItemType.stroke,
        points: List.from(_currentStrokePoints),
        createdAt: DateTime.now(),
        colorValue: _selectedColor.value,
        strokeWidth: _strokeWidth,
      );

      setState(() {
        _optimisticObjects.add(object);
        _myActionHistoryIds.add(object.id);
        _currentStrokePoints.clear();
      });

      _service.addObject(widget.manager.roomData!.id, _currentUserId, object);
    }
  }

  // --- HELPER: GET BOUNDING BOX FOR TEXT ---
  Rect _getTextBoundingBox(WhiteboardObject obj) {
    if (obj.text == null) return Rect.zero;

    final textSpan = TextSpan(
      text: obj.text,
      style: TextStyle(
        fontSize: obj.fontSize,
        fontFamily: 'Roboto',
        fontWeight: FontWeight.w500,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(); // Calculate size

    // Create rectangle at position with calculated size
    return Rect.fromLTWH(
      obj.position.dx,
      obj.position.dy,
      textPainter.width,
      textPainter.height,
    );
  }

  // --- LONG PRESS LOGIC (DRAG TEXT) ---
  void _onLongPressStart(LongPressStartDetails details) {
    if (!_isMyBoard) return;

    final touchPos = details.localPosition;

    for (var obj in _hitTestableObjects) {
      if (obj.type == WhiteboardItemType.text) {
        // Calculate exact bounding box of the text
        final rect = _getTextBoundingBox(obj);

        // Add some padding (inflation) to make it easier to grab
        final hitRect = rect.inflate(20.0);

        if (hitRect.contains(touchPos)) {
          setState(() {
            _draggedObjectId = obj.id;
            // Store the offset so the text doesn't snap to center of finger
            _dragOffset = touchPos - obj.position;
          });
          break;
        }
      }
    }
  }

  void _onLongPressUpdate(LongPressMoveUpdateDetails details) {
    if (!_isMyBoard || _draggedObjectId == null) return;

    // Calculate new Top-Left position based on finger position minus initial offset
    final newPos = details.localPosition - _dragOffset;

    setState(() {
      // Find object in optimistic list
      final index = _optimisticObjects.indexWhere(
        (o) => o.id == _draggedObjectId,
      );

      // If found in local optimistic list, update it there
      if (index != -1) {
        final oldObj = _optimisticObjects[index];
        final newObj = WhiteboardObject(
          id: oldObj.id,
          type: oldObj.type,
          createdAt: oldObj.createdAt,
          colorValue: oldObj.colorValue,
          position: newPos,
          text: oldObj.text,
          fontSize: oldObj.fontSize,
          points: oldObj.points,
          strokeWidth: oldObj.strokeWidth,
        );
        _optimisticObjects[index] = newObj;
      } else {
        // If not in optimistic list (it came from server), we need to create a copy and add it
        // so we can see it moving locally immediately.
        final serverObj = _hitTestableObjects.firstWhere(
          (o) => o.id == _draggedObjectId,
        );
        final newObj = WhiteboardObject(
          id: serverObj.id,
          type: serverObj.type,
          createdAt: serverObj.createdAt,
          colorValue: serverObj.colorValue,
          position: newPos,
          text: serverObj.text,
          fontSize: serverObj.fontSize,
          points: serverObj.points,
          strokeWidth: serverObj.strokeWidth,
        );
        _optimisticObjects.add(newObj);
      }
    });
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    if (!_isMyBoard || _draggedObjectId == null) return;

    // Find final position
    final obj = _optimisticObjects.firstWhere(
      (o) => o.id == _draggedObjectId,
      orElse: () => WhiteboardObject(
        id: '',
        type: WhiteboardItemType.text,
        createdAt: DateTime.now(),
        colorValue: 0,
      ),
    );

    if (obj.id.isNotEmpty && widget.manager.roomData != null) {
      _service.updateObjectPosition(
        widget.manager.roomData!.id,
        _currentUserId,
        obj.id,
        obj.position.dx,
        obj.position.dy,
      );
    }

    setState(() {
      _draggedObjectId = null;
      _dragOffset = Offset.zero;
    });
  }

  // --- ERASER LOGIC ---
  void _checkEraserHit(Offset touchPos) {
    if (widget.manager.roomData == null) return;

    const double strokeHitRadius = 20.0;

    for (var obj in _hitTestableObjects) {
      bool hit = false;

      if (obj.type == WhiteboardItemType.stroke && obj.points != null) {
        for (var point in obj.points!) {
          if ((point.offset - touchPos).distance <= strokeHitRadius) {
            hit = true;
            break;
          }
        }
      } else if (obj.type == WhiteboardItemType.text) {
        // Use the same robust bounding box logic for eraser
        final rect = _getTextBoundingBox(obj);
        final hitRect = rect.inflate(20.0); // Inflate for easier erasing
        if (hitRect.contains(touchPos)) {
          hit = true;
        }
      }

      if (hit) {
        setState(() {
          _optimisticObjects.removeWhere((x) => x.id == obj.id);
          _myActionHistoryIds.remove(obj.id);
        });
        _service.deleteObject(
          widget.manager.roomData!.id,
          _currentUserId,
          obj.id,
        );
        break;
      }
    }
  }

  // --- TEXT LOGIC (In-Place) ---

  void _onTapUp(TapUpDetails details) {
    if (!_isMyBoard || _currentTool != ToolMode.text) return;

    setState(() {
      _typingPosition = details.localPosition;
      _textController.clear();
    });
  }

  void _finalizeText() {
    if (_typingPosition == null || widget.manager.roomData == null) return;

    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      final object = WhiteboardObject(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: WhiteboardItemType.text,
        createdAt: DateTime.now(),
        colorValue: _selectedColor.value,
        position: _typingPosition!,
        text: text,
        fontSize: 24.0,
      );

      setState(() {
        _optimisticObjects.add(object);
        _myActionHistoryIds.add(object.id);
      });

      _service.addObject(widget.manager.roomData!.id, _currentUserId, object);
    }

    _cancelTyping();
  }

  void _cancelTyping() {
    setState(() {
      _typingPosition = null;
      _textController.clear();
    });
  }

  // --- ACTIONS ---

  void _clearMyBoard() {
    if (widget.manager.roomData == null) return;
    setState(() {
      _optimisticObjects.clear();
      _myActionHistoryIds.clear();
      _cancelTyping();
    });
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

    if (streamerId.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (widget.manager.roomData == null) {
      return const Center(child: Text("Room data unavailable"));
    }

    final bool isTextMode = _currentTool == ToolMode.text;

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
                if (snapshot.connectionState == ConnectionState.waiting &&
                    _optimisticObjects.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                final serverObjects = snapshot.data ?? [];

                // Filter out optimistic objects that are already in the server list (to avoid duplicates)
                // EXCEPT if we are currently dragging that object (we want our local dragging version to win)
                final pendingObjects = _optimisticObjects.where((opt) {
                  if (_draggedObjectId == opt.id)
                    return true; // Always show dragging object
                  return !serverObjects.any((server) => server.id == opt.id);
                }).toList();

                // If we are dragging, we hide the server version of the dragged object
                final displayServerObjects = serverObjects
                    .where((s) => s.id != _draggedObjectId)
                    .toList();

                final allObjects = [...displayServerObjects, ...pendingObjects];

                if (_isMyBoard) {
                  _hitTestableObjects = allObjects;
                }

                return CustomPaint(
                  painter: StreamWhiteboardPainter(
                    objects: allObjects,
                    currentDraftPoints: _currentStrokePoints,
                    currentDraftColor: _selectedColor,
                    currentDraftWidth: _strokeWidth,
                    isEraser: _currentTool == ToolMode.eraser,
                  ),
                  size: Size.infinite,
                );
              },
            ),
          ),

          // 2. INPUT LAYER
          if (_isMyBoard && _typingPosition == null)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,

                // Drawing/Erasing
                onPanStart: isTextMode ? null : _onPanStart,
                onPanUpdate: isTextMode ? null : _onPanUpdate,
                onPanEnd: isTextMode ? null : _onPanEnd,

                // Text Input
                onTapUp: isTextMode ? _onTapUp : null,

                // Dragging Text (Long Press) - Works in ANY mode
                onLongPressStart: _onLongPressStart,
                onLongPressMoveUpdate: _onLongPressUpdate,
                onLongPressEnd: _onLongPressEnd,

                child: Container(color: Colors.transparent),
              ),
            ),

          // 3. IN-PLACE TEXT FIELD
          if (_typingPosition != null) _buildFloatingInput(context),

          // 4. UI LAYERS
          _buildTopBar(streamerId),

          if (_isMyBoard) _buildTools(),
        ],
      ),
    );
  }

  Widget _buildFloatingInput(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double tapX = _typingPosition!.dx;
    final double tapY = _typingPosition!.dy;

    double leftPos = tapX;
    double widthConstraint = screenWidth - tapX - 16;

    if (widthConstraint < 150) {
      leftPos = screenWidth - 220;
      widthConstraint = 200;
    }

    return Positioned(
      left: leftPos,
      top: tapY - 20,
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(minWidth: 100, maxWidth: widthConstraint),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [const BoxShadow(color: Colors.black26, blurRadius: 4)],
            border: Border.all(color: Colors.blueAccent),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: TextField(
                  controller: _textController,
                  autofocus: true,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  style: TextStyle(
                    color: _selectedColor,
                    fontSize: 24,
                    fontFamily: 'Roboto',
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: _finalizeText,
                    child: const Icon(Icons.check, color: Colors.green),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _cancelTyping,
                    child: const Icon(Icons.close, color: Colors.red),
                  ),
                ],
              ),
            ],
          ),
        ),
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                _toolBtn(Icons.edit, ToolMode.pen),
                const SizedBox(width: 4),
                _toolBtn(Icons.text_fields, ToolMode.text),
                const SizedBox(width: 4),
                _toolBtn(Icons.auto_fix_normal, ToolMode.eraser),

                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 1,
                  height: 20,
                  color: Colors.white24,
                ),

                _colorBtn(Colors.black),
                const SizedBox(width: 6),
                _colorBtn(Colors.red),
                const SizedBox(width: 6),
                _colorBtn(Colors.blue),
                const SizedBox(width: 6),
                _colorBtn(Colors.green),

                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 1,
                  height: 20,
                  color: Colors.white24,
                ),

                GestureDetector(
                  onTap: _undoLastAction,
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(Icons.undo, color: Colors.white, size: 22),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _clearMyBoard,
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                      size: 22,
                    ),
                  ),
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
        child: Icon(
          icon,
          color: isSelected ? Colors.white : Colors.grey,
          size: 20,
        ),
      ),
    );
  }

  Widget _colorBtn(Color color) {
    bool isSelected = _selectedColor == color;
    return GestureDetector(
      onTap: () => setState(() => _selectedColor = color),
      child: Container(
        width: 20,
        height: 20,
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
  final bool isEraser;

  StreamWhiteboardPainter({
    required this.objects,
    required this.currentDraftPoints,
    required this.currentDraftColor,
    required this.currentDraftWidth,
    this.isEraser = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
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
            fontWeight: FontWeight.w500,
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

    if (currentDraftPoints.isNotEmpty && !isEraser) {
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
