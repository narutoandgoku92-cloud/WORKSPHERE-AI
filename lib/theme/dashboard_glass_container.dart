
import 'dart:ui';
import 'package:flutter/material.dart';

class DashboardGlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;

  const DashboardGlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 10,
          sigmaY: 10,
        ),
        child: Container(
          width: width,
          height: height,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.78),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
