import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../providers/notification_preferences_provider.dart';
import '../../data/birthday_provider.dart';

class BirthdayCalendarScreen extends ConsumerWidget {
  const BirthdayCalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final birthdaysAsync = ref.watch(birthdaysProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Birthday Calendar')),
      body: birthdaysAsync.when(
        data: (birthdays) {
          if (birthdays.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.pink.withValues(alpha: 0.12),
                      ),
                      child: const Icon(Icons.cake_outlined, size: 42, color: AppColors.pink),
                    ),
                    const SizedBox(height: 16),
                    Text('No birthdays yet', style: AppTypography.headingSmall.copyWith(color: theme.colorScheme.onSurface)),
                    const SizedBox(height: 6),
                    Text('Tap + to add birthdays and get reminders', style: AppTypography.bodyMedium.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            );
          }

          final sorted = [...birthdays]
            ..sort((a, b) => _nextBirthday(a.dateOfBirth).compareTo(_nextBirthday(b.dateOfBirth)));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            physics: const BouncingScrollPhysics(),
            itemCount: sorted.length,
            itemBuilder: (context, index) {
              final b = sorted[index];
              final nextDate = _nextBirthday(b.dateOfBirth);
              final left = nextDate.difference(_today()).inDays;
              final subtitle = left == 0
                  ? 'Today'
                  : left == 1
                      ? 'Tomorrow'
                      : '$left days left';

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: AppColors.pink.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.cake_rounded, color: AppColors.pink),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(b.personName, style: AppTypography.labelLarge.copyWith(color: theme.colorScheme.onSurface)),
                            Text(
                              '${DateFormat('dd MMM').format(b.dateOfBirth)} • $subtitle',
                              style: AppTypography.bodySmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                            if (b.phone != null && b.phone!.trim().isNotEmpty)
                              Text(
                                b.phone!,
                                style: AppTypography.labelSmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _openBirthdaySheet(context, ref, existing: b),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                        onPressed: () => _deleteBirthday(context, ref, b),
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
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'birthday_fab',
        onPressed: () => _openBirthdaySheet(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Birthday'),
      ),
    );
  }

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime _nextBirthday(DateTime dateOfBirth) {
    final now = DateTime.now();
    var candidate = DateTime(now.year, dateOfBirth.month, dateOfBirth.day);
    if (candidate.isBefore(_today())) {
      candidate = DateTime(now.year + 1, dateOfBirth.month, dateOfBirth.day);
    }
    return candidate;
  }

  Future<void> _openBirthdaySheet(BuildContext context, WidgetRef ref, {Birthday? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.personName ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final noteCtrl = TextEditingController(text: existing?.note ?? '');

    DateTime selectedDate = existing?.dateOfBirth ?? DateTime(DateTime.now().year - 20, 1, 1);
    bool remindDayBefore = existing?.remindDayBefore ?? true;
    bool remindOnDay = existing?.remindOnDay ?? true;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        existing == null ? 'Add Birthday' : 'Edit Birthday',
                        style: AppTypography.headingMedium.copyWith(color: theme.colorScheme.onSurface),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: nameCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Name'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Phone (optional)'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: noteCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Note (optional)'),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: selectedDate,
                            firstDate: DateTime(1900),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setSheetState(() => selectedDate = picked);
                          }
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                            border: Border.all(color: theme.colorScheme.outline),
                          ),
                          child: Text(
                            'Birthday: ${DateFormat('dd MMM yyyy').format(selectedDate)}',
                            style: AppTypography.bodyMedium.copyWith(color: theme.colorScheme.onSurface),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: remindDayBefore,
                        title: const Text('Notify 1 day before'),
                        onChanged: (v) => setSheetState(() => remindDayBefore = v),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: remindOnDay,
                        title: const Text('Notify on birthday at 12:00 AM'),
                        onChanged: (v) => setSheetState(() => remindOnDay = v),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            final name = nameCtrl.text.trim();
                            if (name.isEmpty) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(content: Text('Name is required')),
                              );
                              return;
                            }

                            final db = ref.read(databaseProvider);
                            final prefs = ref.read(notificationPreferencesProvider);
                            final notif = ref.read(notificationServiceProvider);
                            final now = DateTime.now();

                            int birthdayId;
                            if (existing == null) {
                              birthdayId = await db.addBirthday(
                                BirthdaysCompanion.insert(
                                  personName: name,
                                  phone: Value(phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim()),
                                  note: Value(noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim()),
                                  dateOfBirth: selectedDate,
                                  remindDayBefore: Value(remindDayBefore),
                                  remindOnDay: Value(remindOnDay),
                                  createdAt: now,
                                  updatedAt: now,
                                ),
                              );
                            } else {
                              birthdayId = existing.id;
                              await db.updateBirthday(
                                BirthdaysCompanion(
                                  id: Value(existing.id),
                                  personName: Value(name),
                                  phone: Value(phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim()),
                                  note: Value(noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim()),
                                  dateOfBirth: Value(selectedDate),
                                  remindDayBefore: Value(remindDayBefore),
                                  remindOnDay: Value(remindOnDay),
                                  createdAt: Value(existing.createdAt),
                                  updatedAt: Value(now),
                                ),
                              );
                            }

                            await notif.scheduleBirthdayReminders(
                              birthdayId: birthdayId,
                              personName: name,
                              dateOfBirth: selectedDate,
                              remindDayBefore: remindDayBefore,
                              remindOnDay: remindOnDay,
                              alertMode: prefs.alertMode,
                            );

                            if (!ctx.mounted) return;
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(existing == null ? 'Birthday added' : 'Birthday updated')),
                            );
                          },
                          child: Text(existing == null ? 'Add Birthday' : 'Save Changes'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteBirthday(BuildContext context, WidgetRef ref, Birthday birthday) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete birthday?'),
        content: Text('Delete ${birthday.personName}\'s birthday reminder?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await ref.read(databaseProvider).deleteBirthday(birthday.id);
    await ref.read(notificationServiceProvider).cancelBirthdayReminders(birthday.id);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Birthday deleted')),
    );
  }
}
