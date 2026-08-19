import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../providers/profile_provider.dart';
import '../../../todo/data/todo_provider.dart';
import '../../../routine/data/routine_provider.dart';

class GreetingHeader extends ConsumerWidget {
  const GreetingHeader({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    if (hour < 21) return 'Good Evening';
    return 'Good Night';
  }

  IconData _getGreetingIcon() {
    final hour = DateTime.now().hour;
    if (hour < 12) return Icons.wb_sunny_outlined;
    if (hour < 17) return Icons.light_mode_outlined;
    if (hour < 21) return Icons.wb_twilight_rounded;
    return Icons.nights_stay_outlined;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final now = DateTime.now();
    final profile = ref.watch(userProfileProvider);
    final profileImage = profile.imageProvider;

    final displayName = profile.name.trim().isEmpty ? 'User' : profile.name.trim();
    final initials = displayName.isEmpty ? 'U' : displayName.substring(0, 1).toUpperCase();

    // Productivity metrics calculation
    final todoStatsAsync = ref.watch(todoStatsProvider);
    final routinesAsync = ref.watch(todayRoutinesProvider);
    final completionsAsync = ref.watch(todayCompletionsProvider);

    int totalTasks = 0;
    int completedTasks = 0;
    todoStatsAsync.whenData((stats) {
      totalTasks = stats.total;
      completedTasks = stats.completed;
    });

    int totalRoutines = 0;
    int completedRoutines = 0;
    routinesAsync.whenData((routines) {
      totalRoutines = routines.length;
    });
    completionsAsync.whenData((completions) {
      completedRoutines = completions.length;
    });

    final totalItems = totalTasks + totalRoutines;
    final completedItems = completedTasks + completedRoutines;
    final progressFraction = totalItems > 0 ? (completedItems / totalItems).clamp(0.0, 1.0) : 0.0;
    final progressPercent = (progressFraction * 100).toInt();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [
                  Color(0xFF1E1B4B), // Deep Slate Indigo
                  Color(0xFF311042), // Deep Violet
                ]
              : const [
                  Color(0xFF4338CA), // Royal Indigo
                  Color(0xFF6D28D9), // Vibrant Purple
                ],
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : const Color(0xFF4338CA)).withValues(alpha: isDark ? 0.35 : 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Row: Time Greeting + Avatar ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Greeting Pill with Outline Icon
                      Row(
                        children: [
                          Icon(_getGreetingIcon(), color: Colors.white70, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            _getGreeting(),
                            style: AppTypography.labelMedium.copyWith(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // User Name
                      Text(
                        displayName,
                        style: AppTypography.headingLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),

                      // Formatted Date
                      Text(
                        DateFormat('EEEE, MMMM d, yyyy').format(now),
                        style: AppTypography.bodySmall.copyWith(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                // User Avatar
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(2),
                  child: ClipOval(
                    child: profileImage != null
                        ? Image(
                            image: profileImage,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _initialAvatar(initials),
                          )
                        : _initialAvatar(initials),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Live Productivity Completion Progress Bar ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bolt_rounded, size: 16, color: Color(0xFFFBBF24)), // Amber bolt
                      const SizedBox(width: 6),
                      Text(
                        "Today's Progress",
                        style: AppTypography.labelMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        totalItems > 0 ? '$completedItems of $totalItems completed' : 'No tasks scheduled',
                        style: AppTypography.labelSmall.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$progressPercent%',
                        style: AppTypography.labelMedium.copyWith(
                          color: const Color(0xFF34D399), // Emerald
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Progress Bar Track
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: totalItems > 0 ? progressFraction : 0.0,
                      minHeight: 6,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF34D399)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _initialAvatar(String initials) {
    return Container(
      color: Colors.white.withValues(alpha: 0.2),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 20,
          color: Colors.white,
        ),
      ),
    );
  }
}
