import 'package:drift/drift.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/database/app_database.dart';

class ContactSyncReport {
  const ContactSyncReport({
    required this.status,
    required this.totalContactsScanned,
    required this.totalPhoneEntries,
    required this.newImported,
    required this.totalInAppContacts,
  });

  final int status;
  final int totalContactsScanned;
  final int totalPhoneEntries;
  final int newImported;
  final int totalInAppContacts;

  int get resultCode => status < 0 ? status : newImported;
}

class ContactSyncService {
  ContactSyncService(this._db);

  final AppDatabase _db;

  static const String lastSyncKey = 'contacts_last_sync_iso';

  static const int success = 0;
  static const int permissionDenied = -1;
  static const int noDeviceContacts = -2;

  Future<int> syncIfDue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(lastSyncKey);
    if (raw != null) {
      final last = DateTime.tryParse(raw);
      if (last != null && DateTime.now().difference(last).inDays < 30) {
        return 0;
      }
    }
    final report = await syncNowWithReport();
    return report.resultCode;
  }

  Future<int> syncNow() async {
    final report = await syncNowWithReport();
    return report.resultCode;
  }

  Future<ContactSyncReport> syncNowWithReport() async {
    final beforeSyncCount = (await _db.getAllContactEntries()).length;
    final granted = await FlutterContacts.requestPermission(readonly: true);
    if (!granted) {
      return ContactSyncReport(
        status: permissionDenied,
        totalContactsScanned: 0,
        totalPhoneEntries: 0,
        newImported: 0,
        totalInAppContacts: beforeSyncCount,
      );
    }

    final contacts = await FlutterContacts.getContacts(withProperties: true, withPhoto: false);
    if (contacts.isEmpty) {
      return ContactSyncReport(
        status: noDeviceContacts,
        totalContactsScanned: 0,
        totalPhoneEntries: 0,
        newImported: 0,
        totalInAppContacts: beforeSyncCount,
      );
    }

    int added = 0;
    int phoneEntries = 0;

    for (final contact in contacts) {
      final displayName = contact.displayName.trim().isEmpty ? 'Unknown' : contact.displayName.trim();
      for (final phone in contact.phones) {
        phoneEntries++;
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
    final afterSyncCount = (await _db.getAllContactEntries()).length;

    return ContactSyncReport(
      status: success,
      totalContactsScanned: contacts.length,
      totalPhoneEntries: phoneEntries,
      newImported: added,
      totalInAppContacts: afterSyncCount,
    );
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
