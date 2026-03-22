import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/asset_button.dart';

/// Onboarding ekranı — 3 sayfalık tanıtım
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  final _pages = [
    const _OnboardingPage(
      icon: Icons.sensors_rounded,
      iconColor: AppTheme.accent,
      title: 'Cihazınızı Tanıyın',
      subtitle:
          'ASSET, duman ve sıcaklığı çift doğrulamayla algılayarak\nyanlış alarmları önler.',
    ),
    const _OnboardingPage(
      icon: Icons.notifications_active_rounded,
      iconColor: AppTheme.accentLight,
      title: 'Anında Bildirim',
      subtitle:
          'Tehlike anında telefonunuza anlık bildirim gelir.\nElektrik kesilse bile sistem çalışmaya devam eder.',
    ),
    const _OnboardingPage(
      icon: Icons.lock_rounded,
      iconColor: AppTheme.success,
      title: 'Güvenli Eşleştirme',
      subtitle:
          'Wi-Fi şifreniz yalnızca cihazda saklanır.\nBluetooth ile güvenli kurulum.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Skip / Demo butonları
            Padding(
              padding: const EdgeInsets.only(top: 8, right: 16, left: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox.shrink(), // Sol taraf boş
                  // Atla butonu — Login'e git
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: Text(
                      'Atla',
                      style: TextStyle(
                        color: AppTheme.hintColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Sayfalar
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, index) => _pages[index],
              ),
            ),

            // Page indicator
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: SmoothPageIndicator(
                controller: _pageController,
                count: _pages.length,
                effect: ExpandingDotsEffect(
                  dotWidth: 8,
                  dotHeight: 8,
                  activeDotColor: AppTheme.accent,
                  dotColor: AppTheme.divider,
                  spacing: 6,
                ),
              ),
            ),

            // CTA Butonu
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: AssetButton(
                label:
                    _currentPage == _pages.length - 1 ? 'Başlayalım' : 'Devam',
                icon: _currentPage == _pages.length - 1
                    ? Icons.arrow_forward_rounded
                    : null,
                onPressed: _next,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Onboarding Sayfası ───────────────────────────────

class _OnboardingPage extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const _OnboardingPage({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  State<_OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<_OnboardingPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animasyonlu ikon
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: widget.iconColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(36),
              ),
              child: Icon(widget.icon, color: widget.iconColor, size: 56),
            ),
          ),
          const SizedBox(height: 48),

          // Başlık
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppTheme.titleColor,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 16),

          // Alt yazı
          Text(
            widget.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: AppTheme.bodyColor,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
