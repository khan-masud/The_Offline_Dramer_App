import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/main_shell.dart';
import 'core/services/analytics_service.dart';
import 'features/auth/presentation/screens/lock_screen.dart';
import 'features/settings/presentation/screens/settings_screen.dart';
import 'features/notes/presentation/screens/notes_screen.dart';
import 'features/links/presentation/screens/links_screen.dart';
import 'features/stopwatch/presentation/screens/stopwatch_screen.dart';
import 'features/pomodoro/presentation/screens/pomodoro_screen.dart';
import 'features/habits/presentation/screens/habits_screen.dart';
import 'features/calendar/presentation/screens/calendar_screen.dart';
import 'features/money/presentation/screens/debts_screen.dart';
import 'features/birthday/presentation/screens/birthday_calendar_screen.dart';
import 'features/contacts/presentation/screens/contact_list_screen.dart';
import 'features/diary/presentation/screens/diary_screen.dart';
import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';

import 'package:drift/drift.dart' hide Column;
import 'core/database/database_provider.dart';
import 'core/database/app_database.dart';
import 'core/theme/app_typography.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_dimensions.dart';
import 'main.dart';
import 'core/services/share_intent_service.dart';
import 'features/links/data/links_provider.dart';
import 'features/links/data/link_metadata_service.dart';

/// Navigator observer that logs screen views to Firebase Analytics.
class _AnalyticsNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _logRoute(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) _logRoute(newRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null) _logRoute(previousRoute);
  }

  void _logRoute(Route<dynamic> route) {
    final name = route.settings.name;
    if (name != null && name.isNotEmpty) {
      AnalyticsService().logScreenView(name, screenClass: 'Route');
    }
  }
}

final _navigatorObserver = _AnalyticsNavigatorObserver();

class TODApp extends ConsumerStatefulWidget {
  const TODApp({super.key});

  @override
  ConsumerState<TODApp> createState() => _TODAppState();
}

class _TODAppState extends ConsumerState<TODApp> {
  @override
  void initState() {
    super.initState();
    // Initialize share intent listener
    final shareService = ShareIntentService();
    shareService.onUrlShared = _handleUrlShared;
    shareService.init();
  }

  void _handleUrlShared(String url, String? text) {
    final context = globalNavigatorKey.currentContext;
    if (context != null) {
      _showQuickSaveSheet(context, url, text);
    }
  }

  void _showQuickSaveSheet(BuildContext context, String url, String? text) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _QuickSaveSheet(url: url, text: text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      navigatorKey: globalNavigatorKey,
      title: 'Me++',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      navigatorObservers: [_navigatorObserver],
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
        '/birthdays': (context) => const BirthdayCalendarScreen(),
        '/contacts': (context) => const ContactListScreen(),
        '/diary': (context) => const DiaryScreen(),
      },
    );
  }
}

class _QuickSaveSheet extends ConsumerStatefulWidget {
  final String url;
  final String? text;
  const _QuickSaveSheet({required this.url, this.text});

  @override
  ConsumerState<_QuickSaveSheet> createState() => _QuickSaveSheetState();
}

class _QuickSaveSheetState extends ConsumerState<_QuickSaveSheet> {
  late TextEditingController _titleCtrl;
  String? _selectedFolder;
  bool _isFetchingTitle = false;

  @override
  void initState() {
    super.initState();
    // Auto populate title if possible or leave empty
    _titleCtrl = TextEditingController(text: widget.text == widget.url ? '' : widget.text);
    // Auto-fetch title from URL if title is empty
    if (_titleCtrl.text.isEmpty) {
      _autoFetchTitle();
    }
  }

  Future<void> _autoFetchTitle() async {
    final url = widget.url;
    if (url.isEmpty) return;
    setState(() => _isFetchingTitle = true);
    final meta = await LinkMetadataService.fetchMetadata(url);
    if (mounted && _titleCtrl.text.isEmpty && meta.title.isNotEmpty) {
      setState(() {
        _titleCtrl.text = meta.title;
        _isFetchingTitle = false;
      });
    } else if (mounted) {
      setState(() => _isFetchingTitle = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final foldersAsync = ref.watch(linkFoldersProvider);

    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, bottomInset + 24),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXl)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Save Link', style: AppTypography.headingMedium),
          const SizedBox(height: 16),
          Text(widget.url, style: AppTypography.bodyMedium.copyWith(color: AppColors.primary), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 24),
          
          TextField(
            controller: _titleCtrl,
            decoration: InputDecoration(
              labelText: 'Title',
              prefixIcon: const Icon(Icons.title),
              suffixIcon: _isFetchingTitle
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : null,
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 16),
          
          // Folder Selection
          Text('Folder*', style: AppTypography.labelMedium),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
            child: foldersAsync.when(
              data: (folders) {
                if (folders.isEmpty) return const Text('No folders available.');
                return DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedFolder,
                    hint: const Text('Select a folder'),
                    items: folders.map((f) => DropdownMenuItem(
                      value: f.name,
                      child: Text('${f.emoji} ${f.name}'),
                    )).toList(),
                    onChanged: (v) => setState(() => _selectedFolder = v),
                  ),
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (_, __) => const Text('Error loading folders'),
            ),
          ),
          const SizedBox(height: 24),

          FilledButton(
            onPressed: () async {
              if (_selectedFolder == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a folder')));
                return;
              }
              final db = ref.read(databaseProvider);
              await db.addLink(LinksCompanion(
                title: Value(_titleCtrl.text.trim().isEmpty ? 'Shared Link' : _titleCtrl.text.trim()),
                url: Value(widget.url),
                category: Value(_selectedFolder),
                createdAt: Value(DateTime.now()),
              ));
              if (!context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link saved successfully!')));
            },
            child: const Text('Save Link'),
          ),
        ],
      ),
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

    // After auth — check for pending shared URL
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pendingUrl = ref.read(pendingSharedUrlProvider);
      if (pendingUrl != null && context.mounted) {
        final pendingText = ref.read(pendingSharedTextProvider);
        ref.read(pendingSharedUrlProvider.notifier).state = null;
        ref.read(pendingSharedTextProvider.notifier).state = null;
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _QuickSaveSheet(url: pendingUrl, text: pendingText),
        );
      }
    });

    // Authenticated or no PIN → show main app
    return const MainShell();
  }
}
