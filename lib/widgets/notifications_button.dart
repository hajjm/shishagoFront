import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../data/app_store.dart';

class NotificationsButton extends StatelessWidget {
  const NotificationsButton({super.key, required this.store});

  final ChichagoStore store;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (context, _) {
      final unread = store.notifications.where((value) => !value.isRead).length;
      return IconButton(
        tooltip: 'Notifications',
        onPressed: () => _showNotifications(context),
        icon: Badge(
          isLabelVisible: unread > 0,
          label: Text('$unread'),
          child: const Icon(Icons.notifications_none_rounded),
        ),
      );
    },
  );

  Future<void> _showNotifications(BuildContext context) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) => AnimatedBuilder(
          animation: store,
          builder: (context, _) => SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                Text(
                  'Notifications',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 12),
                if (store.notifications.isEmpty)
                  const ListTile(title: Text('No notifications yet')),
                ...store.notifications.map(
                  (notification) => ListTile(
                    onTap: notification.isRead
                        ? null
                        : () => store.markNotificationRead(notification),
                    leading: Icon(
                      notification.isRead
                          ? Icons.notifications_none
                          : Icons.notifications_active,
                      color: AppColors.ember,
                    ),
                    title: Text(
                      notification.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(notification.body),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
