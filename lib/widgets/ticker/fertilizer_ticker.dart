/// Fertilizer Ticker Widget
/// Dual-row engaging ticker displaying averages and recent updates
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/fertilizer_ticker_models.dart';
import '../../providers/fertilizer_ticker_provider.dart';
import 'marquee_widget.dart';

class FertilizerTicker extends ConsumerWidget {
  const FertilizerTicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch ALL entries - we'll derive both averages and recent from this
    final entriesAsync = ref.watch(fertilizerTickerEntriesProvider);
    // Derived 'recent' list is just the raw entries, sorted by time (already sorted by provider)
    
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1F2937),
            const Color(0xFF111827),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Row - Regional Averages
          _buildAveragesRow(entriesAsync),
          
          // Divider with gradient
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  const Color(0xFF84CC16).withOpacity(0.3),
                  const Color(0xFF84CC16).withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          
          // Bottom Row - Recent Updates
          _buildRecentRow(entriesAsync),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildAveragesRow(AsyncValue<List<FertilizerTickerEntry>> entriesAsync) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '🌾',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(width: 6),
                Text(
                  'AVG',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF84CC16),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          
          // Marquee content
          Expanded(
            child: entriesAsync.when(
              loading: () => _buildLoadingIndicator(),
              error: (_, __) => _buildErrorIndicator(),
              data: (entries) {
                if (entries.isEmpty) return _buildEmptyIndicator();
                
                // convert entries to averages first for helper compatibility
                // simplified: just map raw entries to averages then group
                // actually better: just group raw entries directly
                
                final Map<String, List<FertilizerTickerEntry>> rawGroups = {};
                for (var e in entries) {
                   // grouping by province + type + delivery mode first to get base avgs
                   final key = '${e.provinceState}_${e.fertilizerType.name}_${e.deliveryMode.name}';
                   if (!rawGroups.containsKey(key)) rawGroups[key] = [];
                   rawGroups[key]!.add(e);
                }

                List<FertilizerTickerAverage> baseAverages = rawGroups.entries.map((entry) {
                  final groupEntries = entry.value;
                  final first = groupEntries.first;
                  final avgPrice = groupEntries.map((e) => e.price).reduce((a, b) => a + b) / groupEntries.length;
                  return FertilizerTickerAverage(
                    provinceState: first.provinceState,
                    fertilizerType: first.fertilizerType,
                    deliveryMode: first.deliveryMode,
                    avgPrice: avgPrice,
                    unit: first.unit, // Added
                    currency: first.currency, // Added
                    entryCount: groupEntries.length,
                    lastUpdated: first.createdAt,
                  );
                }).toList();

                final groupedItems = _groupAverages(baseAverages);
                
                return MarqueeWidget(
                  // Slower animation speed for averages (8s per item)
                  animationDuration: Duration(seconds: groupedItems.length * 8),
                  child: Row(
                    children: groupedItems.map((item) => _buildGroupedAverageItem(item)).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentRow(AsyncValue<List<FertilizerTickerEntry>> recentAsync) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: const Color(0xFF84CC16),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF84CC16).withOpacity(0.5),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ).animate(onPlay: (c) => c.repeat())
                  .fadeIn(duration: 500.ms)
                  .then()
                  .fadeOut(duration: 500.ms),
                const SizedBox(width: 6),
                Text(
                  'LIVE',
                  style: GoogleFonts.inter(
                    color: Colors.grey.shade500,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          
          // Marquee content
          Expanded(
            child: recentAsync.when(
              loading: () => _buildLoadingIndicator(),
              error: (_, __) => _buildErrorIndicator(),
              data: (entries) {
                if (entries.isEmpty) return _buildEmptyIndicator();
                return MarqueeWidget(
                  // Slightly faster than top ticker (6s per item vs 8s for top)
                  animationDuration: Duration(seconds: entries.length * 6),
                  child: Row(
                    children: entries.map((entry) => _buildRecentItem(entry)).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Group averages by Province+Type
  List<_GroupedAverage> _groupAverages(List<FertilizerTickerAverage> averages) {
    final Map<String, _GroupedAverage> groups = {};
    
    for (var avg in averages) {
      final key = '${avg.provinceState}_${avg.fertilizerType.code}';
      if (!groups.containsKey(key)) {
        groups[key] = _GroupedAverage(
          provinceAbbreviation: avg.provinceAbbreviation,
          fertilizerCode: avg.fertilizerType.code,
        );
      }
      
      if (avg.deliveryMode == DeliveryMode.pickedUp) {
        groups[key]!.puPrice = avg.formattedPrice;
      } else {
        groups[key]!.dfPrice = avg.formattedPrice;
      }
    }
    
    return groups.values.toList();
  }

  Widget _buildGroupedAverageItem(_GroupedAverage item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Province
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Text(
              item.provinceAbbreviation,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Type
          Text(
            item.fertilizerCode,
            style: GoogleFonts.inter(
              color: Colors.grey.shade300,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 6),
          // PU Price
          if (item.puPrice != null) ...[
            Text(
              '${item.puPrice} (PU)',
              style: GoogleFonts.robotoMono(
                color: const Color(0xFF84CC16),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          
          // Spacer/DF Price
          if (item.dfPrice != null) ...[
            if (item.puPrice != null) const SizedBox(width: 8),
            Text(
              '[${item.dfPrice} DF]',
              style: GoogleFonts.robotoMono(
                color: const Color(0xFF60A5FA), // Different color for DF
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          
          // Separator dot
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Container(
              width: 3,
              height: 3,
              decoration: BoxDecoration(
                color: Colors.grey.shade700,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentItem(FertilizerTickerEntry entry) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Time
          Text(
            entry.relativeTime,
            style: GoogleFonts.inter(
              color: Colors.grey.shade600,
              fontSize: 10,
            ),
          ),
          const SizedBox(width: 6),
          // Loc/Type
          Text(
            '${entry.provinceAbbreviation} - ${entry.fertilizerType.code}',
            style: GoogleFonts.inter(
              color: Colors.grey.shade400,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 6),
          // Price + Delivery Mode
          Text(
            '${entry.formattedPrice} (${entry.deliveryMode.abbreviation})',
            style: GoogleFonts.robotoMono(
              color: const Color(0xFFA3E635),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text('|', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: SizedBox(
        width: 16, height: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey.shade600),
      ),
    );
  }

  Widget _buildErrorIndicator() {
    return Center(child: Text('Unable to load prices', style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 11)));
  }

  Widget _buildEmptyIndicator() {
    return Center(child: Text('Be the first to post a price! 🚀', style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 11)));
  }
}

class _GroupedAverage {
  final String provinceAbbreviation;
  final String fertilizerCode;
  String? puPrice;
  String? dfPrice;

  _GroupedAverage({required this.provinceAbbreviation, required this.fertilizerCode});
}

class FertilizerTickerCompact extends ConsumerWidget {
  const FertilizerTickerCompact({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // SWITCHED TO ENTRIES PROVIDER
    final entriesAsync = ref.watch(fertilizerTickerEntriesProvider);

    return Container(
      height: 32,
      color: const Color(0xFF1F2937),
      child: entriesAsync.when(
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
        data: (entries) {
           if (entries.isEmpty) return const SizedBox.shrink();

           // Quick aggregation for compact view
           // Distinct latest entry per Province+Type+Mode
           final Map<String, FertilizerTickerEntry> latestMap = {};
           for (var e in entries) {
              final key = '${e.provinceState}_${e.fertilizerType.code}_${e.deliveryMode.abbreviation}';
              if (!latestMap.containsKey(key)) {
                latestMap[key] = e; // entries are sorted by time desc, so first is latest
              }
           }
           final latest = latestMap.values.toList();

           return MarqueeWidget(
            animationDuration: Duration(seconds: latest.length * 4),
            child: Row(
              children: latest.map((e) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${e.provinceAbbreviation}: ${e.fertilizerType.code}',
                      style: GoogleFonts.inter(color: Colors.white70, fontSize: 11),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${e.formattedPrice} (${e.deliveryMode.abbreviation})',
                      style: GoogleFonts.robotoMono(color: const Color(0xFF84CC16), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              )).toList(),
            ),
          );
        },
      ),
    ).animate().fadeIn();
  }
}
