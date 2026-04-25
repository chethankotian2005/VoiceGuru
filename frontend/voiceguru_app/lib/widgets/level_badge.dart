import 'package:flutter/material.dart';

class LevelBadge extends StatelessWidget {
  final int level;
  
  const LevelBadge({super.key, required this.level});

  String get _badgeText {
    switch (level) {
      case 5: return '🌟 Master';
      case 4: return '🔬 Explorer';
      case 3: return '📚 Scholar';
      case 2: return '🌿 Learner';
      case 1:
      default: return '🌱 Sprout';
    }
  }

  Color get _badgeColor {
    switch (level) {
      case 5: return Colors.amber;
      case 4: return Colors.purple;
      case 3: return Colors.blue;
      case 2: return Colors.green;
      case 1:
      default: return Colors.lightGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _badgeColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Lv.$level',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: _badgeColor.withValues(alpha: 1.0),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            _badgeText,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: _badgeColor.withValues(alpha: 1.0),
            ),
          ),
        ],
      ),
    );
  }
}
