import 'package:flutter/material.dart';

class CenteredView extends StatelessWidget {
  final Widget child;
  final double? leftPadding;
  final double? rightPadding;
  final double horizontalPadding;

  const CenteredView({
    super.key,
    required this.child,
    this.leftPadding,
    this.rightPadding,
    this.horizontalPadding = 200, // Default fallback
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        // Use specific left padding if provided, otherwise use the global horizontal default
        left: leftPadding ?? horizontalPadding, 
        // Use specific right padding if provided, otherwise use the global horizontal default
        right: rightPadding ?? horizontalPadding,
      ),
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: child,
      ),
    );
  }
}