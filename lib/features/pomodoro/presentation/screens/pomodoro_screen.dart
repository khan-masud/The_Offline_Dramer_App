import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:math' as math;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';

enum PomodoroPhase { focus, shortBreak, longBreak }

class PomodoroScreen extends StatefulWidget {
  const PomodoroScreen({super.key});

  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen> with TickerProviderStateMixin {
  // Durations (in minutes)
  int _focusDuration = 25;
  int _shortBreakDuration = 5;
  int _longBreakDuration = 15;
  final int _sessionsBeforeLongBreak = 4;

  PomodoroPhase _phase = PomodoroPhase.focus;
  int _completedSessions = 0;
  int _remainingSeconds = 25 * 60;
  bool _isRunning = false;
  Timer? _timer;

  late AnimationController _ringController;

  int get _totalSeconds {
    switch (_phase) {
      case PomodoroPhase.focus:
        return _focusDuration * 60;
      case PomodoroPhase.shortBreak:
        return _shortBreakDuration * 60;
      case PomodoroPhase.longBreak:
        return _longBreakDuration * 60;
    }
  }

  double get _progress => 1.0 - (_remainingSeconds / _totalSeconds);

  Color get _phaseColor {
    switch (_phase) {
      case PomodoroPhase.focus:
        return AppColors.error;
      case PomodoroPhase.shortBreak:
        return AppColors.success;
      case PomodoroPhase.longBreak:
        return AppColors.info;
    }
  }

  String get _phaseLabel {
    switch (_phase) {
      case PomodoroPhase.focus:
        return 'Focus Time';
      case PomodoroPhase.shortBreak:
        return 'Short Break';
      case PomodoroPhase.longBreak:
        return 'Long Break';
    }
  }

  IconData get _phaseIcon {
    switch (_phase) {
      case PomodoroPhase.focus:
        return Icons.local_fire_department_rounded;
      case PomodoroPhase.shortBreak:
        return Icons.coffee_rounded;
      case PomodoroPhase.longBreak:
        return Icons.self_improvement_rounded;
    }
  }

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _remainingSeconds = _focusDuration * 60;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ringController.dispose();
    super.dispose();
  }

  void _start() {
    setState(() => _isRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remainingSeconds <= 0) {
        _onPhaseComplete();
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  void _pause() {
    _timer?.cancel();
    setState(() => _isRunning = false);
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _remainingSeconds = _totalSeconds;
    });
  }

  void _skip() {
    _timer?.cancel();
    _onPhaseComplete();
  }

  void _onPhaseComplete() {
    _timer?.cancel();
    HapticFeedback.heavyImpact();

    setState(() {
      _isRunning = false;
      if (_phase == PomodoroPhase.focus) {
        _completedSessions++;
        if (_completedSessions % _sessionsBeforeLongBreak == 0) {
          _phase = PomodoroPhase.longBreak;
          _remainingSeconds = _longBreakDuration * 60;
        } else {
          _phase = PomodoroPhase.shortBreak;
          _remainingSeconds = _shortBreakDuration * 60;
        }
      } else {
        _phase = PomodoroPhase.focus;
        _remainingSeconds = _focusDuration * 60;
      }
    });

    // Show completion dialog
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(_phaseIcon, color: _phaseColor),
            const SizedBox(width: 8),
            Text(_phaseLabel),
          ],
        ),
        content: Text(
          _phase == PomodoroPhase.focus
              ? 'Break is over! Ready to focus? 💪'
              : _phase == PomodoroPhase.longBreak
                  ? 'Great work! Take a long break 🎉'
                  : 'Session complete! Take a short break ☕',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _start();
            },
            child: const Text('Start Now'),
          ),
        ],
      ),
    );
  }

  String _formatTime(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pomodoro'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            onPressed: _showSettings,
          ),
        ],
      ),
      body: Column(
        children: [
          const Spacer(),

          // Phase indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: _phaseColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_phaseIcon, size: 18, color: _phaseColor),
                const SizedBox(width: 8),
                Text(_phaseLabel, style: AppTypography.labelLarge.copyWith(color: _phaseColor)),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms),
          const SizedBox(height: 32),

          // Circular timer
          SizedBox(
            width: 260,
            height: 260,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background ring
                CustomPaint(
                  size: const Size(260, 260),
                  painter: _RingPainter(
                    progress: _progress,
                    color: _phaseColor,
                    bgColor: theme.colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
                // Timer text
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(_remainingSeconds),
                      style: AppTypography.displayLarge.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontSize: 52,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Session ${_completedSessions + 1}',
                      style: AppTypography.labelMedium.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Reset
              _PomodoroButton(
                icon: Icons.refresh_rounded,
                label: 'Reset',
                color: theme.colorScheme.onSurfaceVariant,
                bgColor: theme.colorScheme.surface,
                borderColor: theme.colorScheme.outline,
                onTap: _reset,
              ),
              const SizedBox(width: 20),
              // Play/Pause
              _PomodoroButton(
                icon: _isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                label: _isRunning ? 'Pause' : 'Start',
                color: Colors.white,
                bgColor: _phaseColor,
                onTap: _isRunning ? _pause : _start,
                large: true,
              ),
              const SizedBox(width: 20),
              // Skip
              _PomodoroButton(
                icon: Icons.skip_next_rounded,
                label: 'Skip',
                color: theme.colorScheme.onSurfaceVariant,
                bgColor: theme.colorScheme.surface,
                borderColor: theme.colorScheme.outline,
                onTap: _skip,
              ),
            ],
          ),

          const Spacer(),

          // Session indicators
          Padding(
            padding: const EdgeInsets.only(bottom: 32),
            child: Column(
              children: [
                Text(
                  '$_completedSessions sessions completed',
                  style: AppTypography.labelMedium.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_sessionsBeforeLongBreak, (i) {
                    final isCompleted = i < (_completedSessions % _sessionsBeforeLongBreak);
                    final isCurrent = i == (_completedSessions % _sessionsBeforeLongBreak) && _phase == PomodoroPhase.focus;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: AnimatedContainer(
                        duration: 300.ms,
                        width: isCurrent ? 28 : 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: isCompleted ? _phaseColor : isCurrent ? _phaseColor.withValues(alpha: 0.5) : theme.colorScheme.outline,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSettings() {
    int tempFocus = _focusDuration;
    int tempShort = _shortBreakDuration;
    int tempLong = _longBreakDuration;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final theme = Theme.of(ctx);
          return Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.colorScheme.outline, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                Text('Timer Settings', style: AppTypography.headingMedium.copyWith(color: theme.colorScheme.onSurface)),
                const SizedBox(height: 20),
                _DurationSlider(
                  label: 'Focus Duration',
                  value: tempFocus,
                  min: 5,
                  max: 60,
                  color: AppColors.error,
                  onChanged: (v) => setSheetState(() => tempFocus = v),
                ),
                _DurationSlider(
                  label: 'Short Break',
                  value: tempShort,
                  min: 1,
                  max: 15,
                  color: AppColors.success,
                  onChanged: (v) => setSheetState(() => tempShort = v),
                ),
                _DurationSlider(
                  label: 'Long Break',
                  value: tempLong,
                  min: 5,
                  max: 30,
                  color: AppColors.info,
                  onChanged: (v) => setSheetState(() => tempLong = v),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _focusDuration = tempFocus;
                        _shortBreakDuration = tempShort;
                        _longBreakDuration = tempLong;
                        if (!_isRunning) {
                          _remainingSeconds = _totalSeconds;
                        }
                      });
                      Navigator.pop(ctx);
                    },
                    child: Text('Save', style: AppTypography.labelLarge.copyWith(color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PomodoroButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final Color? borderColor;
  final VoidCallback onTap;
  final bool large;

  const _PomodoroButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    this.borderColor,
    required this.onTap,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = large ? 68.0 : 52.0;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bgColor,
              border: borderColor != null ? Border.all(color: borderColor!) : null,
              boxShadow: large ? [
                BoxShadow(color: bgColor.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
              ] : null,
            ),
            child: Icon(icon, size: large ? 32 : 24, color: color),
          ),
          const SizedBox(height: 6),
          Text(label, style: AppTypography.labelSmall.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _DurationSlider extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final Color color;
  final ValueChanged<int> onChanged;

  const _DurationSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: AppTypography.labelLarge.copyWith(color: theme.colorScheme.onSurface)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                ),
                child: Text('${value}m', style: AppTypography.labelMedium.copyWith(color: color)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: color,
              inactiveTrackColor: color.withValues(alpha: 0.15),
              thumbColor: color,
              overlayColor: color.withValues(alpha: 0.1),
            ),
            child: Slider(
              value: value.toDouble(),
              min: min.toDouble(),
              max: max.toDouble(),
              divisions: max - min,
              onChanged: (v) => onChanged(v.round()),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color bgColor;

  _RingPainter({required this.progress, required this.color, required this.bgColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const strokeWidth = 8.0;

    // Background ring
    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      progress != oldDelegate.progress || color != oldDelegate.color;
}
