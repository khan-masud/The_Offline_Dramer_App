import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';

class StopwatchScreen extends StatefulWidget {
  const StopwatchScreen({super.key});

  @override
  State<StopwatchScreen> createState() => _StopwatchScreenState();
}

class _StopwatchScreenState extends State<StopwatchScreen> {
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  final List<Duration> _laps = [];
  Duration _displayed = Duration.zero;

  bool get _isRunning => _stopwatch.isRunning;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    _stopwatch.start();
    _timer = Timer.periodic(const Duration(milliseconds: 30), (_) {
      setState(() => _displayed = _stopwatch.elapsed);
    });
    setState(() {});
  }

  void _stop() {
    _stopwatch.stop();
    _timer?.cancel();
    setState(() => _displayed = _stopwatch.elapsed);
  }

  void _reset() {
    _stopwatch.reset();
    _timer?.cancel();
    setState(() {
      _displayed = Duration.zero;
      _laps.clear();
    });
  }

  void _lap() {
    setState(() => _laps.insert(0, _stopwatch.elapsed));
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final millis = (d.inMilliseconds.remainder(1000) ~/ 10).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      final hours = d.inHours.toString().padLeft(2, '0');
      return '$hours:$minutes:$seconds.$millis';
    }
    return '$minutes:$seconds.$millis';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stopwatch'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const Spacer(flex: 1),

          // Timer display
          Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  (_isRunning ? AppColors.success : AppColors.primary).withValues(alpha: 0.08),
                  (_isRunning ? AppColors.success : AppColors.primary).withValues(alpha: 0.02),
                ],
              ),
              border: Border.all(
                color: (_isRunning ? AppColors.success : AppColors.primary).withValues(alpha: 0.3),
                width: 3,
              ),
            ),
            child: Center(
              child: Text(
                _formatDuration(_displayed),
                style: AppTypography.displayLarge.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontSize: _displayed.inHours > 0 ? 32 : 38,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ).animate().fadeIn(duration: 400.ms),

          const SizedBox(height: 40),

          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Reset / Lap
              _ControlButton(
                icon: _isRunning ? Icons.flag_rounded : Icons.refresh_rounded,
                label: _isRunning ? 'Lap' : 'Reset',
                color: theme.colorScheme.onSurfaceVariant,
                bgColor: theme.colorScheme.surface,
                onTap: _isRunning
                    ? _lap
                    : (_displayed > Duration.zero ? _reset : null),
                enabled: _isRunning || _displayed > Duration.zero,
              ),
              const SizedBox(width: 24),
              // Start / Stop
              _ControlButton(
                icon: _isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                label: _isRunning ? 'Stop' : 'Start',
                color: Colors.white,
                bgColor: _isRunning ? AppColors.error : AppColors.success,
                onTap: _isRunning ? _stop : _start,
                large: true,
              ),
              const SizedBox(width: 24),
              // Lap (when running) or empty space
              _ControlButton(
                icon: Icons.flag_rounded,
                label: 'Lap',
                color: theme.colorScheme.onSurfaceVariant,
                bgColor: theme.colorScheme.surface,
                onTap: _isRunning ? _lap : null,
                enabled: _isRunning,
              ),
            ],
          ),

          const Spacer(flex: 1),

          // Laps list
          if (_laps.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text('Laps', style: AppTypography.headingSmall.copyWith(color: theme.colorScheme.onSurface)),
                  const Spacer(),
                  Text('${_laps.length} laps', style: AppTypography.labelMedium.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              flex: 2,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                physics: const BouncingScrollPhysics(),
                itemCount: _laps.length,
                itemBuilder: (context, i) {
                  final lapDuration = i == _laps.length - 1
                      ? _laps[i]
                      : _laps[i] - _laps[i + 1];

                  // Find best/worst
                  Duration? bestLap;
                  Duration? worstLap;
                  if (_laps.length > 2) {
                    final diffs = <Duration>[];
                    for (int j = 0; j < _laps.length; j++) {
                      diffs.add(j == _laps.length - 1 ? _laps[j] : _laps[j] - _laps[j + 1]);
                    }
                    diffs.sort();
                    bestLap = diffs.first;
                    worstLap = diffs.last;
                  }

                  final isBest = bestLap != null && lapDuration == bestLap;
                  final isWorst = worstLap != null && lapDuration == worstLap;

                  return AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (isBest ? AppColors.success : isWorst ? AppColors.error : AppColors.primary)
                                .withValues(alpha: 0.1),
                          ),
                          child: Center(
                            child: Text(
                              '${_laps.length - i}',
                              style: AppTypography.labelMedium.copyWith(
                                color: isBest ? AppColors.success : isWorst ? AppColors.error : AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _formatDuration(lapDuration),
                                style: AppTypography.labelLarge.copyWith(
                                  color: isBest ? AppColors.success : isWorst ? AppColors.error : theme.colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                'Total: ${_formatDuration(_laps[i])}',
                                style: AppTypography.labelSmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        if (isBest)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                            ),
                            child: Text('Best', style: AppTypography.labelSmall.copyWith(color: AppColors.success)),
                          ),
                        if (isWorst)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                            ),
                            child: Text('Worst', style: AppTypography.labelSmall.copyWith(color: AppColors.error)),
                          ),
                      ],
                    ),
                  ).animate().fadeIn(delay: (50 * i).ms, duration: 200.ms);
                },
              ),
            ),
          ] else
            const Spacer(flex: 2),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final VoidCallback? onTap;
  final bool large;
  final bool enabled;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    this.onTap,
    this.large = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = large ? 68.0 : 52.0;

    return Opacity(
      opacity: enabled ? 1.0 : 0.3,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: bgColor,
                border: large ? null : Border.all(color: theme.colorScheme.outline),
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
      ),
    );
  }
}
