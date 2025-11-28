import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user_profile.dart';

/// Reputation level badge
class ReputationBadge extends StatelessWidget {
  final ReputationLevelInfo levelInfo;
  final bool showTitle;
  final bool compact;

  const ReputationBadge({
    super.key,
    required this.levelInfo,
    this.showTitle = true,
    this.compact = false,
  });

  /// Create from reputation points
  factory ReputationBadge.fromPoints({
    Key? key,
    required int reputationPoints,
    bool showTitle = true,
    bool compact = false,
  }) {
    return ReputationBadge(
      key: key,
      levelInfo: ReputationLevelInfo.fromPoints(reputationPoints),
      showTitle: showTitle,
      compact: compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Text(
        levelInfo.emoji,
        style: const TextStyle(fontSize: 16),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: _getGradient(),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: _getColor().withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            levelInfo.emoji,
            style: const TextStyle(fontSize: 18),
          ),
          if (showTitle) ...[
            const SizedBox(width: 6),
            Text(
              levelInfo.title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getColor() {
    if (levelInfo.level >= 9) return Colors.purple; // Legend
    if (levelInfo.level >= 7) return Colors.amber; // Guardian/Master
    if (levelInfo.level >= 5) return Colors.blue; // Trusted/Expert
    if (levelInfo.level >= 3) return Colors.green; // Established/Reliable
    if (levelInfo.level >= 1) return Colors.lightGreen; // Sprout/Growing
    return Colors.grey; // Seedling
  }

  LinearGradient _getGradient() {
    final color = _getColor();
    return LinearGradient(
      colors: [color, color.withOpacity(0.7)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
}

/// Widget to display reputation progress to next level
class ReputationProgress extends StatelessWidget {
  final int reputationPoints;
  final bool showDetails;

  const ReputationProgress({
    super.key,
    required this.reputationPoints,
    this.showDetails = true,
  });

  @override
  Widget build(BuildContext context) {
    final currentLevel = ReputationLevelInfo.fromPoints(reputationPoints);
    final nextLevel = ReputationLevelInfo.fromLevel(
      currentLevel.level < 9 ? currentLevel.level + 1 : 9,
    );

    final currentMin = currentLevel.minPoints;
    final nextMin = nextLevel.minPoints;
    final range = nextMin - currentMin;
    final progress = range > 0 ? (reputationPoints - currentMin) / range : 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showDetails)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${currentLevel.emoji} ${currentLevel.title}',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              if (currentLevel.level < 9)
                Text(
                  '${nextMin - reputationPoints} pts to ${nextLevel.title}',
                  style: GoogleFonts.inter(
                    color: Colors.grey.shade400,
                    fontSize: 12,
                  ),
                )
              else
                Text(
                  'Max Level!',
                  style: GoogleFonts.inter(
                    color: Colors.amber,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        if (showDetails) const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: Colors.grey.shade800,
            valueColor: AlwaysStoppedAnimation<Color>(
              _getLevelColor(currentLevel.level),
            ),
            minHeight: 8,
          ),
        ),
        if (showDetails) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$reputationPoints pts',
                style: GoogleFonts.inter(
                  color: Colors.grey.shade500,
                  fontSize: 10,
                ),
              ),
              if (currentLevel.level < 9)
                Text(
                  '$nextMin pts',
                  style: GoogleFonts.inter(
                    color: Colors.grey.shade500,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Color _getLevelColor(int level) {
    switch (level) {
      case 0:
        return Colors.grey;
      case 1:
        return Colors.green.shade300;
      case 2:
        return Colors.green;
      case 3:
        return Colors.teal;
      case 4:
        return Colors.amber;
      case 5:
        return Colors.orange;
      case 6:
        return Colors.deepOrange;
      case 7:
        return Colors.purple;
      case 8:
        return Colors.indigo;
      case 9:
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }
}

/// Widget to display full reputation stats card
class ReputationStatsCard extends StatelessWidget {
  final UserProfile profile;

  const ReputationStatsCard({
    super.key,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    final levelInfo = profile.levelInfo;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade800,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Level badge and title
          Row(
            children: [
              Text(
                levelInfo.emoji,
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    levelInfo.title,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  Text(
                    'Level ${levelInfo.level}',
                    style: GoogleFonts.inter(
                      color: Colors.grey.shade400,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Progress bar
          ReputationProgress(
            reputationPoints: profile.reputationPoints,
            showDetails: true,
          ),
          const SizedBox(height: 16),

          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatColumn(
                icon: Icons.star,
                value: '${profile.reputationPoints}',
                label: 'Total Points',
                color: Colors.amber,
              ),
              _buildStatColumn(
                icon: Icons.visibility,
                value: '${profile.publicReputation}',
                label: 'Public',
                color: Colors.green,
              ),
              _buildStatColumn(
                icon: Icons.masks,
                value: '${profile.anonymousReputation}',
                label: 'Anonymous',
                color: Colors.grey.shade400,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Vote weight indicator
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF84CC16).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF84CC16).withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.how_to_vote,
                  color: Color(0xFF84CC16),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your votes count ${profile.voteWeight}x',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF84CC16),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Perks list
          Text(
            'Level Perks',
            style: GoogleFonts.inter(
              color: Colors.grey.shade400,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...levelInfo.perks.map((perk) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFF84CC16),
                  size: 14,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    perk,
                    style: GoogleFonts.inter(
                      color: Colors.grey.shade300,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildStatColumn({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.grey.shade500,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
