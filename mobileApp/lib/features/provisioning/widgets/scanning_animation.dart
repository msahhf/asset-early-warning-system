import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Büyüyen daireler radar pulse animasyonu — BLE tarama
class ScanningAnimation extends StatefulWidget {
  final bool isActive;

  const ScanningAnimation({super.key, this.isActive = true});

  @override
  State<ScanningAnimation> createState() => _ScanningAnimationState();
}

class _ScanningAnimationState extends State<ScanningAnimation>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _scaleAnimations;
  late final List<Animation<double>> _opacityAnimations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) {
      return AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2400),
      );
    });

    _scaleAnimations = _controllers.map((c) {
      return Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: c, curve: Curves.easeOut),
      );
    }).toList();

    _opacityAnimations = _controllers.map((c) {
      return Tween<double>(begin: 0.6, end: 0.0).animate(
        CurvedAnimation(parent: c, curve: Curves.easeOut),
      );
    }).toList();

    if (widget.isActive) _startAnimations();
  }

  void _startAnimations() {
    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 800), () {
        if (mounted) {
          _controllers[i].repeat();
        }
      });
    }
  }

  @override
  void didUpdateWidget(ScanningAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _startAnimations();
    } else if (!widget.isActive && oldWidget.isActive) {
      for (final c in _controllers) {
        c.stop();
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulse daireleri
          ...List.generate(3, (i) {
            return AnimatedBuilder(
              animation: _controllers[i],
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimations[i].value,
                  child: Opacity(
                    opacity: _opacityAnimations[i].value,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.accent,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }),

          // Merkez ikon
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: AppTheme.accentGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accent.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.bluetooth_searching_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }
}
