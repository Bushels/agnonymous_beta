import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
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

class _PendingPostImage {
  final XFile file;
  final Uint8List previewBytes;

  const _PendingPostImage({
    required this.file,
    required this.previewBytes,
  });
}

class _AliasSelection {
  final String alias;
  final bool hasCustomAlias;
  final bool remember;

  const _AliasSelection({
    required this.alias,
    required this.hasCustomAlias,
    required this.remember,
  });
}

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
  final ImagePicker _imagePicker = ImagePicker();
  final List<_PendingPostImage> _selectedImages = [];

  late String _selectedCategory;
  String? _selectedProvinceState;
  String? _selectedMonetteArea;
  String _postingAlias = AnonymousIdService.defaultDisplayName;
  bool _hasCustomPostingAlias = false;
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
    _loadPostingAlias();
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
      final anonymousId = await AnonymousIdService.getAnonymousId();
      final sanitizedTitle = sanitizeInput(_titleController.text);
      final sanitizedContent = sanitizeInput(_contentController.text);
      final imageUrls = await _uploadSelectedImages(anonymousId);
      final authorUsername = _effectiveAuthorUsername();
      final monetteArea = _selectedCategory == defaultBoardCategory &&
              isKnownMonetteArea(_selectedMonetteArea)
          ? _selectedMonetteArea
          : null;

      final insertPayload = <String, dynamic>{
        'title': sanitizedTitle,
        'content': sanitizedContent,
        'category': _selectedCategory,
        'province_state': _selectedProvinceState,
        'anonymous_user_id': anonymousId,
        'is_anonymous': true,
        'author_username': authorUsername,
        'author_verified': false,
        'image_url': imageUrls.isNotEmpty ? imageUrls.first : null,
        'image_urls': imageUrls,
        if (monetteArea != null) 'monette_area': monetteArea,
      };

      final insertedPost = await _insertPost(insertPayload);

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

  Future<Map<String, dynamic>> _insertPost(
    Map<String, dynamic> insertPayload,
  ) async {
    try {
      final response =
          await supabase.from('posts').insert(insertPayload).select().single();
      return Map<String, dynamic>.from(response);
    } catch (error) {
      if (insertPayload.containsKey('monette_area') &&
          _isMissingMonetteAreaColumn(error)) {
        final fallbackPayload = Map<String, dynamic>.from(insertPayload)
          ..remove('monette_area');
        final response = await supabase
            .from('posts')
            .insert(fallbackPayload)
            .select()
            .single();
        return Map<String, dynamic>.from(response);
      }
      rethrow;
    }
  }

  bool _isMissingMonetteAreaColumn(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('monette_area') &&
        (message.contains('column') || message.contains('schema cache'));
  }

  Future<void> _loadPostingAlias() async {
    final savedAlias = await AnonymousIdService.getSavedDisplayName();
    if (!mounted) return;
    setState(() {
      _postingAlias = savedAlias ?? AnonymousIdService.defaultDisplayName;
      _hasCustomPostingAlias = savedAlias != null;
    });
  }

  String _effectiveAuthorUsername() {
    return _hasCustomPostingAlias
        ? _postingAlias
        : AnonymousIdService.defaultDisplayName;
  }

  Future<void> _pickImages() async {
    final remainingSlots = 3 - _selectedImages.length;
    if (remainingSlots <= 0) return;

    try {
      final pickedImages = await _imagePicker.pickMultiImage(
        maxWidth: 2200,
        maxHeight: 2200,
        imageQuality: 95,
        limit: remainingSlots,
      );
      if (pickedImages.isEmpty) return;

      final additions = <_PendingPostImage>[];
      for (final imageFile in pickedImages.take(remainingSlots)) {
        final bytes = await imageFile.readAsBytes();
        if (bytes.length > 12 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('One image was skipped because it is too large.'),
              ),
            );
          }
          continue;
        }
        additions.add(_PendingPostImage(file: imageFile, previewBytes: bytes));
      }

      if (additions.isEmpty || !mounted) return;
      setState(() => _selectedImages.addAll(additions));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not attach image: $e'),
          backgroundColor: theme.colorScheme.error,
        ),
      );
    }
  }

  void _removeImage(int index) {
    setState(() => _selectedImages.removeAt(index));
  }

  Future<List<String>> _uploadSelectedImages(String anonymousId) async {
    if (_selectedImages.isEmpty) return const [];

    final urls = <String>[];
    for (final pendingImage in _selectedImages) {
      final uploadBytes = await _prepareImageForUpload(pendingImage);
      final path =
          'anonymous/$anonymousId/${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4()}.jpg';

      await supabase.storage.from('post-images').uploadBinary(
            path,
            uploadBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );
      urls.add(supabase.storage.from('post-images').getPublicUrl(path));
    }
    return urls;
  }

  Future<Uint8List> _prepareImageForUpload(
    _PendingPostImage pendingImage,
  ) async {
    final originalBytes = await pendingImage.file.readAsBytes();
    final decoded = img.decodeImage(originalBytes);
    if (decoded == null) {
      throw 'Unsupported image file';
    }

    final oriented = img.bakeOrientation(decoded);
    final resized = oriented.width > 1800 || oriented.height > 1800
        ? img.copyResize(
            oriented,
            width: oriented.width >= oriented.height ? 1800 : null,
            height: oriented.height > oriented.width ? 1800 : null,
          )
        : oriented;

    return Uint8List.fromList(img.encodeJpg(resized, quality: 84));
  }

  Future<void> _openAliasEditor() async {
    final controller = TextEditingController(
      text: _hasCustomPostingAlias ? _postingAlias : '',
    );
    bool rememberOnDevice = true;

    final result = await showModalBottomSheet<_AliasSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: BoardColors.paper,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: BoardColors.line,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text('Posting as', style: BoardText.roomTitle),
                    const SizedBox(height: 8),
                    Text(
                      'This is public display text only. It is not an account.',
                      style: BoardText.body.copyWith(color: BoardColors.muted),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      maxLength: 24,
                      decoration: InputDecoration(
                        labelText: 'Anonymous display name',
                        hintText: AnonymousIdService.defaultDisplayName,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF303229),
                        labelStyle: const TextStyle(color: BoardColors.muted),
                        hintStyle: const TextStyle(color: BoardColors.muted),
                        counterText: '',
                      ),
                      style: BoardText.body,
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: rememberOnDevice,
                      activeColor: BoardColors.green,
                      title: Text(
                        'Remember on this device',
                        style: BoardText.body.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(
                        'No sign-in. Clearing browser/app data removes it.',
                        style: BoardText.meta,
                      ),
                      onChanged: (value) {
                        setSheetState(() {
                          rememberOnDevice = value ?? true;
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.of(context).pop(
                                const _AliasSelection(
                                  alias: AnonymousIdService.defaultDisplayName,
                                  hasCustomAlias: false,
                                  remember: false,
                                ),
                              );
                            },
                            child: const Text('Use default'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: BoardColors.green,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              final sanitized = sanitizeInput(controller.text);
                              final normalized =
                                  AnonymousIdService.normalizeDisplayName(
                                sanitized,
                              );
                              Navigator.of(context).pop(
                                _AliasSelection(
                                  alias: normalized.isEmpty
                                      ? AnonymousIdService.defaultDisplayName
                                      : normalized,
                                  hasCustomAlias: normalized.isNotEmpty,
                                  remember:
                                      rememberOnDevice && normalized.isNotEmpty,
                                ),
                              );
                            },
                            child: const Text('Apply'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    controller.dispose();
    if (result == null) return;

    if (result.remember) {
      await AnonymousIdService.setSavedDisplayName(result.alias);
    }

    if (!mounted) return;
    setState(() {
      _postingAlias = result.alias;
      _hasCustomPostingAlias = result.hasCustomAlias;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BoardColors.prairie,
      appBar: AppBar(
        backgroundColor: const Color(0xFF211B14),
        foregroundColor: BoardColors.ink,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Create Anonymous Post',
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
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF2B2015),
                BoardColors.prairie,
                Color(0xFF11130F),
              ],
            ),
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildComposerHeader(),
                      const SizedBox(height: 12),
                      _buildPostingAsSection(),
                      const SizedBox(height: 10),
                      _buildPhotoSection(),
                      const SizedBox(height: 10),
                      _buildFormPanel(),
                      const SizedBox(height: 16),
                      _buildSubmitButton(),
                      const SizedBox(height: 12),
                      _buildPrivacyNotice(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComposerHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: BoardColors.deepGreen.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: BoardColors.green.withValues(alpha: 0.3)),
            ),
            child: Text(
              'Your post is anonymous. Farmers will judge it by the details, photos, and comments.',
              style: BoardText.body.copyWith(
                color: BoardColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostingAsSection() {
    return _SectionPanel(
      child: InkWell(
        onTap: _openAliasEditor,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: BoardColors.green.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: BoardColors.green.withValues(alpha: 0.25),
                  ),
                ),
                alignment: Alignment.center,
                child: const FaIcon(
                  FontAwesomeIcons.userSecret,
                  size: 18,
                  color: BoardColors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Posting as', style: BoardText.meta),
                    const SizedBox(height: 3),
                    Text(
                      _postingAlias,
                      style: BoardText.body.copyWith(
                        color: BoardColors.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _hasCustomPostingAlias
                          ? 'Saved locally unless changed for this post.'
                          : 'Default public label. No account attached.',
                      style: BoardText.meta,
                    ),
                  ],
                ),
              ),
              const FaIcon(
                FontAwesomeIcons.pen,
                size: 15,
                color: BoardColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    final hasImages = _selectedImages.isNotEmpty;

    return _SectionPanel(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Photos',
                    style: BoardText.body.copyWith(
                      color: BoardColors.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '${_selectedImages.length}/3',
                  style: BoardText.meta,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (hasImages) _buildSelectedImageStrip(),
            if (hasImages) const SizedBox(height: 12),
            InkWell(
              onTap: _selectedImages.length >= 3 ? null : _pickImages,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF303229),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _selectedImages.length >= 3
                        ? BoardColors.line
                        : BoardColors.green.withValues(alpha: 0.45),
                  ),
                ),
                child: Row(
                  children: [
                    const FaIcon(
                      FontAwesomeIcons.image,
                      size: 18,
                      color: BoardColors.green,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _selectedImages.length >= 3
                            ? 'Image limit reached'
                            : hasImages
                                ? 'Add another photo'
                                : 'Add field photo, document, or screenshot',
                        style: BoardText.body.copyWith(
                          color: BoardColors.ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const FaIcon(
                      FontAwesomeIcons.plus,
                      size: 14,
                      color: BoardColors.muted,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'We re-encode uploads to remove image metadata. Visible landmarks, plate numbers, faces, or document details are still public.',
              style: BoardText.meta,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedImageStrip() {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _selectedImages.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final image = _selectedImages[index];
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  image.previewBytes,
                  width: 92,
                  height: 92,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 5,
                right: 5,
                child: InkWell(
                  onTap: () => _removeImage(index),
                  borderRadius: BorderRadius.circular(99),
                  child: Container(
                    height: 26,
                    width: 26,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    alignment: Alignment.center,
                    child: const FaIcon(
                      FontAwesomeIcons.xmark,
                      color: Colors.white,
                      size: 13,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFormPanel() {
    return _SectionPanel(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCategorySection(),
            if (_selectedCategory == defaultBoardCategory) ...[
              const SizedBox(height: 18),
              _buildMonetteAreaSection(),
            ],
            const SizedBox(height: 22),
            _buildStandardPostForm(),
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
              selectedColor: BoardColors.green,
              backgroundColor: const Color(0xFF303229),
              side: BorderSide(
                color: isSelected ? BoardColors.green : BoardColors.line,
              ),
              labelStyle: GoogleFonts.inter(
                color: isSelected ? const Color(0xFF101610) : BoardColors.ink,
                fontWeight: FontWeight.w800,
              ),
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedCategory = category.name;
                    if (_selectedCategory != defaultBoardCategory) {
                      _selectedMonetteArea = null;
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

  Widget _buildMonetteAreaSection() {
    final selectedArea =
        isKnownMonetteArea(_selectedMonetteArea) ? _selectedMonetteArea! : '';

    return DropdownButtonFormField<String>(
      initialValue: selectedArea,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Monette farming area',
        prefixIcon: const Icon(Icons.place_outlined, color: BoardColors.muted),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: const Color(0xFF303229),
        labelStyle: const TextStyle(color: BoardColors.muted),
        helperStyle: const TextStyle(color: BoardColors.muted),
        helperText: 'Optional public tag for Monette threads.',
      ),
      dropdownColor: const Color(0xFF303229),
      style: BoardText.body,
      iconEnabledColor: BoardColors.muted,
      items: [
        const DropdownMenuItem(
          value: '',
          child: Text('No specific area'),
        ),
        ...monetteAreas.map((area) {
          return DropdownMenuItem(
            value: area.name,
            child: Text(
              '${area.name} - ${area.region}',
              overflow: TextOverflow.ellipsis,
            ),
          );
        }),
      ],
      onChanged: (value) {
        final normalized = value?.trim() ?? '';
        setState(() {
          _selectedMonetteArea =
              isKnownMonetteArea(normalized) ? normalized : null;
        });
      },
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
            prefixIcon: const Icon(Icons.title, color: BoardColors.muted),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            filled: true,
            fillColor: const Color(0xFF303229),
            labelStyle: const TextStyle(color: BoardColors.muted),
            hintStyle: const TextStyle(color: BoardColors.muted),
          ),
          style: BoardText.body,
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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            filled: true,
            fillColor: const Color(0xFF303229),
            labelStyle: const TextStyle(color: BoardColors.muted),
            hintStyle: const TextStyle(color: BoardColors.muted),
          ),
          style: BoardText.body,
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
            prefixIcon: const Icon(Icons.location_on, color: BoardColors.muted),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            filled: true,
            fillColor: const Color(0xFF303229),
            labelStyle: const TextStyle(color: BoardColors.muted),
            helperStyle: const TextStyle(color: BoardColors.muted),
            helperText: 'Leave blank if location adds no value.',
          ),
          dropdownColor: const Color(0xFF303229),
          style: BoardText.body,
          iconEnabledColor: BoardColors.muted,
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
          backgroundColor: BoardColors.green,
          foregroundColor: const Color(0xFF101610),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          disabledBackgroundColor: BoardColors.green.withValues(alpha: 0.5),
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
        color: const Color(0xFF20231C),
        borderRadius: BorderRadius.circular(10),
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
            'No account is required. The display name is only public label text, and the post still uses the anonymous board path.',
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

class _SectionPanel extends StatelessWidget {
  final Widget child;

  const _SectionPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: BoardColors.paper,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: BoardColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}
