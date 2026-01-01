import 'package:flutter/material.dart';

class MiniIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  
  const MiniIconButton({
    super.key, 
    required this.icon, 
    required this.color, 
    required this.onTap
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

class GlassButton extends StatelessWidget {
  final IconData icon;
  final bool isRed;
  final VoidCallback onTap;
  
  const GlassButton({
    super.key, 
    required this.icon, 
    this.isRed = false, 
    required this.onTap
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isRed ? Colors.redAccent : Colors.white,
          size: 22,
        ),
      ),
    );
  }
}