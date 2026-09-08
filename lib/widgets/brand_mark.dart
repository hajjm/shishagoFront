import 'package:flutter/material.dart';

import '../core/app_theme.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.light = false, this.compact = false});

  final bool light;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = light ? Colors.white : AppColors.ink;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 34 : 42,
          height: compact ? 34 : 42,
          decoration: BoxDecoration(
            color: light
                ? Colors.white.withValues(alpha: 0.16)
                : AppColors.ember,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.local_fire_department_rounded,
            color: light ? Colors.white : Colors.white,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'chichago',
          style: TextStyle(
            color: color,
            fontSize: compact ? 21 : 25,
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
          ),
        ),
      ],
    );
  }
}
