import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Centralized analytics service for tracking all app events.
/// Singleton — call [AnalyticsService.instance] from anywhere.
class AnalyticsService {
  // ── Singleton ───────────────────────────────────────────────
  AnalyticsService._internal();
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;

  FirebaseAnalytics get _analytics => FirebaseAnalytics.instance;
  FirebaseCrashlytics get _crashlytics => FirebaseCrashlytics.instance;

  bool _initialized = false;

  /// Must be called once after Firebase.initializeApp()
  void init({bool enableAnalytics = true}) {
    if (_initialized || kIsWeb) return;
    _analytics.setAnalyticsCollectionEnabled(enableAnalytics);
    _initialized = true;
  }

  // ═══════════════════════════════════════════════════════════════
  //  SCREEN VIEWS
  // ═══════════════════════════════════════════════════════════════

  Future<void> logScreenView(String screenName, {String? screenClass}) async {
    try {
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass ?? screenName,
      );
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════
  //  AUTH
  // ═══════════════════════════════════════════════════════════════

  Future<void> logPinSet() async => _logEvent('pin_set');
  Future<void> logPinRemoved() async => _logEvent('pin_removed');
  Future<void> logAppUnlocked() async => _logEvent('app_unlocked');

  // ═══════════════════════════════════════════════════════════════
  //  TASKS (TODOS)
  // ═══════════════════════════════════════════════════════════════

  Future<void> logTaskCreated({
    required String title,
    int priority = 0,
    List<String> tags = const [],
    bool hasDueDate = false,
    bool hasSubtask = false,
  }) async {
    await _logEvent('task_created', parameters: {
      'priority': priority.toString(),
      'has_due_date': hasDueDate.toString(),
      'has_subtask': hasSubtask.toString(),
      'tag_count': tags.length.toString(),
    });
  }

  Future<void> logTaskCompleted() async => _logEvent('task_completed');
  Future<void> logTaskDeleted() async => _logEvent('task_deleted');
  Future<void> logTaskFilterChanged(String filter) async {
    await _logEvent('task_filter_changed', parameters: {'filter': filter});
  }

  Future<void> logSubtaskAdded() async => _logEvent('subtask_added');
  Future<void> logSubtaskCompleted() async => _logEvent('subtask_completed');

  // ═══════════════════════════════════════════════════════════════
  //  ROUTINES
  // ═══════════════════════════════════════════════════════════════

  Future<void> logRoutineCreated({
    required String title,
    int priority = 2,
    int itemCount = 0,
  }) async {
    await _logEvent('routine_created', parameters: {
      'priority': priority.toString(),
      'item_count': itemCount.toString(),
    });
  }

  Future<void> logRoutineItemCompleted() async {
    await _logEvent('routine_item_completed');
  }

  Future<void> logRoutineDeleted() async => _logEvent('routine_deleted');

  // ═══════════════════════════════════════════════════════════════
  //  NOTES
  // ═══════════════════════════════════════════════════════════════

  Future<void> logNoteCreated({String? folder}) async {
    await _logEvent('note_created', parameters: {
      'folder': folder ?? 'none',
    });
  }

  Future<void> logNoteDeleted() async => _logEvent('note_deleted');
  Future<void> logNotePinned() async => _logEvent('note_pinned');
  Future<void> logNoteViewToggled(bool isGrid) async {
    await _logEvent('note_view_toggled', parameters: {
      'view': isGrid ? 'grid' : 'list',
    });
  }

  // ═══════════════════════════════════════════════════════════════
  //  LINKS (BOOKMARKS)
  // ═══════════════════════════════════════════════════════════════

  Future<void> logLinkSaved({String? folder}) async {
    await _logEvent('link_saved', parameters: {
      'folder': folder ?? 'none',
    });
  }

  Future<void> logLinkOpened() async => _logEvent('link_opened');
  Future<void> logLinkFolderCreated() async => _logEvent('link_folder_created');

  // ═══════════════════════════════════════════════════════════════
  //  HABITS
  // ═══════════════════════════════════════════════════════════════

  Future<void> logHabitCreated() async => _logEvent('habit_created');
  Future<void> logHabitCompleted() async => _logEvent('habit_completed');
  Future<void> logHabitDeleted() async => _logEvent('habit_deleted');

  // ═══════════════════════════════════════════════════════════════
  //  MONEY / TRANSACTIONS
  // ═══════════════════════════════════════════════════════════════

  Future<void> logTransactionAdded({
    required String type, // 'income' | 'expense'
    required double amount,
    required String category,
  }) async {
    await _logEvent('transaction_added', parameters: {
      'type': type,
      'category': category,
      'amount_range': _amountBucket(amount),
    });
  }

  Future<void> logTransactionDeleted() async => _logEvent('transaction_deleted');
  Future<void> logBudgetSet() async => _logEvent('budget_set');

  // ═══════════════════════════════════════════════════════════════
  //  DEBTS
  // ═══════════════════════════════════════════════════════════════

  Future<void> logDebtAdded({required String type}) async {
    await _logEvent('debt_added', parameters: {'type': type});
  }

  Future<void> logDebtPaymentAdded() async => _logEvent('debt_payment_added');
  Future<void> logDebtSettled() async => _logEvent('debt_settled');

  // ═══════════════════════════════════════════════════════════════
  //  FOCUS / POMODORO / STOPWATCH
  // ═══════════════════════════════════════════════════════════════

  Future<void> logPomodoroSession({
    required int completedSessions,
    required int focusMinutes,
  }) async {
    await _logEvent('pomodoro_session', parameters: {
      'completed_sessions': completedSessions.toString(),
      'focus_minutes': focusMinutes.toString(),
    });
  }

  Future<void> logStopwatchSession({required int durationSeconds}) async {
    await _logEvent('stopwatch_session', parameters: {
      'duration_seconds': durationSeconds.toString(),
    });
  }

  // ═══════════════════════════════════════════════════════════════
  //  BIRTHDAYS
  // ═══════════════════════════════════════════════════════════════

  Future<void> logBirthdayAdded() async => _logEvent('birthday_added');
  Future<void> logBirthdayDeleted() async => _logEvent('birthday_deleted');

  // ═══════════════════════════════════════════════════════════════
  //  CONTACTS
  // ═══════════════════════════════════════════════════════════════

  Future<void> logContactAdded({required String source}) async {
    await _logEvent('contact_added', parameters: {'source': source});
  }

  Future<void> logContactSynced() async => _logEvent('contact_synced');

  // ═══════════════════════════════════════════════════════════════
  //  CALENDAR
  // ═══════════════════════════════════════════════════════════════

  Future<void> logCalendarMonthViewed() async => _logEvent('calendar_month_viewed');
  Future<void> logCalendarEventFilterChanged(String filter) async {
    await _logEvent('calendar_filter_changed', parameters: {'filter': filter});
  }

  // ═══════════════════════════════════════════════════════════════
  //  SETTINGS & THEME
  // ═══════════════════════════════════════════════════════════════

  Future<void> logThemeChanged(String theme) async {
    await _logEvent('theme_changed', parameters: {'theme': theme});
  }

  Future<void> logBackupCreated() async => _logEvent('backup_created');
  Future<void> logBackupRestored() async => _logEvent('backup_restored');

  Future<void> logProfileUpdated() async => _logEvent('profile_updated');

  // ═══════════════════════════════════════════════════════════════
  //  SHARE INTENT
  // ═══════════════════════════════════════════════════════════════

  Future<void> logShareIntentReceived() async => _logEvent('share_intent_received');
  Future<void> logQuickSaveCompleted() async => _logEvent('quick_save_completed');

  // ═══════════════════════════════════════════════════════════════
  //  ENGAGEMENT (Feature usage frequency)
  // ═══════════════════════════════════════════════════════════════

  Future<void> logFeatureUsed(String feature) async {
    await _logEvent('feature_used', parameters: {'feature': feature});
  }

  // ═══════════════════════════════════════════════════════════════
  //  USER PROPERTIES
  // ═══════════════════════════════════════════════════════════════

  Future<void> setUserProperty(String name, String value) async {
    try {
      await _analytics.setUserProperty(name: name, value: value);
    } catch (_) {}
  }

  /// Track theme preference
  Future<void> setThemeProperty(String theme) async {
    await setUserProperty('theme', theme);
  }

  /// Track whether user completed onboarding
  Future<void> setOnboardingComplete() async {
    await setUserProperty('onboarding', 'complete');
  }

  // ═══════════════════════════════════════════════════════════════
  //  ERROR TRACKING
  // ═══════════════════════════════════════════════════════════════

  /// Log a non-fatal error to Crashlytics
  Future<void> logError(String message, {StackTrace? stackTrace, dynamic context}) async {
    try {
      await _crashlytics.log(message);
      if (context != null) {
        await _crashlytics.setCustomKey('error_context', context.toString());
      }
      if (stackTrace != null) {
        await _crashlytics.recordError(message, stackTrace);
      }
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════
  //  INTERNALS
  // ═══════════════════════════════════════════════════════════════

  Future<void> _logEvent(String name, {Map<String, String>? parameters}) async {
    try {
      await _analytics.logEvent(name: name, parameters: parameters);
    } catch (_) {}
  }

  /// Bucket amounts into ranges for analytics (no exact amount sent)
  String _amountBucket(double amount) {
    final abs = amount.abs();
    if (abs < 100) return 'under_100';
    if (abs < 500) return '100_500';
    if (abs < 1000) return '500_1k';
    if (abs < 5000) return '1k_5k';
    if (abs < 10000) return '5k_10k';
    if (abs < 50000) return '10k_50k';
    return 'over_50k';
  }
}
