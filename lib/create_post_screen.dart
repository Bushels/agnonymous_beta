import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import 'features/community/widgets/posting_as_sheet.dart';
import 'features/community/providers/auth_provider.dart';
import 'features/community/widgets/auth_dialog.dart';

class _PendingPostImage {
  final XFile file;
  final Uint8List previewBytes;

  const _PendingPostImage({
    required this.file,
    required this.previewBytes,
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
  bool _isAnonymousPost = true;

  @override
  void initState() {
    super.initState();
    final isKnownCategory = boardCategories.any(
      (category) => category.name == widget.initialCategory,
    );
    _selectedCategory =
        isKnownCategory ? widget.initialCategory : defaultBoardCategory;
    AnalyticsService.instance.logScreenView(screenName: 'CreatePostScreen');
    _loadPostingAlias().then((_) => _checkAndLoadDraft());
  }

  @override
  void dispose() {
    _titleController.removeListener(_saveDraft);
    _contentController.removeListener(_saveDraft);
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _saveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('post_draft_title', _titleController.text);
      await prefs.setString('post_draft_content', _contentController.text);
      await prefs.setString('post_draft_category', _selectedCategory);
      if (_selectedMonetteArea != null) {
        await prefs.setString('post_draft_monette_area', _selectedMonetteArea!);
      } else {
        await prefs.remove('post_draft_monette_area');
      }
    } catch (e) {
      logger.e('Failed to save post draft: $e');
    }
  }

  Future<void> _clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('post_draft_title');
      await prefs.remove('post_draft_content');
      await prefs.remove('post_draft_category');
      await prefs.remove('post_draft_monette_area');
    } catch (e) {
      logger.e('Failed to clear post draft: $e');
    }
  }

  Future<void> _checkAndLoadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftTitle = prefs.getString('post_draft_title') ?? '';
      final draftContent = prefs.getString('post_draft_content') ?? '';
      final draftCategory = prefs.getString('post_draft_category') ?? '';
      final draftMonetteArea = prefs.getString('post_draft_monette_area');

      if (draftTitle.isNotEmpty || draftContent.isNotEmpty) {
        setState(() {
          _titleController.text = draftTitle;
          _contentController.text = draftContent;
          if (draftCategory.isNotEmpty) {
            _selectedCategory = draftCategory;
          }
          if (draftMonetteArea != null) {
            _selectedMonetteArea = draftMonetteArea;
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Draft restored from your last session'),
              backgroundColor: BoardColors.prairie,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: BoardColors.line),
              ),
              action: SnackBarAction(
                label: 'Clear',
                textColor: BoardColors.monette,
                onPressed: () async {
                  await _clearDraft();
                  setState(() {
                    _titleController.clear();
                    _contentController.clear();
                    _selectedCategory = widget.initialCategory;
                    _selectedMonetteArea = null;
                  });
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      logger.e('Failed to load post draft: $e');
    } finally {
      _titleController.addListener(_saveDraft);
      _contentController.addListener(_saveDraft);
    }
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

      final auth = ref.read(authProvider);
      final isRegistered = auth.user != null && !auth.user!.isAnonymous;
      final postAsRegistered = isRegistered && !_isAnonymousPost;

      final insertPayload = <String, dynamic>{
        'title': sanitizedTitle,
        'content': sanitizedContent,
        'category': _selectedCategory,
        'province_state': _selectedProvinceState,
        'anonymous_user_id': anonymousId,
        'is_anonymous': !postAsRegistered,
        'author_username':
            postAsRegistered ? auth.profile?.username : authorUsername,
        'author_verified':
            postAsRegistered && (auth.user?.emailVerified ?? false),
        'image_url': imageUrls.isNotEmpty ? imageUrls.first : null,
        'image_urls': imageUrls,
        if (monetteArea != null) 'monette_area': monetteArea,
      };

      final insertedPost = await _insertPost(insertPayload);

      await _clearDraft();

      await ref
          .read(watchedThreadsProvider.notifier)
          .watch(Post.fromMap(insertedPost));

      postRateLimiter.recordPost();

      if (postAsRegistered) {
        await ref.read(authProvider.notifier).addReputationPoints(5, 'post');
      }

      AnalyticsService.instance.logPostCreated(
        category: _selectedCategory,
        isAnonymous: !postAsRegistered,
        provinceState: _selectedProvinceState,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(postAsRegistered
                ? 'Published as ${auth.profile?.username} (+5 Rep)'
                : 'Posted anonymously'),
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
    final payload = Map<String, dynamic>.from(insertPayload);
    payload['created_at'] = FieldValue.serverTimestamp();
    payload['updated_at'] = FieldValue.serverTimestamp();
    payload['is_deleted'] = false;
    payload['pending_review'] = false; // Standard posts bypass moderation
    payload['comment_count'] = 0;
    payload['vote_count'] = 0;
    payload['thumbs_up_count'] = 0;
    payload['thumbs_down_count'] = 0;
    payload['partial_count'] = 0;
    payload['funny_count'] = 0;
    payload['user_id'] = payload['anonymous_user_id'];

    // Generate search keywords for server-side search
    final searchKeywords = buildSearchKeywords(
      title: payload['title'] as String? ?? '',
      content: payload['content'] as String? ?? '',
      additionalFields: [
        payload['monette_area'] as String?,
        payload['category'] as String?,
      ],
    );
    payload['search_keywords'] = searchKeywords;

    final docRef = firestore.collection('posts').doc();
    final postId = docRef.id;
    payload['id'] = postId;

    final isAnonymous = payload['is_anonymous'] as bool? ?? true;
    final publicPayload = Map<String, dynamic>.from(payload);

    // If anonymous, remove the real user UID from the public document
    if (isAnonymous) {
      publicPayload.remove('user_id');
      publicPayload.remove('anonymous_user_id');
    }

    await firestore.runTransaction((transaction) async {
      transaction.set(docRef, publicPayload);

      // Write private ownership mapping
      final privateRef = firestore.collection('posts_private').doc(postId);
      transaction.set(privateRef, {
        'user_id': payload['anonymous_user_id'] ?? payload['user_id'],
        'created_at': FieldValue.serverTimestamp(),
      });
    });

    final snapshot = await docRef.get();
    final data = snapshot.data() ?? {};
    data['id'] = docRef.id;
    if (data['created_at'] is Timestamp) {
      data['created_at'] =
          (data['created_at'] as Timestamp).toDate().toIso8601String();
    } else {
      data['created_at'] = DateTime.now().toIso8601String();
    }
    return data;
  }

  Future<void> _loadPostingAlias() async {
    final profile = ref.read(authProvider).profile;
    if (profile != null) {
      if (!mounted) return;
      setState(() {
        _postingAlias = profile.username;
        _hasCustomPostingAlias = true;
        _isAnonymousPost = false;
      });
      return;
    }

    final savedAlias = await AnonymousIdService.getSavedDisplayName();
    if (!mounted) return;
    setState(() {
      _postingAlias = savedAlias ?? AnonymousIdService.defaultDisplayName;
      _hasCustomPostingAlias = savedAlias != null;
      _isAnonymousPost = true;
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

      final ref = firebaseStorage.ref().child('post-images/$path');
      final metadata = SettableMetadata(contentType: 'image/jpeg');

      await ref.putData(uploadBytes, metadata);
      final downloadUrl = await ref.getDownloadURL();
      urls.add(downloadUrl);
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
    final profile = ref.read(authProvider).profile;
    final result = await showPostingAsSheet(
      context,
      currentAlias: _postingAlias,
      hasCustomAlias: _hasCustomPostingAlias,
      userProfile: profile,
      initialIsAnonymous: _isAnonymousPost,
    );
    if (result == null) return;

    if (result == 'show_auth') {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => AuthDialog(ref: ref),
      );
      return;
    }

    if (result.remember && result.isAnonymous) {
      await AnonymousIdService.setSavedDisplayName(result.alias);
    }

    if (!mounted) return;
    setState(() {
      _postingAlias = result.alias;
      _hasCustomPostingAlias = result.hasCustomAlias;
      _isAnonymousPost = result.isAnonymous;
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
    final auth = ref.watch(authProvider);
    final profile = auth.profile;
    final isRegistered = profile != null && !_isAnonymousPost;

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
                  color: isRegistered
                      ? BoardColors.sky.withValues(alpha: 0.14)
                      : BoardColors.green.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isRegistered
                        ? BoardColors.sky.withValues(alpha: 0.25)
                        : BoardColors.green.withValues(alpha: 0.25),
                  ),
                ),
                alignment: Alignment.center,
                child: FaIcon(
                  isRegistered
                      ? FontAwesomeIcons.user
                      : FontAwesomeIcons.userSecret,
                  size: 18,
                  color: isRegistered ? BoardColors.sky : BoardColors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Posting Identity', style: BoardText.meta),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            isRegistered ? profile.username : _postingAlias,
                            overflow: TextOverflow.ellipsis,
                            style: BoardText.body.copyWith(
                              color: BoardColors.ink,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (isRegistered) ...[
                          const SizedBox(width: 6),
                          const FaIcon(
                            FontAwesomeIcons.circleCheck,
                            size: 13,
                            color: BoardColors.sky,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            profile.levelInfo.emoji,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isRegistered
                          ? 'Verified Profile. Earns +5 reputation points!'
                          : _hasCustomPostingAlias
                              ? 'Custom handle (saved locally).'
                              : 'Default anonymous label (no points earned).',
                      style: BoardText.meta.copyWith(
                        color: isRegistered ? BoardColors.sky : null,
                      ),
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
                  _saveDraft();
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
        _saveDraft();
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
