import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/auth_provider.dart';

class PinSetupScreen extends ConsumerStatefulWidget {
  final VoidCallback? onComplete;
  const PinSetupScreen({super.key, this.onComplete});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  bool _isError = false;
  String _errorText = '';

  void _onNumberTap(int number) {
    HapticFeedback.lightImpact();
    if (_isConfirming) {
      if (_confirmPin.length >= 4) return;
      setState(() {
        _confirmPin += number.toString();
        _isError = false;
      });
      if (_confirmPin.length == 4) _confirmSetup();
    } else {
      if (_pin.length >= 4) return;
      setState(() {
        _pin += number.toString();
        _isError = false;
      });
      if (_pin.length == 4) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) setState(() => _isConfirming = true);
        });
      }
    }
  }

  void _onDelete() {
    HapticFeedback.lightImpact();
    setState(() {
      _isError = false;
      if (_isConfirming) {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        }
      } else {
        if (_pin.isNotEmpty) {
          _pin = _pin.substring(0, _pin.length - 1);
        }
      }
    });
  }

  Future<void> _confirmSetup() async {
    if (_pin == _confirmPin) {
      await ref.read(authProvider.notifier).setPin(_pin);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PIN set successfully!', style: GoogleFonts.inter()),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        widget.onComplete?.call();
        Navigator.of(context).pop();
      }
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _isError = true;
        _errorText = 'PINs do not match. Try again.';
        _pin = '';
        _confirmPin = '';
        _isConfirming = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPin = _isConfirming ? _confirmPin : _pin;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : theme.colorScheme.onSurface),
                ),
              ),
              const Spacer(flex: 2),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF6366F1)]),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: isDark ? 0.35 : 0.25),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  _isConfirming ? Icons.verified_user_outlined : Icons.lock_outline_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ).animate().fadeIn(),
              const SizedBox(height: 24),
              Text(
                _isConfirming ? 'Confirm Your PIN' : 'Create a PIN',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : theme.colorScheme.onSurface,
                ),
              ).animate().fadeIn(delay: 100.ms),
              const SizedBox(height: 8),
              Text(
                _isError
                    ? _errorText
                    : (_isConfirming ? 'Re-enter your 4-digit PIN' : 'Set a 4-digit PIN to protect your data'),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _isError
                      ? AppColors.error
                      : (isDark ? Colors.white.withValues(alpha: 0.6) : theme.colorScheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 36),
              // PIN dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final isActive = i < currentPin.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: isActive ? 16 : 14,
                    height: isActive ? 16 : 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isError
                          ? AppColors.error
                          : (isActive
                              ? AppColors.primary
                              : (isDark ? Colors.white.withValues(alpha: 0.12) : theme.colorScheme.surfaceContainerHighest)),
                      border: !isActive
                          ? Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.25)
                                  : theme.colorScheme.outline.withValues(alpha: 0.4),
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
              const Spacer(),
              // Number Pad
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Column(
                  children: [
                    for (var row in [[1, 2, 3], [4, 5, 6], [7, 8, 9]]) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: row.map((n) => _buildKey(n, isDark, theme)).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        const SizedBox(width: 72, height: 72),
                        _buildKey(0, isDark, theme),
                        SizedBox(
                          width: 72,
                          height: 72,
                          child: GestureDetector(
                            onTap: _onDelete,
                            child: Center(
                              child: Icon(
                                Icons.backspace_outlined,
                                color: isDark ? Colors.white.withValues(alpha: 0.75) : theme.colorScheme.onSurfaceVariant,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKey(int number, bool isDark, ThemeData theme) {
    return GestureDetector(
      onTap: () => _onNumberTap(number),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? Colors.white.withValues(alpha: 0.07) : theme.colorScheme.surface,
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.12) : theme.colorScheme.outline.withValues(alpha: 0.25),
            width: 1,
          ),
          boxShadow: !isDark
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
              color: isDark ? Colors.white : theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
