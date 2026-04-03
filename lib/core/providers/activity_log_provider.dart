import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _activityLogKey = 'recent_activity_log';
const _maxLogEntries = 50;

class ActivityLogEntry {
  final String type; // 'add' | 'update' | 'delete'
  final String entityType; // 'note' | 'task' | 'routine' | 'transaction' | others
  final String title;
  final DateTime timestamp;

  ActivityLogEntry({
    required this.type,
    required this.entityType,
    required this.title,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'entityType': entityType,
    'title': title,
    'timestamp': timestamp.toIso8601String(),
  };

  factory ActivityLogEntry.fromJson(Map<String, dynamic> json) {
    final rawType = (json['type'] as String?) ?? (json['action'] as String?) ?? 'add';
    return ActivityLogEntry(
      type: _normalizeType(rawType),
      entityType: _normalizeEntityType((json['entityType'] as String?) ?? 'task'),
      title: (json['title'] as String?) ?? (json['entityTitle'] as String?) ?? '',
      timestamp: DateTime.tryParse((json['timestamp'] as String?) ?? '') ?? DateTime.now(),
    );
  }

  static String _normalizeType(String value) {
    switch (value.toLowerCase().trim()) {
      case 'created':
      case 'added':
      case 'add':
        return 'add';
      case 'updated':
      case 'update':
      case 'completed':
        return 'update';
      case 'deleted':
      case 'delete':
        return 'delete';
      default:
        return 'add';
    }
  }

  static String _normalizeEntityType(String value) {
    if (value == 'todo') return 'task';
    return value;
  }

  String get icon {
    switch (type) {
      case 'delete':
        return 'delete';
      case 'update':
        return 'update';
      default:
        switch (entityType) {
          case 'task':
            return 'add_task';
          case 'note':
            return 'note';
          case 'transaction':
            return 'expense';
          case 'routine':
            return 'routine';
          case 'habit':
            return 'habit';
          case 'link':
            return 'link';
          default:
            return 'add_task';
        }
    }
  }

  String get displayTitle {
    final actionLabel = switch (type) {
      'add' => 'Added',
      'update' => 'Updated',
      'delete' => 'Deleted',
      _ => 'Added',
    };
    return '$actionLabel: $title';
  }
}

class ActivityLogNotifier extends StateNotifier<List<ActivityLogEntry>> {
  ActivityLogNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_activityLogKey);
      if (jsonStr != null) {
        final List<dynamic> jsonList = json.decode(jsonStr);
        state = jsonList.map((e) => ActivityLogEntry.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      state = [];
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = json.encode(state.map((e) => e.toJson()).toList());
      await prefs.setString(_activityLogKey, jsonStr);
    } catch (_) {}
  }

  Future<void> log({
    String? type,
    required String entityType,
    required String entityTitle,
    String? action,
  }) async {
    final normalizedType = ActivityLogEntry._normalizeType(type ?? action ?? 'add');
    final entry = ActivityLogEntry(
      type: normalizedType,
      entityType: ActivityLogEntry._normalizeEntityType(entityType),
      title: entityTitle,
      timestamp: DateTime.now(),
    );
    // Add at beginning, trim to max
    state = [entry, ...state].take(_maxLogEntries).toList();
    await _save();
  }

  List<ActivityLogEntry> getRecent({int limit = 10}) {
    return state.take(limit).toList();
  }
}

final activityLogProvider = StateNotifierProvider<ActivityLogNotifier, List<ActivityLogEntry>>(
  (ref) => ActivityLogNotifier(),
);
