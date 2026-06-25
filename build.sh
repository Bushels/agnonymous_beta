#!/bin/bash
set -e  # Exit on error

# Install Flutter (clone exact 3.41.7 tag, minimal depth for speed)
git clone https://github.com/flutter/flutter.git -b 3.41.7 --depth 1

export PATH="$PWD/flutter/bin:$PATH"

# Verify and prepare
flutter doctor
flutter pub get

# Build web with env vars (passed from Vercel)
flutter build web --release --dart-define=SUPABASE_URL=$SUPABASE_URL --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY

# Copy the updated Vercel production configuration containing the correct CSP rules to build/web
cp deploy/vercel.prod.json build/web/vercel.json