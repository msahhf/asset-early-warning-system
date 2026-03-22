import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../models/alert_model.dart';

/// Alarm Detay Ekranı — olayın tüm bilgileri
class AlertDetailScreen extends StatelessWidget {
  final AlertModel alert;

  const AlertDetailScreen({super.key, required this.alert});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Alarm Detayı'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            // ── Tip Başlığı ──────────────────────────
            _buildTypeHeader(),
            const SizedBox(height: 24),

            // ── Durum Kartı ──────────────────────────
            _buildStatusCard(),
            const SizedBox(height: 16),

            // ── Zaman Bilgisi ────────────────────────
            _buildTimeCard(),
            const SizedBox(height: 16),

            // ── Sensör Snapshot ──────────────────────
            if (alert.snapshot != null) ...[
              _buildSectionTitle('Olay Anı Sensör Verileri'),
              const SizedBox(height: 10),
              _buildSensorGrid(),
              const SizedBox(height: 16),
            ],

            // ── Açıklama ────────────────────────────
            _buildSectionTitle('Ne Oldu?'),
            const SizedBox(height: 10),
            _buildDescriptionCard(),
            const SizedBox(height: 16),

            // ── Olay Akışı (Timeline) ───────────────
            _buildSectionTitle('Olay Akışı'),
            const SizedBox(height: 10),
            _buildTimeline(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ── Tip Başlığı ───────────────────────────────────

  Widget _buildTypeHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _typeColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _typeColor.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _typeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Text(
                alert.type.emoji,
                style: const TextStyle(fontSize: 28),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.type.label,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.titleColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  alert.deviceName,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.bodyColor,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: alert.isActive
                  ? _typeColor.withValues(alpha: 0.1)
                  : AppTheme.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              alert.isActive ? 'Aktif' : 'Çözüldü',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: alert.isActive ? _typeColor : AppTheme.success,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Durum Kartı ───────────────────────────────────

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        alert.message,
        style: TextStyle(
          fontSize: 15,
          color: AppTheme.titleColor,
          height: 1.5,
        ),
      ),
    );
  }

  // ── Zaman Kartı ───────────────────────────────────

  Widget _buildTimeCard() {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm:ss');
    final durationStr = alert.duration != null
        ? _formatDuration(alert.duration!)
        : 'Devam ediyor';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _timeRow(
            Icons.access_time_rounded,
            'Başlangıç',
            dateFormat.format(alert.createdAt),
            _typeColor,
          ),
          if (alert.resolvedAt != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: AppTheme.divider),
            ),
            _timeRow(
              Icons.check_circle_outline_rounded,
              'Çözüm',
              dateFormat.format(alert.resolvedAt!),
              AppTheme.success,
            ),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: AppTheme.divider),
          ),
          _timeRow(
            Icons.timer_outlined,
            'Süre',
            durationStr,
            AppTheme.bodyColor,
          ),
        ],
      ),
    );
  }

  Widget _timeRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.bodyColor,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.titleColor,
          ),
        ),
      ],
    );
  }

  // ── Sensör Grid ───────────────────────────────────

  Widget _buildSensorGrid() {
    final s = alert.snapshot!;
    return Row(
      children: [
        Expanded(
          child: _sensorMiniCard(
              'MQ-2', '${s.mq2Value}', 'ppm', Icons.cloud_outlined),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _sensorMiniCard(
              'Sıcaklık', '${s.temperature}', '°C', Icons.thermostat_rounded),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _sensorMiniCard('Nem', s.humidity.toStringAsFixed(0), '%',
              Icons.water_drop_outlined),
        ),
      ],
    );
  }

  Widget _sensorMiniCard(
      String label, String value, String unit, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.hintColor, size: 18),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.titleColor,
            ),
          ),
          Text(
            unit,
            style: TextStyle(fontSize: 11, color: AppTheme.hintColor),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: AppTheme.bodyColor),
          ),
        ],
      ),
    );
  }

  // ── Açıklama ──────────────────────────────────────

  Widget _buildDescriptionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        alert.type.description,
        style: TextStyle(
          fontSize: 14,
          color: AppTheme.bodyColor,
          height: 1.6,
        ),
      ),
    );
  }

  // ── Timeline ──────────────────────────────────────

  Widget _buildTimeline() {
    final timeFormat = DateFormat('HH:mm:ss');
    final events = <_TimelineEvent>[
      _TimelineEvent(
        time: timeFormat.format(alert.createdAt),
        title: '${alert.type.emoji} Alarm tetiklendi',
        subtitle: alert.type.label,
        color: _typeColor,
        isFirst: true,
      ),
      _TimelineEvent(
        time:
            timeFormat.format(alert.createdAt.add(const Duration(seconds: 2))),
        title: '📱 Bildirim gönderildi',
        subtitle: 'Cihaz sahibine push bildirim',
        color: const Color(0xFF007AFF),
      ),
    ];

    if (alert.resolvedAt != null) {
      events.add(_TimelineEvent(
        time: timeFormat.format(alert.resolvedAt!),
        title: '✅ Alarm çözüldü',
        subtitle: 'Durum normale döndü',
        color: AppTheme.success,
        isLast: true,
      ));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: events.map((e) => _buildTimelineItem(e)).toList(),
      ),
    );
  }

  Widget _buildTimelineItem(_TimelineEvent event) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Zaman
        SizedBox(
          width: 60,
          child: Text(
            event.time,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.hintColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        // Çizgi + nokta
        Column(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: event.color,
                shape: BoxShape.circle,
              ),
            ),
            if (!event.isLast)
              Container(
                width: 2,
                height: 40,
                color: AppTheme.divider,
              ),
          ],
        ),
        const SizedBox(width: 14),
        // İçerik
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.titleColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  event.subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.bodyColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Yardımcılar ───────────────────────────────────

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppTheme.titleColor,
      ),
    );
  }

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

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours} saat ${d.inMinutes.remainder(60)} dk';
    }
    if (d.inMinutes > 0) {
      return '${d.inMinutes} dk ${d.inSeconds.remainder(60)} sn';
    }
    return '${d.inSeconds} saniye';
  }
}

class _TimelineEvent {
  final String time;
  final String title;
  final String subtitle;
  final Color color;
  final bool isFirst;
  final bool isLast;

  const _TimelineEvent({
    required this.time,
    required this.title,
    required this.subtitle,
    required this.color,
    this.isFirst = false,
    this.isLast = false,
  });
}
