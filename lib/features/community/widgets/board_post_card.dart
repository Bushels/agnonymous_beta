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

  const BoardPostCard({
    super.key,
    required this.title,
    required this.content,
    required this.category,
    required this.categoryEmoji,
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
  });

  @override
  Widget build(BuildContext context) {
    final accent = boardCategoryColor(category);
    final borderColor =
        accent.withValues(alpha: category == 'Monette' ? 0.6 : 0.25);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: BoardColors.paper,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3C2F16).withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
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
              Container(height: 5, color: accent),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PostMetaRow(
                      category: category,
                      categoryEmoji: categoryEmoji,
                      createdAt: createdAt,
                      accent: accent,
                      isAnonymous: isAnonymous,
                      authorUsername: authorUsername,
                      authorVerified: authorVerified,
                      wasEdited: wasEdited,
                    ),
                    const SizedBox(height: 12),
                    Text(title, style: BoardText.title),
                    const SizedBox(height: 10),
                    Text(
                      _previewText(content),
                      maxLines: isCommentsExpanded ? 12 : 4,
                      overflow: TextOverflow.ellipsis,
                      style: BoardText.body.copyWith(
                        color: BoardColors.ink.withValues(alpha: 0.88),
                      ),
                    ),
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
                    color: Color(0xFFFFF3D7),
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
  final DateTime createdAt;
  final Color accent;
  final bool isAnonymous;
  final String? authorUsername;
  final bool? authorVerified;
  final bool wasEdited;

  const _PostMetaRow({
    required this.category,
    required this.categoryEmoji,
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
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
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
              _Dot(color: BoardColors.line),
              FaIcon(
                isAnonymous
                    ? FontAwesomeIcons.userSecret
                    : FontAwesomeIcons.user,
                size: 11,
                color: BoardColors.muted,
              ),
              Text(
                isAnonymous ? 'Anonymous' : (authorUsername ?? 'Unknown'),
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
          color: filled ? color.withValues(alpha: 0.12) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.25)),
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
        color: const Color(0xFFFFFAED),
        borderRadius: BorderRadius.circular(14),
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
