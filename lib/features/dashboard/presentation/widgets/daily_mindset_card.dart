import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../providers/dashboard_preferences_provider.dart';
import '../../data/daily_info_provider.dart';

enum MindsetTab { motivation, echoes }

class DailyMindsetCard extends ConsumerStatefulWidget {
  const DailyMindsetCard({super.key});

  @override
  ConsumerState<DailyMindsetCard> createState() => _DailyMindsetCardState();
}

class _DailyMindsetCardState extends ConsumerState<DailyMindsetCard> {
  MindsetTab _activeTab = MindsetTab.motivation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dashboardPrefs = ref.watch(dashboardPreferencesProvider);
    final dailyInfoAsync = ref.watch(dailyInfoProvider);

    final showMotivation = dashboardPrefs.showDailyMotivation;
    final showEvents = dashboardPrefs.showDailyEvents;

    // If both disabled in settings, hide widget
    if (!showMotivation && !showEvents) {
      return const SizedBox.shrink();
    }

    // Default to available tab if one is turned off
    final effectiveTab = (!showMotivation && showEvents)
        ? MindsetTab.echoes
        : ((showMotivation && !showEvents) ? MindsetTab.motivation : _activeTab);

    return dailyInfoAsync.when(
      data: (info) {
        if (info == null) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: isDark ? 0.15 : 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Bar: Tab Switcher + Action ──
              Row(
                children: [
                  // Tab Pills
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (showMotivation)
                          _TabPill(
                            label: 'Daily Motivation',
                            icon: Icons.format_quote_rounded,
                            isSelected: effectiveTab == MindsetTab.motivation,
                            onTap: () {
                              if (_activeTab != MindsetTab.motivation) {
                                HapticFeedback.selectionClick();
                                setState(() => _activeTab = MindsetTab.motivation);
                              }
                            },
                          ),
                        if (showMotivation && showEvents) const SizedBox(width: 4),
                        if (showEvents)
                          _TabPill(
                            label: 'Historical Echoes',
                            icon: Icons.history_edu_rounded,
                            isSelected: effectiveTab == MindsetTab.echoes,
                            onTap: () {
                              if (_activeTab != MindsetTab.echoes) {
                                HapticFeedback.selectionClick();
                                setState(() => _activeTab = MindsetTab.echoes);
                              }
                            },
                          ),
                      ],
                    ),
                  ),
                  const Spacer(),

                  // Copy Action (for Motivation Quote)
                  AnimatedOpacity(
                    opacity: effectiveTab == MindsetTab.motivation ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 250),
                    child: effectiveTab == MindsetTab.motivation
                        ? IconButton(
                            icon: Icon(
                              Icons.copy_rounded,
                              size: 16,
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                            ),
                            tooltip: 'Copy Quote',
                            visualDensity: VisualDensity.compact,
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              Clipboard.setData(ClipboardData(text: '"${info.quote}" - ${info.author}'));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Quote copied to clipboard!')),
                              );
                            },
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Smooth Animated Tab Transition ──
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOutCubic,
                alignment: Alignment.topCenter,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  reverseDuration: const Duration(milliseconds: 200),
                  switchInCurve: Curves.easeInOutCubic,
                  switchOutCurve: Curves.easeInOutCubic,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.0, 0.06),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: effectiveTab == MindsetTab.motivation
                      ? _buildMotivationView(info, theme)
                      : _buildEchoesView(info, theme),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildMotivationView(DailyInfo info, ThemeData theme) {
    return Column(
      key: const ValueKey('motivation_content'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '"${info.quote}"',
          style: AppTypography.bodyMedium.copyWith(
            color: theme.colorScheme.onSurface,
            fontStyle: FontStyle.italic,
            height: 1.45,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '— ${info.author}',
            style: AppTypography.labelSmall.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEchoesView(DailyInfo info, ThemeData theme) {
    return Column(
      key: const ValueKey('echoes_content'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          info.historicalEvent,
          style: AppTypography.bodyMedium.copyWith(
            color: theme.colorScheme.onSurface,
            height: 1.45,
            fontSize: 13.5,
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.public_rounded, size: 12, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                'On this day in history',
                style: AppTypography.labelSmall.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TabPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabPill({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? AppColors.primary : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
