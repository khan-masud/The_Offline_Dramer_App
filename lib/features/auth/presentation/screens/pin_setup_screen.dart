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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF0F172A), const Color(0xFF1E293B), const Color(0xFF0F172A)]
                : [const Color(0xFF1E3A5F), const Color(0xFF2563EB), const Color(0xFF1E3A5F)],
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
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                ),
              ),
              const Spacer(flex: 2),
              Icon(
                _isConfirming ? Icons.verified_user_outlined : Icons.lock_outline_rounded,
                color: Colors.white, size: 48,
              ).animate().fadeIn(),
              const SizedBox(height: 24),
              Text(
                _isConfirming ? 'Confirm Your PIN' : 'Create a PIN',
                style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
              ).animate().fadeIn(delay: 100.ms),
              const SizedBox(height: 8),
              Text(
                _isError ? _errorText : (_isConfirming ? 'Re-enter your 4-digit PIN' : 'Set a 4-digit PIN to protect your data'),
                style: GoogleFonts.inter(fontSize: 14, color: _isError ? AppColors.error : Colors.white.withValues(alpha: 0.6)),
              ),
              const SizedBox(height: 40),
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
                      color: _isError ? AppColors.error : (isActive ? Colors.white : Colors.white.withValues(alpha: 0.15)),
                      border: !isActive ? Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5) : null,
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
                            child: Center(child: Icon(Icons.backspace_outlined, color: Colors.white.withValues(alpha: 0.7), size: 24)),
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
          child: Text(number.toString(), style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w500, color: Colors.white)),
        ),
      ),
    );
  }
}
