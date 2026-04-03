# The Offline Dreamer (TOD)

The Offline Dreamer (TOD) is a privacy-focused, offline-first personal life management app built with Flutter. It combines tasks, routines, notes, finance, birthdays, contacts, and utilities in one app.

## Overview

TOD is designed to keep your personal data local and responsive:

- Offline-first architecture using Drift (SQLite)
- Fast local-first workflows
- Built-in reminders and scheduling
- Manual full backup and restore support

## Features

### Dashboard and Daily Overview

- Daily summary for tasks, routines, and activity
- Weather timeline and condition visuals
- Quick app shortcuts

### Tasks and Routines

- Task list with filters (All, Pending, Done)
- Routine tracking with priorities, subtasks, and streaks
- Reminder scheduling and startup re-scheduling

### Money and Debts

- Income and expense transaction tracking
- Monthly budget management
- Debt tools for lent/borrowed tracking
- Quick actions section with popup calculator and debt shortcut

### Notes and Links

- Rich notes editor with markdown preview
- Folder and color organization
- Link manager with folder grouping and quick save/share flow

### Birthday Calendar

- Save birthdays once with date of birth
- Yearly reminder behavior (no need to re-add every year)
- Optional notifications:
  - 1 day before at 12:00 AM
  - Birthday day at 12:00 AM

### Contact List

- Save contacts in local database
- Search, view, edit, copy, and manual add
- Phone contact import/sync support
- Monthly sync policy with new-number ingestion

## Backup and Restore

TOD includes a manual full backup/restore system from Settings.

### What gets backed up

- All Drift database tables (auto discovered)
- SharedPreferences keys
- FlutterSecureStorage keys (for example, PIN data)
- Native app document files (except database files and backup directory itself)

### Dynamic backup behavior

Backup is schema-driven for DB and key-driven for preferences/storage. New tools that store data in DB/prefs/secure storage are automatically included in backup/restore without needing per-feature backup mapping.

### Platform behavior

- Web: backup triggers browser download
- Native (Android/iOS/desktop): backup is saved in app documents backups folder

### Backup actions

After manual backup (native), quick actions are available:

- Open backup file
- Open backup folder
- Share backup file

## Technology Stack

- Framework: Flutter (Dart)
- State Management: Riverpod
- Local Database: Drift + SQLite
- Notifications: flutter_local_notifications + timezone
- Integrations: share_handler, flutter_contacts, image_picker, image_cropper, url_launcher, geolocator, http

## Run from Source

```bash
flutter pub get
flutter run
```

For release builds:

```bash
flutter build apk --release
```

## Privacy

TOD is built as an offline-first app. Your personal records remain on your device unless you explicitly export/backup/share them.
