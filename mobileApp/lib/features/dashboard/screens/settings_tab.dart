import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/theme/app_theme.dart';
import '../models/alert_model.dart';
import '../providers/dashboard_provider.dart';
import '../../../core/services/notification_service.dart';

/// Ayarlar sekmesi
class SettingsTab extends ConsumerWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            Text(
              'Ayarlar',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppTheme.titleColor,
              ),
            ),
            const SizedBox(height: 24),

            // ── Cihaz İşlemleri ─────────────────────
            _sectionTitle('Cihaz İşlemleri'),
            const SizedBox(height: 10),
            _SettingsTile(
              icon: Icons.wifi_protected_setup_rounded,
              iconColor: AppTheme.accent,
              title: 'Cihazı Yeniden Kur / Wifi Senkronizasyonu',
              subtitle: 'Ağ ayarlarını veya eşleştirmeyi yenile',
              onTap: () => context.go('/scan'),
            ),
            const SizedBox(height: 20),

            // ── Test & Demo ──────────────────────────
            _sectionTitle('Test & Demo'),
            const SizedBox(height: 10),
            _SettingsTile(
              icon: Icons.local_fire_department_rounded,
              iconColor: AppTheme.error,
              title: 'Demo Yangın Alarmı',
              subtitle: 'Test amaçlı sahte alarm tetikle',
              onTap: () => _triggerDemoAlert(ref, context, AlertType.fire),
            ),
            const SizedBox(height: 8),
            _SettingsTile(
              icon: Icons.cloud_outlined,
              iconColor: AppTheme.warning,
              title: 'Demo Gaz Alarmı',
              subtitle: 'Test amaçlı sahte gaz alarmı',
              onTap: () => _triggerDemoAlert(ref, context, AlertType.gas),
            ),
            const SizedBox(height: 20),

            // ── Veri Yönetimi ────────────────────────
            _sectionTitle('Veri Yönetimi'),
            const SizedBox(height: 10),
            _SettingsTile(
              icon: Icons.delete_outline_rounded,
              iconColor: AppTheme.error,
              title: 'Geçmişi Temizle',
              subtitle: 'Tüm alarm kayıtlarını sil',
              onTap: () => _clearData(ref, context),
            ),
            const SizedBox(height: 20),

            // ── Hakkında ─────────────────────────────
            _sectionTitle('Hakkında'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _infoRow('Uygulama', 'ASSET Mobile'),
                  _divider(),
                  _infoRow('Versiyon', '2.0.0+1'),
                  _divider(),
                  _infoRow('SDK', 'Flutter 3.x'),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppTheme.hintColor,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(fontSize: 15, color: AppTheme.bodyColor)),
          Text(value,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.titleColor)),
        ],
      ),
    );
  }

  Widget _divider() {
    return Divider(height: 1, color: AppTheme.divider);
  }

  void _triggerDemoAlert(WidgetRef ref, BuildContext context, AlertType type) {
    final now = DateTime.now();
    final alert = AlertModel(
      id: 'demo-${now.millisecondsSinceEpoch}',
      deviceName: 'ASSET-α3f2',
      type: type,
      message: type == AlertType.fire
          ? 'Demo: Duman seviyesi kritik! MQ-2: ${2500 + (now.second * 10)}'
          : 'Demo: Gaz seviyesi uyarı eşiğinde: MQ-2: ${1600 + (now.second * 5)}',
      createdAt: now,
      snapshot: SensorSnapshot(
        mq2Value: type == AlertType.fire ? 2847 : 1623,
        temperature: 38.5,
        humidity: 42.0,
        batteryPercent: 84.0,
      ),
    );

    final typeStr = type == AlertType.fire ? 'Yangın' : 'Gaz';
    // Local notification tetikle
    NotificationService.showWarningNotification(
      title: '${type.emoji} DİKKAT: $typeStr ALARMI!',
      body: alert.message,
    );

    ref.read(dashboardProvider.notifier).addAlert(alert);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${type.emoji} Demo alarm tetiklendi!'),
        backgroundColor: AppTheme.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _clearData(WidgetRef ref, BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Geçmişi Temizle'),
        content: const Text(
            'Tüm alarm kayıtları silinecek. Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(ctx);
              final nav = Navigator.of(ctx);
              await LocalStorageService.clearAll();
              ref.read(dashboardProvider.notifier).clearAlerts();
              nav.pop();
              messenger.showSnackBar(
                SnackBar(
                  content: const Text('Geçmiş temizlendi'),
                  backgroundColor: AppTheme.success,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.all(16),
                ),
              );
            },
            child: Text('Sil', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.titleColor)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style:
                          TextStyle(fontSize: 12, color: AppTheme.bodyColor)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: AppTheme.hintColor, size: 20),
          ],
        ),
      ),
    );
  }
}
