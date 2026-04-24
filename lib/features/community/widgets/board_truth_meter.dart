import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/user_profile.dart' show TruthMeterStatus;
import '../board_theme.dart';

class BoardTruthMeter extends StatelessWidget {
  final TruthMeterStatus status;
  final double score;
  final int thumbsUp;
  final int neutral;
  final int thumbsDown;
  final void Function(String voteType)? onVote;

  const BoardTruthMeter({
    super.key,
    required this.status,
    required this.score,
    required this.thumbsUp,
    required this.neutral,
    required this.thumbsDown,
    this.onVote,
  });

  int get totalSignal => thumbsUp + neutral + thumbsDown;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor;
    final hasDirectionalVotes = thumbsUp + thumbsDown > 0;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF20231C),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: BoardColors.line),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 34,
                width: 34,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: FaIcon(_statusIcon, size: 15, color: statusColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'COMMUNITY READ',
                      style: BoardText.meta.copyWith(
                        color: BoardColors.muted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _statusLabel(hasDirectionalVotes),
                      style: GoogleFonts.outfit(
                        color: BoardColors.ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                hasDirectionalVotes ? '${score.round()}%' : '--',
                style: GoogleFonts.outfit(
                  color: statusColor,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: hasDirectionalVotes ? score / 100 : 0.5,
              backgroundColor: BoardColors.line,
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _VoteButton(
                  icon: FontAwesomeIcons.thumbsDown,
                  label: 'No',
                  count: thumbsDown,
                  color: BoardColors.monette,
                  onTap: onVote == null ? null : () => onVote!('thumbs_down'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _VoteButton(
                  icon: FontAwesomeIcons.circleQuestion,
                  label: 'Neutral',
                  count: neutral,
                  color: BoardColors.amber,
                  onTap: onVote == null ? null : () => onVote!('partial'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _VoteButton(
                  icon: FontAwesomeIcons.thumbsUp,
                  label: 'Yes',
                  count: thumbsUp,
                  color: BoardColors.green,
                  onTap: onVote == null ? null : () => onVote!('thumbs_up'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color get _statusColor {
    switch (status) {
      case TruthMeterStatus.verifiedTruth:
      case TruthMeterStatus.verifiedCommunity:
      case TruthMeterStatus.likelyTrue:
        return BoardColors.green;
      case TruthMeterStatus.partiallyTrue:
        return BoardColors.amber;
      case TruthMeterStatus.questionable:
        return BoardColors.amber;
      case TruthMeterStatus.rumour:
        return BoardColors.monette;
      case TruthMeterStatus.unrated:
        return BoardColors.muted;
    }
  }

  IconData get _statusIcon {
    switch (status) {
      case TruthMeterStatus.verifiedTruth:
      case TruthMeterStatus.verifiedCommunity:
      case TruthMeterStatus.likelyTrue:
        return FontAwesomeIcons.circleCheck;
      case TruthMeterStatus.partiallyTrue:
      case TruthMeterStatus.questionable:
        return FontAwesomeIcons.scaleBalanced;
      case TruthMeterStatus.rumour:
        return FontAwesomeIcons.triangleExclamation;
      case TruthMeterStatus.unrated:
        return FontAwesomeIcons.circleQuestion;
    }
  }

  String _statusLabel(bool hasDirectionalVotes) {
    if (totalSignal == 0) return 'No read yet';
    if (!hasDirectionalVotes) return 'Neutral so far';
    return status.label;
  }
}

class _VoteButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final VoidCallback? onTap;

  const _VoteButton({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(icon, size: 15, color: color),
            const SizedBox(height: 5),
            Text(
              count.toString(),
              style: GoogleFonts.outfit(
                color: BoardColors.ink,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BoardText.meta.copyWith(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
