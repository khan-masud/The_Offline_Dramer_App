import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../providers/theme_provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/profile_provider.dart';
import '../../../../providers/notification_preferences_provider.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/services/notification_service.dart';
import '../../../auth/presentation/screens/pin_setup_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isSavingProfile = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = ref.watch(userProfileProvider);
    final themeMode = ref.watch(themeModeProvider);
    final authState = ref.watch(authProvider);
    final notificationPrefs = ref.watch(notificationPreferencesProvider);
    final isDark = themeMode == ThemeMode.dark;
    final reminderTimeText = MaterialLocalizations.of(context).formatTimeOfDay(
      notificationPrefs.routineReminderTime,
      alwaysUse24HourFormat: MediaQuery.of(context).alwaysUse24HourFormat,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.base),
        physics: const BouncingScrollPhysics(),
        children: [
          // Profile
          _SectionTitle(title: 'Profile'),
          const SizedBox(height: AppDimensions.sm),
          AppCard(
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.person_outline_rounded,
                  iconColor: AppColors.info,
                  title: profile.name,
                  subtitle: profile.photoUrl.isEmpty ? 'No profile picture set' : 'Profile picture linked',
                  trailing: CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    backgroundImage: profile.photoUrl.isNotEmpty ? NetworkImage(profile.photoUrl) : null,
                    child: profile.photoUrl.isEmpty
                        ? Text(
                            profile.name.isEmpty ? 'D' : profile.name.substring(0, 1).toUpperCase(),
                            style: AppTypography.labelMedium.copyWith(color: AppColors.primaryDark),
                          )
                        : null,
                  ),
                  onTap: () => _showEditProfileSheet(context),
                ),
                Divider(height: 1, color: theme.colorScheme.outline),
                _SettingsTile(
                  icon: Icons.edit_note_rounded,
                  iconColor: AppColors.primary,
                  title: _isSavingProfile ? 'Saving profile...' : 'Edit name & photo',
                  subtitle: 'Use your name for dashboard greeting',
                  trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: theme.colorScheme.onSurfaceVariant),
                  onTap: _isSavingProfile ? null : () => _showEditProfileSheet(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.xl),

          // Appearance
          _SectionTitle(title: 'Appearance'),
          const SizedBox(height: AppDimensions.sm),
          AppCard(
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.dark_mode_outlined,
                  iconColor: AppColors.purple,
                  title: 'Dark Mode',
                  trailing: Switch(
                    value: isDark,
                    onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.xl),

          // Security
          _SectionTitle(title: 'Security'),
          const SizedBox(height: AppDimensions.sm),
          AppCard(
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.lock_outline_rounded,
                  iconColor: AppColors.primary,
                  title: 'App Lock',
                  subtitle: authState.isPinSet ? 'PIN is enabled' : 'No PIN set',
                  trailing: Switch(
                    value: authState.isPinSet,
                    onChanged: (value) {
                      if (value) {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const PinSetupScreen()),
                        );
                      } else {
                        _showRemovePinDialog(context, ref);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.xl),

          // Notifications
          _SectionTitle(title: 'Notifications'),
          const SizedBox(height: AppDimensions.sm),
          AppCard(
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.schedule_rounded,
                  iconColor: AppColors.primary,
                  title: 'Daily Routine Reminder Time',
                  subtitle: reminderTimeText,
                  trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: theme.colorScheme.onSurfaceVariant),
                  onTap: () => _pickDailyReminderTime(context),
                ),
                Divider(height: 1, color: theme.colorScheme.outline),
                _SettingsTile(
                  icon: Icons.notifications_active_rounded,
                  iconColor: AppColors.warning,
                  title: 'Reminder Type',
                  subtitle: _alertModeLabel(notificationPrefs.alertMode),
                  trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: theme.colorScheme.onSurfaceVariant),
                  onTap: () => _pickAlertMode(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.xl),

          // Data
          _SectionTitle(title: 'Data & Backup'),
          const SizedBox(height: AppDimensions.sm),
          AppCard(
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.cloud_upload_outlined,
                  iconColor: AppColors.info,
                  title: 'Auto Backup',
                  subtitle: 'Every 7 days to Google Drive',
                  trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: theme.colorScheme.onSurfaceVariant),
                  onTap: () {},
                ),
                Divider(height: 1, color: theme.colorScheme.outline),
                _SettingsTile(
                  icon: Icons.download_outlined,
                  iconColor: AppColors.success,
                  title: 'Manual Backup',
                  subtitle: 'Download backup file',
                  trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: theme.colorScheme.onSurfaceVariant),
                  onTap: () {},
                ),
                Divider(height: 1, color: theme.colorScheme.outline),
                _SettingsTile(
                  icon: Icons.restore_rounded,
                  iconColor: AppColors.warning,
                  title: 'Restore',
                  subtitle: 'Restore from backup',
                  trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: theme.colorScheme.onSurfaceVariant),
                  onTap: () {},
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.xl),

          // About
          _SectionTitle(title: 'About'),
          const SizedBox(height: AppDimensions.sm),
          AppCard(
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.info_outline_rounded,
                  iconColor: AppColors.teal,
                  title: 'Version',
                  subtitle: '2.0.0',
                ),
                Divider(height: 1, color: theme.colorScheme.outline),
                _SettingsTile(
                  icon: Icons.favorite_outline_rounded,
                  iconColor: AppColors.pink,
                  title: 'Developed by ❤️',
                  subtitle: 'Abdullah Al Masud',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.xxl),
        ],
      ),
    );
  }

  Future<void> _showEditProfileSheet(BuildContext context) async {
    final current = ref.read(userProfileProvider);
    final nameCtrl = TextEditingController(text: current.name);
    final photoCtrl = TextEditingController(text: current.photoUrl);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final previewName = nameCtrl.text.trim().isEmpty ? 'Dreamer' : nameCtrl.text.trim();
            final previewPhoto = photoCtrl.text.trim();

            return AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.outline,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Edit Profile', style: AppTypography.headingMedium.copyWith(color: theme.colorScheme.onSurface)),
                      const SizedBox(height: 16),
                      Center(
                        child: CircleAvatar(
                          radius: 28,
                          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                          backgroundImage: previewPhoto.isNotEmpty ? NetworkImage(previewPhoto) : null,
                          child: previewPhoto.isEmpty
                              ? Text(previewName.substring(0, 1).toUpperCase(), style: AppTypography.headingSmall.copyWith(color: AppColors.primaryDark))
                              : null,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: nameCtrl,
                        onChanged: (_) => setSheetState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Your name',
                          hintText: 'Type your name',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: photoCtrl,
                        onChanged: (_) => setSheetState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Profile photo URL',
                          hintText: 'https://...',
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            setState(() => _isSavingProfile = true);
                            await ref.read(userProfileProvider.notifier).saveProfile(
                              name: nameCtrl.text,
                              photoUrl: photoCtrl.text,
                            );
                            if (!mounted) return;
                            setState(() => _isSavingProfile = false);
                            if (ctx.mounted) Navigator.pop(ctx);
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(content: Text('Profile updated successfully')),
                            );
                          },
                          child: const Text('Save Profile'),
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

  void _showRemovePinDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove PIN?'),
        content: const Text('Your app will no longer be protected. Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ref.read(authProvider.notifier).removePin();
              Navigator.pop(ctx);
            },
            child: const Text('Remove', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  String _alertModeLabel(ReminderAlertMode mode) {
    switch (mode) {
      case ReminderAlertMode.ring:
        return 'Ring';
      case ReminderAlertMode.ringAndVibration:
        return 'Ring + Vibration';
      case ReminderAlertMode.vibration:
        return 'Vibration';
      case ReminderAlertMode.silent:
        return 'Silent';
    }
  }

  Future<void> _pickDailyReminderTime(BuildContext context) async {
    final prefsState = ref.read(notificationPreferencesProvider);
    final picked = await showTimePicker(
      context: context,
      initialTime: prefsState.routineReminderTime,
    );
    if (picked == null) return;

    await ref.read(notificationPreferencesProvider.notifier).setRoutineReminderTime(picked);
    await _rescheduleRoutineReminders();
    if (!mounted) return;
    ScaffoldMessenger.of(this.context).showSnackBar(
      const SnackBar(content: Text('Daily reminder time updated')),
    );
  }

  Future<void> _pickAlertMode(BuildContext context) async {
    final current = ref.read(notificationPreferencesProvider).alertMode;
    final selected = await showModalBottomSheet<ReminderAlertMode>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: ReminderAlertMode.values.map((mode) {
                return ListTile(
                  leading: Icon(
                    current == mode ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: current == mode ? AppColors.primary : theme.colorScheme.onSurfaceVariant,
                  ),
                  title: Text(_alertModeLabel(mode)),
                  onTap: () => Navigator.pop(ctx, mode),
                );
              }).toList(),
            ),
          ),
        );
      },
    );

    if (selected == null || selected == current) return;

    await ref.read(notificationPreferencesProvider.notifier).setAlertMode(selected);
    await _rescheduleRoutineReminders();
    if (!mounted) return;
    ScaffoldMessenger.of(this.context).showSnackBar(
      const SnackBar(content: Text('Reminder type updated')),
    );
  }

  Future<void> _rescheduleRoutineReminders() async {
    final db = ref.read(databaseProvider);
    final notification = ref.read(notificationServiceProvider);
    final prefs = ref.read(notificationPreferencesProvider);
    final routines = await db.getAllRoutines();

    for (final routine in routines) {
      await notification.cancelRoutineReminders(routine.id);
      final days = routine.days
          .split(',')
          .map((d) => int.tryParse(d))
          .whereType<int>()
          .toList();
      if (days.isEmpty) continue;

      await notification.scheduleRoutineReminder(
        routineId: routine.id,
        title: 'Routine: ${routine.title}',
        body: 'Time to start your morning routine!',
        daysOfWeek: days,
        hour: prefs.routineReminderTime.hour,
        minute: prefs.routineReminderTime.minute,
        alertMode: prefs.alertMode,
      );
    }
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppTypography.labelLarge.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.md),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: AppDimensions.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.bodyLarge.copyWith(color: theme.colorScheme.onSurface)),
                  if (subtitle != null)
                    Text(subtitle!, style: AppTypography.bodySmall.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
