import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../models/pricing_models.dart';
import '../../providers/pricing_provider.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/input_price_card.dart';

class PriceHistoryScreen extends ConsumerStatefulWidget {
  final String productId;
  final String? initialProvinceState;

  const PriceHistoryScreen({
    super.key,
    required this.productId,
    this.initialProvinceState,
  });

  @override
  ConsumerState<PriceHistoryScreen> createState() => _PriceHistoryScreenState();
}

class _PriceHistoryScreenState extends ConsumerState<PriceHistoryScreen> {
  String? _selectedProvinceState;
  Product? _product;

  @override
  void initState() {
    super.initState();
    _selectedProvinceState = widget.initialProvinceState;
    _loadData();
  }

  Future<void> _loadData() async {
    await ref.read(priceEntriesProvider.notifier).loadPriceEntriesForProduct(
      widget.productId,
      provinceState: _selectedProvinceState,
    );

    // Get product info from first entry if available
    final state = ref.read(priceEntriesProvider);
    if (state.entries.isNotEmpty && state.entries.first.product != null) {
      setState(() {
        _product = state.entries.first.product;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final priceState = ref.watch(priceEntriesProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Price History',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: _showAlertDialog,
            tooltip: 'Set Price Alert',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF111827), Color(0xFF1F2937)],
              ),
            ),
          ),

          SafeArea(
            child: priceState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : priceState.error != null
                    ? _buildErrorView(priceState.error!)
                    : _buildContent(priceState),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Navigate to add price screen
          Navigator.pop(context);
        },
        backgroundColor: const Color(0xFF84CC16),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'Add Price',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            error,
            style: GoogleFonts.inter(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(PriceEntriesState state) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product header
            if (_product != null) _buildProductHeader(_product!),
            const SizedBox(height: 16),

            // Stats card
            if (state.stats != null) _buildStatsCard(state.stats!),
            const SizedBox(height: 16),

            // Price chart
            if (state.entries.isNotEmpty) _buildPriceChart(state.entries),
            const SizedBox(height: 16),

            // Region filter
            _buildRegionFilter(),
            const SizedBox(height: 16),

            // Recent prices list
            Text(
              'Recent Prices',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            if (state.entries.isEmpty)
              _buildEmptyState()
            else
              ...state.entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InputPriceCardCompact(
                  priceEntry: entry,
                  onTap: () => _showPriceDetails(entry),
                ),
              )),

            const SizedBox(height: 80), // FAB space
          ],
        ),
      ),
    );
  }

  Widget _buildProductHeader(Product product) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getColorForType(product.productType).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getIconForType(product.productType),
              color: _getColorForType(product.productType),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.displayName,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getColorForType(product.productType).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        product.productType.displayName,
                        style: GoogleFonts.inter(
                          color: _getColorForType(product.productType),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (product.subCategory != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        product.subCategory!,
                        style: GoogleFonts.inter(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(PriceStats stats) {
    final currency = _selectedProvinceState != null
        ? detectCurrency(_selectedProvinceState!)
        : 'CAD';

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _selectedProvinceState ?? 'All Regions',
            style: GoogleFonts.inter(
              color: Colors.grey[400],
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Average',
                  stats.avgPrice != null
                      ? formatPrice(stats.avgPrice!, currency)
                      : '--',
                  Colors.blue,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Low',
                  stats.minPrice != null
                      ? formatPrice(stats.minPrice!, currency)
                      : '--',
                  const Color(0xFF84CC16),
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'High',
                  stats.maxPrice != null
                      ? formatPrice(stats.maxPrice!, currency)
                      : '--',
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Based on ${stats.entryCount} price entries (last 90 days)',
            style: GoogleFonts.inter(
              color: Colors.grey[600],
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.grey[500],
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.outfit(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildPriceChart(List<PriceEntry> entries) {
    // Simple price chart visualization
    if (entries.length < 2) {
      return const SizedBox.shrink();
    }

    // Get last 30 days of entries
    final sortedEntries = List<PriceEntry>.from(entries)
      ..sort((a, b) => a.priceDate.compareTo(b.priceDate));

    final prices = sortedEntries.map((e) => e.price).toList();
    final minPrice = prices.reduce((a, b) => a < b ? a : b);
    final maxPrice = prices.reduce((a, b) => a > b ? a : b);
    final range = maxPrice - minPrice;

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Price Trend',
                style: GoogleFonts.inter(
                  color: Colors.grey[400],
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Last ${sortedEntries.length} entries',
                style: GoogleFonts.inter(
                  color: Colors.grey[600],
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: CustomPaint(
              size: Size.infinite,
              painter: _PriceChartPainter(
                prices: prices,
                minPrice: minPrice,
                maxPrice: maxPrice,
                range: range,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDateShort(sortedEntries.first.priceDate),
                style: GoogleFonts.inter(
                  color: Colors.grey[600],
                  fontSize: 10,
                ),
              ),
              Text(
                _formatDateShort(sortedEntries.last.priceDate),
                style: GoogleFonts.inter(
                  color: Colors.grey[600],
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRegionFilter() {
    return Row(
      children: [
        Text(
          'Region:',
          style: GoogleFonts.inter(
            color: Colors.grey[400],
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _selectedProvinceState,
                hint: Text(
                  'All Regions',
                  style: TextStyle(color: Colors.grey[500]),
                ),
                isExpanded: true,
                dropdownColor: const Color(0xFF1F2937),
                style: const TextStyle(color: Colors.white),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All Regions'),
                  ),
                  ..._getProvinceOptions(),
                ],
                onChanged: (value) {
                  setState(() => _selectedProvinceState = value);
                  _loadData();
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<DropdownMenuItem<String>> _getProvinceOptions() {
    // Canadian provinces
    const provinces = [
      'Alberta', 'British Columbia', 'Manitoba', 'Saskatchewan', 'Ontario',
      'Quebec', 'New Brunswick', 'Nova Scotia', 'Prince Edward Island',
      'Newfoundland and Labrador',
    ];

    return provinces.map((p) => DropdownMenuItem(
      value: p,
      child: Text(p),
    )).toList();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.price_check,
              size: 48,
              color: Colors.grey[600],
            ),
            const SizedBox(height: 16),
            Text(
              'No prices reported yet',
              style: GoogleFonts.inter(
                color: Colors.grey[400],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Be the first to add a price for this product!',
              style: GoogleFonts.inter(
                color: Colors.grey[600],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showPriceDetails(PriceEntry entry) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1F2937),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              entry.product?.displayName ?? 'Price Entry',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Price', entry.formattedPrice),
            _buildDetailRow('Retailer', entry.retailer?.name ?? 'Unknown'),
            _buildDetailRow(
              'Location',
              '${entry.retailer?.city}, ${entry.retailer?.provinceState}',
            ),
            _buildDetailRow('Date', _formatDate(entry.priceDate)),
            if (entry.notes != null && entry.notes!.isNotEmpty)
              _buildDetailRow('Notes', entry.notes!),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: Colors.grey[500],
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAlertDialog() {
    // TODO: Implement alert dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Price alerts coming soon!')),
    );
  }

  Color _getColorForType(ProductType type) {
    switch (type) {
      case ProductType.fertilizer:
        return Colors.green;
      case ProductType.seed:
        return Colors.amber;
      case ProductType.chemical:
        return Colors.purple;
      case ProductType.equipment:
        return Colors.blue;
    }
  }

  IconData _getIconForType(ProductType type) {
    switch (type) {
      case ProductType.fertilizer:
        return Icons.eco;
      case ProductType.seed:
        return Icons.grass;
      case ProductType.chemical:
        return Icons.science;
      case ProductType.equipment:
        return Icons.agriculture;
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatDateShort(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}

/// Custom painter for simple price chart
class _PriceChartPainter extends CustomPainter {
  final List<double> prices;
  final double minPrice;
  final double maxPrice;
  final double range;

  _PriceChartPainter({
    required this.prices,
    required this.minPrice,
    required this.maxPrice,
    required this.range,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (prices.isEmpty) return;

    final paint = Paint()
      ..color = const Color(0xFF84CC16)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF84CC16).withOpacity(0.3),
          const Color(0xFF84CC16).withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..strokeWidth = 1;

    // Draw grid lines
    for (int i = 0; i <= 3; i++) {
      final y = size.height * (i / 3);
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    // Calculate points
    final points = <Offset>[];
    final step = size.width / (prices.length - 1);

    for (int i = 0; i < prices.length; i++) {
      final x = i * step;
      final normalizedY = range > 0
          ? (prices[i] - minPrice) / range
          : 0.5;
      final y = size.height - (normalizedY * size.height);
      points.add(Offset(x, y));
    }

    // Draw filled area
    final fillPath = Path();
    fillPath.moveTo(0, size.height);
    for (final point in points) {
      fillPath.lineTo(point.dx, point.dy);
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);

    // Draw line
    final linePath = Path();
    linePath.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(linePath, paint);

    // Draw dots at data points
    final dotPaint = Paint()
      ..color = const Color(0xFF84CC16)
      ..style = PaintingStyle.fill;

    for (final point in points) {
      canvas.drawCircle(point, 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
