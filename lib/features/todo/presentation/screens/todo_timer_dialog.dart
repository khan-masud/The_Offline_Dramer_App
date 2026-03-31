import 'dart:async';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';

class TodoTimerDialog extends ConsumerStatefulWidget {
  final Todo todo;
  const TodoTimerDialog({super.key, required this.todo});

  @override
  ConsumerState<TodoTimerDialog> createState() => _TodoTimerDialogState();
}

class _TodoTimerDialogState extends ConsumerState<TodoTimerDialog> {
  // Setup phase
  int _focusMinutes = 25;
  int _shortBreakMinutes = 5;
  int _longBreakMinutes = 15;
  bool _setupComplete = false;

  // Timer phase
  bool _isWorkSession = true;
  int _remainingSeconds = 0;
  int _totalSessionSeconds = 0;
  bool _isRunning = false;
  Timer? _timer;
  DateTime? _startTime;
  int _sessionsCompleted = 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startSetup() {
    setState(() {
      _setupComplete = true;
      _isWorkSession = true;
      _totalSessionSeconds = _focusMinutes * 60;
      _remainingSeconds = _totalSessionSeconds;
    });
  }

  void _toggleTimer() {
    if (_isRunning) {
      _timer?.cancel();
      setState(() => _isRunning = false);
    } else {
      _startTime ??= DateTime.now();
      _isRunning = true;
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
          } else {
            _timer?.cancel();
            _isRunning = false;
            _saveSession();
            _switchMode();
          }
        });
      });
      setState(() {});
    }
  }

  void _saveSession() {
    int elapsed = _totalSessionSeconds - _remainingSeconds;
    if (elapsed > 0 && _startTime != null) {
      String sessionType = _isWorkSession ? 'work' : 
                          (_sessionsCompleted % 4 == 0 ? 'long_break' : 'short_break');
      
      ref.read(databaseProvider).addFocusSession(
            FocusSessionsCompanion(
              todoId: Value(widget.todo.id),
              sessionType: Value(sessionType),
              durationSeconds: Value(elapsed),
              startTime: Value(_startTime!),
              endTime: Value(DateTime.now()),
            ),
          );
    }
  }

  void _switchMode() {
    if (_isWorkSession) {
      _sessionsCompleted++;
      _isWorkSession = false;
      
      // Use long break after every 4 sessions
      if (_sessionsCompleted % 4 == 0) {
        _totalSessionSeconds = _longBreakMinutes * 60;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Excellent! You\'ve earned a ${_longBreakMinutes}min long break'),
              duration: const Duration(seconds: 2),
              backgroundColor: AppColors.info,
            ),
          );
        }
      } else {
        _totalSessionSeconds = _shortBreakMinutes * 60;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Great! Time for a ${_shortBreakMinutes}min break'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
      
      _remainingSeconds = _totalSessionSeconds;
      _startTime = null;
    } else {
      _isWorkSession = true;
      _totalSessionSeconds = _focusMinutes * 60;
      _remainingSeconds = _totalSessionSeconds;
      _startTime = null;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Break over! Ready for session ${_sessionsCompleted + 1}?'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
    setState(() {});
  }

  void _stopAndSave() {
    _timer?.cancel();
    _saveSession();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _setupComplete = false;
      _focusMinutes = 25;
      _shortBreakMinutes = 5;
      _longBreakMinutes = 15;
      _isWorkSession = true;
      _remainingSeconds = 0;
      _isRunning = false;
      _startTime = null;
      _sessionsCompleted = 0;
    });
  }

  String get _timeString {
    int minutes = _remainingSeconds ~/ 60;
    int seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!_setupComplete) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        ),
        backgroundColor: theme.colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Timer Settings',
                  style: AppTypography.headingMedium,
                ),
                const SizedBox(height: 32),
                
                // Focus Duration
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Focus Duration',
                          style: AppTypography.bodyLarge,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                          ),
                          child: Text(
                            '${_focusMinutes}m',
                            style: AppTypography.labelLarge.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Slider(
                      value: _focusMinutes.toDouble(),
                      min: 1,
                      max: 60,
                      divisions: 59,
                      onChanged: (value) {
                        setState(() => _focusMinutes = value.toInt());
                      },
                      activeColor: AppColors.primary,
                      inactiveColor: AppColors.primary.withValues(alpha: 0.2),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Short Break
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Short Break',
                          style: AppTypography.bodyLarge,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                          ),
                          child: Text(
                            '${_shortBreakMinutes}m',
                            style: AppTypography.labelLarge.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Slider(
                      value: _shortBreakMinutes.toDouble(),
                      min: 1,
                      max: 30,
                      divisions: 29,
                      onChanged: (value) {
                        setState(() => _shortBreakMinutes = value.toInt());
                      },
                      activeColor: AppColors.success,
                      inactiveColor: AppColors.success.withValues(alpha: 0.2),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Long Break
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Long Break',
                          style: AppTypography.bodyLarge,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.info.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                          ),
                          child: Text(
                            '${_longBreakMinutes}m',
                            style: AppTypography.labelLarge.copyWith(
                              color: AppColors.info,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Slider(
                      value: _longBreakMinutes.toDouble(),
                      min: 1,
                      max: 60,
                      divisions: 59,
                      onChanged: (value) {
                        setState(() => _longBreakMinutes = value.toInt());
                      },
                      activeColor: AppColors.info,
                      inactiveColor: AppColors.info.withValues(alpha: 0.2),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: _startSetup,
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
      backgroundColor: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _isWorkSession ? AppColors.primary : 
                       (_sessionsCompleted % 4 == 0 ? AppColors.info : AppColors.success),
                borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
              ),
              child: Text(
                _isWorkSession ? '🎯 Focus Time' : 
                (_sessionsCompleted % 4 == 0 ? '☕ Long Break' : '☕ Short Break'),
                style: AppTypography.labelLarge.copyWith(color: Colors.white),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.todo.title,
              style: AppTypography.bodyLarge,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 200,
                  height: 200,
                  child: CircularProgressIndicator(
                    value: _remainingSeconds / _totalSessionSeconds,
                    strokeWidth: 12,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    color: _isWorkSession ? AppColors.primary : 
                           (_sessionsCompleted % 4 == 0 ? AppColors.info : AppColors.success),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _timeString,
                      style: AppTypography.displayLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Session: $_sessionsCompleted',
                      style: AppTypography.labelSmall,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  onPressed: _reset,
                  icon: const Icon(Icons.restart_alt_rounded),
                  tooltip: 'Reset',
                ),
                FloatingActionButton(
                  onPressed: _toggleTimer,
                  backgroundColor: _isWorkSession ? AppColors.primary : 
                                   (_sessionsCompleted % 4 == 0 ? AppColors.info : AppColors.success),
                  child: Icon(
                    _isRunning
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  onPressed: _stopAndSave,
                  icon: const Icon(Icons.exit_to_app_rounded),
                  tooltip: 'Exit & Save',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
