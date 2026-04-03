import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
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
import '../../../../core/services/backup_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../auth/presentation/screens/pin_setup_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isSavingProfile = false;
  bool _isBackupBusy = false;

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
                  subtitle: profile.hasPhoto ? 'Profile picture linked' : 'No profile picture set',
                  trailing: CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    backgroundImage: profile.imageProvider,
                    child: !profile.hasPhoto
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
                  title: _isBackupBusy ? 'Processing...' : 'Manual Backup',
                  subtitle: 'Save full app backup file',
                  trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: theme.colorScheme.onSurfaceVariant),
                  onTap: _isBackupBusy ? null : _runManualBackup,
                ),
                Divider(height: 1, color: theme.colorScheme.outline),
                _SettingsTile(
                  icon: Icons.restore_rounded,
                  iconColor: AppColors.warning,
                  title: 'Restore',
                  subtitle: 'Restore entire app from backup file',
                  trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: theme.colorScheme.onSurfaceVariant),
                  onTap: _isBackupBusy ? null : _confirmRestore,
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
                  subtitle: '3.0.0',
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
    XFile? pickedImage;
    Uint8List? pickedImageBytes;

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

            ImageProvider? avatarImage;
            if (pickedImageBytes != null) {
              avatarImage = MemoryImage(pickedImageBytes!);
            } else {
              avatarImage = current.imageProvider;
            }

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
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                              backgroundImage: avatarImage,
                              child: avatarImage == null
                                  ? Text(previewName.substring(0, 1).toUpperCase(), style: AppTypography.headingSmall.copyWith(color: AppColors.primaryDark))
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: () async {
                                  final cropped = await _pickAndCropImage(this.context);
                                  if (cropped != null) {
                                    setSheetState(() {
                                      pickedImage = cropped.file;
                                      pickedImageBytes = cropped.bytes;
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (avatarImage != null)
                        Center(
                          child: TextButton(
                            onPressed: () {
                              setSheetState(() {
                                pickedImage = null;
                                pickedImageBytes = null;
                              });
                              if (current.hasPhoto) {
                                ref.read(userProfileProvider.notifier).removeProfileImage();
                              }
                            },
                            child: const Text('Remove Photo', style: TextStyle(color: AppColors.error)),
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
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            setState(() => _isSavingProfile = true);
                            
                            await ref.read(userProfileProvider.notifier).saveName(nameCtrl.text);
                            if (pickedImage != null) {
                              await ref.read(userProfileProvider.notifier).saveProfileImage(
                                pickedImage!,
                                imageBytes: pickedImageBytes,
                              );
                            }
                            
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

  Future<({XFile file, Uint8List bytes})?> _pickAndCropImage(BuildContext context) async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
    );
    if (photo == null) return null;
    final originalBytes = await photo.readAsBytes();

    if (!context.mounted) {
      return (file: photo, bytes: originalBytes);
    }

    final cropStyle = await showDialog<CropStyle>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choose crop style'),
        contentPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.circle_outlined),
              title: const Text('Circle crop'),
              onTap: () => Navigator.of(ctx).pop(CropStyle.circle),
            ),
            ListTile(
              leading: const Icon(Icons.crop_square_rounded),
              title: const Text('Square crop'),
              onTap: () => Navigator.of(ctx).pop(CropStyle.rectangle),
            ),
          ],
        ),
      ),
    );

    if (cropStyle == null) return (file: photo, bytes: originalBytes);

    // image_cropper web integration requires dedicated web ui settings.
    // To keep this flow reliable on web, use selected image directly.
    if (kIsWeb) {
      return (file: photo, bytes: originalBytes);
    }

    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: photo.path,
        compressQuality: 92,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Profile Photo',
            hideBottomControls: true,
            lockAspectRatio: true,
            cropStyle: cropStyle,
          ),
          IOSUiSettings(
            title: 'Crop Profile Photo',
            aspectRatioLockEnabled: true,
            cropStyle: cropStyle,
          ),
        ],
      );

      // If crop UI is canceled/failed, keep original selection so avatar still updates.
      if (cropped == null) return (file: photo, bytes: originalBytes);

      final croppedBytes = await cropped.readAsBytes();
      return (
        file: XFile(cropped.path),
        bytes: croppedBytes,
      );
    } catch (e) {
      debugPrint('Profile crop failed: $e');
      return (file: photo, bytes: originalBytes);
    }
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
    final birthdays = await db.getAllBirthdays();

    await notification.scheduleGlobalDailyReminder(
      time: prefs.routineReminderTime,
      alertMode: prefs.alertMode,
    );

    for (final routine in routines) {
      await notification.cancelRoutineReminders(routine.id);
      final days = routine.days
          .split(',')
          .map((d) => int.tryParse(d))
          .whereType<int>()
          .toList();
      if (days.isEmpty) continue;

      final reminderTimes = <TimeOfDay>[];
      if (routine.reminderTime != null && routine.reminderTime!.trim().isNotEmpty) {
        for (final token in routine.reminderTime!.split(',')) {
          final parts = token.trim().split(':');
          if (parts.length != 2) continue;
          final hour = int.tryParse(parts[0]);
          final minute = int.tryParse(parts[1]);
          if (hour == null || minute == null) continue;
          if (hour < 0 || hour > 23 || minute < 0 || minute > 59) continue;
          reminderTimes.add(TimeOfDay(hour: hour, minute: minute));
        }
      }

      if (reminderTimes.isEmpty) {
        reminderTimes.add(prefs.routineReminderTime);
      }

      await notification.scheduleRoutineReminders(
        routineId: routine.id,
        title: 'Routine: ${routine.title}',
        body: 'Time to start your morning routine!',
        daysOfWeek: days,
        reminderTimes: reminderTimes,
        alertMode: prefs.alertMode,
      );
    }

    await notification.rescheduleAllBirthdayReminders(
      birthdays: birthdays,
      alertMode: prefs.alertMode,
    );
  }

  Future<void> _runManualBackup() async {
    if (_isBackupBusy) return;
    setState(() => _isBackupBusy = true);
    try {
      final backupService = AppBackupService(ref.read(databaseProvider));
      final result = await backupService.createBackupFile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    } finally {
      if (mounted) {
        setState(() => _isBackupBusy = false);
      }
    }
  }

  Future<void> _confirmRestore() async {
    final shouldRestore = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Backup?'),
        content: const Text(
          'This will replace your current app data, settings, and PIN with backup content. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Restore', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (shouldRestore != true) return;
    await _runRestoreBackup();
  }

  Future<void> _runRestoreBackup() async {
    if (_isBackupBusy) return;
    setState(() => _isBackupBusy = true);
    try {
      final backupService = AppBackupService(ref.read(databaseProvider));
      final result = await backupService.restoreFromFile();

      if (result.success) {
        ref.invalidate(databaseProvider);
        ref.invalidate(userProfileProvider);
        ref.invalidate(themeModeProvider);
        ref.invalidate(notificationPreferencesProvider);
        ref.invalidate(authProvider);

        await _waitForNotificationPrefsReady();
        await _rescheduleRoutineReminders();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    } finally {
      if (mounted) {
        setState(() => _isBackupBusy = false);
      }
    }
  }

  Future<void> _waitForNotificationPrefsReady() async {
    for (int i = 0; i < 30; i++) {
      final state = ref.read(notificationPreferencesProvider);
      if (!state.isLoading) return;
      await Future<void>.delayed(const Duration(milliseconds: 50));
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
