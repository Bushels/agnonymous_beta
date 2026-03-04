import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/cash_price.dart';
import '../../providers/local_cash_prices_provider.dart';
import '../../widgets/cash_price_card.dart';
import '../../widgets/glass_container.dart';

/// Cash Prices tab for the Markets screen.
/// Shows local elevator cash prices from PDQ and other sources.
class CashPricesTab extends ConsumerStatefulWidget {
  const CashPricesTab({super.key});

  @override
  ConsumerState<CashPricesTab> createState() => _CashPricesTabState();
}

class _CashPricesTabState extends ConsumerState<CashPricesTab> {
  String? _selectedCommodity;
  String? _selectedProvince;

  @override
  Widget build(BuildContext context) {
    final params = CashPriceParams(
      commodity: _selectedCommodity,
      province: _selectedProvince,
      days: 30,
    );

    final pricesAsync = ref.watch(localCashPricesProvider(params));
    final commoditiesAsync = ref.watch(cashPriceCommoditiesProvider);
    final provincesAsync = ref.watch(cashPriceProvincesProvider);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filters row
          _buildFilters(commoditiesAsync, provincesAsync),
          const SizedBox(height: 20),

          // Section header
          Text(
            'CASH BIDS',
            style: GoogleFonts.inter(
              color: Colors.grey.shade400,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),

          // Price list
          pricesAsync.when(
            data: (prices) {
              if (prices.isEmpty) {
                return _buildEmptyState();
              }
              return _buildPriceList(prices);
            },
            loading: () => _buildLoadingShimmer(),
            error: (error, _) => _buildErrorState(),
          ),

          const SizedBox(height: 100), // Bottom nav padding
        ],
      ),
    ).animate().fade(duration: 300.ms);
  }

  Widget _buildFilters(
    AsyncValue<List<String>> commoditiesAsync,
    AsyncValue<List<String>> provincesAsync,
  ) {
    return Row(
      children: [
        // Commodity dropdown
        Expanded(
          child: _buildDropdown(
            value: _selectedCommodity,
            hint: 'All Commodities',
            items: commoditiesAsync.whenOrNull(data: (data) => data) ?? [],
            onChanged: (value) => setState(() => _selectedCommodity = value),
          ),
        ),
        const SizedBox(width: 12),
        // Province dropdown
        Expanded(
          child: _buildDropdown(
            value: _selectedProvince,
            hint: 'All Provinces',
            items: provincesAsync.whenOrNull(data: (data) => data) ?? [],
            onChanged: (value) => setState(() => _selectedProvince = value),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF334155),
          width: 0.5,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: value,
          isExpanded: true,
          dropdownColor: const Color(0xFF1E293B),
          hint: Text(
            hint,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
            ),
          ),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF64748B),
            size: 20,
          ),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(
                hint,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 13,
                ),
              ),
            ),
            ...items.map(
              (item) => DropdownMenuItem<String?>(
                value: item,
                child: Text(
                  item,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildPriceList(List<CashPrice> prices) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: prices.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        return CashPriceCard(price: prices[index]);
      },
    );
  }

  Widget _buildLoadingShimmer() {
    return Column(
      children: List.generate(
        5,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GlassContainer(
            blur: 10,
            opacity: 0.06,
            borderRadius: BorderRadius.circular(14),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  width: 180,
                  decoration: BoxDecoration(
                    color: const Color(0xFF334155).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 12,
                  width: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFF334155).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      height: 20,
                      width: 100,
                      decoration: BoxDecoration(
                        color: const Color(0xFF334155).withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Container(
                      height: 20,
                      width: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFF334155).withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ).animate(interval: 100.ms).fade(duration: 400.ms),
    );
  }

  Widget _buildEmptyState() {
    return GlassContainer(
      blur: 10,
      opacity: 0.06,
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.storefront_rounded,
            size: 48,
            color: const Color(0xFF334155),
          ),
          const SizedBox(height: 12),
          Text(
            'No cash prices available yet',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'PDQ data updates daily at 6pm MST',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return GlassContainer(
      blur: 10,
      opacity: 0.06,
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: Color(0xFFEF4444),
          ),
          const SizedBox(height: 12),
          Text(
            'Unable to load cash prices',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Check your connection and try again.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
