import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/provisioning/screens/splash_screen.dart';
import '../../features/provisioning/screens/onboarding_screen.dart';
import '../../features/provisioning/screens/ble_scan_screen.dart';
import '../../features/provisioning/screens/wifi_config_screen.dart';
import '../../features/provisioning/screens/wifi_config_screen.dart';
import '../../features/provisioning/screens/result_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/scan',
        builder: (context, state) => const BleScanScreen(),
      ),
      GoRoute(
        path: '/wifi-config',
        builder: (context, state) => const WifiConfigScreen(),
      ),
      GoRoute(
        path: '/result',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return ResultScreen(
            success: extra?['success'] ?? false,
            message: extra?['message'] ?? '',
          );
        },
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
    ],
  );
});
