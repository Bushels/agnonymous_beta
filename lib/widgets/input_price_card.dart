import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/pricing_models.dart';
import '../providers/pricing_provider.dart';
import 'glass_container.dart';

/// Card widget for displaying a price entry in the feed
class InputPriceCard extends ConsumerStatefulWidget {
  final PriceEntry priceEntry;
  final VoidCallback? onTap;
  final VoidCallback? onVoteUp;
  final VoidCallback? onVoteDown;

  const InputPriceCard({
    super.key,
    required this.priceEntry,
    this.onTap,
    this.onVoteUp,
    this.onVoteDown,
  });

  @override
  ConsumerState<InputPriceCard> createState() => _InputPriceCardState();
}

class _InputPriceCardState extends ConsumerState<InputPriceCard> {
  PriceStats? _stats;
  bool _loadingStats = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    if (widget.priceEntry.product == null) return;

    setState(() => _loadingStats = true);

    final stats = await ref.read(priceEntriesProvider.notifier).getPriceStats(
      widget.priceEntry.productId,
      provinceState: widget.priceEntry.retailer?.provinceState,
      daysBack: 90,
    );

    if (mounted) {
      setState(() {
        _stats = stats;
        _loadingStats = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.priceEntry;
    final product = entry.product;
    final retailer = entry.retailer;

    return GestureDetector(
      onTap: widget.onTap,
      child: GlassContainer(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with price badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const FaIcon(
                        FontAwesomeIcons.dollarSign,
                        size: 12,
                        color: Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'INPUT PRICE',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFF59E0B),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (product != null)
                  _buildProductTypeBadge(product.productType),
              ],
            ),
            const SizedBox(height: 12),

            // Product name
            Text(
              product?.displayName ?? 'Unknown Product',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (product?.subCategory != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  product!.subCategory!,
                  style: GoogleFonts.inter(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Price display
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF84CC16).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF84CC16).withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    entry.formattedPrice,
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF84CC16),
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Retailer info
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: 16,
                  color: Colors.grey[500],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        retailer?.name ?? 'Unknown Retailer',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (retailer != null)
                        Text(
                          '${retailer.city}, ${retailer.provinceState}',
                          style: GoogleFonts.inter(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Date
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: Colors.grey[500],
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDate(entry.priceDate),
                  style: GoogleFonts.inter(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ],
            ),

            // Regional comparison (if stats available)
            if (_stats != null && _stats!.entryCount > 1) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Regional Comparison (${retailer?.provinceState ?? 'All'})',
                      style: GoogleFonts.inter(
                        color: Colors.grey[400],
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(
                          'Avg',
                          formatPrice(_stats!.avgPrice ?? 0, entry.currency),
                        ),
                        _buildStatItem(
                          'Min',
                          formatPrice(_stats!.minPrice ?? 0, entry.currency),
                        ),
                        _buildStatItem(
                          'Max',
                          formatPrice(_stats!.maxPrice ?? 0, entry.currency),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Based on ${_stats!.entryCount} entries',
                      style: GoogleFonts.inter(
                        color: Colors.grey[600],
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ] else if (_loadingStats) ...[
              const SizedBox(height: 16),
              Center(
                child: SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],

            // Actions row
            const SizedBox(height: 16),
            Row(
              children: [
                // Vote up
                _buildActionButton(
                  icon: Icons.thumb_up_outlined,
                  label: entry.thumbsUpCount.toString(),
                  onTap: widget.onVoteUp,
                  isActive: false,
                  activeColor: const Color(0xFF84CC16),
                ),
                const SizedBox(width: 16),
                // Vote down
                _buildActionButton(
                  icon: Icons.thumb_down_outlined,
                  label: entry.thumbsDownCount.toString(),
                  onTap: widget.onVoteDown,
                  isActive: false,
                  activeColor: Colors.red,
                ),
                const Spacer(),
                  // View post
                TextButton.icon(
                  onPressed: widget.onTap,
                  icon: Icon(
                    Icons.chat_bubble_outline,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                  label: Text(
                    'View Post',
                    style: GoogleFonts.inter(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductTypeBadge(ProductType type) {
    final colors = {
      ProductType.fertilizer: Colors.green,
      ProductType.seed: Colors.amber,
      ProductType.chemical: Colors.purple,
      ProductType.equipment: Colors.blue,
    };
    final color = colors[type] ?? Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        type.displayName,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.grey[600],
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    required bool isActive,
    required Color activeColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? activeColor : Colors.grey[500],
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                color: isActive ? activeColor : Colors.grey[500],
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

/// Compact price card for lists
class InputPriceCardCompact extends StatelessWidget {
  final PriceEntry priceEntry;
  final VoidCallback? onTap;

  const InputPriceCardCompact({
    super.key,
    required this.priceEntry,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final entry = priceEntry;
    final product = entry.product;
    final retailer = entry.retailer;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            // Product info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product?.productName ?? 'Unknown',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${retailer?.name ?? 'Unknown'} \u2022 ${_formatDate(entry.priceDate)}',
                    style: GoogleFonts.inter(
                      color: Colors.grey[500],
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            // Price
            Text(
              entry.formattedPrice,
              style: GoogleFonts.outfit(
                color: const Color(0xFF84CC16),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}
