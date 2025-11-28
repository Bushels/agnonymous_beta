import 'package:flutter/material.dart';

/// User badge widget showing verification status
class UserBadge extends StatelessWidget {
  final bool isAnonymous;
  final bool isVerified;
  final bool compact;

  const UserBadge({
    super.key,
    this.isAnonymous = false,
    this.isVerified = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isAnonymous) {
      return _buildBadge(
        icon: Icons.masks,
        label: compact ? null : 'Anonymous',
        color: Colors.grey.shade600,
        backgroundColor: Colors.grey.shade200,
      );
    }

    if (isVerified) {
      return _buildBadge(
        icon: Icons.verified,
        label: compact ? null : 'Verified',
        color: Colors.blue.shade700,
        backgroundColor: Colors.blue.shade100,
      );
    }

    return _buildBadge(
      icon: Icons.warning_amber,
      label: compact ? null : 'Unverified',
      color: Colors.orange.shade700,
      backgroundColor: Colors.orange.shade100,
    );
  }

  Widget _buildBadge({
    required IconData icon,
    required String? label,
    required Color color,
    required Color backgroundColor,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 4 : 6,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 12 : 14, color: color),
          if (label != null) ...[
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: compact ? 10 : 11,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
