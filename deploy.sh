#!/bin/bash
# ============================================================================
# Agnonymous Beta - Firebase Deployment Script
# ============================================================================
# This script builds and deploys the app to Firebase Hosting
# ============================================================================

set -e  # Exit on error

echo "🚀 Starting Agnonymous Beta deployment..."
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Step 1: Install dependencies
echo "📦 Installing Flutter dependencies..."
flutter pub get
echo -e "${GREEN}✅ Dependencies installed${NC}"
echo ""

# Step 2: Clean previous build
echo "🧹 Cleaning previous build..."
flutter clean
echo -e "${GREEN}✅ Clean complete${NC}"
echo ""

# Step 3: Build for web (production)
echo "🔨 Building Flutter web app (release mode)..."
flutter build web --release \
  --dart-define=SUPABASE_URL=https://ibgsloyjxdopkvwqcqwh.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImliZ3Nsb3lqeGRvcGt2d3FjcXdoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTI2ODYzMzksImV4cCI6MjA2ODI2MjMzOX0.Ik1980vz4s_UxVuEfBm61-kcIzEH-Nt-hQtydZUeNTw

echo -e "${GREEN}✅ Build complete${NC}"
echo ""

# Step 4: Deploy to Firebase
echo "🌐 Deploying to Firebase Hosting..."
firebase deploy --only hosting

echo ""
echo -e "${GREEN}✅ Deployment complete!${NC}"
echo ""
echo "🎉 Your app is now live at: https://agnonymousbeta.web.app"
echo ""
echo -e "${YELLOW}⚠️  IMPORTANT REMINDERS:${NC}"
echo "1. Run database migrations in Supabase SQL Editor:"
echo "   - database_migrations/001_fix_vote_types.sql (optional verification)"
echo "   - database_migrations/002_install_comment_count_triggers.sql (REQUIRED)"
echo ""
echo "2. Test the following features:"
echo "   - XSS protection (try posting HTML tags)"
echo "   - Comment counts (add comments and watch counts update)"
echo "   - Security headers (curl -I https://agnonymousbeta.web.app)"
echo ""
echo "3. Monitor Firebase console for any errors"
echo ""
echo "📖 See SECURITY_FIXES.md and COMMENT_COUNT_FIX.md for details"
