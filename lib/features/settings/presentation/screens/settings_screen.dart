import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../../../core/services/incomplete_reminder_scheduler.dart';
import '../../../../core/services/notification_service.dart';
import '../../../auth/presentation/screens/pin_setup_screen.dart';
import '../../../dashboard/data/weather_provider.dart';

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
    final weatherApiKeyAsync = ref.watch(weatherApiKeyProvider);

    final isDark = themeMode == ThemeMode.dark;
    final reminderTimeText = MaterialLocalizations.of(context).formatTimeOfDay(
      notificationPrefs.routineReminderTime,
      alwaysUse24HourFormat: MediaQuery.of(context).alwaysUse24HourFormat,
    );
    final birthdayTimeText = MaterialLocalizations.of(context).formatTimeOfDay(
      notificationPrefs.birthdayReminderTime,
      alwaysUse24HourFormat: MediaQuery.of(context).alwaysUse24HourFormat,
    );
    final incompleteIntervalText = _incompleteIntervalLabel(
      notificationPrefs.incompleteReminderIntervalHours,
    );
    final currentCustomKey = weatherApiKeyAsync.value ?? '';
    final weatherKeyStatus = currentCustomKey.isNotEmpty
        ? 'Custom key: ${currentCustomKey.substring(0, currentCustomKey.length > 8 ? 8 : currentCustomKey.length)}...'
        : 'Using default key';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        physics: const BouncingScrollPhysics(),
        children: [
          // Profile Header Card
          _buildProfileHeader(theme, profile),
          const SizedBox(height: 24),

          // Appearance
          _sectionLabel(context, 'Appearance & Theme', Icons.palette_outlined),
          AppCard(
            padding: EdgeInsets.zero,
            child: _tile(
              context: context,
              icon: Icons.dark_mode_outlined,
              iconColor: AppColors.purple,
              title: 'Dark Mode',
              subtitle: isDark ? 'Dark theme is on' : 'Light theme is on',
              trailing: Switch(
                value: isDark,
                onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Security
          _sectionLabel(context, 'Security', Icons.shield_outlined),
          AppCard(
            padding: EdgeInsets.zero,
            child: _tile(
              context: context,
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
          ),
          const SizedBox(height: 20),

          // Integrations
          _sectionLabel(context, 'Integrations', Icons.api_outlined),
          AppCard(
            padding: EdgeInsets.zero,
            child: _tile(
              context: context,
              icon: Icons.wb_cloudy_outlined,
              iconColor: AppColors.teal,
              title: 'Weather API Key',
              subtitle: weatherKeyStatus,
              trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
              onTap: () => _showWeatherApiKeyDialog(context, currentCustomKey),
            ),
          ),
          const SizedBox(height: 20),

          // Notifications
          _sectionLabel(context, 'Notifications & Reminders', Icons.notifications_none_rounded),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _tile(
                  context: context,
                  icon: Icons.schedule_rounded,
                  iconColor: AppColors.primary,
                  title: 'Daily Routine Reminder',
                  subtitle: reminderTimeText,
                  trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
                  onTap: () => _pickDailyReminderTime(context),
                ),
                _divider(theme),
                _tile(
                  context: context,
                  icon: Icons.notifications_active_rounded,
                  iconColor: AppColors.warning,
                  title: 'Reminder Type',
                  subtitle: _alertModeLabel(notificationPrefs.alertMode),
                  trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
                  onTap: () => _pickAlertMode(context),
                ),
                _divider(theme),
                _tile(
                  context: context,
                  icon: Icons.repeat_rounded,
                  iconColor: AppColors.info,
                  title: 'Incomplete Reminder Interval',
                  subtitle: incompleteIntervalText,
                  trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
                  onTap: () => _pickIncompleteReminderInterval(context),
                ),
                _divider(theme),
                _tile(
                  context: context,
                  icon: Icons.cake_outlined,
                  iconColor: AppColors.pink,
                  title: 'Birthday Notification Time',
                  subtitle: birthdayTimeText,
                  trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
                  onTap: () => _pickBirthdayReminderTime(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Data & Backups
          _sectionLabel(context, 'Data & Backups', Icons.storage_outlined),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _tile(
                  context: context,
                  icon: Icons.download_outlined,
                  iconColor: AppColors.success,
                  title: _isBackupBusy ? 'Processing...' : 'Create Backup',
                  subtitle: 'Export all app data to a zip file',
                  trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
                  onTap: _isBackupBusy ? null : _runManualBackup,
                ),
                _divider(theme),
                _tile(
                  context: context,
                  icon: Icons.restore_rounded,
                  iconColor: AppColors.warning,
                  title: 'Restore Backup',
                  subtitle: 'Import and restore from backup file',
                  trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
                  onTap: _isBackupBusy ? null : _confirmRestore,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // About
          _sectionLabel(context, 'About', Icons.info_outline_rounded),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _tile(
                  context: context,
                  icon: Icons.tag_rounded,
                  iconColor: AppColors.teal,
                  title: 'Version',
                  subtitle: '1.2.0',
                ),
                _divider(theme),
                _tile(
                  context: context,
                  icon: Icons.favorite_outline_rounded,
                  iconColor: AppColors.pink,
                  title: 'Developed by',
                  subtitle: 'Abdullah Al Masud',
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(ThemeData theme, UserProfileState profile) {
    final displayName = profile.name.isEmpty ? 'User' : profile.name;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            backgroundImage: profile.imageProvider,
            child: !profile.hasPhoto
                ? Text(
                    displayName.substring(0, 1).toUpperCase(),
                    style: AppTypography.headingLarge.copyWith(color: Colors.white),
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: AppTypography.headingMedium.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  profile.hasPhoto ? 'Profile photo is set' : 'Tap to personalize',
                  style: AppTypography.bodySmall.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 22),
            onPressed: _isSavingProfile ? null : () => _showEditProfileSheet(context),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String title, IconData icon) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 15, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            title.toUpperCase(),
            style: AppTypography.labelSmall.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider(ThemeData theme) =>
      Divider(height: 1, indent: 56, color: theme.colorScheme.outline.withValues(alpha: 0.4));

  Widget _tile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: AppTypography.labelLarge.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: AppTypography.bodySmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
              )
            : null,
        trailing: trailing,
      ),
    );
  }

  void _showWeatherApiKeyDialog(BuildContext context, String currentKey) {
    final ctrl = TextEditingController(text: currentKey);
    bool obscure = true;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.wb_cloudy_outlined, color: AppColors.teal, size: 22),
              const SizedBox(width: 8),
              const Text('Weather API Key'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter your WeatherAPI.com key for dashboard weather. Leave empty to use the built-in default.',
                style: AppTypography.bodySmall,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: 'API Key',
                  hintText: 'Paste your key here...',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setDialogState(() => obscure = !obscure),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                await ref.read(weatherApiKeyProvider.notifier).saveKey('');
                ctrl.clear();
                setDialogState(() {});
              },
              child: const Text('Clear'),
            ),
            FilledButton(
              onPressed: () async {
                final newKey = ctrl.text.trim();
                await ref.read(weatherApiKeyProvider.notifier).saveKey(newKey);
                ref.invalidate(weatherProvider);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(newKey.isEmpty ? 'Reverted to default key' : 'Weather API key saved!'),
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
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
            final previewName = nameCtrl.text.trim().isEmpty ? 'User' : nameCtrl.text.trim();
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
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outline,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Edit Profile', style: AppTypography.headingMedium),
                    const SizedBox(height: 16),
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                            backgroundImage: avatarImage,
                            child: avatarImage == null
                                ? Text(previewName.substring(0, 1).toUpperCase(),
                                    style: AppTypography.headingSmall.copyWith(color: AppColors.primaryDark))
                                : null,
                          ),
                          Positioned(
                            bottom: 0, right: 0,
                            child: GestureDetector(
                              onTap: () async {
                                final cropped = await _pickAndCropImage(context);
                                if (cropped != null) {
                                  setSheetState(() {
                                    pickedImage = cropped.file;
                                    pickedImageBytes = cropped.bytes;
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                                child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (avatarImage != null)
                      TextButton(
                        onPressed: () {
                          setSheetState(() { pickedImage = null; pickedImageBytes = null; });
                          if (current.hasPhoto) ref.read(userProfileProvider.notifier).removeProfileImage();
                        },
                        child: const Text('Remove Photo', style: TextStyle(color: AppColors.error)),
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      onChanged: (_) => setSheetState(() {}),
                      decoration: const InputDecoration(labelText: 'Your name', hintText: 'Type your name'),
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
                              pickedImage!, imageBytes: pickedImageBytes,
                            );
                          }
                          if (!mounted) return;
                          setState(() => _isSavingProfile = false);
                          if (ctx.mounted) Navigator.pop(ctx);
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(content: Text('Profile updated!')),
                          );
                        },
                        child: const Text('Save Profile'),
                      ),
                    ),
                  ],
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
    final photo = await picker.pickImage(source: ImageSource.gallery, imageQuality: 92);
    if (photo == null) return null;
    final originalBytes = await photo.readAsBytes();
    if (!context.mounted) return (file: photo, bytes: originalBytes);

    final cropStyle = await showDialog<CropStyle>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Crop style'),
        contentPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.circle_outlined), title: const Text('Circle'), onTap: () => Navigator.pop(ctx, CropStyle.circle)),
            ListTile(leading: const Icon(Icons.crop_square_rounded), title: const Text('Square'), onTap: () => Navigator.pop(ctx, CropStyle.rectangle)),
          ],
        ),
      ),
    );
    if (cropStyle == null) return (file: photo, bytes: originalBytes);
    if (kIsWeb) return (file: photo, bytes: originalBytes);

    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: photo.path, compressQuality: 92,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(toolbarTitle: 'Crop Photo', hideBottomControls: true, lockAspectRatio: true, cropStyle: CropStyle.rectangle),
          IOSUiSettings(title: 'Crop Photo', aspectRatioLockEnabled: true, cropStyle: cropStyle),
        ],
      );
      if (cropped == null) return (file: photo, bytes: originalBytes);
      final croppedBytes = await cropped.readAsBytes();
      return (file: XFile(cropped.path), bytes: croppedBytes);
    } catch (e) {
      return (file: photo, bytes: originalBytes);
    }
  }

  void _showRemovePinDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove PIN?'),
        content: const Text('Your app will no longer be protected.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ref.read(authProvider.notifier).removePin();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN removed')));
            },
            child: const Text('Remove', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDailyReminderTime(BuildContext context) async {
    final prefs = ref.read(notificationPreferencesProvider);
    final time = await showTimePicker(context: context, initialTime: prefs.routineReminderTime);
    if (time != null) {
      await ref.read(notificationPreferencesProvider.notifier).setRoutineReminderTime(time);
      await ref.read(notificationServiceProvider).scheduleGlobalDailyReminder(
        time: time,
        alertMode: ref.read(notificationPreferencesProvider).alertMode,
      );
    }
  }

  Future<void> _pickBirthdayReminderTime(BuildContext context) async {
    final prefs = ref.read(notificationPreferencesProvider);
    final time = await showTimePicker(context: context, initialTime: prefs.birthdayReminderTime);
    if (time != null) {
      await ref.read(notificationPreferencesProvider.notifier).setBirthdayReminderTime(time);
      final birthdays = await ref.read(databaseProvider).getAllBirthdays();
      await ref.read(notificationServiceProvider).rescheduleAllBirthdayReminders(
        birthdays: birthdays,
        alertMode: ref.read(notificationPreferencesProvider).alertMode,
        hour: time.hour,
        minute: time.minute,
      );
    }
  }

  Future<void> _pickAlertMode(BuildContext context) async {
    final mode = await showDialog<ReminderAlertMode>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Reminder Type'),
        children: ReminderAlertMode.values.map((m) => SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, m),
          child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(_alertModeLabel(m))),
        )).toList(),
      ),
    );
    if (mode != null) await ref.read(notificationPreferencesProvider.notifier).setAlertMode(mode);
  }

  Future<void> _pickIncompleteReminderInterval(BuildContext context) async {
    final hours = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Repeat Interval'),
        children: [0, 1, 2, 4, 8, 12, 24].map((h) => SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, h),
          child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text(_incompleteIntervalLabel(h))),
        )).toList(),
      ),
    );
    if (hours != null) {
      final prefs = ref.read(notificationPreferencesProvider);
      await ref.read(notificationPreferencesProvider.notifier).setIncompleteReminderIntervalHours(hours);
      await IncompleteReminderScheduler.refresh(
        db: ref.read(databaseProvider),
        notification: ref.read(notificationServiceProvider),
        globalReminderTime: prefs.routineReminderTime,
        intervalHours: hours,
        alertMode: prefs.alertMode,
      );
    }
  }

  String _alertModeLabel(ReminderAlertMode mode) {
    switch (mode) {
      case ReminderAlertMode.ringAndVibration: return 'Ring & Vibrate';
      case ReminderAlertMode.ring: return 'Ring only';
      case ReminderAlertMode.vibration: return 'Vibration only';
      case ReminderAlertMode.silent: return 'Silent';
    }
  }

  String _incompleteIntervalLabel(int hours) {
    if (hours == 0) return 'Disabled';
    if (hours == 1) return 'Every 1 hour';
    return 'Every $hours hours';
  }

  Future<void> _runManualBackup() async {
    setState(() => _isBackupBusy = true);
    try {
      final db = ref.read(databaseProvider);
      final service = AppBackupService(db);
      final result = await service.createBackupFile();
      if (!result.success && !result.cancelled) throw Exception(result.message);
      if (result.success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup failed: $e')));
    } finally {
      if (mounted) setState(() => _isBackupBusy = false);
    }
  }

  Future<void> _confirmRestore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Backup?'),
        content: const Text('This will replace all current data with data from the backup file. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isBackupBusy = true);
    try {
      final service = AppBackupService(ref.read(databaseProvider));
      final result = await service.restoreFromFile();
      if (result.cancelled) return;
      if (!result.success) throw Exception(result.message);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Restore complete!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Restore failed: $e')));
    } finally {
      if (mounted) setState(() => _isBackupBusy = false);
    }
  }
}
