#!/bin/bash
set -e  # Exit on error

# Install Flutter (clone stable branch, minimal depth for speed)
git clone https://github.com/flutter/flutter.git -b stable --depth 1
export PATH="$PWD/flutter/bin:$PATH"

# Verify and prepare
flutter doctor
flutter pub get

# Build web with env vars (passed from Vercel)
flutter build web --release --dart-define=SUPABASE_URL=$SUPABASE_URL --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY

# Optional: Optimize (minify JS, etc., but Flutter does this by default)