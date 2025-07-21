# Update Web Icons Guide

## Required Icon Sizes

Replace these files in the `web/` directory with your logo:

1. **web/favicon.png** - 32x32px (browser tab icon)
2. **web/icons/Icon-192.png** - 192x192px 
3. **web/icons/Icon-512.png** - 512x512px
4. **web/icons/Icon-maskable-192.png** - 192x192px (with padding for Android)
5. **web/icons/Icon-maskable-512.png** - 512x512px (with padding for Android)

## Steps:

1. Create your logo in these exact pixel sizes
2. Replace the existing files
3. Run: `flutter build web --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`
4. Deploy: `firebase deploy`

## Maskable Icons

For maskable icons (Android adaptive), ensure your logo is centered with at least 20% padding around the edges.

## Tools:

- [Favicon Generator](https://favicon.io/) - Generate all sizes from one image
- [Maskable.app](https://maskable.app/) - Test maskable icons
- [PWA Asset Generator](https://www.pwabuilder.com/imageGenerator) - Generate all PWA icons