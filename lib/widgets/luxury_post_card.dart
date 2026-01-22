import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/sound_service.dart';

/// Parsed input price data from post content
class InputPriceData {
  final String? productType;
  final String? product;
  final String? price;
  final String? retailer;
  final String? location;
  final String? notes;

  const InputPriceData({
    this.productType,
    this.product,
    this.price,
    this.retailer,
    this.location,
    this.notes,
  });

  static InputPriceData? parse(String content) {
    final lines = content.split('\n');
    String? productType, product, price, retailer, location, notes;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Parse **Label:** Value or Label: Value formats
      final match = RegExp(r'\*?\*?([^:*]+)\*?\*?:\s*(.+)').firstMatch(trimmed);
      if (match != null) {
        final label = match.group(1)?.toLowerCase().trim() ?? '';
        final value = match.group(2)?.trim() ?? '';

        if (label.contains('product type') || label.contains('type')) {
          productType = value;
        } else if (label.contains('product') && !label.contains('type')) {
          product = value;
        } else if (label.contains('price')) {
          price = value;
        } else if (label.contains('retailer') || label.contains('dealer') || label.contains('store')) {
          retailer = value;
        } else if (label.contains('location') || label.contains('city') || label.contains('region')) {
          location = value;
        } else if (label.contains('note')) {
          notes = value;
        }
      }
    }

    // Only return if we have at least price and product
    if (price != null || product != null) {
      return InputPriceData(
        productType: productType,
        product: product,
        price: price,
        retailer: retailer,
        location: location,
        notes: notes,
      );
    }
    return null;
  }
}

/// Luxury glassmorphic post card with refined styling
class LuxuryPostCard extends StatefulWidget {
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
  final int funnyCount;
  final bool isCommentsExpanded;
  final VoidCallback? onToggleComments;
  final VoidCallback? onShare;
  final VoidCallback? onFunnyVote;
  final Widget? commentsWidget;
  final bool showSignInPrompt;

  // Edit/Delete support
  final bool isOwner;
  final bool wasEdited;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  // Verification image for Input Prices
  final String? imageUrl;

  const LuxuryPostCard({
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
    this.funnyCount = 0,
    this.isCommentsExpanded = false,
    this.onToggleComments,
    this.onShare,
    this.onFunnyVote,
    this.commentsWidget,
    this.showSignInPrompt = false,
    this.isOwner = false,
    this.wasEdited = false,
    this.onEdit,
    this.onDelete,
    this.imageUrl,
  });

  @override
  State<LuxuryPostCard> createState() => _LuxuryPostCardState();
}

class _LuxuryPostCardState extends State<LuxuryPostCard> {
  bool _isContentExpanded = false;

  bool get _isLongContent => widget.content.length > 300;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1F2937).withOpacity(0.9),
                  const Color(0xFF111827).withOpacity(0.95),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                _buildContent(),
                if (widget.truthMeterWidget != null) _buildTruthMeterCard(),
                _buildActionRow(),
                if (widget.isCommentsExpanded && widget.commentsWidget != null)
                  widget.commentsWidget!,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Category emoji
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(widget.categoryEmoji, style: const TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.category,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF84CC16),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (!widget.isAnonymous && widget.authorUsername != null) ...[
                          Text(
                            widget.authorUsername!,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.grey.shade400,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (widget.authorVerified == true)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Icon(
                                Icons.verified,
                                size: 12,
                                color: Colors.blue.shade400,
                              ),
                            ),
                          _buildSmallDot(),
                        ] else ...[
                          const FaIcon(
                            FontAwesomeIcons.userSecret,
                            size: 10,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Anonymous',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          _buildSmallDot(),
                        ],
                        Text(
                          _formatTimeAgo(widget.createdAt),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        // Edited indicator
                        if (widget.wasEdited) ...[
                          _buildSmallDot(),
                          Text(
                            'edited',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Edit/Delete menu for post owner
              if (widget.isOwner && (widget.onEdit != null || widget.onDelete != null))
                _buildPostMenu(),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            widget.title,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostMenu() {
    return PopupMenuButton<String>(
      icon: FaIcon(
        FontAwesomeIcons.ellipsisVertical,
        size: 16,
        color: Colors.grey.shade500,
      ),
      color: const Color(0xFF1F2937),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      offset: const Offset(0, 40),
      onSelected: (value) {
        HapticFeedback.selectionClick();
        if (value == 'edit' && widget.onEdit != null) {
          widget.onEdit!();
        } else if (value == 'delete' && widget.onDelete != null) {
          widget.onDelete!();
        }
      },
      itemBuilder: (context) => [
        if (widget.onEdit != null)
          PopupMenuItem<String>(
            value: 'edit',
            child: Row(
              children: [
                FaIcon(
                  FontAwesomeIcons.penToSquare,
                  size: 14,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(width: 12),
                Text(
                  'Edit Post',
                  style: GoogleFonts.inter(
                    color: Colors.grey.shade300,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        if (widget.onDelete != null)
          PopupMenuItem<String>(
            value: 'delete',
            child: Row(
              children: [
                FaIcon(
                  FontAwesomeIcons.trash,
                  size: 14,
                  color: Colors.red.shade400,
                ),
                const SizedBox(width: 12),
                Text(
                  'Delete Post',
                  style: GoogleFonts.inter(
                    color: Colors.red.shade400,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSmallDot() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Container(
        width: 3,
        height: 3,
        decoration: BoxDecoration(
          color: Colors.grey.shade600,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildContent() {
    // Check if this is an Input Prices post and render compact display
    if (widget.category == 'Input Prices') {
      final priceData = InputPriceData.parse(widget.content);
      if (priceData != null) {
        return _buildInputPriceContent(priceData);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: _isLongContent
            ? () {
                HapticFeedback.selectionClick();
                setState(() => _isContentExpanded = !_isContentExpanded);
              }
            : null,
        child: AnimatedCrossFade(
          firstChild: _buildTruncatedContent(),
          secondChild: _buildFullContent(),
          crossFadeState: _isContentExpanded || !_isLongContent
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
          sizeCurve: Curves.easeOutCubic,
        ),
      ),
    );
  }

  Widget _buildInputPriceContent(InputPriceData data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Price - the hero element
          if (data.price != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF84CC16).withOpacity(0.15),
                    const Color(0xFF84CC16).withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF84CC16).withOpacity(0.3),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'INPUT PRICE',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF84CC16).withOpacity(0.8),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.price!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF84CC16),
                      letterSpacing: -1.0,
                      shadows: [
                        Shadow(
                          color: const Color(0xFF84CC16).withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 12),

          // Compact info row
          Row(
            children: [
              // Location with icon
              if (data.retailer != null || data.location != null)
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const FaIcon(
                          FontAwesomeIcons.locationDot,
                          size: 12,
                          color: Color(0xFFF59E0B),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (data.retailer != null)
                              Text(
                                data.retailer!,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            if (data.location != null)
                              Text(
                                data.location!,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.grey.shade400,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // Product type badge
              if (data.productType != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _getProductTypeColor(data.productType!).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _getProductTypeColor(data.productType!).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    data.productType!,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _getProductTypeColor(data.productType!),
                    ),
                  ),
                ),
            ],
          ),

          // Notes (if any)
          if (data.notes != null && data.notes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FaIcon(
                    FontAwesomeIcons.quoteLeft,
                    size: 10,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      data.notes!,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Verification image
          if (widget.imageUrl != null) ...[
            const SizedBox(height: 12),
            _buildVerificationImage(),
          ],
        ],
      ),
    );
  }

  Widget _buildVerificationImage() {
    return GestureDetector(
      onTap: () => _showFullImage(context),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF84CC16).withOpacity(0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF84CC16).withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(11),
                  topRight: Radius.circular(11),
                ),
              ),
              child: Row(
                children: [
                  const FaIcon(
                    FontAwesomeIcons.camera,
                    size: 12,
                    color: Color(0xFF84CC16),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'VERIFICATION PHOTO',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF84CC16),
                      letterSpacing: 1,
                    ),
                  ),
                  const Spacer(),
                  const FaIcon(
                    FontAwesomeIcons.expand,
                    size: 10,
                    color: Color(0xFF84CC16),
                  ),
                ],
              ),
            ),
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(11),
                bottomRight: Radius.circular(11),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 200,
                ),
                child: Image.network(
                  widget.imageUrl!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 150,
                      color: Colors.grey.shade900,
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                          strokeWidth: 2,
                          color: const Color(0xFF84CC16),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 100,
                      color: Colors.grey.shade900,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            FaIcon(
                              FontAwesomeIcons.image,
                              size: 24,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Image unavailable',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
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

  void _showFullImage(BuildContext context) {
    if (widget.imageUrl == null) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            // Full image
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  widget.imageUrl!,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade900,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FaIcon(
                            FontAwesomeIcons.image,
                            size: 48,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Failed to load image',
                            style: GoogleFonts.inter(
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            // Close button
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getProductTypeColor(String type) {
    final lowerType = type.toLowerCase();
    if (lowerType.contains('fertilizer')) return Colors.green;
    if (lowerType.contains('seed')) return Colors.amber;
    if (lowerType.contains('chemical') || lowerType.contains('herbicide') ||
        lowerType.contains('fungicide') || lowerType.contains('pesticide')) {
      return Colors.purple;
    }
    if (lowerType.contains('equipment')) return Colors.blue;
    return const Color(0xFF84CC16);
  }

  Widget _buildTruncatedContent() {
    return Stack(
      children: [
        Text(
          widget.content,
          style: GoogleFonts.inter(
            fontSize: 15,
            color: Colors.grey.shade300,
            height: 1.65,
          ),
          maxLines: 5,
          overflow: TextOverflow.clip,
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 60,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  const Color(0xFF111827).withOpacity(0.8),
                  const Color(0xFF111827),
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
            ),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF84CC16).withOpacity(0.2),
                            const Color(0xFF84CC16).withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF84CC16).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const FaIcon(
                            FontAwesomeIcons.chevronDown,
                            size: 10,
                            color: Color(0xFF84CC16),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Read more',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF84CC16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFullContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.content,
          style: GoogleFonts.inter(
            fontSize: 15,
            color: Colors.grey.shade300,
            height: 1.65,
          ),
        ),
        if (_isLongContent) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _isContentExpanded = false);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FaIcon(
                    FontAwesomeIcons.chevronUp,
                    size: 10,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Show less',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTruthMeterCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF111827).withOpacity(0.8),
              Colors.black.withOpacity(0.4),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withOpacity(0.04),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: widget.truthMeterWidget,
        ),
      ),
    );
  }

  Widget _buildActionRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.05),
            width: 1,
          ),
        ),
      ),
      child: widget.showSignInPrompt
          ? _buildSignInPrompt()
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCommentButton(),
                if (widget.onShare != null)
                  _ActionButton(
                    icon: FontAwesomeIcons.shareNodes,
                    label: 'Share',
                    onTap: widget.onShare!,
                  ),
                _FunnyActionButton(
                  count: widget.funnyCount,
                  onTap: widget.onFunnyVote,
                ),
              ],
            ),
    );
  }

  Widget _buildSignInPrompt() {
    // Extreme Simplification: Never show sign-in prompt.
    // Interactions should be enabled for everyone (anonymous).
    return const SizedBox.shrink();
  }

  Widget _buildCommentButton() {
    final hasComments = widget.commentCount > 0;
    final buttonText = !hasComments ? 'Comment' : '${widget.commentCount}';

    if (widget.onToggleComments == null) {
      return const SizedBox.shrink();
    }

    return _ActionButton(
      icon: FontAwesomeIcons.comment,
      label: buttonText,
      onTap: widget.onToggleComments!,
      isActive: widget.isCommentsExpanded,
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat.MMMd().format(dateTime);
    }
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? Colors.white.withOpacity(0.2) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            FaIcon(icon, size: 14, color: isActive ? Colors.white : Colors.grey.shade400),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                color: isActive ? Colors.white : Colors.grey.shade400,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Enhanced Funny Button with orange/coral color, hover effects, dynamic sizing,
/// and laugh wiggle animation on click
class _FunnyActionButton extends StatefulWidget {
  final int count;
  final VoidCallback? onTap;

  const _FunnyActionButton({
    required this.count,
    this.onTap,
  });

  @override
  State<_FunnyActionButton> createState() => _FunnyActionButtonState();
}

class _FunnyActionButtonState extends State<_FunnyActionButton>
    with TickerProviderStateMixin {
  bool _isHovered = false;
  int _previousCount = 0;
  
  // Animation controllers
  late AnimationController _pressController;
  late AnimationController _laughController;
  late AnimationController _pulseController;
  late AnimationController _countPopController;
  
  // Animations
  late Animation<double> _pressScale;
  late Animation<double> _laughWiggle;
  late Animation<double> _pulseAnimation;
  late Animation<double> _countPopScale;

  // Orange/Coral color - psychologically associated with fun/humor
  static const Color _funnyColor = Color(0xFFF97316);

  @override
  void initState() {
    super.initState();
    _previousCount = widget.count;
    
    // Press animation (scale down on press)
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _pressScale = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
    
    // Laugh wiggle animation (shake side-to-side)
    _laughController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _laughWiggle = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.08), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.08, end: -0.08), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -0.08, end: 0.06), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.06, end: -0.04), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -0.04, end: 0.02), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.02, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _laughController, curve: Curves.easeOut));
    
    // Background pulse animation
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _pulseAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeOut));
    
    // Count pop animation (when count increases)
    _countPopController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _countPopScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 0.9), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.1), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _countPopController, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(_FunnyActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Trigger count pop animation when count increases
    if (widget.count > _previousCount) {
      _countPopController.forward(from: 0);
    }
    _previousCount = widget.count;
  }

  @override
  void dispose() {
    _pressController.dispose();
    _laughController.dispose();
    _pulseController.dispose();
    _countPopController.dispose();
    super.dispose();
  }

  /// Calculate dynamic size multiplier based on vote count
  double get _sizeMultiplier {
    if (widget.count >= 20) return 1.2;  // Very popular
    if (widget.count >= 6) return 1.1;   // Popular  
    return 1.0;                           // Normal
  }

  /// Calculate glow intensity based on popularity
  double get _glowIntensity {
    if (widget.count >= 20) return 0.5;
    if (widget.count >= 6) return 0.3;
    if (widget.count >= 1) return 0.15;
    return 0.1;
  }

  void _handleTapDown(TapDownDetails details) {
    _pressController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _pressController.reverse();
  }

  void _handleTapCancel() {
    _pressController.reverse();
  }

  void _handleTap() {
    // Trigger haptic feedback
    HapticFeedback.lightImpact();
    
    // Play pop sound (respects user preference)
    SoundService.playFunnyPop();
    
    // Start laugh wiggle animation
    _laughController.forward(from: 0);
    
    // Start pulse animation
    _pulseController.forward(from: 0);
    
    // Call the callback
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final baseIconSize = 20.0 * _sizeMultiplier;
    final baseFontSize = 14.0 * _sizeMultiplier;
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Tooltip(
        message: 'Mark as funny',
        preferBelow: false,
        child: GestureDetector(
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onTapCancel: _handleTapCancel,
          onTap: _handleTap,
          child: AnimatedBuilder(
            animation: Listenable.merge([_pressScale, _pulseAnimation]),
            builder: (context, child) {
              final combinedScale = _pressScale.value * 
                  (_isHovered ? 1.1 : 1.0) * 
                  _pulseAnimation.value;
              
              return Transform.scale(
                scale: combinedScale,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(
                    horizontal: 14 * _sizeMultiplier,
                    vertical: 10 * _sizeMultiplier,
                  ),
                  decoration: BoxDecoration(
                    color: _funnyColor.withOpacity(_isHovered ? 0.2 : 0.12),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _funnyColor.withOpacity(_isHovered ? 0.6 : 0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _funnyColor.withOpacity(_glowIntensity * (_isHovered ? 1.5 : 1.0)),
                        blurRadius: _isHovered ? 12 : 8,
                        spreadRadius: _isHovered ? 2 : 0,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Laughing icon with wiggle animation
                      AnimatedBuilder(
                        animation: _laughWiggle,
                        builder: (context, child) {
                          return Transform.rotate(
                            angle: _laughWiggle.value + (_isHovered ? 0.04 : 0),
                            child: FaIcon(
                              FontAwesomeIcons.faceLaughSquint,
                              size: baseIconSize,
                              color: _funnyColor,
                            ),
                          );
                        },
                      ),
                      // Show count if > 0 with pop animation
                      if (widget.count > 0) ...[
                        SizedBox(width: 8 * _sizeMultiplier),
                        AnimatedBuilder(
                          animation: _countPopScale,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _countPopScale.value,
                              child: Text(
                                '${widget.count}',
                                style: GoogleFonts.inter(
                                  color: _funnyColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: baseFontSize,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                      // Fire indicator for very popular posts
                      if (widget.count >= 20) ...[
                        const SizedBox(width: 4),
                        const Text('🔥', style: TextStyle(fontSize: 14)),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}


