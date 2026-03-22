import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'signal_indicator.dart';

/// Bulunan BLE cihaz kartı — Apple-tarzı
class DeviceCard extends StatelessWidget {
  final String name;
  final int rssi;
  final bool isSelected;
  final VoidCallback onTap;

  const DeviceCard({
    super.key,
    required this.name,
    required this.rssi,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accent.withValues(alpha: 0.06)
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.accent : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: isSelected ? AppTheme.softShadow : null,
        ),
        child: Row(
          children: [
            // BLE İkonu
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.accent.withValues(alpha: 0.1)
                    : AppTheme.divider,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.bluetooth_rounded,
                color: isSelected ? AppTheme.accent : AppTheme.hintColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),

            // Cihaz Adı
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color:
                          isSelected ? AppTheme.titleColor : AppTheme.bodyColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$rssi dBm',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.hintColor,
                    ),
                  ),
                ],
              ),
            ),

            // Sinyal + Check
            SignalIndicator(rssi: rssi),
            if (isSelected) ...[
              const SizedBox(width: 10),
              const Icon(Icons.check_circle_rounded,
                  color: AppTheme.accent, size: 22),
            ],
          ],
        ),
      ),
    );
  }
}
