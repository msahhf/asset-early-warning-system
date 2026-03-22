import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/dashboard_provider.dart';

// ── Cihaz Durum Başlığı (Çoklu Cihaz Dropdown Serisi) ──
class DeviceHeader extends ConsumerWidget {
  const DeviceHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardProvider);
    final device = state.device;
    if (device == null) return const SizedBox.shrink();

    final allDevices = state.allDevices;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Merhaba 👋',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.bodyColor,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    // Açılır menü (Dropdown) ile cihaz seçimi
                    DropdownButton<String>(
                      value: device.deviceId,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.accent),
                      elevation: 16,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.titleColor,
                      ),
                      dropdownColor: AppTheme.surface,
                      underline: const SizedBox(), // Çizgiyi kaldır
                      onChanged: (String? value) {
                        if (value != null) {
                          ref.read(dashboardProvider.notifier).switchDevice(value);
                        }
                      },
                      items: allDevices.map<DropdownMenuItem<String>>((devItem) {
                        return DropdownMenuItem<String>(
                          value: devItem.deviceId,
                          child: Text(devItem.name),
                        );
                      }).toList(),
                    ),
                    const SizedBox(width: 10),
                    _OnlineBadge(isOnline: device.isOnline),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  device.location,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.hintColor,
                  ),
                ),
              ],
            ),
          ),

          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: AppTheme.accentGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.local_fire_department_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}

class _OnlineBadge extends StatelessWidget {
  final bool isOnline;
  const _OnlineBadge({required this.isOnline});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (isOnline ? AppTheme.success : AppTheme.error)
            .withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isOnline ? AppTheme.success : AppTheme.error,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isOnline ? 'Çevrimiçi' : 'Çevrimdışı',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isOnline ? AppTheme.success : AppTheme.error,
            ),
          ),
        ],
      ),
    );
  }
}
