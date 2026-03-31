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
    final success = await ref.read(authProvider.notifier).verifyPin(_pin);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0F172A)],
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
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8)),
                  ],
                ),
                child: const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 36),
              ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.8, 0.8)),
              const SizedBox(height: 24),
              Text(
                'THE OFFLINE DREAMER',
                style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 2),
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 8),
              Text(
                _isError ? 'Incorrect PIN. Try again.' : 'Enter your PIN to continue',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: _isError ? AppColors.error : Colors.white.withValues(alpha: 0.5),
                ),
              ).animate().fadeIn(delay: 300.ms),
              const SizedBox(height: 40),
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
                            : isActive
                                ? AppColors.primary
                                : Colors.white.withValues(alpha: 0.15),
                        border: !isActive && !_isError
                            ? Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5)
                            : null,
                        boxShadow: isActive
                            ? [BoxShadow(color: (_isError ? AppColors.error : AppColors.primary).withValues(alpha: 0.4), blurRadius: 8)]
                            : null,
                      ),
                    );
                  }),
                ),
              ).animate().fadeIn(delay: 400.ms),
              const Spacer(),
              // Number Pad
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Column(
                  children: [
                    for (var row in [[1, 2, 3], [4, 5, 6], [7, 8, 9]]) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: row.map((n) => _buildKey(n)).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        const SizedBox(width: 72, height: 72),
                        _buildKey(0),
                        SizedBox(
                          width: 72,
                          height: 72,
                          child: GestureDetector(
                            onTap: _onDelete,
                            child: Center(
                              child: Icon(Icons.backspace_outlined, color: Colors.white.withValues(alpha: 0.7), size: 24),
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

  Widget _buildKey(int number) {
    return GestureDetector(
      onTap: () => _onNumberTap(number),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.08),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1),
        ),
        child: Center(
          child: Text(
            number.toString(),
            style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w500, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
