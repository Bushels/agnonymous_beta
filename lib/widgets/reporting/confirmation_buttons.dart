import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/farmer_price_report.dart';
import '../../providers/farmer_reports_provider.dart';

/// Confirmation buttons for a farmer price report.
///
/// Displays confirm/outdated counts and lets authenticated users
/// submit a confirmation vote. Disabled if the user is not logged in
/// or has already confirmed.
class ConfirmationButtons extends ConsumerWidget {
  final FarmerPriceReport report;

  const ConfirmationButtons({
    super.key,
    required this.report,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    final isLoggedIn = userId != null;

    // Check if user already confirmed this report
    final hasConfirmedAsync = isLoggedIn
        ? ref.watch(hasUserConfirmedProvider(
            UserConfirmParams(reportId: report.id, userId: userId),
          ))
        : const AsyncValue<bool>.data(false);

    return hasConfirmedAsync.when(
      data: (hasConfirmed) => _buildButtons(
        context,
        ref,
        isLoggedIn: isLoggedIn,
        hasConfirmed: hasConfirmed,
        userId: userId,
      ),
      loading: () => _buildButtons(
        context,
        ref,
        isLoggedIn: isLoggedIn,
        hasConfirmed: false,
        userId: userId,
        isLoading: true,
      ),
      error: (_, __) => _buildButtons(
        context,
        ref,
        isLoggedIn: isLoggedIn,
        hasConfirmed: false,
        userId: userId,
      ),
    );
  }

  Widget _buildButtons(
    BuildContext context,
    WidgetRef ref, {
    required bool isLoggedIn,
    required bool hasConfirmed,
    String? userId,
    bool isLoading = false,
  }) {
    final canVote = isLoggedIn && !hasConfirmed && !isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Confirm button
            Expanded(
              child: _VoteButton(
                icon: Icons.thumb_up_outlined,
                activeIcon: Icons.thumb_up,
                label: 'Confirm',
                count: report.confirmCount,
                color: const Color(0xFF84CC16),
                enabled: canVote,
                onTap: canVote
                    ? () => _handleConfirmation(
                          context, ref, userId!, 'confirm')
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            // Outdated button
            Expanded(
              child: _VoteButton(
                icon: Icons.thumb_down_outlined,
                activeIcon: Icons.thumb_down,
                label: 'Outdated',
                count: report.outdatedCount,
                color: const Color(0xFFF59E0B),
                enabled: canVote,
                onTap: canVote
                    ? () => _handleConfirmation(
                          context, ref, userId!, 'outdated')
                    : null,
              ),
            ),
          ],
        ),
        if (!isLoggedIn)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Login to confirm',
              style: GoogleFonts.inter(
                color: const Color(0xFF64748B),
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        if (hasConfirmed)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                const Icon(Icons.check_circle,
                    color: Color(0xFF10B981), size: 14),
                const SizedBox(width: 4),
                Text(
                  'You have already voted on this report',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF10B981),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _handleConfirmation(
    BuildContext context,
    WidgetRef ref,
    String userId,
    String type,
  ) async {
    try {
      final supabase = Supabase.instance.client;
      await submitConfirmation(
        supabase,
        reportId: report.id,
        confirmerId: userId,
        type: type,
      );

      // Invalidate to refresh counts and user confirmation status
      ref.invalidate(hasUserConfirmedProvider);
      ref.invalidate(elevatorReportsProvider);

      if (context.mounted) {
        final label = type == 'confirm' ? 'Confirmed' : 'Marked outdated';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  type == 'confirm' ? Icons.thumb_up : Icons.thumb_down,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  '$label! Thank you for contributing.',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            backgroundColor: type == 'confirm'
                ? const Color(0xFF84CC16)
                : const Color(0xFFF59E0B),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } on PostgrestException catch (e) {
      // Handle duplicate confirmation (unique constraint violation)
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.code == '23505'
                  ? 'You have already voted on this report.'
                  : 'Error: ${e.message}',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }
}

/// Individual vote button with icon, label, and count.
class _VoteButton extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int count;
  final Color color;
  final bool enabled;
  final VoidCallback? onTap;

  const _VoteButton({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.count,
    required this.color,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: enabled
              ? color.withValues(alpha: 0.08)
              : const Color(0xFF1E293B).withValues(alpha: 0.5),
          border: Border.all(
            color: enabled
                ? color.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              enabled ? icon : icon,
              color: enabled ? color : const Color(0xFF475569),
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: GoogleFonts.inter(
                color: enabled ? color : const Color(0xFF475569),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                color: enabled
                    ? color.withValues(alpha: 0.8)
                    : const Color(0xFF475569),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ).animate().fade(duration: 300.ms);
  }
}
