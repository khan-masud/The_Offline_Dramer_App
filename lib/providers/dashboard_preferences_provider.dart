import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardPreferences {
  final bool showDailyMotivation;
  final bool showDailyEvents;
  final bool showWeather;

  const DashboardPreferences({
    this.showDailyMotivation = true,
    this.showDailyEvents = true,
    this.showWeather = true,
  });

  DashboardPreferences copyWith({
    bool? showDailyMotivation,
    bool? showDailyEvents,
    bool? showWeather,
  }) {
    return DashboardPreferences(
      showDailyMotivation: showDailyMotivation ?? this.showDailyMotivation,
      showDailyEvents: showDailyEvents ?? this.showDailyEvents,
      showWeather: showWeather ?? this.showWeather,
    );
  }
}

class DashboardPreferencesNotifier extends StateNotifier<DashboardPreferences> {
  static const _keyMotivation = 'dashboard_show_motivation';
  static const _keyEvents = 'dashboard_show_events';
  static const _keyWeather = 'dashboard_show_weather';

  DashboardPreferencesNotifier() : super(const DashboardPreferences()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = DashboardPreferences(
      showDailyMotivation: prefs.getBool(_keyMotivation) ?? true,
      showDailyEvents: prefs.getBool(_keyEvents) ?? true,
      showWeather: prefs.getBool(_keyWeather) ?? true,
    );
  }

  Future<void> toggleMotivation([bool? value]) async {
    final newValue = value ?? !state.showDailyMotivation;
    state = state.copyWith(showDailyMotivation: newValue);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyMotivation, newValue);
  }

  Future<void> toggleEvents([bool? value]) async {
    final newValue = value ?? !state.showDailyEvents;
    state = state.copyWith(showDailyEvents: newValue);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEvents, newValue);
  }

  Future<void> toggleWeather([bool? value]) async {
    final newValue = value ?? !state.showWeather;
    state = state.copyWith(showWeather: newValue);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyWeather, newValue);
  }
}

final dashboardPreferencesProvider =
    StateNotifierProvider<DashboardPreferencesNotifier, DashboardPreferences>((ref) {
  return DashboardPreferencesNotifier();
});
