import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/main_shell.dart';
import 'features/auth/presentation/screens/lock_screen.dart';
import 'features/settings/presentation/screens/settings_screen.dart';
import 'features/notes/presentation/screens/notes_screen.dart';
import 'features/links/presentation/screens/links_screen.dart';
import 'features/stopwatch/presentation/screens/stopwatch_screen.dart';
import 'features/pomodoro/presentation/screens/pomodoro_screen.dart';
import 'features/habits/presentation/screens/habits_screen.dart';
import 'features/calendar/presentation/screens/calendar_screen.dart';
import 'features/money/presentation/screens/debts_screen.dart';
import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';

class TODApp extends ConsumerWidget {
  const TODApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'The Offline Dreamer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: const _AuthGate(),
      routes: {
        '/settings': (context) => const SettingsScreen(),
        '/notes': (context) => const NotesScreen(),
        '/links': (context) => const LinksScreen(),
        '/stopwatch': (context) => const StopwatchScreen(),
        '/pomodoro': (context) => const PomodoroScreen(),
        '/habits': (context) => const HabitsScreen(),
        '/calendar': (context) => const CalendarScreen(),
        '/debts': (context) => const DebtsScreen(),
      },
    );
  }
}

class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    // Still loading
    if (authState.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // PIN set but not authenticated → show lock screen
    if (authState.isPinSet && !authState.isAuthenticated) {
      return LockScreen(
        onUnlocked: () {
          // Riverpod state change will rebuild this widget
        },
      );
    }

    // Authenticated or no PIN → show main app
    return const MainShell();
  }
}
