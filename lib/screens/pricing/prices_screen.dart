import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import '../../models/pricing_models.dart';
import '../../providers/pricing_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/glass_container.dart';
import '../../widgets/input_price_card.dart';
import '../../main.dart' show Post, supabase, logger;
import '../post_details_screen.dart';
import 'price_history_screen.dart';



class PricesScreen extends ConsumerStatefulWidget {
  const PricesScreen({super.key});

  @override
  ConsumerState<PricesScreen> createState() => _PricesScreenState();
}

class _PricesScreenState extends ConsumerState<PricesScreen>
    with SingleTickerProviderStateMixin {
  // Sorting state
  String _sortBy = 'date'; // 'date' or 'price'
  bool _ascending = false;

  // Filter state
  String? _selectedProvinceState;
  ProductType? _selectedType;
  
  // Data state
  bool _isLoading = false;
  List<PriceEntry> _recentPrices = [];

  @override
  void initState() {
    super.initState();
    // Set default region from user profile
    final userProfile = ref.read(currentUserProfileProvider);
    if (userProfile?.provinceState != null) {
      _selectedProvinceState = userProfile!.provinceState;
    }
    
    _loadPrices();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadPrices() async {
    setState(() => _isLoading = true);

    final prices = await ref.read(priceEntriesProvider.notifier).getRecentPrices(
      provinceState: _selectedProvinceState,
      productType: _selectedType,
      limit: 30,
      sortBy: _sortBy,
      ascending: _ascending,
    );

    if (mounted) {
      setState(() {
        _recentPrices = prices;
        _isLoading = false;
      });
    }
  }

  void _openPostDetails(PriceEntry entry) {
    if (entry.postId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PostDetailsScreen(postId: entry.postId!),
        ),
      );
    } else {
      // Fallback if no post ID (shouldn't happen for new entries)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Original post not found')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const FaIcon(
                    FontAwesomeIcons.dollarSign,
                    color: Color(0xFF84CC16),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Input Prices',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.search, color: Colors.white),
                    onPressed: _showSearchSheet,
                  ),
                ],
              ),
            ),

            // Region filter
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      onTap: _showRegionPicker,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _selectedProvinceState ?? 'All Regions',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_drop_down,
                              color: Colors.grey[500],
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_selectedProvinceState != null)
                    IconButton(
                      icon: Icon(Icons.clear, size: 18, color: Colors.grey[500]),
                      onPressed: () {
                        setState(() => _selectedProvinceState = null);
                        _loadPrices();
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Product type filter chips
            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildFilterChip(null, 'All'),
                  ...ProductType.values.map((type) =>
                      _buildFilterChip(type, type.displayName)),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Sort bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Sort by:',
                    style: GoogleFonts.inter(
                      color: Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _showSortPicker,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Text(
                            _getSortLabel(),
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_drop_down,
                            color: Colors.grey[500],
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Price entries list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _recentPrices.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadPrices,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _recentPrices.length,
                            itemBuilder: (context, index) {
                              final entry = _recentPrices[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: InputPriceCard(
                                  priceEntry: entry,
                                  onTap: () => _openPostDetails(entry),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  String _getSortLabel() {
    if (_sortBy == 'date') {
      return _ascending ? 'Oldest First' : 'Newest First';
    } else {
      return _ascending ? 'Price: Low to High' : 'Price: High to Low';
    }
  }

  void _showSortPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1F2937),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
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
            const SizedBox(height: 16),
            Text(
              'Sort Prices',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildSortOption('Newest First', 'date', false),
            _buildSortOption('Oldest First', 'date', true),
            _buildSortOption('Price: Low to High', 'price', true),
            _buildSortOption('Price: High to Low', 'price', false),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(String label, String sortBy, bool ascending) {
    final isSelected = _sortBy == sortBy && _ascending == ascending;
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        setState(() {
          _sortBy = sortBy;
          _ascending = ascending;
        });
        _loadPrices();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                color: isSelected ? const Color(0xFF84CC16) : Colors.white,
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const Spacer(),
            if (isSelected)
              const Icon(
                Icons.check,
                color: Color(0xFF84CC16),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }





  Widget _buildFilterChip(ProductType? type, String label) {
    final isSelected = _selectedType == type;
    final color = type != null ? _getColorForType(type) : const Color(0xFF84CC16);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedType = type);
          _loadPrices();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? color : Colors.grey.withOpacity(0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (type != null) ...[
                Icon(
                  _getIconForType(type),
                  size: 14,
                  color: isSelected ? color : Colors.grey[500],
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: GoogleFonts.inter(
                  color: isSelected ? color : Colors.grey[400],
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.price_check,
            size: 64,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            'No prices found',
            style: GoogleFonts.inter(
              color: Colors.grey[400],
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedType != null || _selectedProvinceState != null
                ? 'Try adjusting your filters'
                : 'Be the first to add a price!',
            style: GoogleFonts.inter(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          if (_selectedType != null || _selectedProvinceState != null)
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedType = null;
                  _selectedProvinceState = null;
                });
                _loadPrices();
              },
              child: Text(
                'Clear Filters',
                style: GoogleFonts.inter(
                  color: const Color(0xFF84CC16),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openPriceHistory(PriceEntry entry) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PriceHistoryScreen(
          productId: entry.productId,
          initialProvinceState: entry.retailer?.provinceState,
        ),
      ),
    );
  }

  void _showSearchSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1F2937),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => _ProductSearchSheet(
          scrollController: scrollController,
          onProductSelected: (product) {
            Navigator.pop(context);
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PriceHistoryScreen(productId: product.id),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showRegionPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1F2937),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _RegionPickerSheet(
        selectedRegion: _selectedProvinceState,
        onRegionSelected: (region) {
          Navigator.pop(context);
          setState(() => _selectedProvinceState = region);
          _loadPrices();
        },
      ),
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
}

/// Product search sheet
class _ProductSearchSheet extends ConsumerStatefulWidget {
  final ScrollController scrollController;
  final ValueChanged<Product> onProductSelected;

  const _ProductSearchSheet({
    required this.scrollController,
    required this.onProductSelected,
  });

  @override
  ConsumerState<_ProductSearchSheet> createState() => _ProductSearchSheetState();
}

class _ProductSearchSheetState extends ConsumerState<_ProductSearchSheet> {
  final _searchController = TextEditingController();
  List<Product> _results = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.length < 2) {
      setState(() => _results = []);
      return;
    }

    setState(() => _isSearching = true);

    final results = await ref.read(productsProvider.notifier).searchProducts(query);

    if (mounted) {
      setState(() {
        _results = results;
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Handle
        Padding(
          padding: const EdgeInsets.all(12),
          child: Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),

        // Search field
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search products...',
              hintStyle: TextStyle(color: Colors.grey[500]),
              prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: Colors.grey[500]),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _results = []);
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey.withOpacity(0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: _search,
          ),
        ),
        const SizedBox(height: 16),

        // Results
        Expanded(
          child: _isSearching
              ? const Center(child: CircularProgressIndicator())
              : _results.isEmpty
                  ? Center(
                      child: Text(
                        _searchController.text.isEmpty
                            ? 'Search for a product'
                            : 'No products found',
                        style: GoogleFonts.inter(color: Colors.grey[500]),
                      ),
                    )
                  : ListView.builder(
                      controller: widget.scrollController,
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final product = _results[index];
                        return ListTile(
                          leading: Icon(
                            _getIconForType(product.productType),
                            color: _getColorForType(product.productType),
                          ),
                          title: Text(
                            product.displayName,
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: Text(
                            '${product.productType.displayName}${product.subCategory != null ? ' \u2022 ${product.subCategory}' : ''}',
                            style: TextStyle(color: Colors.grey[500], fontSize: 12),
                          ),
                          trailing: Text(
                            '${product.priceEntryCount} prices',
                            style: TextStyle(color: Colors.grey[600], fontSize: 11),
                          ),
                          onTap: () => widget.onProductSelected(product),
                        );
                      },
                    ),
        ),
      ],
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
}

/// Region picker sheet
class _RegionPickerSheet extends StatelessWidget {
  final String? selectedRegion;
  final ValueChanged<String?> onRegionSelected;

  const _RegionPickerSheet({
    this.selectedRegion,
    required this.onRegionSelected,
  });

  static const _canadianProvinces = [
    'Alberta',
    'British Columbia',
    'Manitoba',
    'New Brunswick',
    'Newfoundland and Labrador',
    'Nova Scotia',
    'Ontario',
    'Prince Edward Island',
    'Quebec',
    'Saskatchewan',
  ];

  static const _usStates = [
    'Montana',
    'North Dakota',
    'South Dakota',
    'Minnesota',
    'Wisconsin',
    'Michigan',
    'Iowa',
    'Nebraska',
    'Kansas',
    'Oklahoma',
    'Texas',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
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
          const SizedBox(height: 16),

          Text(
            'Select Region',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // All regions option
          ListTile(
            leading: Icon(
              Icons.public,
              color: selectedRegion == null ? const Color(0xFF84CC16) : Colors.grey[500],
            ),
            title: Text(
              'All Regions',
              style: TextStyle(
                color: selectedRegion == null ? const Color(0xFF84CC16) : Colors.white,
                fontWeight: selectedRegion == null ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            trailing: selectedRegion == null
                ? const Icon(Icons.check, color: Color(0xFF84CC16))
                : null,
            onTap: () => onRegionSelected(null),
          ),

          const Divider(color: Colors.grey),

          // Canadian provinces
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Canada',
              style: GoogleFonts.inter(
                color: Colors.grey[500],
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _canadianProvinces.map((province) {
              final isSelected = selectedRegion == province;
              return GestureDetector(
                onTap: () => onRegionSelected(province),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF84CC16).withOpacity(0.2)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: isSelected
                        ? Border.all(color: const Color(0xFF84CC16))
                        : null,
                  ),
                  child: Text(
                    province,
                    style: GoogleFonts.inter(
                      color: isSelected ? const Color(0xFF84CC16) : Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // US states (agriculture focused)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'United States',
              style: GoogleFonts.inter(
                color: Colors.grey[500],
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _usStates.map((state) {
              final isSelected = selectedRegion == state;
              return GestureDetector(
                onTap: () => onRegionSelected(state),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF84CC16).withOpacity(0.2)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: isSelected
                        ? Border.all(color: const Color(0xFF84CC16))
                        : null,
                  ),
                  child: Text(
                    state,
                    style: GoogleFonts.inter(
                      color: isSelected ? const Color(0xFF84CC16) : Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Card for displaying Input Prices posts from the community
class _InputPricePostCard extends StatelessWidget {
  final Post post;

  const _InputPricePostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy');

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              // User avatar/icon
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: FaIcon(
                    FontAwesomeIcons.dollarSign,
                    size: 16,
                    color: Color(0xFFF59E0B),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Author and date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.authorUsername ?? 'Anonymous',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      dateFormat.format(post.createdAt),
                      style: GoogleFonts.inter(
                        color: Colors.grey[600],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),

              // Location badge
              if (post.provinceState != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 12,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        post.provinceState!,
                        style: GoogleFonts.inter(
                          color: Colors.grey[400],
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Title
          Text(
            post.title,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          // Content preview
          if (post.content.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              post.content,
              style: GoogleFonts.inter(
                color: Colors.grey[400],
                fontSize: 13,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          const SizedBox(height: 12),

          // Stats row
          Row(
            children: [
              // Truth score
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _getTruthColor(post.truthMeterScore).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FaIcon(
                      FontAwesomeIcons.chartLine,
                      size: 12,
                      color: _getTruthColor(post.truthMeterScore),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${post.truthMeterScore.toStringAsFixed(0)}%',
                      style: GoogleFonts.inter(
                        color: _getTruthColor(post.truthMeterScore),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Vote counts
              _buildStatChip(
                FontAwesomeIcons.thumbsUp,
                post.thumbsUpCount,
                const Color(0xFF84CC16),
              ),
              const SizedBox(width: 8),
              _buildStatChip(
                FontAwesomeIcons.comment,
                post.commentCount,
                Colors.blue,
              ),

              const Spacer(),

              // View post arrow
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: Colors.grey[600],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FaIcon(icon, size: 12, color: color.withOpacity(0.7)),
        const SizedBox(width: 4),
        Text(
          count.toString(),
          style: GoogleFonts.inter(
            color: Colors.grey[500],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Color _getTruthColor(double score) {
    if (score >= 70) return const Color(0xFF84CC16);
    if (score >= 40) return const Color(0xFFF59E0B);
    return Colors.red;
  }
}
