import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/weather_provider.dart';

class WeatherTimeline extends ConsumerStatefulWidget {
  const WeatherTimeline({super.key});

  @override
  ConsumerState<WeatherTimeline> createState() => _WeatherTimelineState();
}

class _WeatherTimelineState extends ConsumerState<WeatherTimeline> {
  int _selectedHourIndex = 0;
  bool _isRefreshing = false;

  IconData _getWeatherIcon(int code, bool isDay) {
    final text = code.toString();
    if (text.contains('1000')) {
      return isDay ? Icons.wb_sunny_outlined : Icons.nights_stay_outlined;
    }
    if (text.contains('1003') || text.contains('1006') || text.contains('1009')) {
      return isDay ? Icons.wb_cloudy_outlined : Icons.cloud_outlined;
    }
    if (text.contains('1030') || text.contains('1135') || text.contains('1147')) {
      return Icons.foggy;
    }
    if (text.contains('1063') ||
        text.contains('1150') ||
        text.contains('1153') ||
        text.contains('1180') ||
        text.contains('1183') ||
        text.contains('1186') ||
        text.contains('1189') ||
        text.contains('1192') ||
        text.contains('1195') ||
        text.contains('1240') ||
        text.contains('1243') ||
        text.contains('1246')) {
      return Icons.water_drop_outlined;
    }
    if (text.contains('1087') || text.contains('1273') || text.contains('1276') || text.contains('1279')) {
      return Icons.thunderstorm_outlined;
    }
    if (text.contains('1066') || text.contains('1114') || text.contains('1210') || text.contains('1213') || text.contains('1219')) {
      return Icons.ac_unit_rounded;
    }
    return isDay ? Icons.wb_sunny_outlined : Icons.nights_stay_outlined;
  }

  Color _getWeatherColor(int code, bool isDay) {
    final text = code.toString();
    if (text.contains('1000')) return isDay ? const Color(0xFFF59E0B) : const Color(0xFF818CF8);
    if (text.contains('1003') || text.contains('1006') || text.contains('1009')) return const Color(0xFF38BDF8);
    if (text.contains('1063') || text.contains('1180') || text.contains('1183') || text.contains('1189') || text.contains('1240')) {
      return const Color(0xFF0284C7);
    }
    if (text.contains('1087') || text.contains('1273')) return const Color(0xFF8B5CF6);
    return const Color(0xFF0EA5E9);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final weatherAsync = ref.watch(weatherProvider);

    return weatherAsync.when(
      data: (weather) {
        if (weather == null || weather.hourly.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: isDark ? 0.15 : 0.08),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.location_off_outlined,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Weather Unavailable',
                        style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Enable location permission to view live forecasts.',
                        style: AppTypography.bodySmall.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  onPressed: () => ref.invalidate(weatherProvider),
                  tooltip: 'Retry',
                ),
              ],
            ),
          );
        }

        final selectedIndex = _selectedHourIndex.clamp(0, weather.hourly.length - 1);
        final activeHour = weather.hourly[selectedIndex];
        final isNowSelected = selectedIndex == 0;
        final displayTemp = isNowSelected ? weather.currentTemp : activeHour.temperature;
        final displayCondition = isNowSelected ? weather.currentCondition : activeHour.conditionText;
        final weatherIcon = _getWeatherIcon(activeHour.weatherCode, activeHour.isDay);
        final weatherAccentColor = _getWeatherColor(activeHour.weatherCode, activeHour.isDay);

        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: weatherAccentColor.withValues(alpha: isDark ? 0.25 : 0.16),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.25)
                    : weatherAccentColor.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header: Location Pin + Refresh Action ──
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 15,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      weather.locationName,
                      style: AppTypography.labelMedium.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Refresh Action Button
                  GestureDetector(
                    onTap: () async {
                      if (_isRefreshing) return;
                      HapticFeedback.lightImpact();
                      setState(() => _isRefreshing = true);
                      ref.invalidate(weatherProvider);
                      await Future.delayed(const Duration(milliseconds: 800));
                      if (mounted) setState(() => _isRefreshing = false);
                    },
                    child: AnimatedRotation(
                      turns: _isRefreshing ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeInOut,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.refresh_rounded,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ── Temperature & Condition Row ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Current / Selected Temperature
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${displayTemp.round()}°C',
                        style: AppTypography.headingLarge.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                          fontSize: 32,
                          height: 1.0,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: weatherAccentColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              displayCondition,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: weatherAccentColor,
                              ),
                            ),
                          ),
                          if (!isNowSelected) ...[
                            const SizedBox(width: 6),
                            Text(
                              DateFormat('ha').format(activeHour.time).toLowerCase(),
                              style: AppTypography.bodySmall.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Weather Icon Badge
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: weatherAccentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: weatherAccentColor.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Icon(
                      weatherIcon,
                      size: 28,
                      color: weatherAccentColor,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ── High / Low Temp Indicator Strip ──
              Row(
                children: [
                  Icon(Icons.thermostat_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    'High: ${weather.maxTemp.round()}°  •  Low: ${weather.minTemp.round()}°',
                    style: AppTypography.bodySmall.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Tap hour for forecast',
                    style: AppTypography.labelSmall.copyWith(
                      color: theme.colorScheme.primary,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              Divider(
                height: 1,
                color: theme.colorScheme.outline.withValues(alpha: isDark ? 0.12 : 0.08),
              ),
              const SizedBox(height: 10),

              // ── Interactive Hourly Timeline Strip ──
              SizedBox(
                height: 84,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: weather.hourly.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    final item = weather.hourly[index];
                    final isSelected = index == _selectedHourIndex;
                    final isNow = index == 0;
                    final hourIcon = _getWeatherIcon(item.weatherCode, item.isDay);
                    final hourColor = _getWeatherColor(item.weatherCode, item.isDay);

                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedHourIndex = index);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 62,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? hourColor.withValues(alpha: isDark ? 0.25 : 0.12)
                              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? hourColor
                                : theme.colorScheme.outline.withValues(alpha: 0.1),
                            width: isSelected ? 1.5 : 1.0,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: hourColor.withValues(alpha: 0.15),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isNow ? 'Now' : DateFormat('ha').format(item.time).toLowerCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected || isNow ? FontWeight.bold : FontWeight.w500,
                                color: isSelected
                                    ? theme.colorScheme.onSurface
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Icon(
                              hourIcon,
                              size: 18,
                              color: isSelected ? hourColor : theme.colorScheme.onSurfaceVariant,
                            ),
                            Text(
                              '${item.temperature.round()}°',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? hourColor
                                    : theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
      loading: () => Container(
        height: 170,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: isDark ? 0.15 : 0.08),
          ),
        ),
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
        ),
      ),
      error: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(Icons.cloud_off_outlined, color: theme.colorScheme.error, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Could not load weather information',
                style: AppTypography.bodySmall.copyWith(color: theme.colorScheme.error),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 18),
              onPressed: () => ref.invalidate(weatherProvider),
            ),
          ],
        ),
      ),
    );
  }
}
