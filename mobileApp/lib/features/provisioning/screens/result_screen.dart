import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/asset_button.dart';

/// Sonuç ekranı — Başarı veya Hata
class ResultScreen extends StatefulWidget {
  final bool success;
  final String message;

  const ResultScreen({
    super.key,
    required this.success,
    required this.message,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.success ? AppTheme.success : AppTheme.error;
    final icon =
        widget.success ? Icons.check_circle_rounded : Icons.cancel_rounded;
    final title = widget.success ? 'Cihaz Hazır!' : 'Bağlantı Başarısız';
    final subtitle = widget.success
        ? 'Cihazınız başarıyla yapılandırıldı\nve Wi-Fi ağına bağlandı.'
        : 'Lütfen Wi-Fi bilgilerinizi kontrol edip\ntekrar deneyin.';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Animasyonlu ikon
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnim.value,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 64),
                    ),
                  );
                },
              ),
              const SizedBox(height: 40),

              // Başlık ve açıklama
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnim.value,
                    child: Column(
                      children: [
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.titleColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: AppTheme.bodyColor,
                            height: 1.5,
                          ),
                        ),

                        // Cihaz IP göster (başarılıysa)
                        if (widget.success && widget.message.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.wifi_rounded,
                                  color: AppTheme.success,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  widget.message,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.titleColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Hata mesajı göster
                        if (!widget.success && widget.message.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppTheme.error.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              widget.message,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.error,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),

              const Spacer(flex: 3),

              // Butonlar
              if (widget.success) ...[
                AssetButton(
                  label: 'Tamam',
                  icon: Icons.home_rounded,
                  onPressed: () {
                    context.go('/dashboard');
                  },
                ),
              ] else ...[
                AssetButton(
                  label: 'Tekrar Dene',
                  icon: Icons.refresh_rounded,
                  onPressed: () => context.go('/wifi-config'),
                ),
                const SizedBox(height: 12),
                AssetButton(
                  label: 'Farklı Cihaz Seç',
                  outlined: true,
                  onPressed: () => context.go('/scan'),
                ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
