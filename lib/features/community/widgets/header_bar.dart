import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/globals.dart';
import '../../../services/analytics_service.dart';
import '../../../services/anonymous_id_service.dart';
import '../providers/community_providers.dart';
import '../providers/watch_provider.dart';
import '../../../providers/presence_provider.dart';

// --- HEADER BAR ---
class HeaderBar extends ConsumerStatefulWidget {
  final Function(String) onSearchChanged;
  final Future<void> Function()? onRefresh;
  final bool isRefreshing;
  final DateTime? lastRefreshedAt;

  const HeaderBar({
    super.key,
    required this.onSearchChanged,
    this.onRefresh,
    this.isRefreshing = false,
    this.lastRefreshedAt,
  });

  @override
  ConsumerState<HeaderBar> createState() => _HeaderBarState();
}

class _HeaderBarState extends ConsumerState<HeaderBar> {
  bool isSearchExpanded = false;
  final searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    widget.onSearchChanged(query);
    // Debounce analytics logging to avoid excessive events
    _searchDebounce?.cancel();
    if (query.length >= 3) {
      _searchDebounce = Timer(const Duration(milliseconds: 800), () {
        AnalyticsService.instance.logSearch(searchTerm: query);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 400;
    final isMediumScreen = MediaQuery.of(context).size.width < 600;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (!isSearchExpanded) ...[
            Expanded(
              child: Row(
                children: [
                  Image.asset(
                    'assets/images/app_icon_foreground.png',
                    height: 32,
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'Agnonymous',
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: isSmallScreen ? 19 : 22,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (!isSmallScreen) _buildLiveBadge(ref),
                ],
              ),
            ),
            if (!isMediumScreen && widget.lastRefreshedAt != null) ...[
              const SizedBox(width: 12),
              Text(
                _statusText(),
                style: GoogleFonts.inter(
                  color: Colors.grey.shade500,
                  fontSize: 11,
                ),
              ),
            ],
            if (isMediumScreen)
              IconButton(
                icon: const FaIcon(FontAwesomeIcons.magnifyingGlass, size: 18),
                onPressed: () {
                  setState(() {
                    isSearchExpanded = true;
                  });
                },
                color: Colors.grey.shade400,
              ),
            if (!isMediumScreen) ...[
              _buildSearchField(),
              const SizedBox(width: 12),
            ],
            _RefreshHeaderButton(
              isRefreshing: widget.isRefreshing,
              onRefresh: widget.onRefresh,
            ),
            _IdentityMenuButton(),
          ] else ...[
            // Expanded search mode for mobile
            Expanded(
              child: TextField(
                controller: searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search posts...',
                  prefixIcon:
                      const Icon(FontAwesomeIcons.magnifyingGlass, size: 16),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        isSearchExpanded = false;
                        searchController.clear();
                        widget.onSearchChanged('');
                      });
                    },
                  ),
                  filled: true,
                  fillColor: Colors.black.withOpacity(0.2),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: _onSearchChanged,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 200),
      child: SizedBox(
        height: 40,
        child: TextField(
          controller: searchController,
          decoration: InputDecoration(
            hintText: 'Search posts...',
            prefixIcon: const Icon(FontAwesomeIcons.magnifyingGlass, size: 16),
            filled: true,
            fillColor: Colors.black.withOpacity(0.2),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: _onSearchChanged,
        ),
      ),
    );
  }

  Widget _buildLiveBadge(WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF22C55E),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Color(0xFF22C55E), blurRadius: 4),
              ],
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .fadeIn(duration: 1000.ms)
              .fadeOut(delay: 1000.ms),
          const SizedBox(width: 6),
          Text(
            '${ref.watch(presenceProvider)} Online',
            style: GoogleFonts.robotoMono(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _statusText() {
    if (widget.isRefreshing) return 'Checking...';
    final refreshedAt = widget.lastRefreshedAt;
    if (refreshedAt == null) return '';
    final difference = DateTime.now().difference(refreshedAt);
    if (difference.inMinutes < 1) return 'Updated just now';
    return 'Updated ${difference.inMinutes}m ago';
  }
}

class _RefreshHeaderButton extends StatelessWidget {
  final bool isRefreshing;
  final Future<void> Function()? onRefresh;

  const _RefreshHeaderButton({
    required this.isRefreshing,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: isRefreshing
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const FaIcon(FontAwesomeIcons.arrowsRotate, size: 18),
      color: Colors.white70,
      tooltip: 'Refresh',
      onPressed: isRefreshing || onRefresh == null ? null : onRefresh,
    );
  }
}

class _IdentityMenuButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: 'Identity',
      icon: const FaIcon(
        FontAwesomeIcons.ellipsisVertical,
        size: 18,
        color: Colors.white70,
      ),
      color: const Color(0xFF1F2937),
      itemBuilder: (context) => const [
        PopupMenuItem<String>(
          value: 'reset',
          child: Row(
            children: [
              FaIcon(FontAwesomeIcons.arrowRotateLeft,
                  size: 14, color: Colors.white70),
              SizedBox(width: 10),
              Text(
                'Reset anonymous identity',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ],
      onSelected: (value) async {
        if (value == 'reset') {
          await _showResetDialog(context, ref);
        }
      },
    );
  }

  Future<void> _showResetDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        title: const Text(
          'Reset anonymous identity?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'A new anonymous device id will be generated. Your watched threads '
          'and any device-only history will be cleared. Posts, comments, and '
          'votes already published remain on the board.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(
              'Reset',
              style: TextStyle(
                  color: Color(0xFF84CC16), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await AnonymousIdService.resetAnonymousId();
      await ref.read(watchedThreadsProvider.notifier).clearAll();
    } catch (e) {
      logger.w('Anonymous id reset failed: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reset failed. Try again in a moment.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Anonymous identity reset.'),
          backgroundColor: Color(0xFF84CC16),
        ),
      );
    }
  }
}

// --- GLOBAL STATS HEADER ---
class GlobalStatsHeader extends ConsumerWidget {
  const GlobalStatsHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(globalStatsProvider);
    final isVerySmallScreen = MediaQuery.of(context).size.width < 350;

    return statsAsync.when(
      loading: () => const SizedBox(
        height: 36,
        width: 36,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (err, stack) => const FaIcon(
        FontAwesomeIcons.triangleExclamation,
        color: Colors.red,
        size: 20,
      ),
      data: (stats) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatItem(
            label: isVerySmallScreen ? 'P' : 'Posts',
            value: NumberFormat.compact().format(stats.totalPosts),
          ),
          const SizedBox(width: 12),
          _StatItem(
            label: isVerySmallScreen ? 'V' : 'Votes',
            value: NumberFormat.compact().format(stats.totalVotes),
          ),
          const SizedBox(width: 12),
          _StatItem(
            label: isVerySmallScreen ? 'C' : 'Comments',
            value: NumberFormat.compact().format(stats.totalComments),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
