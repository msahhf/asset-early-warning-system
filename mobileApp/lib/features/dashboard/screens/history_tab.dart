import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../models/alert_model.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/alert_list_tile.dart';
import 'alert_detail_screen.dart';

/// Geçmiş (Detay) sekmesi — filtrelenebilir olay zaman çizelgesi
class HistoryTab extends ConsumerStatefulWidget {
  const HistoryTab({super.key});

  @override
  ConsumerState<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends ConsumerState<HistoryTab> {
  AlertType? _filter;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardProvider);
    final alerts = _filter == null
        ? state.alerts
        : state.alerts.where((a) => a.type == _filter).toList();

    // Tarih bazlı gruplanmış
    final grouped = _groupByDate(alerts);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),

          // Başlık
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Olay Geçmişi',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppTheme.titleColor,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              '${alerts.length} olay kayıtlı',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.hintColor,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Filtre chips
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                _FilterChip(
                  label: 'Tümü',
                  isSelected: _filter == null,
                  onTap: () => setState(() => _filter = null),
                ),
                const SizedBox(width: 8),
                ...AlertType.values.map((type) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _FilterChip(
                        label: '${type.emoji} ${type.label}',
                        isSelected: _filter == type,
                        onTap: () => setState(() => _filter = type),
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Gruplandırılmış liste
          Expanded(
            child: alerts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_rounded,
                            color: AppTheme.hintColor, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          'Henüz olay kaydı yok',
                          style: TextStyle(
                              fontSize: 16, color: AppTheme.hintColor),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: grouped.length,
                    itemBuilder: (context, index) {
                      final entry = grouped.entries.elementAt(index);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Tarih başlığı
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 10),
                            child: Text(
                              entry.key,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.hintColor,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          // Alarmlar
                          ...entry.value.map((alert) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: GestureDetector(
                                  onTap: () => _openDetail(alert),
                                  child: AlertListTile(alert: alert),
                                ),
                              )),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _openDetail(AlertModel alert) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AlertDetailScreen(alert: alert),
      ),
    );
  }

  Map<String, List<AlertModel>> _groupByDate(List<AlertModel> alerts) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateFormat = DateFormat('dd MMMM yyyy');

    final grouped = <String, List<AlertModel>>{};

    for (final alert in alerts) {
      final alertDate = DateTime(
        alert.createdAt.year,
        alert.createdAt.month,
        alert.createdAt.day,
      );

      String key;
      if (alertDate == today) {
        key = 'Bugün';
      } else if (alertDate == yesterday) {
        key = 'Dün';
      } else {
        key = dateFormat.format(alert.createdAt);
      }

      grouped.putIfAbsent(key, () => []).add(alert);
    }

    return grouped;
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accent : AppTheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.accent : AppTheme.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : AppTheme.bodyColor,
          ),
        ),
      ),
    );
  }
}
