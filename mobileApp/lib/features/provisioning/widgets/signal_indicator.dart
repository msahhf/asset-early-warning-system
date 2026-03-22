import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// BLE cihaz sinyal gücü göstergesi (3 çubuk)
class SignalIndicator extends StatelessWidget {
  final int rssi;

  const SignalIndicator({super.key, required this.rssi});

  /// RSSI → sinyal seviyesi (0-3)
  int get _level {
    if (rssi >= -50) return 3; // Güçlü
    if (rssi >= -70) return 2; // Orta
    if (rssi >= -85) return 1; // Zayıf
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(3, (i) {
        final isActive = i < _level;
        final height = 8.0 + (i * 5.0);
        return Padding(
          padding: const EdgeInsets.only(right: 2),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 4,
            height: height,
            decoration: BoxDecoration(
              color: isActive
                  ? (_level >= 2 ? AppTheme.success : AppTheme.warning)
                  : AppTheme.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}
