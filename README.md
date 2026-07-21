# 🚀 Me++ (TOD)

<div align="center">

[![Latest Release](https://img.shields.io/github/v/release/khan-masud/me-plus-plus?label=Download&color=2196F3)](https://github.com/khan-masud/me-plus-plus/releases/latest)
[![Platform](https://img.shields.io/badge/platform-Android-4CAF50)](https://github.com/khan-masud/me-plus-plus/releases/latest)
[![License](https://img.shields.io/badge/license-MIT-yellow)](LICENSE)

**Extend Yourself** — An all-in-one personal productivity and life management app.

[⬇️ Download Latest APK](https://github.com/khan-masud/me-plus-plus/releases/latest)

</div>

Me++ is a privacy-focused, offline-first personal life management assistant built with Flutter. It combines task management, routines, notes, finance tracking, birthdays, contacts, habit tracking, focus tools, and more — all wrapped in a modern Material 3 design.

---

## ✨ Features

### 📊 Dashboard (Home Screen)

| Widget | Description |
|--------|-------------|
| **Greeting Header** | Time-based greeting with emoji, profile photo, daily inspirational quote, and "On This Day" historical event |
| **Weather Timeline** | Current weather + hourly forecast via WeatherAPI.com with location-based updates |
| **Overview Cards** | 4 quick-stat cards: Pending Tasks, Today's Routines, Spent Today, and Total Notes |
| **Insights** | Money flow charts (bar + pie) and productivity radar chart for today's completion |
| **Quick Actions** | One-tap shortcuts: Add Task, Add Expense, New Note, Stopwatch, Save Link |
| **Recent Activity** | Last 8 actions across all modules with timestamps |

### ✅ Task Manager

- Create, edit, delete tasks with title, description, due date, priority & category
- **Sub-tasks** with completion tracking & progress bar
- **Tags** with auto-suggestions from recent labels
- Search, filter (All/Pending/Completed), drag-to-reorder, swipe-to-delete with UNDO
- Per-task **reminders** with local notifications
- Link **pomodoro/stopwatch sessions** to any task

### 🔄 Routine Manager

- Weekly routines with multi-item support, start/end times & per-item priority
- **Sub-tasks** and **completion tracking** with streak calculation
- Auto-filters by current day of the week
- Multiple reminders per routine

### 🎯 Habit Tracker

- Create habits with emoji, color, and weekly target
- Daily check-off with progress bar & streak tracking
- Optional daily reminders

### 📝 Notes

- Full **Markdown editor** with live preview
- **11 background colors**, folders, pinning, search
- Grid/List view toggle
- **Export to PDF**, share, add images from camera/gallery

### 🔗 Links / Bookmarks

- Save links with folders, auto-fetch webpage titles
- Favorites, search, folder filtering
- **Share Intent** — Save URLs from any app instantly

### 💰 Money Manager

- **Income/Expense** tracking with 16 categories
- Monthly budget with spending progress bar
- Category breakdown charts
- **Recurring transactions** (daily/weekly/monthly/yearly)
- **Debt tracker** — Lent/borrowed with partial payments, settlement, and wallet integration

### 📅 Calendar

- Monthly grid with all events aggregated
- Filter by type: Todos, Transactions, Habits, Routines, Focus, Debts, Birthdays

### 🎂 Birthday Tracker

- Countdown display ("Today", "Tomorrow", "X days left")
- Day-before + on-day notifications with configurable time

### 👥 Contacts

- Manual add or import from phonebook
- Auto-sync every 30 days, search, source tracking

### ⏱️ Focus Tools

- **Pomodoro Timer** — Customizable focus/break phases with circular progress ring
- **Stopwatch** — Precision timer with lap tracking
- Sessions saved to database

### 🔒 App Lock

- 4-digit PIN with shake animation on wrong input
- Haptic feedback, enable/disable in Settings

### ⚙️ Settings

| Setting | Description |
|---------|-------------|
| Profile | Edit name, set profile photo |
| Dark Mode | Toggle light/dark theme |
| App Lock | Enable/disable PIN |
| Weather API Key | Custom WeatherAPI.com key |
| Daily Routine Reminder | Set notification time |
| Reminder Type | Ring / Vibration / Silent |
| Incomplete Reminder Interval | 1-12 hours follow-up |
| Birthday Notification Time | Custom reminder time |
| Backup / Restore | Export/import all data as `.todbackup` |

### 🔔 Notifications

- Todo reminders, routine reminders, daily digest
- Habit nudges, incomplete task follow-ups (1-12 hr interval)
- Birthday alerts (day-before + on-day)
- Multiple alert modes (Ring, Vibration, Silent)

### 💾 Backup & Restore

- Full backup of database, settings, PIN, and app files
- One-tap restore from `.todbackup` file

### 📤 Share Intent

- Receive URLs from any app → save as link instantly
- Works on cold start and in-memory

### 📊 Analytics & Crash Reporting (Firebase)

- Automatic screen view tracking
- 40+ custom events for feature usage insights
- Crashlytics for bug detection

---

## 📱 Download

Get the latest version of Me++:

| Method | Link |
|--------|------|
| **GitHub Release (APK)** | [⬇️ Download Latest](https://github.com/khan-masud/me-plus-plus/releases/latest) |
| **All Releases** | [View All Releases](https://github.com/khan-masud/me-plus-plus/releases) |

---

## 🛠️ Tech Stack

| Component | Technology |
|-----------|-----------|
| **Framework** | Flutter + Dart 3.7 |
| **State Management** | Riverpod |
| **Local Database** | Drift (SQLite) — 18 tables |
| **Notifications** | flutter_local_notifications |
| **Analytics** | Firebase Analytics & Crashlytics |
| **Charts** | fl_chart |
| **Fonts** | Google Fonts Inter |

---

## 🚀 Getting Started

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

---

## 🔑 Key Features at a Glance

- ✅ **Offline-first** — all data stored locally on your device
- 🎨 **Modern Material 3** UI with light/dark themes
- 🔔 **Smart notifications** — never miss a task or birthday
- 💾 **Full backup & restore** — your data, your control
- 🔒 **PIN lock** for privacy
- 🌐 **Weather integration** with live forecasts
- 📱 **Share intent** support for quick link saving
- 📊 **No ads**, no unnecessary permissions, no data collection

---

<div align="center">

**Made with ❤️ by Abdullah Al Masud**

[⬇️ Download Me++](https://github.com/khan-masud/me-plus-plus/releases/latest) · [Report Issue](https://github.com/khan-masud/me-plus-plus/issues) · [Request Feature](https://github.com/khan-masud/me-plus-plus/issues)

</div>
