import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'main.dart';
import 'services/analytics_service.dart';
import 'providers/auth_provider.dart';
import 'models/pricing_models.dart';
import 'providers/pricing_provider.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();

  // Standard post fields
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String _selectedCategory = 'Farming';
  String? _selectedProvinceState;
  bool _isLoading = false;

  // Post identity toggle (true = anonymous, false = post with username)
  bool _postAsAnonymous = true;

  // Input Prices specific fields
  String? _inputPriceType; // fertilizer, seed, chemical, equipment
  final _productNameController = TextEditingController();
  final _brandController = TextEditingController();
  final _formulationController = TextEditingController();
  final _townController = TextEditingController();
  final _retailerController = TextEditingController();
  final _priceController = TextEditingController();
  final _notesController = TextEditingController();
  String _selectedUnit = 'per tonne';
  String _currency = 'CAD';

  // Equipment specific fields
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();

  // Categories with special flag for Input Prices
  final List<Map<String, dynamic>> _categories = [
    {'name': 'Farming', 'icon': '🚜', 'isSpecial': false},
    {'name': 'Livestock', 'icon': '🐄', 'isSpecial': false},
    {'name': 'Ranching', 'icon': '🤠', 'isSpecial': false},
    {'name': 'Crops', 'icon': '🌾', 'isSpecial': false},
    {'name': 'Markets', 'icon': '📈', 'isSpecial': false},
    {'name': 'Weather', 'icon': '🌦️', 'isSpecial': false},
    {'name': 'Chemicals', 'icon': '🧪', 'isSpecial': false},
    {'name': 'Equipment', 'icon': '🔧', 'isSpecial': false},
    {'name': 'Politics', 'icon': '🏛️', 'isSpecial': false},
    {'name': 'Input Prices', 'icon': '💰', 'isSpecial': true},
    {'name': 'General', 'icon': '📝', 'isSpecial': false},
    {'name': 'Other', 'icon': '🔗', 'isSpecial': false},
  ];

  // Input price types
  final List<Map<String, dynamic>> _inputPriceTypes = [
    {'name': 'Fertilizer', 'icon': Icons.eco, 'color': Colors.green},
    {'name': 'Seed', 'icon': Icons.grass, 'color': Colors.amber},
    {'name': 'Chemical', 'icon': Icons.science, 'color': Colors.purple},
    {'name': 'Equipment', 'icon': Icons.agriculture, 'color': Colors.blue},
  ];

  // Units by input type
  final Map<String, List<String>> _unitsByType = {
    'Fertilizer': ['per tonne', 'per lb', 'per bag', 'per acre'],
    'Seed': ['per bag', 'per acre', 'per bu', 'per lb'],
    'Chemical': ['per gallon', 'per litre', 'per acre', 'per jug', 'per case'],
    'Equipment': ['each', 'per hour', 'per acre', 'per day'],
  };

  // Canadian provinces for currency detection
  static const _canadianProvinces = {
    'Alberta', 'British Columbia', 'Manitoba', 'New Brunswick',
    'Newfoundland and Labrador', 'Northwest Territories', 'Nova Scotia',
    'Nunavut', 'Ontario', 'Prince Edward Island', 'Quebec',
    'Saskatchewan', 'Yukon'
  };

  bool get _isInputPrices => _selectedCategory == 'Input Prices';

  @override
  void initState() {
    super.initState();
    // Track screen view
    AnalyticsService.instance.logScreenView(screenName: 'CreatePostScreen');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _productNameController.dispose();
    _brandController.dispose();
    _formulationController.dispose();
    _townController.dispose();
    _retailerController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  void _updateCurrency(String? provinceState) {
    if (provinceState != null) {
      setState(() {
        _currency = _canadianProvinces.contains(provinceState) ? 'CAD' : 'USD';
      });
    }
  }

  String _formatCurrency(String currency) {
    return currency == 'CAD' ? 'C\$' : 'US\$';
  }

  Future<void> _submitPost() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw 'User not authenticated. Cannot create post.';
      }

      if (_isInputPrices) {
        await _submitInputPrice(userId);
      } else {
        await _submitStandardPost(userId);
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isInputPrices
              ? 'Price submitted successfully!'
              : 'Post created successfully!'),
            backgroundColor: theme.colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitStandardPost(String userId) async {
    final sanitizedTitle = sanitizeInput(_titleController.text);
    final sanitizedContent = sanitizeInput(_contentController.text);

    // Get user profile for author info if not anonymous
    final authState = ref.read(authProvider);
    final userProfile = authState.profile;

    final postData = <String, dynamic>{
      'title': sanitizedTitle,
      'content': sanitizedContent,
      'category': _selectedCategory,
      'province_state': _selectedProvinceState,
      'anonymous_user_id': userId,
      'is_anonymous': _postAsAnonymous,
    };

    // Only include user_id if profile exists (FK constraint requires valid profile)
    if (userProfile != null) {
      postData['user_id'] = userId;
    }

    // Add author info if not posting anonymously
    if (!_postAsAnonymous && userProfile != null) {
      postData['author_username'] = userProfile.username;
      postData['author_verified'] = userProfile.emailVerified;
    }

    await supabase.from('posts').insert(postData);

    // Track analytics
    AnalyticsService.instance.logPostCreated(
      category: _selectedCategory,
      isAnonymous: _postAsAnonymous,
      provinceState: _selectedProvinceState,
    );
  }

  Future<void> _submitInputPrice(String userId) async {
    // 1. Find or create the product
    final productsNotifier = ref.read(productsProvider.notifier);
    
    // Search for existing product first to avoid duplicates
    // This is a simple check - in a real app we might want a more robust search/select UI
    // For now, we'll try to create it, and if it's a duplicate, we might want to handle that
    // But since we don't have a complex search UI here, we'll just create a new one for now
    // or rely on the backend to handle duplicates if we had unique constraints
    
    final product = await productsNotifier.createProduct(
      productType: ProductType.values.firstWhere(
        (e) => e.name == _inputPriceType?.toLowerCase(),
        orElse: () => ProductType.fertilizer,
      ),
      productName: sanitizeInput(_productNameController.text),
      brandName: _brandController.text.isNotEmpty
        ? sanitizeInput(_brandController.text)
        : null,
      formulation: _formulationController.text.isNotEmpty
        ? sanitizeInput(_formulationController.text)
        : null,
      // Equipment specific
      subCategory: _inputPriceType == 'Equipment' && _modelController.text.isNotEmpty
          ? _modelController.text
          : null,
    );

    if (product == null) throw 'Failed to create/find product';

    // 2. Find or create retailer
    final retailersNotifier = ref.read(retailersProvider.notifier);
    final retailer = await retailersNotifier.createRetailer(
      name: sanitizeInput(_retailerController.text),
      city: sanitizeInput(_townController.text),
      provinceState: _selectedProvinceState ?? '',
    );

    if (retailer == null) throw 'Failed to create/find retailer';

    // 3. Create the social post
    final title = _inputPriceType == 'Equipment'
      ? '${_brandController.text} ${_modelController.text} ${_yearController.text}'.trim()
      : '${_brandController.text} ${_productNameController.text}'.trim();

    final content = '''
**Product Type:** ${_inputPriceType}
**Product:** ${_productNameController.text}
${_brandController.text.isNotEmpty ? '**Brand:** ${_brandController.text}' : ''}
${_inputPriceType == 'Equipment' && _modelController.text.isNotEmpty ? '**Model:** ${_modelController.text}' : ''}
${_inputPriceType == 'Equipment' && _yearController.text.isNotEmpty ? '**Year:** ${_yearController.text}' : ''}
${_formulationController.text.isNotEmpty ? '**Formulation:** ${_formulationController.text}' : ''}

**Price:** ${_formatCurrency(_currency)}${_priceController.text} $_selectedUnit

**Retailer:** ${_retailerController.text}
**Location:** ${_townController.text}, $_selectedProvinceState

${_notesController.text.isNotEmpty ? '**Notes:** ${_notesController.text}' : ''}
'''.trim();

    // Get user profile for author info if not anonymous
    final authState = ref.read(authProvider);
    final userProfile = authState.profile;

    final postData = <String, dynamic>{
      'title': title.isNotEmpty ? title : _productNameController.text,
      'content': content,
      'category': 'Input Prices',
      'province_state': _selectedProvinceState,
      'anonymous_user_id': userId,
      'is_anonymous': _postAsAnonymous,
    };

    if (userProfile != null) {
      postData['user_id'] = userId;
    }

    if (!_postAsAnonymous && userProfile != null) {
      postData['author_username'] = userProfile.username;
      postData['author_verified'] = userProfile.emailVerified;
    }

    final postResponse = await supabase.from('posts').insert(postData).select().single();
    final postId = postResponse['id'] as String;

    // 4. Create the structured price entry linked to everything
    final priceEntriesNotifier = ref.read(priceEntriesProvider.notifier);
    await priceEntriesNotifier.submitPriceEntry(
      productId: product.id,
      retailerId: retailer.id,
      price: double.tryParse(_priceController.text) ?? 0.0,
      unit: _selectedUnit,
      currency: _currency,
      notes: _notesController.text,
      isAnonymous: _postAsAnonymous,
      postId: postId,
    );

    // Track analytics
    AnalyticsService.instance.logInputPriceSubmitted(
      productType: _inputPriceType ?? 'unknown',
      provinceState: _selectedProvinceState ?? 'unknown',
      currency: _currency,
      retailerName: _retailerController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(17, 24, 39, 0.8),
        title: Text(
          _isInputPrices ? 'Submit Price' : 'Create Post',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const FaIcon(FontAwesomeIcons.xmark),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Post-As Toggle (only show for authenticated users)
            _buildPostAsToggle(),
            const SizedBox(height: 24),

            // Category Selection
            _buildCategorySection(),
            const SizedBox(height: 24),

            // Conditional form based on category
            if (_isInputPrices)
              _buildInputPriceForm()
            else
              _buildStandardPostForm(),

            const SizedBox(height: 24),

            // Submit Button
            _buildSubmitButton(),

            const SizedBox(height: 16),

            // Info boxes
            if (_isInputPrices)
              _buildPriceInfoBox()
            else
              ...[
                if (_postAsAnonymous) _buildPrivacyNotice(),
                if (!_postAsAnonymous) _buildReputationNotice(),
                const SizedBox(height: 32),
                _buildPostingGuidelines(),
              ],
          ],
        ),
      ),
    );
  }

  Widget _buildPostAsToggle() {
    final authState = ref.watch(authProvider);
    final userProfile = authState.profile;
    final isLoggedIn = userProfile != null;
    final username = userProfile?.username ?? 'Unknown';
    final isVerified = userProfile?.emailVerified ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How do you want to post?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[300],
          ),
        ),
        const SizedBox(height: 12),

        // Toggle buttons
        Row(
          children: [
            // Anonymous option
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _postAsAnonymous = true),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  decoration: BoxDecoration(
                    color: _postAsAnonymous
                        ? theme.colorScheme.surface
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _postAsAnonymous
                          ? theme.colorScheme.primary
                          : Colors.grey.withOpacity(0.3),
                      width: _postAsAnonymous ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      FaIcon(
                        FontAwesomeIcons.userSecret,
                        color: _postAsAnonymous
                            ? theme.colorScheme.primary
                            : Colors.grey[400],
                        size: 24,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Anonymous',
                        style: TextStyle(
                          color: _postAsAnonymous
                              ? Colors.white
                              : Colors.grey[400],
                          fontWeight: _postAsAnonymous
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Hidden identity',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Username option (only if logged in)
            Expanded(
              child: InkWell(
                onTap: isLoggedIn
                    ? () => setState(() => _postAsAnonymous = false)
                    : null,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  decoration: BoxDecoration(
                    color: !_postAsAnonymous
                        ? theme.colorScheme.surface
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: !_postAsAnonymous
                          ? theme.colorScheme.primary
                          : Colors.grey.withOpacity(0.3),
                      width: !_postAsAnonymous ? 2 : 1,
                    ),
                  ),
                  child: Opacity(
                    opacity: isLoggedIn ? 1.0 : 0.5,
                    child: Column(
                      children: [
                        Icon(
                          isVerified ? Icons.verified : Icons.person,
                          color: !_postAsAnonymous
                              ? theme.colorScheme.primary
                              : Colors.grey[400],
                          size: 24,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isLoggedIn ? '@$username' : 'Sign in required',
                          style: TextStyle(
                            color: !_postAsAnonymous
                                ? Colors.white
                                : Colors.grey[400],
                            fontWeight: !_postAsAnonymous
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isLoggedIn ? 'Earn reputation' : 'Login to enable',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        // Warning about reputation
        if (!_postAsAnonymous) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.star,
                  color: theme.colorScheme.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You\'ll earn +5 reputation points for this post!',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        if (_postAsAnonymous) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.grey.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.grey[400],
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Anonymous posts don\'t earn reputation points.',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildReputationNotice() {
    final authState = ref.watch(authProvider);
    final userProfile = authState.profile;
    final isVerified = userProfile?.emailVerified ?? false;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isVerified ? Icons.verified : Icons.warning_amber,
                color: isVerified ? Colors.blue : Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isVerified
                      ? 'Your post will show as verified'
                      : 'Your post will show as unverified',
                  style: TextStyle(
                    color: isVerified ? Colors.blue[300] : Colors.orange[300],
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isVerified
                ? 'Your username will be displayed with a verified badge, increasing trust in your post.'
                : 'Verify your email to get a verified badge and increase trust in your posts.',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Category',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[300],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _categories.map((category) {
            final isSelected = _selectedCategory == category['name'];
            final isSpecial = category['isSpecial'] as bool;
            return ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(category['icon'] as String),
                  const SizedBox(width: 8),
                  Text(category['name'] as String),
                ],
              ),
              selected: isSelected,
              selectedColor: isSpecial
                ? Colors.amber[700]
                : theme.colorScheme.primary,
              backgroundColor: isSpecial
                ? Colors.amber.withOpacity(0.2)
                : theme.colorScheme.surface,
              side: isSpecial && !isSelected
                ? BorderSide(color: Colors.amber.withOpacity(0.5))
                : null,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedCategory = category['name'] as String;
                    // Reset input price fields when switching away
                    if (!_isInputPrices) {
                      _inputPriceType = null;
                    }
                  });
                }
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildInputPriceForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Input Type Selection
        _buildInputTypeSection(),

        if (_inputPriceType != null) ...[
          const SizedBox(height: 24),

          // Product Details
          _buildProductDetailsSection(),

          const SizedBox(height: 24),

          // Location & Retailer
          _buildLocationSection(),

          const SizedBox(height: 24),

          // Price
          _buildPriceSection(),
        ],
      ],
    );
  }

  Widget _buildInputTypeSection() {
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
        Row(
          children: _inputPriceTypes.map((type) {
            final isSelected = _inputPriceType == type['name'];
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _inputPriceType = type['name'] as String;
                      // Set default unit for this type
                      _selectedUnit = _unitsByType[_inputPriceType]?.first ?? 'each';
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: isSelected
                        ? (type['color'] as Color).withOpacity(0.3)
                        : theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                          ? type['color'] as Color
                          : Colors.grey.withOpacity(0.3),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          type['icon'] as IconData,
                          color: isSelected
                            ? type['color'] as Color
                            : Colors.grey[400],
                          size: 28,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          type['name'] as String,
                          style: TextStyle(
                            color: isSelected
                              ? Colors.white
                              : Colors.grey[400],
                            fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildProductDetailsSection() {
    final isEquipment = _inputPriceType == 'Equipment';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isEquipment ? 'Equipment Details' : 'Product Details',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[300],
          ),
        ),
        const SizedBox(height: 12),

        // Brand (required for equipment)
        TextFormField(
          controller: _brandController,
          decoration: InputDecoration(
            labelText: isEquipment ? 'Brand *' : 'Brand (optional)',
            hintText: isEquipment
              ? 'e.g., John Deere, Case IH, New Holland'
              : 'e.g., Nutrien, Bayer, Pioneer',
            filled: true,
            fillColor: theme.colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            labelStyle: TextStyle(color: Colors.grey[400]),
          ),
          style: const TextStyle(color: Colors.white),
          validator: isEquipment ? (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Brand is required for equipment';
            }
            return null;
          } : null,
        ),
        const SizedBox(height: 16),

        if (isEquipment) ...[
          // Model (for equipment)
          TextFormField(
            controller: _modelController,
            decoration: InputDecoration(
              labelText: 'Model *',
              hintText: 'e.g., 8R 410, Magnum 340, T8.435',
              filled: true,
              fillColor: theme.colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              labelStyle: TextStyle(color: Colors.grey[400]),
            ),
            style: const TextStyle(color: Colors.white),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Model is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Year (for equipment)
          TextFormField(
            controller: _yearController,
            decoration: InputDecoration(
              labelText: 'Year *',
              hintText: 'e.g., 2024',
              filled: true,
              fillColor: theme.colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              labelStyle: TextStyle(color: Colors.grey[400]),
            ),
            style: const TextStyle(color: Colors.white),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Year is required';
              }
              final year = int.tryParse(value);
              if (year == null || year < 1950 || year > DateTime.now().year + 1) {
                return 'Please enter a valid year';
              }
              return null;
            },
          ),
        ] else ...[
          // Product Name (for non-equipment)
          TextFormField(
            controller: _productNameController,
            decoration: InputDecoration(
              labelText: 'Product Name *',
              hintText: _getProductHint(),
              filled: true,
              fillColor: theme.colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              labelStyle: TextStyle(color: Colors.grey[400]),
            ),
            style: const TextStyle(color: Colors.white),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Product name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Formulation/Variety
          TextFormField(
            controller: _formulationController,
            decoration: InputDecoration(
              labelText: 'Formulation / Variety (optional)',
              hintText: _getFormulationHint(),
              filled: true,
              fillColor: theme.colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              labelStyle: TextStyle(color: Colors.grey[400]),
            ),
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ],
    );
  }

  String _getProductHint() {
    switch (_inputPriceType) {
      case 'Fertilizer':
        return 'e.g., Urea 46-0-0, MAP 11-52-0, Potash';
      case 'Seed':
        return 'e.g., InVigor L340P, AAC Brandon Wheat';
      case 'Chemical':
        return 'e.g., Liberty 150, Roundup WeatherMax';
      default:
        return 'Enter product name';
    }
  }

  String _getFormulationHint() {
    switch (_inputPriceType) {
      case 'Fertilizer':
        return 'e.g., Granular, Liquid';
      case 'Seed':
        return 'e.g., Liberty Link, Roundup Ready, Treated';
      case 'Chemical':
        return 'e.g., Liquid, Granular, EC';
      default:
        return 'Optional details';
    }
  }

  Widget _buildLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Location & Retailer',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[300],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Prices vary by location - please be specific',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
          ),
        ),
        const SizedBox(height: 12),

        // Province/State (Required)
        DropdownButtonFormField<String>(
          initialValue: _selectedProvinceState,
          decoration: InputDecoration(
            labelText: 'Province/State *',
            filled: true,
            fillColor: theme.colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            labelStyle: TextStyle(color: Colors.grey[400]),
          ),
          dropdownColor: theme.colorScheme.surface,
          style: const TextStyle(color: Colors.white),
          icon: const FaIcon(
            FontAwesomeIcons.chevronDown,
            color: Colors.grey,
            size: 16,
          ),
          items: PROVINCES_STATES.map((String province) {
            return DropdownMenuItem<String>(
              value: province,
              child: Text(
                province,
                style: const TextStyle(color: Colors.white),
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              _selectedProvinceState = newValue;
            });
            _updateCurrency(newValue);
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Province/State is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Town/City (Required)
        TextFormField(
          controller: _townController,
          decoration: InputDecoration(
            labelText: 'Town/City *',
            hintText: 'e.g., Lethbridge, Medicine Hat, Saskatoon',
            filled: true,
            fillColor: theme.colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            labelStyle: TextStyle(color: Colors.grey[400]),
            prefixIcon: Icon(Icons.location_on, color: Colors.grey[400]),
          ),
          style: const TextStyle(color: Colors.white),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Town/City is required for price comparison';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Retailer Name (Required)
        TextFormField(
          controller: _retailerController,
          decoration: InputDecoration(
            labelText: 'Retailer Name *',
            hintText: 'e.g., Nutrien Ag Solutions, UFA, Richardson Pioneer',
            filled: true,
            fillColor: theme.colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            labelStyle: TextStyle(color: Colors.grey[400]),
            prefixIcon: Icon(Icons.store, color: Colors.grey[400]),
          ),
          style: const TextStyle(color: Colors.white),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Retailer name is required';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPriceSection() {
    final units = _unitsByType[_inputPriceType] ?? ['each'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Price',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[300],
          ),
        ),
        const SizedBox(height: 12),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Currency indicator
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
              ),
              child: Center(
                child: Text(
                  _formatCurrency(_currency),
                  style: TextStyle(
                    color: _currency == 'CAD' ? Colors.red[300] : Colors.green[300],
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),

            // Price input
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _priceController,
                decoration: InputDecoration(
                  hintText: '0.00',
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide.none,
                  ),
                  hintStyle: TextStyle(color: Colors.grey[600]),
                ),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Price is required';
                  }
                  final price = double.tryParse(value);
                  if (price == null || price <= 0) {
                    return 'Enter a valid price';
                  }
                  return null;
                },
              ),
            ),

            // Unit dropdown
            Expanded(
              flex: 2,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                ),
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedUnit,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                  ),
                  dropdownColor: theme.colorScheme.surface,
                  style: const TextStyle(color: Colors.white),
                  icon: const FaIcon(
                    FontAwesomeIcons.chevronDown,
                    color: Colors.grey,
                    size: 12,
                  ),
                  items: units.map((String unit) {
                    return DropdownMenuItem<String>(
                      value: unit,
                      child: Text(
                        unit,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() => _selectedUnit = newValue);
                    }
                  },
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Currency toggle
        Row(
          children: [
            Text(
              'Currency: ',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  _currency = _currency == 'CAD' ? 'USD' : 'CAD';
                });
              },
              child: Text(
                '$_currency (tap to change)',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 12,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Notes
        TextFormField(
          controller: _notesController,
          decoration: InputDecoration(
            labelText: 'Notes (optional)',
            hintText: 'e.g., Volume discount, cash price, delivery included',
            filled: true,
            fillColor: theme.colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            labelStyle: TextStyle(color: Colors.grey[400]),
          ),
          style: const TextStyle(color: Colors.white),
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildStandardPostForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Province/State Selection (Optional for standard posts)
        Text(
          'Select Province/State (Optional)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[300],
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _selectedProvinceState,
          decoration: InputDecoration(
            hintText: 'Choose your province/state',
            filled: true,
            fillColor: theme.colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            hintStyle: TextStyle(color: Colors.grey[400]),
          ),
          dropdownColor: theme.colorScheme.surface,
          style: const TextStyle(color: Colors.white),
          icon: const FaIcon(
            FontAwesomeIcons.chevronDown,
            color: Colors.grey,
            size: 16,
          ),
          items: PROVINCES_STATES.map((String province) {
            return DropdownMenuItem<String>(
              value: province,
              child: Text(
                province,
                style: const TextStyle(color: Colors.white),
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            setState(() {
              _selectedProvinceState = newValue;
            });
          },
        ),
        const SizedBox(height: 24),

        // Title Field
        TextFormField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: 'Title',
            hintText: 'Brief summary of your observation',
            filled: true,
            fillColor: theme.colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            labelStyle: TextStyle(color: Colors.grey[400]),
          ),
          style: const TextStyle(color: Colors.white),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a title';
            }
            if (value.trim().length > 100) {
              return 'Title must be less than 100 characters';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Content Field
        TextFormField(
          controller: _contentController,
          decoration: InputDecoration(
            labelText: 'Details',
            hintText: 'Share your experience, provide evidence, and be specific to help others learn...',
            filled: true,
            fillColor: theme.colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            labelStyle: TextStyle(color: Colors.grey[400]),
            alignLabelWithHint: true,
          ),
          style: const TextStyle(color: Colors.white),
          maxLines: 8,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter details';
            }
            if (value.trim().length < 10) {
              return 'Please provide more details (at least 10 characters)';
            }
            if (value.trim().length > 2000) {
              return 'Content is too long (max 2000 characters)';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _submitPost,
      style: ElevatedButton.styleFrom(
        backgroundColor: _isInputPrices
          ? Colors.amber[700]
          : theme.colorScheme.primary,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: _isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Text(
              _isInputPrices ? 'Submit Price' : 'Submit Post',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
    );
  }

  Widget _buildPriceInfoBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.amber.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: Colors.amber[300],
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Why Share Prices?',
                style: TextStyle(
                  color: Colors.amber[300],
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Price transparency helps farmers negotiate better deals.\n\n'
            'A Nutrien in Lethbridge might charge \$50/tonne more than one in Medicine Hat. '
            'By sharing what you paid, you help other farmers know what\'s fair.\n\n'
            'Your submission builds our database - the more prices we have, the more valuable it becomes for everyone.',
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyNotice() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          FaIcon(
            FontAwesomeIcons.userSecret,
            color: theme.colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your post will be completely anonymous. No personal information is stored.',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostingGuidelines() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.blue.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FaIcon(
                FontAwesomeIcons.circleInfo,
                color: Colors.blue[300],
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'How to Make Great Posts',
                style: TextStyle(
                  color: Colors.blue[300],
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Post confidently! Your experience matters\n'
            'Be as specific as possible - it may draw out additional tips\n'
            'Provide evidence, first-hand accounts, or links to help build truth\n'
            'Share what you heard - it might develop into a valuable discussion\n'
            'Help fellow farmers by contributing to the knowledge base',
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
