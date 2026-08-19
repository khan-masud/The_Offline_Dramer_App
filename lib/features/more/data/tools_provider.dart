import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';

class ToolItem {
  final String id;
  final String label;
  final String description;
  final IconData icon;
  final Color color;
  final String route;
  final List<String> searchKeywords;

  const ToolItem({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
    required this.route,
    required this.searchKeywords,
  });
}

const allAppTools = <ToolItem>[
  ToolItem(
    id: 'diary',
    label: 'Diary',
    description: 'Daily thoughts, reflections, memories & structured logs',
    icon: Icons.menu_book_rounded,
    color: AppColors.purple,
    route: '/diary',
    searchKeywords: ['diary', 'daily', 'notes', 'journal', 'writing', 'reflection', 'memories'],
  ),
  ToolItem(
    id: 'notes',
    label: 'Notes',
    description: 'Rich markdown notes, version history & PDF export',
    icon: Icons.note_alt_outlined,
    color: AppColors.teal,
    route: '/notes',
    searchKeywords: ['notes', 'docs', 'text', 'markdown', 'draft', 'writing'],
  ),
  ToolItem(
    id: 'links',
    label: 'Links',
    description: 'Visual bookmark saver with OpenGraph previews & tags',
    icon: Icons.link_rounded,
    color: AppColors.info,
    route: '/links',
    searchKeywords: ['links', 'bookmarks', 'urls', 'web', 'save', 'reading'],
  ),
  ToolItem(
    id: 'calendar',
    label: 'Calendar',
    description: 'Unified agenda hub aggregating tasks, money, habits & diary',
    icon: Icons.calendar_month_rounded,
    color: AppColors.pink,
    route: '/calendar',
    searchKeywords: ['calendar', 'events', 'schedule', 'agenda', 'month', 'date'],
  ),
  ToolItem(
    id: 'habits',
    label: 'Habits',
    description: 'Daily streak tracker, completions calendar & reminders',
    icon: Icons.trending_up_rounded,
    color: AppColors.purple,
    route: '/habits',
    searchKeywords: ['habits', 'streak', 'tracker', 'daily', 'routine', 'goals'],
  ),
  ToolItem(
    id: 'debts',
    label: 'Debts',
    description: 'Track money lent & borrowed with WhatsApp reminder templates',
    icon: Icons.handshake_outlined,
    color: AppColors.orange,
    route: '/debts',
    searchKeywords: ['debts', 'money', 'loans', 'borrow', 'lend', 'settle', 'khata'],
  ),
  ToolItem(
    id: 'pomodoro',
    label: 'Pomodoro',
    description: 'Custom focus timer with break intervals & linked tasks',
    icon: Icons.hourglass_bottom_rounded,
    color: AppColors.error,
    route: '/pomodoro',
    searchKeywords: ['pomodoro', 'focus', 'work', 'session', 'timer', 'break'],
  ),
  ToolItem(
    id: 'stopwatch',
    label: 'Stopwatch',
    description: 'Precision timer with lap split times',
    icon: Icons.timer_outlined,
    color: AppColors.orange,
    route: '/stopwatch',
    searchKeywords: ['stopwatch', 'timer', 'lap', 'clock', 'time', 'split'],
  ),
  ToolItem(
    id: 'birthdays',
    label: 'Birthdays',
    description: 'Countdown alerts & 1-tap WhatsApp greetings',
    icon: Icons.cake_outlined,
    color: AppColors.pink,
    route: '/birthdays',
    searchKeywords: ['birthdays', 'bday', 'anniversary', 'special', 'wish', 'cake'],
  ),
  ToolItem(
    id: 'contacts',
    label: 'Contacts',
    description: 'Phonebook directory linked to debts & birthdays',
    icon: Icons.contact_phone_outlined,
    color: AppColors.info,
    route: '/contacts',
    searchKeywords: ['contacts', 'people', 'phone', 'friends', 'directory', 'phonebook'],
  ),
  ToolItem(
    id: 'settings',
    label: 'Settings',
    description: 'App lock, themes, backup & notifications configuration',
    icon: Icons.settings_outlined,
    color: AppColors.lightTextSecondary,
    route: '/settings',
    searchKeywords: ['settings', 'config', 'preferences', 'backup', 'lock', 'theme'],
  ),
  ToolItem(
    id: 'report_issue',
    label: 'Report Issue',
    description: 'Report bugs or suggest new features via GitHub Issues',
    icon: Icons.bug_report_outlined,
    color: AppColors.error,
    route: 'https://github.com/khan-masud/me-plus-plus/issues/new',
    searchKeywords: ['bug', 'report', 'issue', 'feature', 'request', 'github', 'suggest', 'feedback'],
  ),
];

// State notifier for tool personalization & usage stats
class ToolsPersonalizationState {
  final Set<String> pinnedIds;
  final Map<String, int> usageCounts;
  final Map<String, int> lastUsedTimestamps;
  final String searchQuery;

  const ToolsPersonalizationState({
    required this.pinnedIds,
    required this.usageCounts,
    required this.lastUsedTimestamps,
    required this.searchQuery,
  });

  ToolsPersonalizationState copyWith({
    Set<String>? pinnedIds,
    Map<String, int>? usageCounts,
    Map<String, int>? lastUsedTimestamps,
    String? searchQuery,
  }) {
    return ToolsPersonalizationState(
      pinnedIds: pinnedIds ?? this.pinnedIds,
      usageCounts: usageCounts ?? this.usageCounts,
      lastUsedTimestamps: lastUsedTimestamps ?? this.lastUsedTimestamps,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class ToolsPersonalizationNotifier extends StateNotifier<ToolsPersonalizationState> {
  ToolsPersonalizationNotifier()
      : super(const ToolsPersonalizationState(
          pinnedIds: {},
          usageCounts: {},
          lastUsedTimestamps: {},
          searchQuery: '',
        )) {
    _loadState();
  }

  static const _pinnedKey = 'user_pinned_tools';
  static const _usageKey = 'user_tool_usage_counts';
  static const _lastUsedKey = 'user_tool_last_used';

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final pinnedList = prefs.getStringList(_pinnedKey) ?? [];
    final usageRaw = prefs.getString(_usageKey);
    final lastUsedRaw = prefs.getString(_lastUsedKey);

    Map<String, int> usageMap = {};
    if (usageRaw != null) {
      try {
        final decoded = jsonDecode(usageRaw) as Map<String, dynamic>;
        usageMap = decoded.map((k, v) => MapEntry(k, v as int));
      } catch (_) {}
    }

    Map<String, int> lastUsedMap = {};
    if (lastUsedRaw != null) {
      try {
        final decoded = jsonDecode(lastUsedRaw) as Map<String, dynamic>;
        lastUsedMap = decoded.map((k, v) => MapEntry(k, v as int));
      } catch (_) {}
    }

    state = state.copyWith(
      pinnedIds: pinnedList.toSet(),
      usageCounts: usageMap,
      lastUsedTimestamps: lastUsedMap,
    );
  }

  // Toggle Pin / Featured state
  Future<void> togglePin(String toolId) async {
    final updated = Set<String>.from(state.pinnedIds);
    if (updated.contains(toolId)) {
      updated.remove(toolId);
    } else {
      updated.add(toolId);
    }
    state = state.copyWith(pinnedIds: updated);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_pinnedKey, updated.toList());
  }

  // Track Tool Tap / Usage
  Future<void> trackUsage(String toolId) async {
    final updatedCounts = Map<String, int>.from(state.usageCounts);
    final updatedTimestamps = Map<String, int>.from(state.lastUsedTimestamps);

    updatedCounts[toolId] = (updatedCounts[toolId] ?? 0) + 1;
    updatedTimestamps[toolId] = DateTime.now().millisecondsSinceEpoch;

    state = state.copyWith(
      usageCounts: updatedCounts,
      lastUsedTimestamps: updatedTimestamps,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usageKey, jsonEncode(updatedCounts));
    await prefs.setString(_lastUsedKey, jsonEncode(updatedTimestamps));
  }

  // Update Debounced Search Query
  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }
}

final toolsPersonalizationProvider = StateNotifierProvider<ToolsPersonalizationNotifier, ToolsPersonalizationState>((ref) {
  return ToolsPersonalizationNotifier();
});

// Computed Sorted & Filtered Tools
final sortedAndFilteredToolsProvider = Provider<List<ToolItem>>((ref) {
  final personalization = ref.watch(toolsPersonalizationProvider);
  final query = personalization.searchQuery.trim().toLowerCase();
  final pinned = personalization.pinnedIds;
  final usage = personalization.usageCounts;
  final lastUsed = personalization.lastUsedTimestamps;

  // 1. Search Filter
  var items = allAppTools.where((tool) {
    if (query.isEmpty) return true;
    if (tool.label.toLowerCase().contains(query)) return true;
    if (tool.description.toLowerCase().contains(query)) return true;
    return tool.searchKeywords.any((kw) => kw.toLowerCase().contains(query));
  }).toList();

  // 2. Personalization Sorting: Pinned first, then by highest usage count, then by last used timestamp
  items.sort((a, b) {
    final aPinned = pinned.contains(a.id);
    final bPinned = pinned.contains(b.id);

    if (aPinned && !bPinned) return -1;
    if (!aPinned && bPinned) return 1;

    final aCount = usage[a.id] ?? 0;
    final bCount = usage[b.id] ?? 0;
    if (aCount != bCount) {
      return bCount.compareTo(aCount); // Higher count first
    }

    final aTime = lastUsed[a.id] ?? 0;
    final bTime = lastUsed[b.id] ?? 0;
    return bTime.compareTo(aTime); // More recently used first
  });

  return items;
});
