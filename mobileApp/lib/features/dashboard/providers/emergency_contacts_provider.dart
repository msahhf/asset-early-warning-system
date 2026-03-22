import 'package:flutter_riverpod/flutter_riverpod.dart';

class EmergencyContact {
  final String id;
  final String name;
  final String phone;

  EmergencyContact({required this.id, required this.name, required this.phone});
}

class EmergencyContactsNotifier extends StateNotifier<List<EmergencyContact>> {
  EmergencyContactsNotifier() : super([
    EmergencyContact(id: '1', name: 'Muhammet', phone: '+90 555 123 4567'),
    EmergencyContact(id: '2', name: 'Ev Sahibi', phone: '+90 532 987 6543'),
  ]);

  void addContact(String name, String phone) {
    final newContact = EmergencyContact(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      phone: phone,
    );
    state = [...state, newContact];
  }

  void removeContact(String id) {
    state = state.where((c) => c.id != id).toList();
  }
}

final emergencyContactsProvider = StateNotifierProvider<EmergencyContactsNotifier, List<EmergencyContact>>((ref) {
  return EmergencyContactsNotifier();
});
