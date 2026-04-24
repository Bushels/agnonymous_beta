import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/utils/globals.dart';
import 'core/models/post.dart';
import 'app/constants.dart';
import 'app/theme.dart';
import 'services/analytics_service.dart';
import 'services/rate_limiter.dart';
import 'services/anonymous_id_service.dart';
import 'features/community/board_theme.dart';
import 'features/community/community_categories.dart';
import 'features/community/providers/watch_provider.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  final String initialCategory;

  const CreatePostScreen({
    super.key,
    this.initialCategory = defaultBoardCategory,
  });

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  late String _selectedCategory;
  String? _selectedProvinceState;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final isKnownCategory = boardCategories.any(
      (category) => category.name == widget.initialCategory,
    );
    _selectedCategory =
        isKnownCategory ? widget.initialCategory : defaultBoardCategory;
    AnalyticsService.instance.logScreenView(screenName: 'CreatePostScreen');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submitPost() async {
    if (!_formKey.currentState!.validate()) return;

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
      final sanitizedTitle = sanitizeInput(_titleController.text);
      final sanitizedContent = sanitizeInput(_contentController.text);

      final insertedPost = await supabase
          .from('posts')
          .insert({
            'title': sanitizedTitle,
            'content': sanitizedContent,
            'category': _selectedCategory,
            'province_state': _selectedProvinceState,
            'anonymous_user_id': await AnonymousIdService.getAnonymousId(),
            'is_anonymous': true,
          })
          .select()
          .single();

      await ref
          .read(watchedThreadsProvider.notifier)
          .watch(Post.fromMap(insertedPost));

      postRateLimiter.recordPost();

      AnalyticsService.instance.logPostCreated(
        category: _selectedCategory,
        isAnonymous: true,
        provinceState: _selectedProvinceState,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Posted anonymously'),
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
      backgroundColor: BoardColors.prairie,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'Post anonymously',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w900,
            color: BoardColors.ink,
          ),
        ),
        leading: IconButton(
          icon: const FaIcon(FontAwesomeIcons.xmark),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Container(
              decoration: BoxDecoration(
                color: BoardColors.paper,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: BoardColors.line),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3C2F16).withValues(alpha: 0.10),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('What needs to be said?', style: BoardText.roomTitle),
                  const SizedBox(height: 8),
                  Text(
                    'No sign up. No username. Keep it useful enough that someone checks back.',
                    style: BoardText.body.copyWith(color: BoardColors.muted),
                  ),
                  const SizedBox(height: 22),
                  _buildCategorySection(),
                  const SizedBox(height: 24),
                  _buildStandardPostForm(),
                  const SizedBox(height: 24),
                  _buildSubmitButton(),
                  const SizedBox(height: 16),
                  _buildPrivacyNotice(),
                ],
              ),
            ),
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
          'Category',
          style: BoardText.meta.copyWith(color: BoardColors.ink),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: boardCategories.map((category) {
            final isSelected = _selectedCategory == category.name;
            return ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(category.icon),
                  const SizedBox(width: 8),
                  Text(category.name),
                ],
              ),
              selected: isSelected,
              selectedColor: theme.colorScheme.primary,
              backgroundColor: BoardColors.paper,
              side: BorderSide(
                color: isSelected ? BoardColors.green : BoardColors.line,
              ),
              labelStyle: GoogleFonts.inter(
                color: isSelected ? Colors.white : BoardColors.ink,
                fontWeight: FontWeight.w800,
              ),
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedCategory = category.name);
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
        TextFormField(
          controller: _titleController,
          autofocus: true,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'Title',
            hintText: 'What should people know?',
            prefixIcon: const Icon(Icons.title),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white,
          ),
          validator: (value) {
            final trimmed = value?.trim() ?? '';
            if (trimmed.isEmpty) {
              return 'Please enter a title';
            }
            if (trimmed.length < 3) {
              return 'Title must be at least 3 characters';
            }
            if (trimmed.length > 100) {
              return 'Title must be under 100 characters';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _contentController,
          maxLines: 6,
          decoration: InputDecoration(
            labelText: 'Details',
            hintText: 'Share the details. No sign-up required.',
            alignLabelWithHint: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white,
          ),
          validator: (value) {
            final trimmed = value?.trim() ?? '';
            if (trimmed.isEmpty) {
              return 'Please enter some details';
            }
            if (trimmed.length < 5) {
              return 'Details must be at least 5 characters';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _selectedProvinceState,
          decoration: InputDecoration(
            labelText: 'Province/State (optional)',
            prefixIcon: const Icon(Icons.location_on),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white,
            helperText: 'Leave blank if location adds no value.',
          ),
          items: PROVINCES_STATES.map((location) {
            return DropdownMenuItem(value: location, child: Text(location));
          }).toList(),
          onChanged: (value) => setState(() => _selectedProvinceState = value),
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          disabledBackgroundColor:
              theme.colorScheme.primary.withValues(alpha: 0.5),
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
                'Post anonymously',
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
        color: const Color(0xFFFFF2D2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: BoardColors.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.security,
                color: BoardColors.green,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Anonymous by default',
                style: TextStyle(
                  color: BoardColors.ink,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'No account is required. We do not attach your auth profile to anonymous board posts.',
            style: TextStyle(
              color: BoardColors.muted,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
