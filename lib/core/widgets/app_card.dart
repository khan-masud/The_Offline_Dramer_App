import 'package:flutter/material.dart';
import '../theme/app_dimensions.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(AppDimensions.radiusLg);

    return Material(
      color: color ?? theme.cardTheme.color,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          padding: padding ?? const EdgeInsets.all(AppDimensions.base),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: theme.colorScheme.outline, width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}
