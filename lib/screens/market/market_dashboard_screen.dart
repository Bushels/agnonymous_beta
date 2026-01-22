import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/ticker/fertilizer_ticker.dart';
import '../../widgets/market/category_card.dart';
import 'fertilizer_detail_screen.dart';

class MarketDashboardScreen extends ConsumerWidget {
  const MarketDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      appBar: AppBar(
        title: Text(
          'Market Dashboard',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1F2937),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Global Ticker Headline
          const FertilizerTicker(),
          
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
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
                
                // Grid of Categories
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.85,
                  children: [
                    // Fertilizer
                    CategoryCard(
                      title: 'Fertilizer',
                      icon: '🌾',
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
                    
                    // Chemicals (Coming Soon)
                    CategoryCard(
                      title: 'Chemicals',
                      icon: '🧪',
                      subtitle: 'Glyphosate, Liberty, etc.',
                      color: const Color(0xFF60A5FA),
                      onTap: () {},
                      isLocked: true,
                    ),
                    
                    // Fuel (Coming Soon)
                    CategoryCard(
                      title: 'Fuel',
                      icon: '⛽',
                      subtitle: 'Diesel, Gas, Propane',
                      color: const Color(0xFFF59E0B),
                      onTap: () {},
                      isLocked: true,
                    ),
                    
                    // Equipment (Coming Soon)
                    CategoryCard(
                      title: 'Equipment',
                      icon: '🚜',
                      subtitle: 'Tractors, Combines, etc.',
                      color: const Color(0xFFEF4444),
                      onTap: () {},
                      isLocked: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
