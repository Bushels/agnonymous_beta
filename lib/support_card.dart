// support_card.dart — reader support / "tip jar" widget
//
// Tip-jar surface for the anonymous board. Payment-provider-agnostic:
// every tier has a click-through URL, swap any time. Currently wired
// to PayPal.Me/buperac.
//
// To swap providers later (Stripe, Ko-fi, Shopify, etc.), edit `tiers`
// and `customAmountUrl` below — no widget code needs to change.
//
// Styled with the April 2026 relaunch's BoardColors/BoardText tokens
// (prairie amber on clay) so it sits naturally between the trending
// section and the post feed without looking like a transplanted v2
// glass component.

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'features/community/board_theme.dart';

class SupportConfig {
  static const String customAmountUrl = 'https://paypal.me/buperac';
  static const List<SupportTier> tiers = [
    SupportTier(label: r'$5', amount: 5, url: 'https://paypal.me/buperac/5'),
    SupportTier(label: r'$20', amount: 20, url: 'https://paypal.me/buperac/20'),
    SupportTier(label: r'$50', amount: 50, url: 'https://paypal.me/buperac/50'),
  ];
}

class SupportTier {
  final String label;
  final int amount;
  final String url;
  const SupportTier({
    required this.label,
    required this.amount,
    required this.url,
  });
}

Future<void> _openSupportUrl(String url) async {
  final uri = Uri.parse(url);
  // Force external browser/app — opening PayPal inside a webview iframe
  // breaks PayPal's anti-fraud checks and produces a degraded checkout.
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// Full-width support card — used at the top of the post feed.
class SupportCard extends StatelessWidget {
  final String headline;
  final String sub;
  final String? signoff;
  final EdgeInsetsGeometry margin;

  const SupportCard({
    super.key,
    this.headline = 'Being Agnonymous comes with risks.',
    this.sub =
        'Anonymous reporting attracts cease-and-desists, takedown threats, and legal pressure from people who would rather farmers stayed quiet. Your support keeps this board open. One-time, processed by PayPal, no account needed if you pay by card.',
    this.signoff = '~bushels',
    this.margin = const EdgeInsets.fromLTRB(14, 4, 14, 12),
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: Container(
          margin: margin,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: BoardColors.paper,
            borderRadius: BorderRadius.circular(12),
            border: Border(
              left: BorderSide(color: BoardColors.amber, width: 3),
              top: BorderSide(color: BoardColors.line),
              right: BorderSide(color: BoardColors.line),
              bottom: BorderSide(color: BoardColors.line),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.20),
                blurRadius: 16,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                headline,
                style: BoardText.title.copyWith(fontSize: 18, height: 1.25),
              ),
              const SizedBox(height: 8),
              Text(
                sub,
                style: BoardText.body.copyWith(
                  color: BoardColors.muted,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
              if (signoff != null && signoff!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    signoff!,
                    style: BoardText.meta.copyWith(
                      fontFamily: 'monospace',
                      letterSpacing: 0.02,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              // Tier buttons + custom-amount link, wrapped so they stack on
              // narrow viewports instead of overflowing.
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final tier in SupportConfig.tiers)
                    _SupportTierButton(tier: tier),
                  _SupportCustomLink(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportTierButton extends StatelessWidget {
  final SupportTier tier;
  const _SupportTierButton({required this.tier});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => _openSupportUrl(tier.url),
      style: ElevatedButton.styleFrom(
        backgroundColor: BoardColors.amber,
        foregroundColor: const Color(0xFF1D1B12),
        minimumSize: const Size(64, 40),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          letterSpacing: 0.02,
        ),
      ),
      child: Text(tier.label),
    );
  }
}

class _SupportCustomLink extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => _openSupportUrl(SupportConfig.customAmountUrl),
      style: TextButton.styleFrom(
        foregroundColor: BoardColors.muted,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Custom amount', style: TextStyle(fontSize: 13)),
          SizedBox(width: 4),
          Icon(Icons.arrow_forward, size: 14),
        ],
      ),
    );
  }
}

/// Small persistent "Support" link for use in header rows on wider
/// viewports — low-pressure always-visible affordance.
class SupportHeaderLink extends StatelessWidget {
  const SupportHeaderLink({super.key});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => _openSupportUrl(SupportConfig.customAmountUrl),
      icon: const FaIcon(
        FontAwesomeIcons.handHoldingHeart,
        size: 14,
        color: BoardColors.amber,
      ),
      label: const Text('Support', style: TextStyle(fontSize: 13)),
      style: TextButton.styleFrom(
        foregroundColor: BoardColors.ink,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
    );
  }
}
