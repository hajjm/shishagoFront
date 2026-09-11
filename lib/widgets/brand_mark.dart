import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// The shared artwork used by every role and authentication screen.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 48, this.blendColor});

  final double size;
  final Color? blendColor;

  @override
  Widget build(BuildContext context) {
    Widget logo = Image.asset(
      'assets/branding/shishago-logo.jpeg',
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticLabel: 'Shisha Go logo',
      filterQuality: FilterQuality.high,
    );
    if (blendColor != null) {
      logo = ColorFiltered(
        colorFilter: ColorFilter.mode(blendColor!, BlendMode.multiply),
        child: Opacity(opacity: 0.96, child: logo),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.16),
      child: logo,
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.light = false,
    this.compact = false,
    this.logoBlendColor,
  });

  final bool light;
  final bool compact;
  final Color? logoBlendColor;

  @override
  Widget build(BuildContext context) {
    final color = light ? Colors.white : AppColors.ink;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandLogo(size: compact ? 40 : 56, blendColor: logoBlendColor),
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
