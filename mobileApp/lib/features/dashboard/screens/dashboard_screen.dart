import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/bottom_nav.dart';
import '../models/sensor_reading.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/device_header.dart';
import '../widgets/sensor_card.dart';
import '../widgets/mini_chart.dart';
import '../widgets/alert_list_tile.dart';
import '../models/alert_model.dart';
import '../widgets/dashboard_shimmer.dart';
import 'alert_detail_screen.dart';
import 'history_tab.dart';
import 'settings_tab.dart';
import 'profile_tab.dart';

/// Ana Dashboard ekranı
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _navIndex = 0;

  void _switchToTab(int index) {
    setState(() => _navIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _navIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _navIndex != 0) {
          setState(() => _navIndex = 0);
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: IndexedStack(
          index: _navIndex,
          children: [
            _HomeTab(),
            const HistoryTab(),
            const SettingsTab(),
            const ProfileTab(),
          ],
        ),
        bottomNavigationBar: AssetBottomNav(
          currentIndex: _navIndex,
          onTap: (i) => setState(() => _navIndex = i),
        ),
      ),
    );
  }
}

/// Ana Sayfa tab içeriği
class _HomeTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardProvider);

    if (state.isLoading) {
      return const DashboardShimmer();
    }

    final reading = state.currentReading;
    final device = state.device;

    if (device == null || reading == null) {
      return Center(
        child: Text(
          'Veri bekleniyor...',
          style: TextStyle(color: AppTheme.hintColor),
        ),
      );
    }

    return SafeArea(
      child: RefreshIndicator(
        color: AppTheme.accent,
        onRefresh: () async {
          ref.invalidate(dashboardProvider);
          await Future.delayed(const Duration(milliseconds: 300));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // ── Cihaz Başlığı ────────────────────
              const DeviceHeader(),
              const SizedBox(height: 24),

              // ── Sensör Kartları (2×2 grid) ───────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 1.05,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    SensorCard(
                      label: 'Duman',
                      value: reading.mq2Value.toString(),
                      unit: 'ppm',
                      status: reading.gasStatus.label,
                      icon: Icons.cloud_outlined,
                      statusColor: _gasColor(reading.gasStatus),
                    ),
                    SensorCard(
                      label: 'Sıcaklık',
                      value: reading.temperature.toStringAsFixed(1),
                      unit: '°C',
                      status: _tempStatus(reading.temperature),
                      icon: Icons.thermostat_rounded,
                      statusColor: _tempColor(reading.temperature),
                    ),
                    SensorCard(
                      label: 'Nem',
                      value: reading.humidity.toStringAsFixed(0),
                      unit: '%',
                      status: _humidityStatus(reading.humidity),
                      icon: Icons.water_drop_outlined,
                      statusColor: _humidityColor(reading.humidity),
                    ),
                    SensorCard(
                      label: 'Pil',
                      value: reading.batteryPercent.toStringAsFixed(0),
                      unit: '%',
                      status: _batteryStatus(reading.batteryPercent),
                      icon: _batteryIcon(reading.batteryPercent),
                      statusColor: _batteryColor(reading.batteryPercent),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Mini Grafik ──────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: MiniChart(history: state.history),
              ),
              const SizedBox(height: 20),

              // ── Alarm Geçmişi ────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Icon(Icons.notifications_outlined,
                        color: AppTheme.accent, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Son Alarmlar',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.titleColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              if (state.alerts.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline_rounded,
                            color: AppTheme.success, size: 24),
                        const SizedBox(width: 12),
                        Text(
                          'Aktif alarm yok',
                          style: TextStyle(
                            fontSize: 15,
                            color: AppTheme.bodyColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: state.alerts.length > 3 ? 3 : state.alerts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final alert = state.alerts[i];
                    return GestureDetector(
                      onTap: () => _openDetail(context, alert),
                      child: AlertListTile(alert: alert),
                    );
                  },
                ),

              // "Tümünü Gör" butonu
              if (state.alerts.length > 3)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Center(
                    child: TextButton(
                      onPressed: () {
                        // Use a simple approach - find ancestor and switch tab
                        final scaffold = context
                            .findAncestorStateOfType<_DashboardScreenState>();
                        scaffold?._switchToTab(1);
                      },
                      child: Text(
                        'Tümünü Gör →',
                        style: TextStyle(
                          color: AppTheme.accent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  void _openDetail(BuildContext context, AlertModel alert) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AlertDetailScreen(alert: alert),
      ),
    );
  }

  Color _gasColor(GasStatus status) {
    switch (status) {
      case GasStatus.safe:
        return AppTheme.success;
      case GasStatus.warning:
        return AppTheme.warning;
      case GasStatus.danger:
        return AppTheme.error;
    }
  }

  String _tempStatus(double temp) {
    if (temp >= 40) return 'Çok Yüksek';
    if (temp >= 30) return 'Yüksek';
    if (temp <= 10) return 'Düşük';
    return 'Normal';
  }

  Color _tempColor(double temp) {
    if (temp >= 40) return AppTheme.error;
    if (temp >= 30) return AppTheme.warning;
    if (temp <= 10) return const Color(0xFF007AFF);
    return AppTheme.success;
  }

  String _humidityStatus(double h) {
    if (h >= 70) return 'Yüksek';
    if (h <= 30) return 'Düşük';
    return 'Normal';
  }

  Color _humidityColor(double h) {
    if (h >= 70) return AppTheme.warning;
    if (h <= 30) return AppTheme.warning;
    return AppTheme.success;
  }

  String _batteryStatus(double b) {
    if (b >= 80) return 'İyi';
    if (b >= 40) return 'Orta';
    if (b >= 15) return 'Düşük';
    return 'Kritik';
  }

  Color _batteryColor(double b) {
    if (b >= 80) return AppTheme.success;
    if (b >= 40) return AppTheme.warning;
    return AppTheme.error;
  }

  IconData _batteryIcon(double b) {
    if (b >= 80) return Icons.battery_full_rounded;
    if (b >= 40) return Icons.battery_3_bar_rounded;
    if (b >= 15) return Icons.battery_1_bar_rounded;
    return Icons.battery_alert_rounded;
  }
}
