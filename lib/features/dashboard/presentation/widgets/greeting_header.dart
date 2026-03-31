import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../providers/profile_provider.dart';
import '../../data/daily_info_provider.dart';

class GreetingHeader extends ConsumerWidget {
  const GreetingHeader({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    if (hour < 21) return 'Good Evening';
    return 'Good Night';
  }

  String _getEmoji() {
    final hour = DateTime.now().hour;
    if (hour < 12) return '🌅';
    if (hour < 17) return '🌤️';
    if (hour < 21) return '🌇';
    return '🌙';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final profile = ref.watch(userProfileProvider);
    final dailyInfoAsync = ref.watch(dailyInfoProvider);
    
    final displayName = profile.name.trim().isEmpty ? 'Dreamer' : profile.name.trim();
    final initials = displayName.isEmpty ? 'D' : displayName.substring(0, 1).toUpperCase();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            // Background Base Gradient
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF4F46E5), // Indigo
                      Color(0xFF7C3AED), // Deeper Indigo
                    ],
                  ),
                ),
              ),
            ),
            
            // Decorative Blobs for Glassmorphism pop
            Positioned(
              top: -40,
              right: -40,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF43F5E).withValues(alpha: 0.6), // Rose
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              left: -20,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.5), // Light Blue
                ),
              ),
            ),
            
            // Foreground Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_getGreeting()}, $displayName ${_getEmoji()}',
                              style: AppTypography.headingLarge.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 2))
                                ]
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('EEEE, MMMM d, yyyy').format(now),
                              style: AppTypography.bodyMedium.copyWith(
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(2),
                        child: ClipOval(
                          child: profile.photoUrl.isNotEmpty
                              ? Image.network(
                                  profile.photoUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _initialAvatar(initials),
                                )
                              : _initialAvatar(initials),
                        ),
                      ),
                    ],
                  ),
                  
                  // Daily Info Cards (Glassmorphic)
                  dailyInfoAsync.when(
                    data: (info) {
                      if (info == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildGlassCard(
                              icon: Icons.format_quote_rounded,
                              title: "Daily Motivation",
                              content: '"${info.quote}"',
                              footer: "- ${info.author}",
                            ),
                            const SizedBox(height: 16),
                            _buildGlassCard(
                              icon: Icons.history_edu_rounded,
                              title: "Historical Echoes",
                              content: info.historicalEvent,
                            ),
                          ],
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassCard({
    required IconData icon, 
    required String title, 
    required String content, 
    String? footer
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            boxShadow: [
               BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
               )
            ]
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                   Container(
                     padding: const EdgeInsets.all(6),
                     decoration: BoxDecoration(
                       color: Colors.white.withValues(alpha: 0.2),
                       shape: BoxShape.circle,
                     ),
                     child: Icon(icon, color: Colors.white, size: 16),
                   ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: AppTypography.labelMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                content,
                style: AppTypography.bodyMedium.copyWith(
                  color: Colors.white.withValues(alpha: 0.95),
                  height: 1.4,
                  fontStyle: footer != null ? FontStyle.italic : FontStyle.normal,
                ),
              ),
              if (footer != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    footer,
                    style: AppTypography.labelSmall.copyWith(color: Colors.white.withValues(alpha: 0.8), fontWeight: FontWeight.bold),
                  ),
                ),
              ]
            ],
          ),
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
          fontSize: 22,
          color: Colors.white,
        ),
      ),
    );
  }
}
