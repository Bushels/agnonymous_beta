import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Skeleton placeholder card shown while posts are loading
class PostSkeletonCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header skeleton
          Row(
            children: [
              SkeletonBox(width: 40, height: 40, borderRadius: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 120, height: 14),
                    const SizedBox(height: 6),
                    SkeletonBox(width: 80, height: 10),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Content skeleton
          SkeletonBox(width: double.infinity, height: 14),
          const SizedBox(height: 8),
          SkeletonBox(width: double.infinity, height: 14),
          const SizedBox(height: 8),
          SkeletonBox(width: 200, height: 14),
          const SizedBox(height: 16),
          // Footer skeleton
          Row(
            children: [
              SkeletonBox(width: 60, height: 24, borderRadius: 12),
              const SizedBox(width: 16),
              SkeletonBox(width: 60, height: 24, borderRadius: 12),
              const Spacer(),
              SkeletonBox(width: 40, height: 24, borderRadius: 12),
            ],
          ),
        ],
      ),
    ).animate(onPlay: (c) => c.repeat())
      .shimmer(duration: 1500.ms, color: Colors.white.withOpacity(0.05));
  }
}

class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 4,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}
