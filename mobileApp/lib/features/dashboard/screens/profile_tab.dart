import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/dashboard_provider.dart';
import '../providers/emergency_contacts_provider.dart';

/// Profil sekmesi — cihaz teknik bilgileri
class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardProvider);
    final contacts = ref.watch(emergencyContactsProvider);
    final device = state.device;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            Text(
              'Profil',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppTheme.titleColor,
              ),
            ),
            const SizedBox(height: 24),

            // ── Cihaz Kartı ──────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppTheme.accentGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accent.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.local_fire_department_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    device?.name ?? 'ASSET Cihaz',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    device?.location ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      device?.isOnline == true
                          ? '🟢 Çevrimiçi'
                          : '🔴 Çevrimdışı',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Teknik Bilgiler ──────────────────────
            _sectionTitle('Cihaz Bilgileri'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _infoRow('Cihaz ID', device?.deviceId.substring(0, 8) ?? '—'),
                  _divider(),
                  _infoRow('Firmware', device?.firmwareVersion ?? '—'),
                  _divider(),
                  _infoRow('Pil',
                      '${device?.batteryLevel.toStringAsFixed(0) ?? '—'}%'),
                  _divider(),
                  _infoRow(
                    'Son Heartbeat',
                    device?.lastHeartbeat != null
                        ? DateFormat('HH:mm:ss').format(device!.lastHeartbeat!)
                        : '—',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Sensörler ────────────────────────────
            _sectionTitle('Donanım'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _hardwareRow(
                      Icons.memory_rounded, 'MCU', 'Deneyap Kart 1A v2'),
                  _divider(),
                  _hardwareRow(Icons.cloud_outlined, 'Gaz Sensörü', 'MQ-2'),
                  _divider(),
                  _hardwareRow(
                      Icons.thermostat_rounded, 'Sıcaklık/Nem', 'DHT22'),
                  _divider(),
                  _hardwareRow(Icons.battery_charging_full_rounded, 'UPS',
                      'TP4056 + 18650'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── İstatistikler ────────────────────────
            _sectionTitle('İstatistikler'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _statCard(
                    '${state.alerts.length}',
                    'Toplam Alarm',
                    Icons.notifications_outlined,
                    AppTheme.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard(
                    '${state.alerts.where((a) => !a.isActive).length}',
                    'Çözülen',
                    Icons.check_circle_outline_rounded,
                    AppTheme.success,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard(
                    '${state.history.length}',
                    'Veri Noktası',
                    Icons.show_chart_rounded,
                    const Color(0xFF007AFF),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Acil Durum Kişileri ──────────────────
            _sectionTitle('Acil Durum Kişileri'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  if (contacts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'Kayıtlı kişi yok.',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ),
                    ),
                  ...contacts.expand((contact) => [
                        _contactRow(context, ref, contact),
                        _divider(),
                      ]),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showAddContactDialog(context, ref),
                      icon: const Icon(Icons.person_add_rounded, size: 18),
                      label: const Text('Yeni Kişi Ekle'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.accent,
                        side: const BorderSide(color: AppTheme.accent),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ── Çıkış Yap Butonu ──────────────────────
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('auth_token');
                  if (context.mounted) {
                    context.go('/login');
                  }
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Oturumu Kapat', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.error.withValues(alpha: 0.1),
                  foregroundColor: AppTheme.error,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
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
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(fontSize: 15, color: AppTheme.bodyColor)),
          Text(
            value,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.titleColor),
          ),
        ],
      ),
    );
  }

  Widget _hardwareRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.hintColor, size: 18),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(fontSize: 15, color: AppTheme.bodyColor)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.titleColor),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Divider(height: 1, color: AppTheme.divider);
  }

  Widget _statCard(String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.titleColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: AppTheme.bodyColor),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _contactRow(BuildContext context, WidgetRef ref, EmergencyContact contact) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.accent.withValues(alpha: 0.2),
            child: const Icon(Icons.person, color: AppTheme.accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.titleColor),
                ),
                Text(
                  contact.phone,
                  style: TextStyle(fontSize: 13, color: AppTheme.bodyColor),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 20),
            onPressed: () {
              ref.read(emergencyContactsProvider.notifier).removeContact(contact.id);
            },
          )
        ],
      ),
    );
  }

  void _showAddContactDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Yeni Kişi Ekle', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'İsim',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              style: const TextStyle(color: Colors.white),
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Telefon NUMARASI',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty && phoneCtrl.text.isNotEmpty) {
                ref.read(emergencyContactsProvider.notifier).addContact(nameCtrl.text, phoneCtrl.text);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Ekle', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
