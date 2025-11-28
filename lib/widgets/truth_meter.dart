import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user_profile.dart';

/// Vote types for the Truth Meter
enum TruthVoteType {
  stronglyAgree,  // Double thumbs up
  agree,          // Single thumb up
  neutral,        // Question mark / meh
  disagree,       // Thumbs down
}

extension TruthVoteTypeExtension on TruthVoteType {
  String get apiValue {
    switch (this) {
      case TruthVoteType.stronglyAgree:
        return 'thumbs_up'; // Maps to existing, weighted higher
      case TruthVoteType.agree:
        return 'partial'; // Maps to partial as "soft agree"
      case TruthVoteType.neutral:
        return 'funny'; // Repurpose funny as neutral
      case TruthVoteType.disagree:
        return 'thumbs_down';
    }
  }

  String get label {
    switch (this) {
      case TruthVoteType.stronglyAgree:
        return 'Strongly Agree';
      case TruthVoteType.agree:
        return 'Agree';
      case TruthVoteType.neutral:
        return 'Neutral';
      case TruthVoteType.disagree:
        return 'Disagree';
    }
  }

  String get emoji {
    switch (this) {
      case TruthVoteType.stronglyAgree:
        return '👍👍';
      case TruthVoteType.agree:
        return '👍';
      case TruthVoteType.neutral:
        return '😐';
      case TruthVoteType.disagree:
        return '👎';
    }
  }

  Color get color {
    switch (this) {
      case TruthVoteType.stronglyAgree:
        return const Color(0xFF22C55E); // Bright green
      case TruthVoteType.agree:
        return const Color(0xFF84CC16); // Lime green
      case TruthVoteType.neutral:
        return const Color(0xFFF59E0B); // Amber
      case TruthVoteType.disagree:
        return const Color(0xFFEF4444); // Red
    }
  }
}

/// Luxury animated Truth Meter widget
class TruthMeter extends StatelessWidget {
  final TruthMeterStatus status;
  final double score;
  final int voteCount;
  final int thumbsUp;
  final int thumbsDown;
  final int partial;
  final int funny;
  final bool compact;
  final bool showVoteBreakdown;
  final void Function(String voteType)? onVote;

  const TruthMeter({
    super.key,
    required this.status,
    required this.score,
    required this.voteCount,
    this.thumbsUp = 0,
    this.thumbsDown = 0,
    this.partial = 0,
    this.funny = 0,
    this.compact = false,
    this.showVoteBreakdown = false,
    this.onVote,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _CompactTruthMeter(
        status: status,
        score: score,
        voteCount: voteCount,
      );
    }
    return _FullTruthMeter(
      status: status,
      score: score,
      voteCount: voteCount,
      thumbsUp: thumbsUp,
      thumbsDown: thumbsDown,
      partial: partial,
      funny: funny,
      showVoteBreakdown: showVoteBreakdown,
      onVote: onVote,
    );
  }
}

/// Compact truth meter for list views
class _CompactTruthMeter extends StatelessWidget {
  final TruthMeterStatus status;
  final double score;
  final int voteCount;

  const _CompactTruthMeter({
    required this.status,
    required this.score,
    required this.voteCount,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = status.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.analytics_outlined, size: 14, color: statusColor),
          const SizedBox(width: 6),
          Text(
            '${score.toStringAsFixed(0)}%',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Full animated truth meter display
class _FullTruthMeter extends StatefulWidget {
  final TruthMeterStatus status;
  final double score;
  final int voteCount;
  final int thumbsUp;
  final int thumbsDown;
  final int partial;
  final int funny;
  final bool showVoteBreakdown;
  final void Function(String voteType)? onVote;

  const _FullTruthMeter({
    required this.status,
    required this.score,
    required this.voteCount,
    required this.thumbsUp,
    required this.thumbsDown,
    required this.partial,
    required this.funny,
    required this.showVoteBreakdown,
    this.onVote,
  });

  @override
  State<_FullTruthMeter> createState() => _FullTruthMeterState();
}

class _FullTruthMeterState extends State<_FullTruthMeter>
    with TickerProviderStateMixin {
  late AnimationController _barController;
  late AnimationController _glowController;
  late Animation<double> _barAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    _barController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _barAnimation = Tween<double>(begin: 0, end: widget.score / 100).animate(
      CurvedAnimation(parent: _barController, curve: Curves.easeOutCubic),
    );

    _glowAnimation = Tween<double>(begin: 0.3, end: 0.6).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _barController.forward();
  }

  @override
  void didUpdateWidget(_FullTruthMeter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.score != widget.score) {
      _barAnimation = Tween<double>(
        begin: _barAnimation.value,
        end: widget.score / 100,
      ).animate(
        CurvedAnimation(parent: _barController, curve: Curves.easeOutCubic),
      );
      _barController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _barController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = widget.status.color;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, child) {
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    statusColor.withOpacity(0.15),
                    const Color(0xFF1F2937).withOpacity(0.9),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: statusColor.withOpacity(0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withOpacity(_glowAnimation.value * 0.3),
                    blurRadius: 20,
                    spreadRadius: -5,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(statusColor),
                      if (widget.voteCount > 0) ...[
                        const SizedBox(height: 16),
                        _buildAnimatedBar(statusColor),
                      ],
                      // Show vote breakdown for authenticated users (even with 0 votes)
                      if (widget.showVoteBreakdown) ...[
                        const SizedBox(height: 16),
                        _buildVoteBreakdown(),
                      ] else if (widget.voteCount == 0) ...[
                        const SizedBox(height: 12),
                        _buildNoVotesMessage(),
                      ],
                    ],
                  ),
                  // Funny vote badge removed from here as it will be in the action row
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(Color statusColor) {
    return Row(
      children: [
        _AnimatedStatusIcon(status: widget.status, color: statusColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'COMMUNITY TRUTH METER',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade400,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.status.label,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ],
          ),
        ),
        if (widget.voteCount > 0)
          _AnimatedScoreBadge(
            score: widget.score,
            color: statusColor,
            animation: _barAnimation,
          ),
      ],
    );
  }

  Widget _buildAnimatedBar(Color statusColor) {
    return AnimatedBuilder(
      animation: _barAnimation,
      builder: (context, child) {
        return Column(
          children: [
            // Main progress bar
            Container(
              height: 12,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Stack(
                children: [
                  // Animated fill
                  FractionallySizedBox(
                    widthFactor: _barAnimation.value,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            statusColor.withOpacity(0.8),
                            statusColor,
                            Color.lerp(statusColor, Colors.white, 0.2)!,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: statusColor.withOpacity(0.6),
                            blurRadius: 10,
                            spreadRadius: -2,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Shimmer effect
                  if (_barAnimation.value > 0)
                    Positioned.fill(
                      child: _ShimmerOverlay(
                        widthFactor: _barAnimation.value,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Credibility label only (no vote count)
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                _getCredibilityLabel(),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: statusColor.withOpacity(0.8),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _getCredibilityLabel() {
    if (widget.score >= 80) return 'Highly Credible';
    if (widget.score >= 60) return 'Credible';
    if (widget.score >= 40) return 'Mixed Reviews';
    if (widget.score >= 20) return 'Questionable';
    return 'Likely False';
  }

  Widget _buildVoteBreakdown() {
    final total = widget.thumbsUp + widget.partial + widget.thumbsDown;
    // Always show breakdown if we have callback, even if total is 0 (to allow voting)
    if (total == 0 && widget.onVote == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _VoteStatItem(
            icon: FontAwesomeIcons.thumbsDown,
            count: widget.thumbsDown,
            label: null,
            color: const Color(0xFFEF4444),
            total: total,
            onTap: widget.onVote != null ? () => widget.onVote!('thumbs_down') : null,
          ),
          _VoteStatItem(
            icon: FontAwesomeIcons.circleQuestion,
            count: widget.partial,
            label: null,
            color: const Color(0xFFF59E0B),
            total: total,
            onTap: widget.onVote != null ? () => widget.onVote!('partial') : null,
          ),
          _VoteStatItem(
            icon: FontAwesomeIcons.thumbsUp,
            count: widget.thumbsUp,
            label: null,
            color: const Color(0xFF22C55E),
            total: total,
            onTap: widget.onVote != null ? () => widget.onVote!('thumbs_up') : null,
          ),
        ],
      ),
    );
  }

  Widget _buildNoVotesMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            FontAwesomeIcons.handPointer,
            size: 14,
            color: Colors.grey.shade500,
          ),
          const SizedBox(width: 8),
          Text(
            'Be the first to verify this!',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.grey.shade400,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated status icon with pulse effect
class _AnimatedStatusIcon extends StatefulWidget {
  final TruthMeterStatus status;
  final Color color;

  const _AnimatedStatusIcon({
    required this.status,
    required this.color,
  });

  @override
  State<_AnimatedStatusIcon> createState() => _AnimatedStatusIconState();
}

class _AnimatedStatusIconState extends State<_AnimatedStatusIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                widget.color.withOpacity(0.3),
                widget.color.withOpacity(0.1),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.3 * _pulseAnimation.value),
                blurRadius: 15 * _pulseAnimation.value,
                spreadRadius: -5,
              ),
            ],
          ),
          child: Transform.scale(
            scale: _pulseAnimation.value * 0.9,
            child: _buildIcon(),
          ),
        );
      },
    );
  }

  Widget _buildIcon() {
    return Icon(Icons.help_outline_rounded, size: 24, color: widget.color);
  }
}

/// Animated score badge that counts up
class _AnimatedScoreBadge extends StatelessWidget {
  final double score;
  final Color color;
  final Animation<double> animation;

  const _AnimatedScoreBadge({
    required this.score,
    required this.color,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final displayScore = (animation.value * 100).toInt();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color,
                Color.lerp(color, Colors.white, 0.15)!,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.5),
                blurRadius: 12,
                spreadRadius: -3,
              ),
            ],
          ),
          child: Text(
            '$displayScore%',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }
}

/// Vote stat item in breakdown - shows only percentage, no raw count
class _VoteStatItem extends StatelessWidget {
  final IconData icon;
  final int count;
  final String? label;
  final Color color;
  final int total;
  final VoidCallback? onTap;

  const _VoteStatItem({
    required this.icon,
    required this.count,
    this.label,
    required this.color,
    required this.total,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = total > 0 ? (count / total * 100).toStringAsFixed(0) : '0';

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 8,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: FaIcon(icon, size: 16, color: color),
          ),
          if (label != null) ...[
            const SizedBox(height: 8),
            Text(
              label!,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Shimmer overlay for the progress bar
class _ShimmerOverlay extends StatefulWidget {
  final double widthFactor;
  final Color color;

  const _ShimmerOverlay({
    required this.widthFactor,
    required this.color,
  });

  @override
  State<_ShimmerOverlay> createState() => _ShimmerOverlayState();
}

class _ShimmerOverlayState extends State<_ShimmerOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: FractionallySizedBox(
            widthFactor: widget.widthFactor,
            alignment: Alignment.centerLeft,
            child: ShaderMask(
              shaderCallback: (bounds) {
                return LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.transparent,
                    widget.color.withOpacity(0.3),
                    Colors.transparent,
                  ],
                  stops: [
                    (_shimmerController.value - 0.3).clamp(0.0, 1.0),
                    _shimmerController.value,
                    (_shimmerController.value + 0.3).clamp(0.0, 1.0),
                  ],
                ).createShader(bounds);
              },
              blendMode: BlendMode.srcATop,
              child: Container(
                color: Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Admin verified badge with premium styling
class AdminVerifiedBadge extends StatefulWidget {
  const AdminVerifiedBadge({super.key});

  @override
  State<AdminVerifiedBadge> createState() => _AdminVerifiedBadgeState();
}

class _AdminVerifiedBadgeState extends State<AdminVerifiedBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.3, end: 0.6).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3B82F6).withOpacity(_glowAnimation.value),
                blurRadius: 15,
                spreadRadius: -3,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified_rounded, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                'VERIFIED TRUTH',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FunnyVoteBadge extends StatelessWidget {
  final int count;

  const _FunnyVoteBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF8B5CF6).withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const FaIcon(
            FontAwesomeIcons.faceLaughSquint,
            size: 12,
            color: Color(0xFF8B5CF6),
          ),
          const SizedBox(width: 4),
          Text(
            count.toString(),
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF8B5CF6),
            ),
          ),
        ],
      ),
    );
  }
}
