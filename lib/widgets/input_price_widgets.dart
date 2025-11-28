import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/pricing_models.dart';
import '../providers/pricing_provider.dart';
import '../main.dart' show theme;

/// Product type selector widget
class ProductTypeSelector extends StatelessWidget {
  final ProductType? selected;
  final ValueChanged<ProductType> onChanged;

  const ProductTypeSelector({
    super.key,
    this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What type of input?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[300],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: ProductType.values.map((type) {
            final isSelected = selected == type;
            return InkWell(
              onTap: () => onChanged(type),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary.withOpacity(0.2)
                      : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : Colors.grey.withOpacity(0.3),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getIconForType(type),
                      color: isSelected ? theme.colorScheme.primary : Colors.grey[400],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      type.displayName,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[400],
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
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

/// Product search field with autocomplete
class ProductSearchField extends ConsumerStatefulWidget {
  final ProductType? productType;
  final Product? initialProduct;
  final ValueChanged<Product> onProductSelected;
  final Function(String name, String? brand) onNewProduct;

  const ProductSearchField({
    super.key,
    this.productType,
    this.initialProduct,
    required this.onProductSelected,
    required this.onNewProduct,
  });

  @override
  ConsumerState<ProductSearchField> createState() => _ProductSearchFieldState();
}

class _ProductSearchFieldState extends ConsumerState<ProductSearchField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<Product> _suggestions = [];
  bool _showSuggestions = false;
  Product? _selectedProduct;

  @override
  void initState() {
    super.initState();
    _selectedProduct = widget.initialProduct;
    if (_selectedProduct != null) {
      _controller.text = _selectedProduct!.displayName;
    }
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          setState(() => _showSuggestions = false);
        }
      });
    }
  }

  Future<void> _search(String query) async {
    if (query.length < 2) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    final results = await ref.read(productsProvider.notifier).searchProducts(
      query,
      productType: widget.productType,
    );

    if (mounted) {
      setState(() {
        _suggestions = results;
        _showSuggestions = true;
      });
    }
  }

  void _selectProduct(Product product) {
    setState(() {
      _selectedProduct = product;
      _controller.text = product.displayName;
      _showSuggestions = false;
    });
    widget.onProductSelected(product);
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Product Name',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[300],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _controller,
          focusNode: _focusNode,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search or enter product name...',
            hintStyle: TextStyle(color: Colors.grey[500]),
            prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
            suffixIcon: _selectedProduct != null
                ? IconButton(
                    icon: Icon(Icons.clear, color: Colors.grey[500]),
                    onPressed: () {
                      setState(() {
                        _selectedProduct = null;
                        _controller.clear();
                      });
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.grey.withOpacity(0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.colorScheme.primary),
            ),
          ),
          onChanged: _search,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a product name';
            }
            return null;
          },
        ),
        if (_showSuggestions && _suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2937),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _suggestions.length + 1,
              itemBuilder: (context, index) {
                if (index == _suggestions.length) {
                  return ListTile(
                    leading: Icon(Icons.add, color: theme.colorScheme.primary),
                    title: Text(
                      'Add "${_controller.text}" as new product',
                      style: TextStyle(color: theme.colorScheme.primary),
                    ),
                    onTap: () {
                      widget.onNewProduct(_controller.text, null);
                      setState(() => _showSuggestions = false);
                    },
                  );
                }

                final product = _suggestions[index];
                return ListTile(
                  leading: Icon(
                    _getIconForType(product.productType),
                    color: Colors.grey[400],
                  ),
                  title: Text(
                    product.displayName,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: product.subCategory != null
                      ? Text(
                          product.subCategory!,
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        )
                      : null,
                  onTap: () => _selectProduct(product),
                );
              },
            ),
          ),
      ],
    );
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

/// Retailer search field with autocomplete
class RetailerSearchField extends ConsumerStatefulWidget {
  final String? provinceState;
  final String? city;
  final Retailer? initialRetailer;
  final ValueChanged<Retailer> onRetailerSelected;
  final Function(String name) onNewRetailer;

  const RetailerSearchField({
    super.key,
    this.provinceState,
    this.city,
    this.initialRetailer,
    required this.onRetailerSelected,
    required this.onNewRetailer,
  });

  @override
  ConsumerState<RetailerSearchField> createState() => _RetailerSearchFieldState();
}

class _RetailerSearchFieldState extends ConsumerState<RetailerSearchField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  List<Retailer> _suggestions = [];
  bool _showSuggestions = false;
  Retailer? _selectedRetailer;

  @override
  void initState() {
    super.initState();
    _selectedRetailer = widget.initialRetailer;
    if (_selectedRetailer != null) {
      _controller.text = _selectedRetailer!.displayName;
    }
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          setState(() => _showSuggestions = false);
        }
      });
    }
  }

  Future<void> _search(String query) async {
    if (query.length < 2 || widget.provinceState == null) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }

    final results = await ref.read(retailersProvider.notifier).searchRetailers(
      query,
      provinceState: widget.provinceState!,
      city: widget.city,
    );

    if (mounted) {
      setState(() {
        _suggestions = results;
        _showSuggestions = true;
      });
    }
  }

  void _selectRetailer(Retailer retailer) {
    setState(() {
      _selectedRetailer = retailer;
      _controller.text = retailer.displayName;
      _showSuggestions = false;
    });
    widget.onRetailerSelected(retailer);
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.provinceState == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Retailer Name',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[300],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _controller,
          focusNode: _focusNode,
          enabled: !isDisabled,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: isDisabled
                ? 'Select location first'
                : 'Search or enter retailer...',
            hintStyle: TextStyle(color: Colors.grey[500]),
            prefixIcon: Icon(Icons.store, color: Colors.grey[500]),
            suffixIcon: _selectedRetailer != null
                ? IconButton(
                    icon: Icon(Icons.clear, color: Colors.grey[500]),
                    onPressed: () {
                      setState(() {
                        _selectedRetailer = null;
                        _controller.clear();
                      });
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.grey.withOpacity(isDisabled ? 0.05 : 0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.colorScheme.primary),
            ),
          ),
          onChanged: _search,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a retailer name';
            }
            return null;
          },
        ),
        if (_showSuggestions && _suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2937),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _suggestions.length + 1,
              itemBuilder: (context, index) {
                if (index == _suggestions.length) {
                  return ListTile(
                    leading: Icon(Icons.add, color: theme.colorScheme.primary),
                    title: Text(
                      'Add "${_controller.text}" as new retailer',
                      style: TextStyle(color: theme.colorScheme.primary),
                    ),
                    onTap: () {
                      widget.onNewRetailer(_controller.text);
                      setState(() => _showSuggestions = false);
                    },
                  );
                }

                final retailer = _suggestions[index];
                return ListTile(
                  leading: Icon(Icons.store, color: Colors.grey[400]),
                  title: Text(
                    retailer.name,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    '${retailer.city}, ${retailer.provinceState}',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                  trailing: retailer.chainName != null
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            retailer.chainName!,
                            style: const TextStyle(color: Colors.blue, fontSize: 10),
                          ),
                        )
                      : null,
                  onTap: () => _selectRetailer(retailer),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// Price entry fields widget
class PriceEntryFields extends StatelessWidget {
  final String currency;
  final ProductType? productType;
  final TextEditingController priceController;
  final String? selectedUnit;
  final ValueChanged<String> onUnitChanged;

  const PriceEntryFields({
    super.key,
    required this.currency,
    this.productType,
    required this.priceController,
    this.selectedUnit,
    required this.onUnitChanged,
  });

  @override
  Widget build(BuildContext context) {
    final units = productType != null
        ? getUnitsForProductType(productType!)
        : ['tonne', 'lb', 'bag', 'acre', 'gallon', 'litre', 'each'];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Price field
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Price',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[300],
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: priceController,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                decoration: InputDecoration(
                  prefixText: currency == 'CAD' ? 'C\$ ' : 'US\$ ',
                  prefixStyle: TextStyle(color: Colors.grey[400], fontSize: 18),
                  hintText: '0.00',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  filled: true,
                  fillColor: Colors.grey.withOpacity(0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: theme.colorScheme.primary),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Required';
                  }
                  final price = double.tryParse(value);
                  if (price == null || price <= 0) {
                    return 'Invalid price';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Unit dropdown
        Expanded(
          flex: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Unit',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[300],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withOpacity(0.3)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedUnit ?? units.first,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1F2937),
                    style: const TextStyle(color: Colors.white),
                    items: units.map((unit) {
                      return DropdownMenuItem(
                        value: unit,
                        child: Text('per $unit'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) onUnitChanged(value);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Input price info box with pricing tips
class InputPriceInfoBox extends StatelessWidget {
  final String currency;

  const InputPriceInfoBox({
    super.key,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[300], size: 20),
              const SizedBox(width: 8),
              Text(
                'Pricing Tips',
                style: GoogleFonts.inter(
                  color: Colors.blue[300],
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Currency detected: ${currency == 'CAD' ? 'Canadian Dollar (C\$)' : 'US Dollar (US\$)'}',
            style: TextStyle(color: Colors.grey[300], fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            '\u2022 Include any volume discounts in notes\n'
            '\u2022 Specify if cash price differs\n'
            '\u2022 Your entry helps farmers compare prices!',
            style: TextStyle(color: Colors.grey[400], fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }
}

/// Review price entry before submission
class PriceEntryReview extends StatelessWidget {
  final Product product;
  final Retailer retailer;
  final double price;
  final String unit;
  final String currency;
  final DateTime priceDate;
  final String? notes;
  final VoidCallback onEdit;
  final VoidCallback onSubmit;
  final bool isLoading;

  const PriceEntryReview({
    super.key,
    required this.product,
    required this.retailer,
    required this.price,
    required this.unit,
    required this.currency,
    required this.priceDate,
    this.notes,
    required this.onEdit,
    required this.onSubmit,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review Your Price Entry',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 20),

          _buildReviewRow('Product', product.displayName),
          _buildReviewRow('Type', product.productType.displayName),
          _buildReviewRow('Retailer', '${retailer.name} - ${retailer.city}, ${retailer.provinceState}'),
          _buildReviewRow('Price', formatPrice(price, currency) + '/$unit'),
          _buildReviewRow('Date', _formatDate(priceDate)),
          if (notes != null && notes!.isNotEmpty)
            _buildReviewRow('Notes', notes!),

          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onEdit,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.grey.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Edit'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: isLoading ? null : onSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Submit Price',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ],
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
