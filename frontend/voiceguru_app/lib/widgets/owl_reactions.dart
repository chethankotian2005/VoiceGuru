import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

enum MascotState { idle, thinking, bouncy, happy, wave }

class MascotWidget extends StatefulWidget {
  final String mascotType;
  final MascotState state;
  final VoidCallback? onWaveCompleted;

  const MascotWidget({
    super.key,
    required this.mascotType,
    required this.state,
    this.onWaveCompleted,
  });

  @override
  State<MascotWidget> createState() => _MascotWidgetState();
}

class _MascotWidgetState extends State<MascotWidget> {
  Timer? _idleTimer;
  bool _isWaving = false;

  @override
  void initState() {
    super.initState();
    _startIdleTimer();
  }

  @override
  void didUpdateWidget(MascotWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state != oldWidget.state) {
      if (widget.state != MascotState.idle) {
        _isWaving = false;
        _cancelIdleTimer();
      } else {
        _startIdleTimer();
      }
    }
  }

  @override
  void dispose() {
    _cancelIdleTimer();
    super.dispose();
  }

  void _startIdleTimer() {
    _cancelIdleTimer();
    if (widget.state == MascotState.idle) {
      _idleTimer = Timer(const Duration(seconds: 30), () {
        if (mounted && widget.state == MascotState.idle) {
          setState(() => _isWaving = true);
        }
      });
    }
  }

  void _cancelIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = null;
  }

  String get _mascotEmoji {
    switch (widget.mascotType) {
      case 'finn': return '🐬';
      case 'leo': return '🦁';
      case 'owl':
      default: return '🦉';
    }
  }

  Color get _stateColor {
    if (_isWaving) return Colors.orange.shade100;
    switch (widget.state) {
      case MascotState.thinking: return Colors.blue.shade100;
      case MascotState.bouncy: return Colors.green.shade100;
      case MascotState.happy: return Colors.purple.shade100;
      case MascotState.idle:
      default: return Colors.grey.shade200;
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveState = _isWaving ? MascotState.wave : widget.state;
    
    Widget content = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: _stateColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        _mascotEmoji,
        style: const TextStyle(fontSize: 24),
      ),
    );

    // Apply animations based on state
    switch (effectiveState) {
      case MascotState.thinking:
        return Stack(
          clipBehavior: Clip.none,
          children: [
            content
                .animate(onPlay: (controller) => controller.repeat(reverse: true))
                .scaleXY(begin: 1.0, end: 1.1, duration: 600.ms),
            Positioned(
              top: -15,
              right: -10,
              child: const Text('🤔', style: TextStyle(fontSize: 16))
                  .animate(onPlay: (controller) => controller.repeat(reverse: true))
                  .moveY(begin: 0, end: -4, duration: 400.ms),
            ),
          ],
        );
      case MascotState.bouncy:
        return content
            .animate(onPlay: (controller) => controller.repeat(reverse: true))
            .moveY(begin: 0, end: -10, duration: 300.ms, curve: Curves.easeOutQuad);
      case MascotState.happy:
        return Stack(
          clipBehavior: Clip.none,
          children: [
            content
                .animate(onPlay: (controller) => controller.repeat(reverse: true))
                .rotate(begin: -0.1, end: 0.1, duration: 200.ms)
                .scaleXY(begin: 1.0, end: 1.15, duration: 200.ms),
            Positioned(
              top: -15,
              right: -15,
              child: const Text('🎉', style: TextStyle(fontSize: 16))
                  .animate(onPlay: (controller) => controller.repeat())
                  .moveY(begin: 0, end: -10, duration: 600.ms)
                  .fadeOut(duration: 600.ms),
            ),
          ],
        );
      case MascotState.wave:
        return Stack(
          clipBehavior: Clip.none,
          children: [
            content,
            Positioned(
              top: -15,
              right: -15,
              child: const Text('👋', style: TextStyle(fontSize: 20))
                  .animate(
                    onComplete: (_) {
                      setState(() => _isWaving = false);
                      _startIdleTimer();
                      widget.onWaveCompleted?.call();
                    },
                  )
                  .rotate(begin: -0.2, end: 0.2, duration: 300.ms, curve: Curves.easeInOut)
                  .then(delay: 200.ms)
                  .rotate(begin: 0.2, end: -0.2, duration: 300.ms, curve: Curves.easeInOut)
                  .then(delay: 200.ms)
                  .rotate(begin: -0.2, end: 0.0, duration: 300.ms, curve: Curves.easeInOut)
                  .fadeOut(duration: 300.ms),
            ),
          ],
        );
      case MascotState.idle:
        return content;
    }
  }
}
