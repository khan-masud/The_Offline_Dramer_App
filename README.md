# The Offline Dreamer (TOD)

The Offline Dreamer (TOD) is a comprehensive, privacy-focused, offline-first personal life management application built with Flutter. It seamlessly integrates your tasks, routines, finances, links, and notes into a single beautiful interface.

## 🚀 Key Features

### 📅 Dashboard & Overview
*   **Today's Overview:** A gorgeous, glanceable dashboard summarizing your pending tasks, routines, daily spending, and notes.
*   **Live Weather Timeline:** Interactive, real-time weather integration dynamically updating you on daily conditions using smart emoji representation.

### ✅ Task & Routine Management
*   **Tasks Checklist:** Organize your day efficiently.
*   **Routines Tracker:** Keep your positive habits going with streak tracking and daily progress.

### 💰 Money Manager
*   **Transactions:** Track expenses and income seamlessly with categorizations.
*   **Debt Form:** Keep a log of money Lent (📤) and Borrowed (📥) localized in English for easy reading.
*   **Monthly Budget:** Setup and track your spending against monthly targets.

### 📝 Notes & Markdown
*   **Markdown Editor:** Write rich-formatted text in real-time. Typing `**bold**` or creating `- [ ] Checkboxes` dynamically highlights as you type.
*   **Masonry Layout:** Google Keep style responsive grid for quickly reading your pinned and recent notes.
*   **Color & Folder Coding:** Keep your ideas brilliantly organized visually.

### 🔗 Link Manager
*   **Folder System:** Create folders to group your links (e.g., Work, Shopping, Social).
*   **Quick Share Intents:** The app listens to Android Share events—whenever you are in Chrome or another app, tap "Share", select TOD, and immediately save the link!
*   **Quick Actions:** Open links instantly, or copy everything over to your clipboard in a tap.

## 🛠️ Technology Stack

*   **Framework:** [Flutter](https://flutter.dev/) (Dart) 
*   **State Management:** [Riverpod](https://riverpod.dev/) (`flutter_riverpod`)
*   **Local Database:** [Drift](https://drift.simonbinder.eu/) (SQLite for robust offline-first relational data)
*   **Design:** Material 3, Custom Typography, and Theming (`Google Fonts`, `flutter_animate`)
*   **Integrations:** 
    *   `share_handler` for OS-level native URL sharing.
    *   `geolocator` & `http` for Weather API.
    *   `url_launcher` for navigation.

## 📥 Download & Installation

The easiest way to install and try out **The Offline Dreamer** is by downloading the ready-to-use APK file from the GitHub Releases page.

### Option 1: Direct APK Download (Recommended)
You can directly download the latest Android `.apk` file:
1. Go to the [Releases](../../releases) page of this repository.
2. Download the `app-release.apk` file from the latest version tag.
3. Install it on your Android device (ensure "Install from unknown sources" is enabled in your Android settings).

### Option 2: Build from Source
If you are a developer and want to build the app yourself:

1. Clone or download the repository to your local machine.
2. Fetch the required dependencies:
   ```bash
   flutter pub get
   ```
3. Run or build the app:
   ```bash
   flutter run
   # OR to build the release APK:
   flutter build apk --release
   ```
*(Note: To test Android Share Intents, ensure you test on an actual Android Emulator or Physical Android Device, as the Web Browser doesn't natively support this feature).*

## 🔒 Privacy & Architecture

**The Offline Dreamer** was built on the philosophy of privacy. It is an **offline-first** application utilizing a local SQLite database (`Drift`), meaning your personal tasks, routines, financial logs, and notes belong strictly to you and aren't synced automatically to unknown third-party clouds.
