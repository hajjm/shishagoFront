import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/app_models.dart';

class OrderStatusPill extends StatelessWidget {
  const OrderStatusPill({super.key, required this.stage});

  final OrderStage stage;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (stage) {
      OrderStage.pending => (Colors.amber.shade800, Icons.schedule_rounded),
      OrderStage.accepted => (
        Colors.blue.shade700,
        Icons.check_circle_outline_rounded,
      ),
      OrderStage.preparing => (
        Colors.deepPurple.shade600,
        Icons.inventory_2_outlined,
      ),
      OrderStage.onTheWay => (AppColors.ember, Icons.delivery_dining_rounded),
      OrderStage.completed => (AppColors.sage, Icons.check_circle_rounded),
      OrderStage.cancelled => (Colors.red.shade700, Icons.cancel_outlined),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            stage.label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
