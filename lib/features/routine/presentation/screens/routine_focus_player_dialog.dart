import 'dart:async';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../data/routine_provider.dart';

class RoutineFocusPlayerDialog extends ConsumerStatefulWidget {
  final Routine routine;
  final List<RoutineItem> items;

  const RoutineFocusPlayerDialog({
    super.key,
    required this.routine,
    required this.items,
  });

  @override
  ConsumerState<RoutineFocusPlayerDialog> createState() => _RoutineFocusPlayerDialogState();
}

class _RoutineFocusPlayerDialogState extends ConsumerState<RoutineFocusPlayerDialog> {
  int _currentIndex = 0;
  int _secondsRemaining = 300; // default 5 minutes
  int _totalStepSeconds = 300;
  bool _isRunning = true;
  Timer? _timer;
  int _totalSessionSeconds = 0;
  bool _isCompletedAll = false;
  late DateTime _sessionStartTime;

  @override
  void initState() {
    super.initState();
    _sessionStartTime = DateTime.now();
    _initCurrentStepTimer();
    _startTimer();
  }

  void _initCurrentStepTimer() {
    if (_currentIndex < widget.items.length) {
      final item = widget.items[_currentIndex];
      int duration = 300; // default 5 minutes
      if (item.startTime != null && item.endTime != null) {
        try {
          final sParts = item.startTime!.split(':').map(int.parse).toList();
          final eParts = item.endTime!.split(':').map(int.parse).toList();
          final sMins = sParts[0] * 60 + sParts[1];
          final eMins = eParts[0] * 60 + eParts[1];
          if (eMins > sMins) {
            duration = (eMins - sMins) * 60;
          }
        } catch (_) {}
      }
      setState(() {
        _secondsRemaining = duration;
        _totalStepSeconds = duration;
      });
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_isRunning) {
        setState(() {
          _totalSessionSeconds++;
          if (_secondsRemaining > 0) {
            _secondsRemaining--;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _completeCurrentStep({bool advance = true}) async {
    HapticFeedback.mediumImpact();
    final db = ref.read(databaseProvider);
    if (_currentIndex < widget.items.length) {
      final currentItem = widget.items[_currentIndex];
      await db.markRoutineItemCompleted(currentItem.id);
    }

    if (advance) {
      if (_currentIndex + 1 < widget.items.length) {
        setState(() {
          _currentIndex++;
        });
        _initCurrentStepTimer();
      } else {
        _finishEntireRoutine();
      }
    }
  }

  void _skipCurrentStep() {
    HapticFeedback.lightImpact();
    if (_currentIndex + 1 < widget.items.length) {
      setState(() {
        _currentIndex++;
      });
      _initCurrentStepTimer();
    } else {
      _finishEntireRoutine();
    }
  }

  Future<void> _finishEntireRoutine() async {
    _timer?.cancel();
    setState(() {
      _isCompletedAll = true;
    });
    HapticFeedback.heavyImpact();

    // Log Focus Session to Database
    final db = ref.read(databaseProvider);
    if (_totalSessionSeconds > 10) {
      await db.addFocusSession(FocusSessionsCompanion(
        sessionType: const Value('pomodoro'),
        durationSeconds: Value(_totalSessionSeconds),
        startTime: Value(_sessionStartTime),
        endTime: Value(DateTime.now()),
      ));
    }
  }

  String _formatTime(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isCompletedAll) {
      return _buildCelebrationScreen(theme, isDark);
    }

    if (widget.items.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.routine.title)),
        body: const Center(child: Text('No items in this routine')),
      );
    }

    final currentItem = widget.items[_currentIndex];
    final nextItem = (_currentIndex + 1 < widget.items.length) ? widget.items[_currentIndex + 1] : null;
    final progress = (_currentIndex + 1) / widget.items.length;
    final timerProgress = _totalStepSeconds > 0 ? (_secondsRemaining / _totalStepSeconds).clamp(0.0, 1.0) : 0.0;
    final subTasksAsync = ref.watch(routineSubTasksProvider(currentItem.id));
    final subTasks = subTasksAsync.valueOrNull ?? [];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.routine.title,
              style: AppTypography.headingSmall.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              'Step ${_currentIndex + 1} of ${widget.items.length}',
              style: AppTypography.labelSmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_isRunning ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded),
            iconSize: 28,
            onPressed: () => setState(() => _isRunning = !_isRunning),
            tooltip: _isRunning ? 'Pause Timer' : 'Resume Timer',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Overall Step Progress
            LinearProgressIndicator(
              value: progress,
              backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.15),
              color: AppColors.primary,
              minHeight: 4,
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    // Timer Circle
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 200,
                          height: 200,
                          child: CircularProgressIndicator(
                            value: timerProgress,
                            strokeWidth: 8,
                            backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.15),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _secondsRemaining == 0 ? AppColors.error : AppColors.primary,
                            ),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatTime(_secondsRemaining),
                              style: AppTypography.displayLarge.copyWith(
                                fontWeight: FontWeight.w800,
                                fontSize: 42,
                                letterSpacing: 2,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isRunning ? 'FOCUSING' : 'PAUSED',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                                color: _isRunning ? AppColors.success : AppColors.warning,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ).animate().scale(begin: const Offset(0.9, 0.9), duration: 300.ms),

                    const SizedBox(height: 28),

                    // Current Item Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'CURRENT TASK',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              if (currentItem.startTime != null)
                                Row(
                                  children: [
                                    Icon(Icons.schedule_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${currentItem.startTime} - ${currentItem.endTime ?? ''}',
                                      style: AppTypography.labelSmall.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            currentItem.title,
                            style: AppTypography.headingMedium.copyWith(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (subTasks.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            const Divider(height: 1),
                            const SizedBox(height: 12),
                            ...subTasks.map((st) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          ref.read(databaseProvider).toggleRoutineSubTask(st.id, !st.isCompleted);
                                        },
                                        child: Container(
                                          width: 18,
                                          height: 18,
                                          decoration: BoxDecoration(
                                            color: st.isCompleted ? AppColors.success : Colors.transparent,
                                            borderRadius: BorderRadius.circular(5),
                                            border: Border.all(
                                              color: st.isCompleted ? AppColors.success : theme.colorScheme.outline,
                                              width: 1.5,
                                            ),
                                          ),
                                          child: st.isCompleted
                                              ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          st.title,
                                          style: AppTypography.bodyMedium.copyWith(
                                            decoration: st.isCompleted ? TextDecoration.lineThrough : null,
                                            color: st.isCompleted
                                                ? theme.colorScheme.onSurfaceVariant
                                                : theme.colorScheme.onSurface,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                          ],
                        ],
                      ),
                    ),

                    // Next up preview
                    if (nextItem != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.skip_next_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 8),
                            Text(
                              'Next: ',
                              style: AppTypography.labelSmall.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                nextItem.title,
                                style: AppTypography.labelMedium.copyWith(
                                  color: theme.colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Bottom Action Controls
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  OutlinedButton(
                    onPressed: _skipCurrentStep,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Skip'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _completeCurrentStep(advance: true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
                      label: Text(
                        _currentIndex + 1 < widget.items.length ? 'Complete & Next' : 'Finish Routine',
                        style: AppTypography.labelLarge.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
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

  Widget _buildCelebrationScreen(ThemeData theme, bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.celebration_rounded, color: AppColors.success, size: 54),
                ),
              ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
              const SizedBox(height: 24),
              Text(
                'Routine Completed! 🎉',
                style: AppTypography.headingLarge.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'You successfully powered through ${widget.routine.title}',
                style: AppTypography.bodyMedium.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              // Session Stat card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        Text('Steps Done', style: AppTypography.labelSmall.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 4),
                        Text('${widget.items.length}', style: AppTypography.headingMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary)),
                      ],
                    ),
                    Container(width: 1, height: 32, color: theme.colorScheme.outline.withValues(alpha: 0.2)),
                    Column(
                      children: [
                        Text('Total Time', style: AppTypography.labelSmall.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 4),
                        Text(_formatTime(_totalSessionSeconds), style: AppTypography.headingMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.success)),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Done', style: AppTypography.labelLarge.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
