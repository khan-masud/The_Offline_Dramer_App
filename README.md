# Me++ — All-in-One Personal Life Management & Productivity Hub

<div align="center">

[![Latest Release](https://img.shields.io/github/v/release/khan-masud/me-plus-plus?label=Download&color=2563EB)](https://github.com/khan-masud/me-plus-plus/releases/latest)
[![Platform](https://img.shields.io/badge/Platform-Android%206.0+-34D399?logo=android&logoColor=white)](https://github.com/khan-masud/me-plus-plus/releases/latest)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.7-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Database](https://img.shields.io/badge/Database-Drift%20SQLite-4479A1?logo=sqlite&logoColor=white)](https://drift.simonbinder.eu/)
[![Architecture](https://img.shields.io/badge/Architecture-Offline--First-10B981)](#-architecture--privacy)
[![License](https://img.shields.io/badge/License-MIT-F59E0B)](LICENSE)

**Extend Yourself** — A private, offline-first personal management system unifying tasks, routines, habits, multi-wallet finances, markdown notes, daily mood diary, calendar, and focus timers into a single Material 3 experience.

[Download Latest APK](https://github.com/khan-masud/me-plus-plus/releases/latest) • [Report Bug](https://github.com/khan-masud/me-plus-plus/issues) • [Request Feature](https://github.com/khan-masud/me-plus-plus/issues)

</div>

---

## 📖 Overview

**Me++** is designed for individuals who want complete control over their daily productivity, personal finances, and mental clarity without depending on cloud lock-in or subscription paywalls. 

Built with **Flutter** and backed by a local **Drift (SQLite)** engine, Me++ keeps **100% of your data on your device** while delivering an interactive, executive UI with smooth micro-animations and zero clutter.

---

## ⚡ Core Feature Modules

### 1. 📊 Executive Dashboard & Morning Hub
- **Time-Aware Greeting & Daily Motivation**: Dynamic greeting with customizable profile, inspirational daily quotes, and "On This Day" historical echoes with smooth accordion reveal.
- **Interactive Weather Hub**: Live temperature, weather condition icons, 24-hour hourly forecast bar chart, air metrics (AQI, Humidity, Wind Speed, UV Index), and location switcher powered by WeatherAPI.
- **Today's Progress Ring**: Visual completion ring aggregating pending tasks, daily routines, and habit check-offs.
- **Cashflow & Consistency Insights**: Visual spending trends and 7-day routine consistency radar.
- **Quick Action Bar**: 1-Tap shortcuts for new tasks, transactions, markdown notes, stopwatch, and web bookmarks.
- **Recent Activity Feed**: Real-time audit log of your latest actions across all modules.

### 2. ✅ Task & Action Management
- **Structured Task Engine**: Due dates, reminder alarms, 4-tier priorities (Urgent, High, Medium, Low), and customizable tag chips with auto-suggestions.
- **Sub-Tasks Modal & Live Progress**: Quick-sheet subtask builder with instant check-off, progress percentage, and strike-through animations.
- **Smart Filtering & Organization**: Segment by All, Today, Upcoming, Priority, and Completed with smooth drag-and-drop reordering.
- **Focus Timer Integration**: Attach Pomodoro or Stopwatch focus sessions directly to any task.
- **Swipe-to-Dismiss with 3s Undo**: Quick task deletion with accidental swipe recovery.

### 3. 🔄 Routine Flow & Consistency Engine
- **Weekly Schedule & Start Times**: Day-of-week routines with custom start/end times and multi-item execution.
- **Interactive Subtasks Sheet**: View and toggle subtasks directly from routine cards without editing the parent item.
- **1-Tap Focus Flow Player**: Guided fullscreen player to progress through routine steps with integrated countdown timers.
- **365-Day Consistency Heatmap**: GitHub-style yearly contribution heatmap tracking execution streaks.

### 4. 💳 Multi-Wallet Money & Cashflow Manager
- **Net Balance Hero Card**: Bold monthly net balance with emerald inflow (`+Income`) and coral outflow (`-Expense`) indicators.
- **Custom Wallets & Accounts Hub**: Create and manage custom accounts (Cash, Bank, bKash, Nagad, Rocket, Credit Card, Savings Vault, Crypto) with custom outline icons, color themes, and starting balances.
- **Live Wallet Balances**: Real-time balance computation per wallet across all historical transactions.
- **Category Spending Breakdown**: Multi-segment horizontal stacked chart with percentage distribution across 16+ spending categories.
- **Category Budgets & Spending Limits**: Set monthly spending caps per category with live warning thresholds.
- **Recurring Transactions**: Automate regular subscriptions, rent, and salaries (Daily, Weekly, Monthly, Yearly).
- **Debts Ledger**: Track lent and borrowed funds with partial payments, debtor contact linking, reminder templates, and wallet settlements.
- **Built-in Quick Calculator**: Overlay keypad for rapid financial math.
- **CSV Statement Export**: Export monthly transaction reports for external spreadsheets.

### 5. 🎯 Habit Tracker & Streak Builder
- **Daily Check-Offs & Streak Counters**: Track positive habits with visual streak badges and weekly target completion.
- **Color Palettes & Custom Icons**: Categorize habits with distinct color themes.
- **Smart Reminders**: Dedicated daily nudge notifications per habit.

### 6. 📝 Markdown Notes & Knowledge Vault
- **Full Markdown Editor**: Live preview support for headings, code blocks, tables, lists, blockquotes, and links.
- **11 Curated Notebook Colors**: Color-code notes for fast visual filtering.
- **Folder Organization**: Categorize notes into dedicated folders with grid/list view toggles.
- **Media Attachments & PDF Export**: Attach photos from camera or gallery and export styled notes as shareable PDF documents.

### 7. 📖 Daily Diary & Mood Journal
- **Daily Reflections & Mood Tracking**: Record private thoughts and tag entries with mood states (Happy, Productive, Grateful, Calm, Tired, etc.).
- **Rich Media & Photo Memories**: Attach memory images directly from camera or gallery.
- **Book-Style Reader Mode**: Distraction-free reader view for revisiting memories like a personal journal book.
- **Chronological Timeline & Search**: Search past reflections by date, keywords, or mood filters.
- **Complete Privacy**: Zero cloud exposure; all diary reflections are stored strictly on-device in local SQLite.

### 8. 🔗 Web Links & Bookmarks Vault
- **Direct Share-to-App Intent**: Share URLs from Chrome, YouTube, Twitter, or any app directly into Me++ to auto-fetch metadata and titles.
- **Folder Filtering & Favorites**: Tag, organize, and search saved links.

### 9. ⏱️ Focus & Time Mastery
- **Pomodoro Timer**: Configurable focus, short break, and long break intervals with animated circular timer rings.
- **Precision Stopwatch**: Millisecond accuracy with lap splits and session recording to SQLite.

### 10. 🎂 Birthdays & 👥 Emergency Contacts
- **Birthday Countdown**: Dynamic countdown alerts ("Today", "Tomorrow", "In X days") with day-before notifications.
- **Offline Contacts Hub**: Store emergency contacts or import from device phonebook with fast search.

### 11. 🔒 Privacy, Security & App Lock
- **4-Digit PIN Security**: App lock with biometric haptics and wrong-pin shake animation.
- **Encrypted Local Backups**: Export and import complete snapshots (`.todbackup`) containing all SQLite tables, preferences, and settings.
- **Zero Cloud Tracking**: All personal entries remain strictly on your device.

---

## 🛠️ Architecture & Tech Stack

```
lib/
├── core/
│   ├── database/           # Drift SQLite database schema & migrations (18 tables)
│   ├── services/           # Notifications, Backup, Analytics, Weather Service
│   ├── theme/              # Material 3 Color Tokens, Typography, Themes
│   └── widgets/            # Reusable buttons, cards, dialogs, bottom sheets
└── features/
    ├── dashboard/          # Morning greeting, weather timeline, progress ring
    ├── todo/               # Tasks, subtasks modal, filters, alarms
    ├── routine/            # Routine flow, focus player, streak heatmap
    ├── money/              # Wallets, transactions, budgets, debts, calculator
    ├── habits/             # Daily habits, consistency trackers
    ├── notes/              # Markdown editor, PDF generator, folders
    ├── diary/              # Daily reflections, mood tracker, reader mode
    ├── links/              # Bookmarks, share intent listener
    ├── focus/              # Pomodoro timer, stopwatch
    ├── contacts/           # Phonebook & emergency contacts
    └── settings/           # App lock, backup/restore, notifications config
```

| Layer | Technology |
|---|---|
| **Framework** | [Flutter](https://flutter.dev) (Dart 3.7) |
| **State Management** | [Riverpod](https://riverpod.dev) |
| **Local Database** | [Drift](https://drift.simonbinder.eu) (SQLite) with SQLite3 Native Libs |
| **Local Notifications** | `flutter_local_notifications` + `timezone` |
| **Charts & Visualization** | `fl_chart` |
| **Markdown Engine** | `flutter_markdown` + `markdown` |
| **Document Generation** | `pdf` + `printing` |
| **Secure Storage** | `flutter_secure_storage` + `shared_preferences` |
| **Analytics & Crash Reports** | Firebase Analytics & Firebase Crashlytics |

---

## 🚀 Building & Running from Source

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`^3.7.0` on `stable` channel)
- Android SDK (API 23+) / Android Studio
- Java 17 (JDK)

### 1. Clone the Repository
```bash
git clone https://github.com/khan-masud/me-plus-plus.git
cd me-plus-plus
```

### 2. Configure Environment Keys
Create a `.env` file in the root directory:
```env
WEATHER_API_KEY=your_weatherapi_key_here
```
*(You can get a free key from [WeatherAPI.com](https://www.weatherapi.com/))*

### 3. Install Dependencies & Generate Code
```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

### 4. Run the App Locally
```bash
flutter run
```

### 5. Build Universal Release APK
```bash
flutter build apk --release
```
The optimized universal APK will be generated at `build/app/outputs/flutter-apk/app-release.apk`.

---

## 🔒 Privacy & Offline-First Philosophy

- **No account creation required**: Open the app and start organizing immediately.
- **Local SQLite storage**: Your tasks, transactions, routines, and notes never leave your device.
- **No intrusive ads or third-party trackers**: Pure productivity without distractions.
- **Full Data Portability**: Export your entire dataset as a `.todbackup` file anytime.

---

## 🤝 Contributing

Contributions, bug reports, and feature suggestions are welcome!
1. Fork the repository.
2. Create your feature branch (`git checkout -b feature/AmazingFeature`).
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`).
4. Push to the branch (`git push origin feature/AmazingFeature`).
5. Open a Pull Request.

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

<div align="center">

**Developed by [Abdullah Al Masud](https://github.com/khan-masud)**

[⬇️ Download Me++](https://github.com/khan-masud/me-plus-plus/releases/latest) • [⭐ Star on GitHub](https://github.com/khan-masud/me-plus-plus)

</div>
