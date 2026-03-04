import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../widgets/ticker/fertilizer_ticker.dart';
import '../dashboard/grain_dashboard_screen.dart';
import 'fertilizer_detail_screen.dart';
import '../../widgets/market/category_card.dart';
import 'crop_stats_tab.dart';
import 'cash_prices_tab.dart';
import '../map/elevator_map_screen.dart';

/// Unified Markets screen with tab navigation.
/// Combines Grains, Fertilizer, Cash Prices, and Crop Stats into one tabbed interface.
class MarketsScreen extends ConsumerStatefulWidget {
  const MarketsScreen({super.key});

  @override
  ConsumerState<MarketsScreen> createState() => _MarketsScreenState();
}

class _MarketsScreenState extends ConsumerState<MarketsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            backgroundColor: const Color(0xFF0F172A),
            elevation: 0,
            floating: true,
            pinned: true,
            expandedHeight: 100,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 50),
              title: Text(
                'Markets',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF052e16).withValues(alpha: 0.6),
                      const Color(0xFF0F172A),
                    ],
                  ),
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFF1E293B), width: 1),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: const Color(0xFF84CC16),
                  indicatorWeight: 2.5,
                  labelColor: const Color(0xFF84CC16),
                  unselectedLabelColor: const Color(0xFF64748B),
                  labelStyle: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: const [
                    Tab(text: 'Grains'),
                    Tab(text: 'Fertilizer'),
                    Tab(text: 'Cash Prices'),
                    Tab(text: 'Crop Stats'),
                    Tab(text: 'Map'),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            // Grains tab - reuse existing dashboard
            const GrainDashboardScreen(),

            // Fertilizer tab
            _buildFertilizerTab(),

            // Cash Prices tab - PDQ local elevator prices
            const CashPricesTab(),

            // Crop Stats tab - Statistics Canada + USDA data
            const CropStatsTab(),

            // Map tab - Interactive elevator map
            const ElevatorMapScreen(),
          ],
        ),
      ),
    );
  }

  Widget _buildFertilizerTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Compact ticker at top
          const FertilizerTicker(),
          const SizedBox(height: 24),

          Text(
            'Commodities',
            style: GoogleFonts.inter(
              color: Colors.grey.shade400,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.85,
            children: [
              CategoryCard(
                title: 'Fertilizer',
                icon: '\u{1F33E}', // wheat emoji
                subtitle: 'Urea, NH3, S15 & more',
                color: const Color(0xFF84CC16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FertilizerDetailScreen(),
                    ),
                  );
                },
              ),
              CategoryCard(
                title: 'Chemicals',
                icon: '\u{1F9EA}', // test tube
                subtitle: 'Glyphosate, Liberty, etc.',
                color: const Color(0xFF60A5FA),
                onTap: () {},
                isLocked: true,
              ),
              CategoryCard(
                title: 'Fuel',
                icon: '\u{26FD}', // fuel
                subtitle: 'Diesel, Gas, Propane',
                color: const Color(0xFFF59E0B),
                onTap: () {},
                isLocked: true,
              ),
              CategoryCard(
                title: 'Equipment',
                icon: '\u{1F69C}', // tractor
                subtitle: 'Tractors, Combines, etc.',
                color: const Color(0xFFEF4444),
                onTap: () {},
                isLocked: true,
              ),
            ],
          ),
        ],
      ),
    ).animate().fade(duration: 300.ms);
  }

}
