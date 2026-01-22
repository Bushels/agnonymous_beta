import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'main.dart';
import 'services/analytics_service.dart';
import 'services/rate_limiter.dart';
import 'services/anonymous_id_service.dart';
import 'services/location_service.dart';

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

  // Post identity toggle (User Identity posting removed)
  // Always true for now as per specific request for "Guest Posting" flow.
  final bool _postAsAnonymous = true;

  // Categories (Removed Input Prices)
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
    {'name': 'General', 'icon': '📝', 'isSpecial': false},
    {'name': 'Other', 'icon': '🔗', 'isSpecial': false},
  ];

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.logScreenView(screenName: 'CreatePostScreen');
    _detectLocation();
  }

  Future<void> _detectLocation() async {
    // Attempt to auto-detect location from IP
    final region = await LocationService.instance.getRegionFromIp();
    if (region != null && mounted) {
      // Basic matching - if the detected region exists in our list, use it
      if (PROVINCES_STATES.contains(region)) {
        setState(() => _selectedProvinceState = region);
      } else {
        // Try fallback matching/cleaning if needed?
        // optimizing: if "North Dakota" comes in identical, it works.
        // For now, only set if exact match to avoid UI errors
        // or check common variations (optional)
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submitPost() async {
    if (!_formKey.currentState!.validate()) return;

    // Check client-side rate limiting for posts
    final postRateLimiter = PostRateLimiter();
    final rateLimitError = postRateLimiter.canPost();
    if (rateLimitError != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(rateLimitError),
            backgroundColor: Colors.orange.shade700,
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = supabase.auth.currentUser?.id;
      // Note: user might be logged in, but we are posting anonymously regardless if forced

      final sanitizedTitle = sanitizeInput(_titleController.text);
      final sanitizedContent = sanitizeInput(_contentController.text);

      final postData = <String, dynamic>{
        'title': sanitizedTitle,
        'content': sanitizedContent,
        'category': _selectedCategory,
        'province_state': _selectedProvinceState,
        'anonymous_user_id': await AnonymousIdService.getAnonymousId(),
        'is_anonymous': _postAsAnonymous, // Always true
      };

      // If needed, we could store 'user_id' even for anon posts if they are logged in,
      // but user explicitly asked for "guest posting" flow.
      // Keeping it simple: if you are logged in, we link it for moderation but display as anon.
      if (userId != null) {
        postData['user_id'] = userId;
      }

      await supabase.from('posts').insert(postData);

      // Record successful post for rate limiting
      postRateLimiter.recordPost();

      // Track analytics
      AnalyticsService.instance.logPostCreated(
        category: _selectedCategory,
        isAnonymous: _postAsAnonymous,
        provinceState: _selectedProvinceState,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Post created anonymously!'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(17, 24, 39, 0.8),
        title: Text(
          'Create Anonymous Post',
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
            // Category Selection (Moved to top for flow)
            _buildCategorySection(),
            const SizedBox(height: 24),

            // Standard Form
            _buildStandardPostForm(),

            const SizedBox(height: 24),

            // Submit Button
            _buildSubmitButton(),

            const SizedBox(height: 16),

            // Notice
            _buildPrivacyNotice(),
          ],
        ),
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
                  });
                }
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStandardPostForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        TextFormField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: 'Title',
            hintText: 'What\'s happening?',
            prefixIcon: const Icon(Icons.title),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: theme.colorScheme.surface,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a title';
            }
            if (value.length < 5) return 'Title must be at least 5 characters';
            if (value.length > 100) return 'Title must be under 100 characters';
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Province/State
        DropdownButtonFormField<String>(
          initialValue: _selectedProvinceState,
          decoration: InputDecoration(
            labelText: 'Province/State (Auto-detected)',
            prefixIcon: const Icon(Icons.location_on),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: theme.colorScheme.surface,
            helperText: 'Your detailed location is never shared.',
          ),
          items: PROVINCES_STATES.map((location) {
            return DropdownMenuItem(value: location, child: Text(location));
          }).toList(),
          onChanged: (value) => setState(() => _selectedProvinceState = value),
        ),
        const SizedBox(height: 16),

        // Content
        TextFormField(
          controller: _contentController,
          maxLines: 6,
          decoration: InputDecoration(
            labelText: 'Details',
            hintText: 'Share the full story...',
            alignLabelWithHint: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: theme.colorScheme.surface,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter some details';
            }
            if (value.length < 20) return 'Content must be at least 20 characters';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitPost,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          disabledBackgroundColor: theme.colorScheme.primary.withOpacity(0.5),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Post Anonymously',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildPrivacyNotice() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.security,
                color: Colors.grey[400],
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Secure & Anonymous',
                style: TextStyle(
                  color: Colors.grey[300],
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Your identity is hidden. We auto-detect your province/state to display alongside your post, but never your exact location.',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
