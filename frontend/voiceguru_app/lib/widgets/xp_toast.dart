import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class XPToast extends StatelessWidget {
  final VoidCallback onComplete;

  const XPToast({super.key, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 120, // Above input bar
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.amber.shade100,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.amber.shade400, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '+10 XP',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
              SizedBox(width: 8),
              Text('🌟', style: TextStyle(fontSize: 20)),
            ],
          ),
        )
            .animate(onComplete: (_) => onComplete())
            .fadeIn(duration: 300.ms)
            .slideY(begin: 0.5, end: -1.5, duration: 1500.ms, curve: Curves.easeOut)
            .fadeOut(delay: 1000.ms, duration: 500.ms),
      ),
    );
  }
}
