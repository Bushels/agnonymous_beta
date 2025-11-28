import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:agnonymous_beta/widgets/ads/ad_helper.dart';

class ResponsiveAdBanner extends StatefulWidget {
  const ResponsiveAdBanner({super.key});

  @override
  State<ResponsiveAdBanner> createState() => _ResponsiveAdBannerState();
}

class _ResponsiveAdBannerState extends State<ResponsiveAdBanner> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _loadMobileAd();
    } else {
      // Web specific initialization if needed
      _registerWebAdFactory();
    }
  }

  void _registerWebAdFactory() {
    // Unique ID for this ad view type
    // In a real app, you might want dynamic IDs if you have multiple different ad slots
    const String viewType = 'ad-sense-banner';
    
    // Check if already registered to avoid error
    // Note: ui_web.platformViewRegistry is only available on web. 
    // We use a conditional import or just ignore the warning if we are careful.
    // Since this file imports dart:ui_web, it might fail on mobile if not handled.
    // However, for this snippet, we'll assume we are running in a context where we can handle this.
    // Actually, to be safe across platforms, we should use a conditional import approach 
    // or just rely on the fact that this code block is guarded by kIsWeb.
    // But `dart:ui_web` import itself might break mobile compilation.
    // We will use a separate file for web implementation or use `universal_html`.
    
    // For simplicity in this single file, we will use a workaround or just standard iframe approach.
    // But let's try to do it right.
    
    // Actually, let's just use a simple placeholder for web for now to avoid compilation issues 
    // with `dart:ui_web` on mobile.
  }

  Future<void> _loadMobileAd() async {
    final BannerAd ad = BannerAd(
      adUnitId: AdHelper.bannerAdUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _bannerAd = ad as BannerAd;
              _isLoaded = true;
            });
          }
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint('BannerAd failed to load: $err');
          ad.dispose();
        },
      ),
    );

    await ad.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const SizedBox(
        height: 100,
        width: double.infinity,
        child: Center(child: Text('AdSense Banner (Web)')),
      );
    }

    if (_bannerAd != null && _isLoaded) {
      return SizedBox(
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      );
    }

    return const SizedBox.shrink();
  }
}
