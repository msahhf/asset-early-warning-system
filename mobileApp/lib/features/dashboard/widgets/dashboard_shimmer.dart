import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/app_theme.dart';

/// Dashboard yüklenirken gösterilen iskelet (shimmer) animasyonu
class DashboardShimmer extends StatelessWidget {
  const DashboardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Shimmer.fromColors(
        baseColor: AppTheme.surface,
        highlightColor: AppTheme.divider,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // Cihaz başlığı iskeleti
              _shimmerBox(height: 72, borderRadius: 16),
              const SizedBox(height: 24),

              // 2×2 sensör kartları iskeleti
              Row(
                children: [
                  Expanded(child: _shimmerBox(height: 130, borderRadius: 16)),
                  const SizedBox(width: 14),
                  Expanded(child: _shimmerBox(height: 130, borderRadius: 16)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _shimmerBox(height: 130, borderRadius: 16)),
                  const SizedBox(width: 14),
                  Expanded(child: _shimmerBox(height: 130, borderRadius: 16)),
                ],
              ),
              const SizedBox(height: 20),

              // Grafik iskeleti
              _shimmerBox(height: 200, borderRadius: 16),
              const SizedBox(height: 20),

              // Son Alarmlar başlığı
              _shimmerBox(height: 16, width: 120, borderRadius: 8),
              const SizedBox(height: 12),

              // Alarm satırları
              _shimmerBox(height: 72, borderRadius: 14),
              const SizedBox(height: 8),
              _shimmerBox(height: 72, borderRadius: 14),
              const SizedBox(height: 8),
              _shimmerBox(height: 72, borderRadius: 14),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shimmerBox({
    required double height,
    double? width,
    double borderRadius = 12,
  }) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}
