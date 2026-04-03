import 'package:drift/drift.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/app_database.dart';

class ContactSyncService {
  ContactSyncService(this._db);

  final AppDatabase _db;

  static const String lastSyncKey = 'contacts_last_sync_iso';

  Future<int> syncIfDue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(lastSyncKey);
    if (raw != null) {
      final last = DateTime.tryParse(raw);
      if (last != null && DateTime.now().difference(last).inDays < 30) {
        return 0;
      }
    }
    return syncNow();
  }

  Future<int> syncNow() async {
    final granted = await FlutterContacts.requestPermission();
    if (!granted) {
      return 0;
    }

    final contacts = await FlutterContacts.getContacts(withProperties: true, withPhoto: false);
    int added = 0;

    for (final contact in contacts) {
      final displayName = contact.displayName.trim().isEmpty ? 'Unknown' : contact.displayName.trim();
      for (final phone in contact.phones) {
        final normalized = normalizePhone(phone.number);
        if (normalized.isEmpty) continue;

        final externalId = '${contact.id}|$normalized';
        final existsByExternal = await _db.getContactByExternalId(externalId);
        if (existsByExternal != null) continue;

        final existsByPhone = await _db.getContactByNormalizedPhone(normalized);
        if (existsByPhone != null) continue;

        await _db.addContactEntry(
          ContactEntriesCompanion.insert(
            displayName: displayName,
            phone: phone.number.trim(),
            normalizedPhone: normalized,
            source: const Value('phone'),
            externalContactId: Value(externalId),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        added++;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(lastSyncKey, DateTime.now().toIso8601String());
    return added;
  }

  static String normalizePhone(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '';

    final withPlus = trimmed.startsWith('+') ? '+' : '';
    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';

    return '$withPlus$digits';
  }
}
