import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../models/notification_model.dart';
import '../../../services/auth_service.dart';
import '../../../services/database_service.dart';
import 'profile_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    final dbService = DatabaseService();

    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: dbService.getNotifications(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading notifications',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(Icons.notifications_none, size: 64, color: Colors.grey[400]),
                   const SizedBox(height: 16),
                   Text(
                     'No notifications yet',
                     style: TextStyle(color: Colors.grey[600]),
                   ),
                ],
              ),
            );
          }

          final notifications = snapshot.data!;

          return ListView.separated(
            itemCount: notifications.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return NotificationTile(notification: notification);
            },
          );
        },
      ),
    );
  }
}

class NotificationTile extends StatelessWidget {
  final NotificationModel notification;

  const NotificationTile({super.key, required this.notification});

  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 7) {
      return DateFormat('MMM d').format(timestamp);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  IconData _getIcon() {
    switch (notification.type) {
      case NotificationType.like:
        return Icons.favorite;
      case NotificationType.comment:
        return Icons.comment;
      case NotificationType.follow:
        return Icons.person_add;
    }
  }

  Color _getIconColor() {
    switch (notification.type) {
      case NotificationType.like:
        return Colors.red;
      case NotificationType.comment:
        return Colors.blue;
      case NotificationType.follow:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      tileColor: notification.isRead ? null : Theme.of(context).colorScheme.primaryContainer.withOpacity(0.1),
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundImage: notification.senderPhoto != null
                ? NetworkImage(notification.senderPhoto!)
                : null,
            child: notification.senderPhoto == null
                ? Text(notification.senderName[0].toUpperCase())
                : null,
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getIcon(),
                size: 14,
                color: _getIconColor(),
              ),
            ),
          ),
        ],
      ),
      title: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style,
          children: [
            TextSpan(
              text: notification.senderName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: ' ${notification.message}'),
          ],
        ),
      ),
      subtitle: Text(
        _getTimeAgo(notification.timestamp),
        style: TextStyle(color: Colors.grey[600], fontSize: 12),
      ),
      onTap: () async {
        if (!notification.isRead) {
          await DatabaseService().markNotificationRead(notification.id);
        }

        if (context.mounted) {
          if (notification.type == NotificationType.follow) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProfileScreen(viewUserId: notification.senderId),
              ),
            );
          } else {
            // For likes/comments, ideally navigate to post details
            // For now, simpler to just go to profile or show snackbar if post details not implemented
             ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Post navigation coming soon')),
              );
          }
        }
      },
    );
  }
}
