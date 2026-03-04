import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/elevator_location.dart';
import '../../models/cash_price.dart';
import '../../providers/local_cash_prices_provider.dart';
import '../glass_container.dart';

/// Bottom sheet showing elevator details, latest bids, and farmer reports.
class ElevatorDetailSheet extends ConsumerWidget {
  final ElevatorLocation elevator;

  const ElevatorDetailSheet({super.key, required this.elevator});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Fetch latest cash prices for this elevator (last 14 days).
    final cashPrices = ref.watch(localCashPricesProvider(
      CashPriceParams(days: 14),
    ));

    return DraggableScrollableSheet(
      initialChildSize: 0.4,
      minChildSize: 0.25,
      maxChildSize: 0.85,
      snap: true,
      snapSizes: const [0.4, 0.85],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
            border: Border(
              top: BorderSide(
                color: elevator.companyColor.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 30,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF334155),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header: facility name + company badge
              _buildHeader(),
              const SizedBox(height: 16),

              // Location + facility info row
              _buildInfoRow(),
              const SizedBox(height: 20),

              // Grain types chips
              if (elevator.grainTypes.isNotEmpty) ...[
                _buildGrainTypeChips(),
                const SizedBox(height: 20),
              ],

              // Latest bids section
              _buildLatestBidsSection(cashPrices),
              const SizedBox(height: 20),

              // Farmer reports section (placeholder)
              _buildFarmerReportsSection(),
              const SizedBox(height: 24),

              // Report a Price button
              _buildReportPriceButton(context),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------
  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Company color indicator
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: elevator.companyColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: elevator.companyColor.withValues(alpha: 0.3),
            ),
          ),
          child: Icon(
            elevator.facilityType == 'terminal'
                ? Icons.warehouse
                : elevator.facilityType == 'process'
                    ? Icons.factory
                    : Icons.grain,
            color: elevator.companyColor,
            size: 22,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                elevator.facilityName,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: elevator.companyColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: elevator.companyColor.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      elevator.company,
                      style: GoogleFonts.inter(
                        color: elevator.companyColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      elevator.facilityType.toUpperCase(),
                      style: GoogleFonts.inter(
                        color: const Color(0xFF64748B),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ).animate().fade(duration: 300.ms);
  }

  // ---------------------------------------------------------------------------
  // Info row
  // ---------------------------------------------------------------------------
  Widget _buildInfoRow() {
    return GlassContainer(
      blur: 10,
      opacity: 0.08,
      borderRadius: BorderRadius.circular(14),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          // Location
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.location_on, color: Color(0xFF94A3B8), size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${elevator.city}, ${elevator.province}',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Capacity (if available)
          if (elevator.licensedCapacityTonnes != null) ...[
            Container(
              width: 1,
              height: 24,
              color: const Color(0xFF334155),
            ),
            const SizedBox(width: 12),
            Row(
              children: [
                const Icon(Icons.storage, color: Color(0xFF94A3B8), size: 16),
                const SizedBox(width: 6),
                Text(
                  '${elevator.licensedCapacityTonnes!.round()} T',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF94A3B8),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    ).animate().fade(duration: 300.ms, delay: 50.ms);
  }

  // ---------------------------------------------------------------------------
  // Grain type chips
  // ---------------------------------------------------------------------------
  Widget _buildGrainTypeChips() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: elevator.grainTypes.map((grain) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFF334155),
            ),
          ),
          child: Text(
            grain,
            style: GoogleFonts.inter(
              color: const Color(0xFF94A3B8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList(),
    ).animate().fade(duration: 300.ms, delay: 100.ms);
  }

  // ---------------------------------------------------------------------------
  // Latest bids section
  // ---------------------------------------------------------------------------
  Widget _buildLatestBidsSection(AsyncValue<List<CashPrice>> cashPrices) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Latest Bids',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        cashPrices.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF84CC16),
                ),
              ),
            ),
          ),
          error: (_, __) => _buildNoBidsPlaceholder('Unable to load bids'),
          data: (prices) {
            // Filter to prices matching this elevator name.
            final elevatorPrices = prices
                .where((p) =>
                    p.elevatorName.toLowerCase() ==
                    elevator.facilityName.toLowerCase())
                .toList();

            if (elevatorPrices.isEmpty) {
              return _buildNoBidsPlaceholder('No recent bids for this elevator');
            }

            return Column(
              children: elevatorPrices.take(5).map((price) {
                return _BidRow(price: price);
              }).toList(),
            );
          },
        ),
      ],
    ).animate().fade(duration: 300.ms, delay: 150.ms);
  }

  Widget _buildNoBidsPlaceholder(String message) {
    return GlassContainer(
      blur: 8,
      opacity: 0.06,
      borderRadius: BorderRadius.circular(12),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF64748B), size: 16),
          const SizedBox(width: 10),
          Text(
            message,
            style: GoogleFonts.inter(
              color: const Color(0xFF64748B),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Farmer reports section (placeholder)
  // ---------------------------------------------------------------------------
  Widget _buildFarmerReportsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Farmer Reports',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        GlassContainer(
          blur: 8,
          opacity: 0.06,
          borderRadius: BorderRadius.circular(12),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.people_outline, color: Color(0xFF64748B), size: 16),
              const SizedBox(width: 10),
              Text(
                'No reports yet',
                style: GoogleFonts.inter(
                  color: const Color(0xFF64748B),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    ).animate().fade(duration: 300.ms, delay: 200.ms);
  }

  // ---------------------------------------------------------------------------
  // Report a Price button
  // ---------------------------------------------------------------------------
  Widget _buildReportPriceButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: () {
          // Placeholder: will navigate to price reporting screen.
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Price reporting coming soon!',
                style: GoogleFonts.inter(fontWeight: FontWeight.w500),
              ),
              backgroundColor: const Color(0xFF1E293B),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        icon: const Icon(Icons.edit_note, size: 20),
        label: Text(
          'Report a Price',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF84CC16),
          foregroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
      ),
    ).animate().fade(duration: 300.ms, delay: 250.ms).slideY(begin: 0.1);
  }
}

// -----------------------------------------------------------------------------
// Bid row widget
// -----------------------------------------------------------------------------
class _BidRow extends StatelessWidget {
  final CashPrice price;
  const _BidRow({required this.price});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF334155).withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Commodity + grade
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  price.commodity,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (price.grade != null)
                  Text(
                    price.grade!,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF64748B),
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),

          // Bid price
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price.formattedBid,
                style: GoogleFonts.outfit(
                  color: const Color(0xFF84CC16),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (price.basis != null)
                Text(
                  'Basis ${price.formattedBasis}',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF64748B),
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
