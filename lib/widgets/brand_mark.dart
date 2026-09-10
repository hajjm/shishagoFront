import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// The shared artwork used by every role and authentication screen.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * 0.16),
    child: Image.asset(
      'assets/branding/shishago-logo.jpeg',
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticLabel: 'Shisha Go logo',
      filterQuality: FilterQuality.high,
    ),
  );
}

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
        BrandLogo(size: compact ? 40 : 56),
        const SizedBox(width: 10),
        Text(
          'Shisha Go',
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
