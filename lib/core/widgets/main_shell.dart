import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/more/presentation/screens/more_screen.dart';
import '../../features/money/presentation/screens/money_screen.dart';
import '../../features/routine/presentation/screens/routine_screen.dart';
import '../../features/todo/presentation/screens/todo_screen.dart';
import '../../features/todo/data/todo_provider.dart';
import '../../features/routine/data/routine_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Provides tab-switching capability to descendant widgets.
class MainShellController extends InheritedWidget {
  final void Function(int index) switchTab;

  const MainShellController({
    super.key,
    required this.switchTab,
    required super.child,
  });

  static MainShellController? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<MainShellController>();
  }

  @override
  bool updateShouldNotify(MainShellController oldWidget) => false;
}

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 0;

  final _screens = const [
    DashboardScreen(),
    TodoScreen(),
    RoutineScreen(),
    MoneyScreen(),
    MoreScreen(),
  ];

  void _switchTab(int index) {
    if (index >= 0 && index < _screens.length) {
      setState(() => _currentIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final todoStats = ref.watch(todoStatsProvider).valueOrNull;
    final todayRoutines = ref.watch(todayRoutinesProvider).valueOrNull;

    final pendingCount = todoStats?.pending ?? 0;
    final routineCount = todayRoutines?.length ?? 0;

    return MainShellController(
      switchTab: _switchTab,
      child: Scaffold(
        body: IndexedStack(index: _currentIndex, children: _screens),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: theme.bottomNavigationBarTheme.backgroundColor,
            border: Border(
              top: BorderSide(color: theme.colorScheme.outline, width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NavItem(
                    icon: Icons.dashboard_rounded,
                    label: 'Home',
                    isActive: _currentIndex == 0,
                    onTap: () => _switchTab(0),
                  ),
                  _NavItem(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Tasks',
                    isActive: _currentIndex == 1,
                    badgeCount: pendingCount > 99 ? 99 : pendingCount,
                    onTap: () => _switchTab(1),
                  ),
                  
                  _NavItem(
                    icon: Icons.loop_rounded,
                    label: 'Routine',
                    isActive: _currentIndex == 2,
                    badgeCount: routineCount > 99 ? 99 : routineCount,
                    onTap: () => _switchTab(2),
                  ),
                  _NavItem(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Money',
                    isActive: _currentIndex == 3,
                    onTap: () => _switchTab(3),
                  ),
                  _NavItem(
                    icon: Icons.grid_view_rounded,
                    label: 'More',
                    isActive: _currentIndex == 4,
                    onTap: () => _switchTab(4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final int? badgeCount;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    this.badgeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color:
              isActive
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: 24,
                  color:
                      isActive
                          ? AppColors.primary
                          : theme.colorScheme.onSurfaceVariant,
                ),
                if ((badgeCount ?? 0) > 0)
                  Positioned(
                    right: -8,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(minWidth: 16),
                      child: Text(
                        '${badgeCount!}',
                        textAlign: TextAlign.center,
                        style: AppTypography.labelSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color:
                    isActive
                        ? AppColors.primary
                        : theme.colorScheme.onSurfaceVariant,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
