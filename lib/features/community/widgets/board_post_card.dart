import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../board_theme.dart';

class BoardPostCard extends StatelessWidget {
  final String title;
  final String content;
  final String category;
  final String categoryEmoji;
  final String? monetteArea;
  final DateTime createdAt;
  final String? authorUsername;
  final bool? authorVerified;
  final bool isAnonymous;
  final Widget? truthMeterWidget;
  final int commentCount;
  final bool isCommentsExpanded;
  final bool isWatched;
  final int newCommentCount;
  final VoidCallback? onToggleComments;
  final VoidCallback? onToggleWatch;
  final VoidCallback? onShare;
  final Widget? commentsWidget;
  final bool showSignInPrompt;
  final bool isOwner;
  final bool wasEdited;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final String? imageUrl;
  final List<String> imageUrls;

  const BoardPostCard({
    super.key,
    required this.title,
    required this.content,
    required this.category,
    required this.categoryEmoji,
    this.monetteArea,
    required this.createdAt,
    this.authorUsername,
    this.authorVerified,
    this.isAnonymous = true,
    this.truthMeterWidget,
    this.commentCount = 0,
    this.isCommentsExpanded = false,
    this.isWatched = false,
    this.newCommentCount = 0,
    this.onToggleComments,
    this.onToggleWatch,
    this.onShare,
    this.commentsWidget,
    this.showSignInPrompt = false,
    this.isOwner = false,
    this.wasEdited = false,
    this.onEdit,
    this.onDelete,
    this.imageUrl,
    this.imageUrls = const [],
  });

  @override
  Widget build(BuildContext context) {
    final accent = boardCategoryColor(category);
    final borderColor =
        accent.withValues(alpha: category == 'Monette' ? 0.6 : 0.25);
    final attachedImages = <String>{
      ...imageUrls,
      if (imageUrl != null && imageUrl!.trim().isNotEmpty) imageUrl!,
    }.toList();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: BoardColors.paper,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onToggleComments,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PostMetaRow(
                      category: category,
                      categoryEmoji: categoryEmoji,
                      monetteArea: monetteArea,
                      createdAt: createdAt,
                      accent: accent,
                      isAnonymous: isAnonymous,
                      authorUsername: authorUsername,
                      authorVerified: authorVerified,
                      wasEdited: wasEdited,
                    ),
                    const SizedBox(height: 10),
                    Text(title, style: BoardText.title),
                    const SizedBox(height: 7),
                    Text(
                      _previewText(content),
                      maxLines: isCommentsExpanded ? 12 : 4,
                      overflow: TextOverflow.ellipsis,
                      style: BoardText.body.copyWith(
                        color: BoardColors.ink.withValues(alpha: 0.9),
                      ),
                    ),
                    if (attachedImages.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _PostImageGallery(imageUrls: attachedImages),
                    ],
                    const SizedBox(height: 14),
                    _ThreadSignalRow(
                      commentCount: commentCount,
                      isWatched: isWatched,
                      newCommentCount: newCommentCount,
                      accent: accent,
                      isExpanded: isCommentsExpanded,
                      onToggleComments: onToggleComments,
                      onToggleWatch: onToggleWatch,
                      onShare: onShare,
                    ),
                    if (truthMeterWidget != null) ...[
                      const SizedBox(height: 12),
                      _SignalPanel(child: truthMeterWidget!),
                    ],
                    if (isOwner || onEdit != null || onDelete != null) ...[
                      const SizedBox(height: 10),
                      _OwnerActions(onEdit: onEdit, onDelete: onDelete),
                    ],
                  ],
                ),
              ),
              if (isCommentsExpanded && commentsWidget != null)
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1D1F18),
                    border: Border(top: BorderSide(color: BoardColors.line)),
                  ),
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: commentsWidget!,
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _previewText(String value) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= 420) return normalized;
    return '${normalized.substring(0, 420).trim()}...';
  }
}

class _PostMetaRow extends StatelessWidget {
  final String category;
  final String categoryEmoji;
  final String? monetteArea;
  final DateTime createdAt;
  final Color accent;
  final bool isAnonymous;
  final String? authorUsername;
  final bool? authorVerified;
  final bool wasEdited;

  const _PostMetaRow({
    required this.category,
    required this.categoryEmoji,
    required this.monetteArea,
    required this.createdAt,
    required this.accent,
    required this.isAnonymous,
    required this.authorUsername,
    required this.authorVerified,
    required this.wasEdited,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 34,
          width: 34,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: accent.withValues(alpha: 0.28)),
          ),
          alignment: Alignment.center,
          child: Text(categoryEmoji, style: const TextStyle(fontSize: 17)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Wrap(
            spacing: 7,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                category.toUpperCase(),
                style: BoardText.meta.copyWith(color: accent),
              ),
              if (_hasMonetteArea()) ...[
                _Dot(color: BoardColors.line),
                const FaIcon(
                  FontAwesomeIcons.locationDot,
                  size: 11,
                  color: BoardColors.monette,
                ),
                Text(
                  monetteArea!.trim(),
                  style: BoardText.meta.copyWith(color: BoardColors.monette),
                ),
              ],
              _Dot(color: BoardColors.line),
              FaIcon(
                isAnonymous
                    ? FontAwesomeIcons.userSecret
                    : FontAwesomeIcons.user,
                size: 11,
                color: BoardColors.muted,
              ),
              Text(
                isAnonymous
                    ? _anonymousDisplayName()
                    : (authorUsername ?? 'Unknown'),
                style: BoardText.meta,
              ),
              if (authorVerified == true)
                const FaIcon(
                  FontAwesomeIcons.circleCheck,
                  size: 11,
                  color: BoardColors.sky,
                ),
              _Dot(color: BoardColors.line),
              Text(
                DateFormat.MMMd().add_jm().format(createdAt),
                style: BoardText.meta,
              ),
              if (wasEdited) ...[
                _Dot(color: BoardColors.line),
                Text('updated', style: BoardText.meta),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _anonymousDisplayName() {
    final displayName = authorUsername?.trim() ?? '';
    return displayName.isEmpty ? 'Anonymous' : displayName;
  }

  bool _hasMonetteArea() {
    return category == 'Monette' && (monetteArea?.trim().isNotEmpty ?? false);
  }
}

class _PostImageGallery extends StatelessWidget {
  final List<String> imageUrls;

  const _PostImageGallery({required this.imageUrls});

  @override
  Widget build(BuildContext context) {
    if (imageUrls.length == 1) {
      return _PostImageTile(
        imageUrl: imageUrls.first,
        width: double.infinity,
        aspectRatio: 16 / 10,
      );
    }

    return SizedBox(
      height: 128,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: imageUrls.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          return _PostImageTile(
            imageUrl: imageUrls[index],
            width: 150,
            aspectRatio: 1.12,
          );
        },
      ),
    );
  }
}

class _PostImageTile extends StatelessWidget {
  final String imageUrl;
  final double width;
  final double aspectRatio;

  const _PostImageTile({
    required this.imageUrl,
    required this.width,
    required this.aspectRatio,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: SizedBox(
          width: width,
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                color: const Color(0xFF303229),
                alignment: Alignment.center,
                child: const FaIcon(
                  FontAwesomeIcons.image,
                  color: BoardColors.muted,
                  size: 18,
                ),
              );
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                color: const Color(0xFF303229),
                alignment: Alignment.center,
                child: const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ThreadSignalRow extends StatelessWidget {
  final int commentCount;
  final bool isWatched;
  final int newCommentCount;
  final Color accent;
  final bool isExpanded;
  final VoidCallback? onToggleComments;
  final VoidCallback? onToggleWatch;
  final VoidCallback? onShare;

  const _ThreadSignalRow({
    required this.commentCount,
    required this.isWatched,
    required this.newCommentCount,
    required this.accent,
    required this.isExpanded,
    required this.onToggleComments,
    required this.onToggleWatch,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _ActionPill(
          icon: FontAwesomeIcons.commentDots,
          label: isExpanded ? 'Hide comments' : '$commentCount comments',
          color: accent,
          onTap: onToggleComments,
          filled: commentCount > 0,
        ),
        _ActionPill(
          icon: isWatched ? FontAwesomeIcons.solidBell : FontAwesomeIcons.bell,
          label: _watchLabel(),
          color: newCommentCount > 0 ? BoardColors.monette : BoardColors.green,
          onTap: onToggleWatch,
          filled: isWatched,
        ),
        if (onShare != null)
          _ActionPill(
            icon: FontAwesomeIcons.shareNodes,
            label: 'Share',
            color: BoardColors.sky,
            onTap: onShare,
          ),
      ],
    );
  }

  String _watchLabel() {
    if (isWatched && newCommentCount > 0) {
      return newCommentCount == 1 ? '1 new' : '$newCommentCount new';
    }
    if (isWatched) return 'Watching';
    return 'Watch';
  }
}

class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool filled;

  const _ActionPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color:
              filled ? color.withValues(alpha: 0.16) : const Color(0xFF1B1D17),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.32)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(icon, size: 13, color: color),
            const SizedBox(width: 7),
            Text(
              label,
              style: GoogleFonts.inter(
                color: BoardColors.ink,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignalPanel extends StatelessWidget {
  final Widget child;

  const _SignalPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1E18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: BoardColors.line),
      ),
      padding: const EdgeInsets.all(10),
      child: child,
    );
  }
}

class _OwnerActions extends StatelessWidget {
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _OwnerActions({this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        if (onEdit != null)
          TextButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.add_comment_rounded, size: 16),
            label: const Text('Add update'),
          ),
        if (onDelete != null)
          TextButton.icon(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded, size: 16),
            label: const Text('Delete'),
          ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;

  const _Dot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: 4,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
