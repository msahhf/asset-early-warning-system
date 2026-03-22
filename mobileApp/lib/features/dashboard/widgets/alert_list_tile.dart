import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../models/alert_model.dart';

/// Alarm listesi satırı
class AlertListTile extends StatelessWidget {
  final AlertModel alert;

  const AlertListTile({super.key, required this.alert});

  Color get _typeColor {
    switch (alert.type) {
      case AlertType.fire:
        return AppTheme.error;
      case AlertType.gas:
        return AppTheme.warning;
      case AlertType.offline:
        return const Color(0xFF007AFF);
      case AlertType.lowBattery:
        return AppTheme.warning;
    }
  }

  IconData get _typeIcon {
    switch (alert.type) {
      case AlertType.fire:
        return Icons.local_fire_department_rounded;
      case AlertType.gas:
        return Icons.cloud_outlined;
      case AlertType.offline:
        return Icons.wifi_off_rounded;
      case AlertType.lowBattery:
        return Icons.battery_alert_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeFormatter = DateFormat('HH:mm');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          // Tip ikonu
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _typeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_typeIcon, color: _typeColor, size: 20),
          ),
          const SizedBox(width: 12),

          // Mesaj
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.type.label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.titleColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  alert.message,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.bodyColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Saat + durum
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                timeFormatter.format(alert.createdAt),
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.hintColor,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: alert.isActive
                      ? _typeColor.withValues(alpha: 0.1)
                      : AppTheme.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  alert.isActive ? 'Aktif' : 'Çözüldü',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: alert.isActive ? _typeColor : AppTheme.success,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
