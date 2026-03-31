import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/weather_provider.dart';

class WeatherTimeline extends ConsumerWidget {
  const WeatherTimeline({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final weatherAsync = ref.watch(weatherProvider);

    return weatherAsync.when(
      data: (weather) {
        if (weather == null || weather.hourly.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.location_disabled_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                    size: 24,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Weather unavailable.\nPlease enable device location.',
                    textAlign: TextAlign.center,
                    style: AppTypography.labelMedium.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    weather.locationName,
                    style: AppTypography.labelMedium.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.sm),
            Container(
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppDimensions.md),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${weather.currentTemp.round()}°C',
                              style: AppTypography.headingLarge.copyWith(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                                height: 1.1,
                              ),
                            ),
                            Text(
                              weather.currentCondition,
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              weather.hourly[0].icon,
                              style: const TextStyle(fontSize: 40),
                            ),
                            Text(
                              'H: ${weather.maxTemp.round()}°  L: ${weather.minTemp.round()}°',
                              style: AppTypography.labelSmall.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: weather.hourly.length,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.sm,
                      ),
                      itemBuilder: (context, index) {
                        final item = weather.hourly[index];
                        final isNow = index == 0;

                        return Container(
                          width: 65,
                          margin: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 4,
                          ),
                          decoration:
                              isNow
                                  ? BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  )
                                  : null,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                isNow
                                    ? 'Now'
                                    : DateFormat(
                                      'ha',
                                    ).format(item.time).toLowerCase(),
                                style: AppTypography.labelSmall.copyWith(
                                  color:
                                      isNow
                                          ? AppColors.primary
                                          : theme.colorScheme.onSurfaceVariant,
                                  fontWeight:
                                      isNow
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                item.icon,
                                style: const TextStyle(fontSize: 22),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${item.temperature.round()}°',
                                style: AppTypography.labelMedium.copyWith(
                                  color:
                                      isNow
                                          ? AppColors.primary
                                          : theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
      loading:
          () => Container(
            height: 160,
            margin: const EdgeInsets.only(top: AppDimensions.sm),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: const Center(child: CircularProgressIndicator()),
          ),
      error:
          (_, __) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: theme.colorScheme.error,
                    size: 24,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Failed to load weather data',
                    textAlign: TextAlign.center,
                    style: AppTypography.labelMedium.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}
