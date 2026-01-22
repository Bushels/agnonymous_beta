import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/fertilizer_ticker_models.dart';
import '../../providers/fertilizer_ticker_provider.dart';

class FertilizerDetailScreen extends ConsumerStatefulWidget {
  const FertilizerDetailScreen({super.key});

  @override
  ConsumerState<FertilizerDetailScreen> createState() => _FertilizerDetailScreenState();
}

class _FertilizerDetailScreenState extends ConsumerState<FertilizerDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedTimeFilter = 'Weekly'; // Daily, Weekly, Monthly

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch ALL raw entries
    final entriesAsync = ref.watch(fertilizerTickerEntriesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      appBar: AppBar(
        title: Text(
          'Fertilizer Market',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF111827), // Seamless header
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF84CC16),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF84CC16),
          indicatorWeight: 3,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Urea 46'),
            Tab(text: 'NH3'),
            Tab(text: 'S15'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Time filter bar is ALWAYS visible, regardless of data state
          _buildTimeFilterBar(),

          // Content area responds to data state
          Expanded(
            child: entriesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF84CC16))),
              error: (err, stack) => Center(child: Text('Error loading market data', style: TextStyle(color: Colors.red.shade400))),
              data: (allEntries) {
                // Filter entries by selected time frame
                final now = DateTime.now();
                final cutoff = switch (_selectedTimeFilter) {
                  'Daily' => now.subtract(const Duration(hours: 24)),
                  'Weekly' => now.subtract(const Duration(days: 7)),
                  'Monthly' => now.subtract(const Duration(days: 30)),
                  _ => now.subtract(const Duration(days: 30)),
                };

                final filteredEntries = allEntries.where((e) => e.createdAt.isAfter(cutoff)).toList();

                if (filteredEntries.isEmpty) {
                  return _buildEmptyState();
                }

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildCommodityView(FertilizerType.urea46, filteredEntries),
                    _buildCommodityView(FertilizerType.nh3, filteredEntries),
                    _buildCommodityView(FertilizerType.s15, filteredEntries),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
     return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined, size: 64, color: Colors.grey.shade800),
            const SizedBox(height: 16),
            Text(
              'No market data for this period',
              style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 16),
            ),
             const SizedBox(height: 8),
            Text(
              'Be the first to submit a price!',
              style: GoogleFonts.inter(color: const Color(0xFF84CC16), fontSize: 14),
            ),
          ],
        ),
      );
  }

  Widget _buildTimeFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      color: const Color(0xFF111827),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: ['Daily', 'Weekly', 'Monthly'].map((filter) {
          final isSelected = _selectedTimeFilter == filter;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedTimeFilter = filter;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF84CC16).withOpacity(0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isSelected ? const Color(0xFF84CC16) : Colors.grey.shade800,
                  width: 1.5,
                ),
                boxShadow: isSelected ? [
                  BoxShadow(color: const Color(0xFF84CC16).withOpacity(0.2), blurRadius: 8, spreadRadius: 1)
                ] : [],
              ),
              child: Text(
                filter,
                style: GoogleFonts.inter(
                  color: isSelected ? const Color(0xFF84CC16) : Colors.grey.shade500,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCommodityView(FertilizerType type, List<FertilizerTickerEntry> entries) {
    // 1. Filter by Commodity Type
    final typeEntries = entries.where((e) => e.fertilizerType == type).toList();

    if (typeEntries.isEmpty) {
      return Center(
        child: Text(
          'No data for ${type.displayName}',
          style: GoogleFonts.inter(color: Colors.grey),
        ),
      );
    }

    // 2. Group by Province
    final Map<String, List<FertilizerTickerEntry>> byProvince = {};
    for (var e in typeEntries) {
      if (!byProvince.containsKey(e.provinceState)) {
        byProvince[e.provinceState] = [];
      }
      byProvince[e.provinceState]!.add(e);
    }

    // 3. Create Summaries
    final summaries = byProvince.entries.map((entry) {
      final province = entry.key;
      final provinceEntries = entry.value;

      final pickedUp = provinceEntries.where((e) => e.deliveryMode == DeliveryMode.pickedUp).toList();
      final delivered = provinceEntries.where((e) => e.deliveryMode == DeliveryMode.delivered).toList();

      double? avgPU;
      if (pickedUp.isNotEmpty) {
        avgPU = pickedUp.map((e) => e.price).reduce((a, b) => a + b) / pickedUp.length;
      }

      double? avgDF;
      if (delivered.isNotEmpty) {
        avgDF = delivered.map((e) => e.price).reduce((a, b) => a + b) / delivered.length;
      }

      double min = provinceEntries.first.price;
      double max = provinceEntries.first.price;
      DateTime newest = provinceEntries.first.createdAt;

      for (var e in provinceEntries) {
        if (e.price < min) min = e.price;
        if (e.price > max) max = e.price;
        if (e.createdAt.isAfter(newest)) newest = e.createdAt;
      }

      return RegionMarketSummary(
        provinceState: province,
        type: type,
        avgPricePickedUp: avgPU,
        avgPriceDelivered: avgDF,
        countPickedUp: pickedUp.length,
        countDelivered: delivered.length,
        minPrice: min,
        maxPrice: max,
        lastUpdated: newest,
      );
    }).toList();

    // Sort: Most recent updates first
    summaries.sort((a, b) => (b.lastUpdated ?? DateTime(0)).compareTo(a.lastUpdated ?? DateTime(0)));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: summaries.length + 1, // +1 for header
      itemBuilder: (context, index) {
        if (index == 0) return _buildMarketSummaryHeader(summaries);
        return _buildRegionSummaryCard(summaries[index - 1]);
      },
    );
  }

  Widget _buildMarketSummaryHeader(List<RegionMarketSummary> summaries) {
    int totalSubs = 0;
    for(var s in summaries) totalSubs += s.totalCount;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF1F2937), const Color(0xFF111827)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MARKET OVERVIEW',
                style: GoogleFonts.inter(
                  color: const Color(0xFF84CC16),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$_selectedTimeFilter Trends',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF84CC16).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF84CC16).withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Text(
                  '$totalSubs',
                  style: GoogleFonts.robotoMono(
                    color: const Color(0xFF84CC16),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Submissions',
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 10),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildRegionSummaryCard(RegionMarketSummary summary) {
    // Determine currency/unit based on province (Assumption: Generic logic or from model)
    // For now, assuming standard based on province check or using raw values. 
    // Ideally we should check the unit/currency of entries but assuming homogeneity per region for now.
    final isCanada = true; // Simplified: Add `isCanadianProvince` logic back if needed or rely on stored data
    final currencySymbol = '\$'; // Could be improved

    String timeAgo = 'Just now';
    if (summary.lastUpdated != null) {
        final diff = DateTime.now().difference(summary.lastUpdated!);
        if (diff.inMinutes < 60) timeAgo = '${diff.inMinutes}m ago';
        else if (diff.inHours < 24) timeAgo = '${diff.inHours}h ago';
        else timeAgo = '${diff.inDays}d ago';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey.shade400),
                    const SizedBox(width: 8),
                    Text(
                      summary.provinceState,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Updated $timeAgo',
                  style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 11),
                ),
              ],
            ),
          ),

          // Pricing Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Picked Up Segment
                Expanded(
                  child: _buildPriceSegment(
                    'Picked Up',
                    summary.avgPricePickedUp,
                    summary.countPickedUp,
                    Colors.blue.shade400,
                    Icons.store_mall_directory_outlined,
                  ),
                ),
                Container(width: 1, height: 50, color: Colors.white.withOpacity(0.1)),
                // Delivered Segment
                Expanded(
                  child: _buildPriceSegment(
                    'Delivered',
                    summary.avgPriceDelivered,
                    summary.countDelivered,
                    const Color(0xFF84CC16),
                    Icons.local_shipping_outlined,
                  ),
                ),
              ],
            ),
          ),

          // Footer Metrics (Range + Spread)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
            ),
            child: Row(
              children: [
                // Min/Max Range
                Icon(Icons.linear_scale, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 6),
                Text(
                  'Range: \$${summary.minPrice?.round() ?? 0} - \$${summary.maxPrice?.round() ?? 0}',
                   style: GoogleFonts.robotoMono(color: Colors.grey.shade400, fontSize: 11),
                ),
                const Spacer(),
                // Spread
                if (summary.spread != null)
                Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                        'PU/DF Spread: \$${summary.spread?.round()}',
                        style: GoogleFonts.inter(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.normal),
                    ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceSegment(String label, double? price, int count, Color color, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: Colors.grey.shade500),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                color: Colors.grey.shade500,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (price != null)
          Column(
            children: [
              Text(
                '\$${price.round()}',
                style: GoogleFonts.robotoMono(
                  color: color,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '$count quotes',
                style: GoogleFonts.inter(color: Colors.grey.shade600, fontSize: 10),
              ),
            ],
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No Data',
              style: GoogleFonts.inter(color: Colors.grey.shade700, fontSize: 14, fontStyle: FontStyle.italic),
            ),
          ),
      ],
    );
  }
}
