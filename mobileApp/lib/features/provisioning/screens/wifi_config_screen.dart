import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/asset_button.dart';
import '../../../shared/widgets/asset_text_field.dart';
import '../providers/provisioning_provider.dart';

/// Wi-Fi konfigürasyon ekranı — SSID ve şifre girişi
class WifiConfigScreen extends ConsumerStatefulWidget {
  const WifiConfigScreen({super.key});

  @override
  ConsumerState<WifiConfigScreen> createState() => _WifiConfigScreenState();
}

class _WifiConfigScreenState extends ConsumerState<WifiConfigScreen> {
  final _ssidCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _ssidCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _provision() async {
    final ssid = _ssidCtrl.text.trim();
    if (ssid.isEmpty) {
      _showError('Wi-Fi adı (SSID) zorunludur.');
      return;
    }

    final success = await ref.read(provisioningProvider.notifier).provision(
          ssid,
          _passCtrl.text,
          _nameCtrl.text,
        );

    if (mounted) {
      final state = ref.read(provisioningProvider);
      context.go('/result', extra: {
        'success': success,
        'message': state.statusMessage,
      });
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(provisioningProvider);
    final deviceName =
        state.selectedDevice?.device.platformName ?? 'ASSET Cihaz';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Wi-Fi Ayarları'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: state.isProvisioning ? null : () => context.go('/scan'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // Bağlanan cihaz bilgisi
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.bluetooth_connected_rounded,
                        color: AppTheme.accent,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            deviceName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.titleColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Seçili cihaz',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.hintColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Hazır',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.success,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Wi-Fi bilgileri başlık
              const Text(
                'Bağlanılacak Wi-Fi ağının\nbilgilerini girin.',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.bodyColor,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),

              // Özel Cihaz Adı
              AssetTextField(
                controller: _nameCtrl,
                label: 'Cihaz Adı (İsteğe Bağlı)',
                hint: 'Örn: Salon, Mutfak',
                prefixIcon: Icons.badge_outlined,
              ),
              const SizedBox(height: 20),

              // SSID
              AssetTextField(
                controller: _ssidCtrl,
                label: 'Wi-Fi Adı (SSID)',
                hint: 'Ağ adını girin',
                prefixIcon: Icons.wifi_rounded,
              ),
              const SizedBox(height: 20),

              // Şifre
              AssetTextField(
                controller: _passCtrl,
                label: 'Wi-Fi Şifresi',
                hint: 'Şifreyi girin',
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: _obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppTheme.hintColor,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              const SizedBox(height: 16),

              // Güvenlik notu
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      color: AppTheme.success,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Şifreniz yalnızca cihazda saklanır, buluta gönderilmez.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.success.withValues(alpha: 0.9),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Durum göstergesi
              if (state.isProvisioning) ...[
                _buildStatusIndicator(state.statusMessage),
                const SizedBox(height: 24),
              ],

              // Yapılandır butonu
              AssetButton(
                label: 'Cihazı Yapılandır',
                icon: Icons.send_rounded,
                isLoading: state.isProvisioning,
                onPressed: state.isProvisioning ? null : _provision,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.accentLight.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.accentLight.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              color: AppTheme.accentLight,
              strokeWidth: 2,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.accentLight,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
