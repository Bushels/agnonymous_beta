import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../widgets/glass_container.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notifications_provider.dart';
import '../../models/notification_model.dart';
import '../auth/login_screen.dart';
import '../post_details_screen.dart';

/// Notifications/Alerts screen for system notifications
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  Widget build(BuildContext context) {
    final isAuthenticated = ref.watch(isAuthenticatedProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const FaIcon(
                    FontAwesomeIcons.bell,
                    color: Color(0xFF84CC16),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Notifications',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Content
            Expanded(
              child: isAuthenticated
                  ? const _ActivityTab()
                  : _buildSignInPrompt(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignInPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: GlassContainer(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF84CC16).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const FaIcon(
                  FontAwesomeIcons.bellSlash,
                  size: 48,
                  color: Color(0xFF84CC16),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Sign In to Get Notifications',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Create an account to receive notifications about your posts.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
                icon: const FaIcon(FontAwesomeIcons.rightToBracket, size: 16),
                label: const Text('Sign In'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF84CC16),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Activity tab content
class _ActivityTab extends ConsumerWidget {
  const _ActivityTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsState = ref.watch(notificationsProvider);
    final activityNotifications = ref.watch(activityNotificationsProvider);

    if (notificationsState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (notificationsState.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FaIcon(FontAwesomeIcons.triangleExclamation,
                color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              'Error loading activity',
              style: GoogleFonts.inter(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () =>
                  ref.read(notificationsProvider.notifier).refresh(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (activityNotifications.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        // Mark all as read button
        if (notificationsState.unreadCount > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () =>
                      ref.read(notificationsProvider.notifier).markAllAsRead(),
                  icon: const FaIcon(FontAwesomeIcons.check, size: 14),
                  label: Text(
                    'Mark all read (${notificationsState.unreadCount})',
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF84CC16),
                  ),
                ),
              ],
            ),
          ),

        // Notifications list
        Expanded(
          child: RefreshIndicator(
            onRefresh: () =>
                ref.read(notificationsProvider.notifier).refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: activityNotifications.length,
              itemBuilder: (context, index) {
                final notification = activityNotifications[index];
                return _ActivityNotificationCard(
                  notification: notification,
                  onTap: () {
                    // Mark as read when tapped
                    if (!notification.isRead) {
                      ref
                          .read(notificationsProvider.notifier)
                          .markAsRead([notification.id]);
                    }
                    // Navigate to post if postId exists
                    if (notification.postId != null) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              PostDetailsScreen(postId: notification.postId!),
                        ),
                      );
                    }
                  },
                  onDismiss: () {
                    ref
                        .read(notificationsProvider.notifier)
                        .deleteNotification(notification.id);
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const FaIcon(
                FontAwesomeIcons.commentDots,
                size: 48,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Activity Yet',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'When people vote or comment on your posts, you\'ll see it here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildActivityType(
                    FontAwesomeIcons.thumbsUp, 'Votes', const Color(0xFF84CC16)),
                _buildActivityType(
                    FontAwesomeIcons.comment, 'Comments', Colors.blue),
                _buildActivityType(
                    FontAwesomeIcons.star, 'Mentions', const Color(0xFFF59E0B)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityType(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual notification card for activity
class _ActivityNotificationCard extends StatelessWidget {
  final UserNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _ActivityNotificationCard({
    required this.notification,
    required this.onTap,
    required this.onDismiss,
  });

  Color _getColorForType() {
    switch (notification.type) {
      case NotificationType.vote:
        switch (notification.voteType) {
          case 'thumbs_up':
            return const Color(0xFF84CC16);
          case 'thumbs_down':
            return Colors.red;
          case 'partial':
            return Colors.orange;
          case 'funny':
            return Colors.amber;
          default:
            return Colors.grey;
        }
      case NotificationType.comment:
        return Colors.blue;
      case NotificationType.mention:
        return const Color(0xFFF59E0B);
      default:
        return Colors.grey;
    }
  }

  IconData _getIconForType() {
    switch (notification.type) {
      case NotificationType.vote:
        switch (notification.voteType) {
          case 'thumbs_up':
            return FontAwesomeIcons.thumbsUp;
          case 'thumbs_down':
            return FontAwesomeIcons.thumbsDown;
          case 'partial':
            return FontAwesomeIcons.scaleBalanced;
          case 'funny':
            return FontAwesomeIcons.faceLaughSquint;
          default:
            return FontAwesomeIcons.check;
        }
      case NotificationType.comment:
        return FontAwesomeIcons.comment;
      case NotificationType.mention:
        return FontAwesomeIcons.at;
      default:
        return FontAwesomeIcons.bell;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColorForType();

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const FaIcon(FontAwesomeIcons.trash, color: Colors.red),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: GestureDetector(
          onTap: onTap,
          child: GlassContainer(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: FaIcon(
                      _getIconForType(),
                      size: 18,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: notification.isRead
                                    ? FontWeight.normal
                                    : FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!notification.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.message,
                        style: GoogleFonts.inter(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.timeAgo,
                        style: GoogleFonts.inter(
                          color: Colors.grey[600],
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
