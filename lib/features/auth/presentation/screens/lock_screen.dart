import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/auth_provider.dart';

class LockScreen extends ConsumerStatefulWidget {
  final VoidCallback onUnlocked;
  const LockScreen({super.key, required this.onUnlocked});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> with SingleTickerProviderStateMixin {
  String _pin = '';
  bool _isError = false;
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onNumberTap(int number) {
    final authState = ref.read(authProvider);
    if (authState.isLocked) return;
    if (_pin.length >= 4) return;
    HapticFeedback.lightImpact();
    setState(() {
      _pin += number.toString();
      _isError = false;
    });
    if (_pin.length == 4) _verifyPin();
  }

  void _onDelete() {
    if (_pin.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _isError = false;
    });
  }

  Future<void> _verifyPin() async {
    final notifier = ref.read(authProvider.notifier);
    final success = await notifier.verifyPin(_pin);
    if (success) {
      widget.onUnlocked();
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _isError = true;
        _pin = '';
      });
      _shakeController.forward(from: 0);
    }
  }

  String _formatLockDuration(Duration d) {
    if (d.inMinutes >= 1) {
      final m = d.inMinutes;
      final s = d.inSeconds % 60;
      return s > 0 ? '${m}m ${s}s' : '${m}m';
    }
    return '${d.inSeconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final authState = ref.watch(authProvider);
    final isLocked = authState.isLocked;
    final remainingAttempts = authState.remainingAttempts;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [Color(0xFF090D16), Color(0xFF111827), Color(0xFF090D16)]
                : const [Color(0xFFF8FAFC), Color(0xFFEEF2F7), Color(0xFFF1F5F9)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
              // App Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF6366F1)]),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: isDark ? 0.35 : 0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 36),
              ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.8, 0.8)),
              const SizedBox(height: 20),
              Text(
                'ME++',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : theme.colorScheme.onSurface,
                  letterSpacing: 3,
                ),
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 8),
              // Status message
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildStatusMessage(isLocked, authState, remainingAttempts, isDark, theme),
              ),
              const SizedBox(height: 36),
              // PIN dots
              AnimatedBuilder(
                animation: _shakeController,
                builder: (context, child) {
                  final dx = _shakeController.isAnimating
                      ? sin(_shakeController.value * 3 * pi) * 12
                      : 0.0;
                  return Transform.translate(offset: Offset(dx, 0), child: child);
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (i) {
                    final isActive = i < _pin.length;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: isActive ? 16 : 14,
                      height: isActive ? 16 : 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isError
                            ? AppColors.error
                            : isLocked
                                ? (isDark ? Colors.white.withValues(alpha: 0.08) : theme.colorScheme.outline.withValues(alpha: 0.15))
                                : isActive
                                    ? AppColors.primary
                                    : (isDark ? Colors.white.withValues(alpha: 0.12) : theme.colorScheme.surfaceContainerHighest),
                        border: !isActive && !_isError
                            ? Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: isLocked ? 0.06 : 0.25)
                                    : theme.colorScheme.outline.withValues(alpha: isLocked ? 0.2 : 0.4),
                                width: 1.5,
                              )
                            : null,
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: (_isError ? AppColors.error : AppColors.primary).withValues(alpha: 0.4),
                                  blurRadius: 8,
                                )
                              ]
                            : null,
                      ),
                    );
                  }),
                ),
              ).animate().fadeIn(delay: 400.ms),
              const SizedBox(height: 16),
              // Remaining attempts indicator
              if (!isLocked && authState.attemptCount > 0)
                Text(
                  '$remainingAttempts attempt${remainingAttempts == 1 ? '' : 's'} remaining',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: remainingAttempts <= 2
                        ? AppColors.error
                        : (isDark ? Colors.white.withValues(alpha: 0.5) : theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              const Spacer(),
              // Number Pad
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Column(
                  children: [
                    for (var row in [[1, 2, 3], [4, 5, 6], [7, 8, 9]]) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: row.map((n) => _buildKey(n, isLocked, isDark, theme)).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        const SizedBox(width: 72, height: 72),
                        _buildKey(0, isLocked, isDark, theme),
                        SizedBox(
                          width: 72,
                          height: 72,
                          child: GestureDetector(
                            onTap: isLocked ? null : _onDelete,
                            child: Center(
                              child: Icon(
                                Icons.backspace_outlined,
                                color: isLocked
                                    ? (isDark ? Colors.white.withValues(alpha: 0.15) : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.25))
                                    : (isDark ? Colors.white.withValues(alpha: 0.75) : theme.colorScheme.onSurfaceVariant),
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1),
              const SizedBox(height: 20),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusMessage(bool isLocked, AuthState authState, int remainingAttempts, bool isDark, ThemeData theme) {
    if (isLocked) {
      final lockedUntil = authState.lockUntil!;
      final remaining = lockedUntil.difference(DateTime.now());
      final formatted = _formatLockDuration(remaining);
      return TweenAnimationBuilder<double>(
        key: const ValueKey('locked'),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(seconds: 1),
        builder: (context, value, _) {
          return Opacity(
            opacity: value,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_clock, color: AppColors.error, size: 20),
                const SizedBox(height: 6),
                Text(
                  'Too many attempts',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Try again in $formatted',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.error.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }
    return Text(
      _isError ? 'Incorrect PIN. Try again.' : 'Enter your PIN to continue',
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: _isError
            ? AppColors.error
            : (isDark ? Colors.white.withValues(alpha: 0.6) : theme.colorScheme.onSurfaceVariant),
      ),
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _buildKey(int number, bool isLocked, bool isDark, ThemeData theme) {
    return GestureDetector(
      onTap: isLocked ? null : () => _onNumberTap(number),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark
              ? (isLocked ? Colors.white.withValues(alpha: 0.02) : Colors.white.withValues(alpha: 0.07))
              : (isLocked ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35) : theme.colorScheme.surface),
          border: Border.all(
            color: isDark
                ? (isLocked ? Colors.white.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.12))
                : (isLocked ? theme.colorScheme.outline.withValues(alpha: 0.15) : theme.colorScheme.outline.withValues(alpha: 0.25)),
            width: 1,
          ),
          boxShadow: !isDark && !isLocked
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            number.toString(),
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? (isLocked ? Colors.white.withValues(alpha: 0.15) : Colors.white)
                  : (isLocked ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3) : theme.colorScheme.onSurface),
            ),
          ),
        ),
      ),
    );
  }
}
