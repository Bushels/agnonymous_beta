import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/cash_price.dart';
import 'glass_container.dart';

/// A glassmorphism card displaying a single cash price entry.
/// Shows elevator name, company, commodity, grade, bid price,
/// basis, and price date. Basis uses green for positive, red for negative.
class CashPriceCard extends StatelessWidget {
  final CashPrice price;
  final VoidCallback? onTap;

  const CashPriceCard({
    super.key,
    required this.price,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final basisColor = _basisColor();
    final dateStr = DateFormat('MMM d').format(price.priceDate);

    return GlassContainer(
      blur: 10,
      opacity: 0.08,
      borderRadius: BorderRadius.circular(14),
      padding: const EdgeInsets.all(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: elevator name + province badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    price.elevatorName,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF84CC16).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    price.locationProvince,
                    style: const TextStyle(
                      color: Color(0xFF84CC16),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),

            // Company line (if present)
            if (price.company != null) ...[
              const SizedBox(height: 2),
              Text(
                price.company!,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 11,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const SizedBox(height: 10),

            // Commodity + grade row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF334155),
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    price.commodity,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (price.grade != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    price.grade!,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  dateStr,
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 11,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Price + basis row
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Bid price (large)
                Text(
                  price.formattedBid,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                // Basis (if present)
                if (price.basis != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: basisColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Basis ',
                          style: TextStyle(
                            color: basisColor.withValues(alpha: 0.7),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          price.formattedBasis,
                          style: TextStyle(
                            color: basisColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Returns a color based on basis direction:
  /// green for positive/zero, red for negative, grey if null.
  Color _basisColor() {
    if (price.basis == null) return const Color(0xFF64748B);
    if (price.basis! < 0) return const Color(0xFFEF4444);
    return const Color(0xFF22C55E);
  }
}
