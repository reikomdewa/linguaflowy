import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum WhiteboardItemType { stroke, text }

class DrawPoint {
  final Offset offset;
  
  DrawPoint({required this.offset});

  Map<String, dynamic> toMap() {
    return {
      'x': offset.dx,
      'y': offset.dy,
    };
  }

  factory DrawPoint.fromMap(Map<String, dynamic> map) {
    return DrawPoint(
      offset: Offset((map['x'] as num).toDouble(), (map['y'] as num).toDouble()),
    );
  }
}

class WhiteboardObject {
  final String id;
  final WhiteboardItemType type;
  final DateTime createdAt;
  
  // COMMON PROPERTIES
  final int colorValue;
  final Offset position; // Used as starting point for text

  // STROKE SPECIFIC
  final List<DrawPoint>? points;
  final double strokeWidth;

  // TEXT SPECIFIC
  final String? text;
  final double fontSize;

  WhiteboardObject({
    required this.id,
    required this.type,
    required this.createdAt,
    required this.colorValue,
    this.position = Offset.zero,
    this.points,
    this.strokeWidth = 3.0,
    this.text,
    this.fontSize = 20.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type.name, // 'stroke' or 'text'
      'createdAt': Timestamp.fromDate(createdAt),
      'color': colorValue,
      'posX': position.dx,
      'posY': position.dy,
      // Stroke Data
      'points': points?.map((p) => p.toMap()).toList(),
      'strokeWidth': strokeWidth,
      // Text Data
      'text': text,
      'fontSize': fontSize,
    };
  }

  factory WhiteboardObject.fromMap(Map<String, dynamic> map, String id) {
    return WhiteboardObject(
      id: id,
      type: WhiteboardItemType.values.firstWhere(
        (e) => e.name == map['type'], 
        orElse: () => WhiteboardItemType.stroke
      ),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      colorValue: map['color'] ?? Colors.black.value,
      position: Offset(
        (map['posX'] as num?)?.toDouble() ?? 0.0,
        (map['posY'] as num?)?.toDouble() ?? 0.0,
      ),
      points: map['points'] != null 
          ? (map['points'] as List<dynamic>).map((p) => DrawPoint.fromMap(p)).toList() 
          : [],
      strokeWidth: (map['strokeWidth'] as num?)?.toDouble() ?? 3.0,
      text: map['text'],
      fontSize: (map['fontSize'] as num?)?.toDouble() ?? 20.0,
    );
  }
}