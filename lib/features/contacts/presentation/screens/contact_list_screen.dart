import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../data/contact_sync_service.dart';
import '../../data/contacts_provider.dart';

class ContactListScreen extends ConsumerStatefulWidget {
  const ContactListScreen({super.key});

  @override
  ConsumerState<ContactListScreen> createState() => _ContactListScreenState();
}

class _ContactListScreenState extends ConsumerState<ContactListScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  bool _isSyncing = false;
  String? _lastSyncText;
  String? _lastSyncSummary;

  @override
  void initState() {
    super.initState();
    // Ensure stale search text from previous visits does not hide existing contacts.
    ref.read(contactSearchProvider.notifier).state = '';
    _searchCtrl.clear();
    _loadLastSync();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contactsAsync = ref.watch(contactEntriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact List'),
        actions: [
          IconButton(
            icon: _isSyncing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sync_rounded),
            tooltip: 'Sync now',
            onPressed: _isSyncing ? null : _syncNow,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => ref.read(contactSearchProvider.notifier).state = v,
              decoration: const InputDecoration(
                hintText: 'Search name or phone...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          if (_lastSyncText != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _lastSyncText!,
                  style: AppTypography.labelSmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          if (_lastSyncSummary != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _lastSyncSummary!,
                  style: AppTypography.bodySmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSyncing ? null : _syncNow,
                icon: _isSyncing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_rounded),
                label: Text(_isSyncing ? 'Syncing contacts...' : 'Sync Contacts'),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: contactsAsync.when(
              data: (contacts) {
                if (contacts.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: AppColors.info.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.contact_phone_outlined, color: AppColors.info, size: 42),
                          ),
                          const SizedBox(height: 14),
                          Text('No contacts yet', style: AppTypography.headingSmall.copyWith(color: theme.colorScheme.onSurface)),
                          const SizedBox(height: 6),
                          Text('Use + to add manually or tap Sync Contacts to import phone contacts', style: AppTypography.bodyMedium.copyWith(color: theme.colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  physics: const BouncingScrollPhysics(),
                  itemCount: contacts.length,
                  itemBuilder: (context, index) {
                    final c = contacts[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(
                        onTap: () => _showContactDetails(context, c),
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: (c.source == 'phone' ? AppColors.success : AppColors.primary).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                c.source == 'phone' ? Icons.phone_android_rounded : Icons.edit_note_rounded,
                                size: 18,
                                color: c.source == 'phone' ? AppColors.success : AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c.displayName, style: AppTypography.labelLarge.copyWith(color: theme.colorScheme.onSurface)),
                                  Text(c.phone, style: AppTypography.bodySmall.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded),
                              tooltip: 'Copy number',
                              onPressed: () => _copyPhone(context, c.phone),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: 'Edit',
                              onPressed: () => _openContactSheet(context, existing: c),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'contact_fab',
        onPressed: () => _openContactSheet(context),
        icon: const Icon(Icons.person_add_alt_rounded),
        label: const Text('Add Contact'),
      ),
    );
  }

  Future<void> _loadLastSync() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(ContactSyncService.lastSyncKey);
    if (!mounted) return;
    if (raw == null) {
      setState(() => _lastSyncText = 'Last sync: never');
      return;
    }

    final dt = DateTime.tryParse(raw);
    if (dt == null) {
      setState(() => _lastSyncText = 'Last sync: unknown');
      return;
    }
    setState(() => _lastSyncText = 'Last sync: ${DateFormat('dd MMM yyyy, hh:mm a').format(dt)}');
  }

  Future<void> _syncNow() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);

    try {
      final db = ref.read(databaseProvider);
      final service = ContactSyncService(db);
      final report = await service.syncNowWithReport();
      final summaryText =
          'Total contacts scanned: ${report.totalContactsScanned}, phone entries: ${report.totalPhoneEntries}, new imported: ${report.newImported}, in app: ${report.totalInAppContacts}';
      ref.invalidate(contactEntriesProvider);
      if (mounted) {
        setState(() => _lastSyncSummary = summaryText);
      }
      await _loadLastSync();
      if (!mounted) return;

      if (report.newImported > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${report.newImported} new contact(s) imported from phone\n$summaryText')),
        );
      } else if (report.status == ContactSyncService.permissionDenied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Contact permission is required to sync phone contacts\n$summaryText')),
        );
      } else if (report.status == ContactSyncService.noDeviceContacts) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No contacts found on this device\n$summaryText')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No new contacts found\n$summaryText')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _openContactSheet(BuildContext context, {ContactEntry? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.displayName ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;

        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(existing == null ? 'Add Contact' : 'Edit Contact', style: AppTypography.headingMedium.copyWith(color: theme.colorScheme.onSurface)),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone Number'),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      final phone = phoneCtrl.text.trim();
                      if (name.isEmpty || phone.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Name and phone are required')));
                        return;
                      }

                      final normalized = ContactSyncService.normalizePhone(phone);
                      if (normalized.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Invalid phone number')));
                        return;
                      }

                      final db = ref.read(databaseProvider);
                      final now = DateTime.now();

                      if (existing == null) {
                        final duplicate = await db.getContactByNormalizedPhone(normalized);
                        if (duplicate != null) {
                          if (!ctx.mounted) return;
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('This number already exists')));
                          return;
                        }

                        await db.addContactEntry(
                          ContactEntriesCompanion.insert(
                            displayName: name,
                            phone: phone,
                            normalizedPhone: normalized,
                            source: const Value('manual'),
                            externalContactId: const Value(null),
                            createdAt: now,
                            updatedAt: now,
                          ),
                        );
                      } else {
                        await db.updateContactEntry(
                          ContactEntriesCompanion(
                            id: Value(existing.id),
                            displayName: Value(name),
                            phone: Value(phone),
                            normalizedPhone: Value(normalized),
                            source: Value(existing.source),
                            externalContactId: Value(existing.externalContactId),
                            createdAt: Value(existing.createdAt),
                            updatedAt: Value(now),
                          ),
                        );
                      }

                      ref.invalidate(contactEntriesProvider);
                      if (!ctx.mounted) return;
                      Navigator.of(ctx).pop();
                    },
                    child: Text(existing == null ? 'Add Contact' : 'Save Changes'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _copyPhone(BuildContext context, String phone) {
    Clipboard.setData(ClipboardData(text: phone));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Number copied')),
    );
  }

  Future<void> _showContactDetails(BuildContext context, ContactEntry entry) async {
    final theme = Theme.of(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(entry.displayName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Phone: ${entry.phone}'),
            const SizedBox(height: 8),
            Text('Source: ${entry.source == 'phone' ? 'Phone Sync' : 'Manual'}'),
            const SizedBox(height: 8),
            Text(
              'Updated: ${DateFormat('dd MMM yyyy, hh:mm a').format(entry.updatedAt)}',
              style: AppTypography.bodySmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: entry.phone));
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Number copied')));
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
