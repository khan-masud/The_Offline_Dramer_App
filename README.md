# Me++

Me++ is a privacy-focused, offline-first personal life management and optimization assistant built with Flutter. It combines task management, routines, notes, finance, birthdays, local contact lists, and utility integrations into one cohesive dashboard.

## Overview

Me++ is designed to keep your personal data local, secure, and fast:

- **Offline-First Architecture**: Powered by Drift (SQLite) for ultra-fast local database operations.
- **Privacy Guaranteed**: Your records remain on your device. Backup and sync operations are explicitly initiated by the user.
- **Rich Dashboard Insights**: Real-time stats on completed tasks, budgets, and habits.
- **Intelligent Reminders**: Fully local background alerts for birthdays, habits, routines, and pending item digests.

## Features

### 📊 Dashboard & Overview
- Greeting card with active user profile name and image.
- Weather timeline showing live temperature and conditions using your own WeatherAPI.com API key (configurable in Settings).
- Real-time productivity overview stats and interactive quick actions.

### 📝 Tasks & Routines
- Advanced Todo list with drag-and-drop reordering restricted to corresponding priority levels.
- Routine tracking with custom streak counters, recurrence frequencies, priority levels, and subtasks.
- Auto-tag suggestions tracking the 5 most recently used labels.

### 💰 Money & Debts
- Income and expense transaction ledger with category tracking.
- Monthly budget allocation limits.
- Lent/Borrowed debt tracker with optional Wallet Integration. Adding installment payments automatically records cash ledger logs, and settling a debt handles the remaining unpaid balances cleanly.

### 📓 Notes & Links
- Category folders with custom background colors.
- Markdown editor with full zoomable image preview/save options.
- Dynamic web link manager supporting external share-intent ingestion (no password prompts required for quick saves).

### 🎂 Birthday Calendar
- Timezone-safe birthday notifications scheduled 24 hours before and/or on the day itself.
- Visual birthday indicators directly on the interactive calendar.

---


## Getting Started

### Prerequisites
- Flutter SDK (stable channel)
- Android SDK (for mobile builds)

### Run from Source
1. Clone the repository:
   ```bash
   git clone https://github.com/khan-masud/me-plus-plus.git
   cd me-plus-plus
   ```
2. Setup environment keys:
   Create a `.env` file in the root directory:
   ```env
   WEATHER_API_KEY=your_default_key_here
   ```
3. Install dependencies:
   ```bash
   flutter pub get
   ```
4. Run code generation:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```
5. Run the application:
   ```bash
   flutter run
   ```

### Compile Release APK
```bash
flutter build apk --release
```
