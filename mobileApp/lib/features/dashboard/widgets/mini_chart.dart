import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/sensor_reading.dart';

/// Son sensör verilerinin mini grafiği
class MiniChart extends StatelessWidget {
  final List<SensorReading> history;

  const MiniChart({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık
          Row(
            children: [
              Icon(Icons.show_chart_rounded, color: AppTheme.accent, size: 18),
              const SizedBox(width: 8),
              Text(
                'Duman Seviyesi',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.titleColor,
                ),
              ),
              const Spacer(),
              Text(
                'Son ${history.length} okuma',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.hintColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Grafik
          SizedBox(
            height: 140,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 500,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppTheme.divider,
                    strokeWidth: 0.5,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: 500,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.hintColor,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minY: 0,
                maxY: 3000,
                lineBarsData: [
                  // Duman çizgisi
                  LineChartBarData(
                    spots: history.asMap().entries.map((e) {
                      return FlSpot(
                          e.key.toDouble(), e.value.mq2Value.toDouble());
                    }).toList(),
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: AppTheme.accent,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.accent.withValues(alpha: 0.15),
                          AppTheme.accent.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                // Eşik çizgileri
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: 1500,
                      color: AppTheme.warning.withValues(alpha: 0.4),
                      strokeWidth: 1,
                      dashArray: [6, 4],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topRight,
                        style: TextStyle(fontSize: 9, color: AppTheme.warning),
                        labelResolver: (_) => 'Uyarı',
                      ),
                    ),
                    HorizontalLine(
                      y: 2500,
                      color: AppTheme.error.withValues(alpha: 0.4),
                      strokeWidth: 1,
                      dashArray: [6, 4],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topRight,
                        style: TextStyle(fontSize: 9, color: AppTheme.error),
                        labelResolver: (_) => 'Tehlike',
                      ),
                    ),
                  ],
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) {
                      return spots.map((spot) {
                        return LineTooltipItem(
                          'MQ-2: ${spot.y.toInt()}',
                          TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
            ),
          ),
        ],
      ),
    );
  }
}
