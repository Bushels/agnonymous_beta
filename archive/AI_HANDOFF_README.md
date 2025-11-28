# AI Agent Handoff Documentation - Agnonymous Beta

## Project Overview

**Agnonymous** is a Flutter-based anonymous agricultural community platform where farmers and agriculture professionals can share posts, vote on content truthfulness, and engage in discussions while maintaining complete anonymity.

### Core Purpose
- Create a safe space for agricultural professionals to share experiences and concerns
- Allow community-driven fact-checking through a voting system (True/Partial/False)
- Provide real-time statistics and trending topics in agriculture
- Enable anonymous but accountable discussions

## Tech Stack

- **Frontend**: Flutter (Dart)
- **Backend**: Supabase (PostgreSQL, Auth, Realtime)
- **State Management**: Riverpod
- **Deployment**: 
  - Web: Vercel (primary) and Firebase Hosting (secondary)
  - Mobile: Android/iOS apps
- **Styling**: Material Design 3, Google Fonts, Font Awesome icons

## Current Project State

### What's Working
1. **Core Functionality**
   - Anonymous user authentication via Supabase
   - Post creation with categories (Farming, Livestock, Ranching, etc.)
   - Real-time post feed with sorting by newest
   - Truth voting system (True/Partial/False) with visual meter
   - Comment system on posts
   - Real-time updates for votes and comments

2. **UI Features**
   - Dark theme optimized for agricultural professionals
   - Responsive design (partially working)
   - Global statistics dashboard (Posts, Votes, Comments counts)
   - Trending section showing popular category and post
   - Category icons for visual identification

3. **Deployment**
   - Successfully deployed to Firebase Hosting
   - Vercel deployment configured but has environment variable issues

### Current Problems

1. **Android App Issues**
   - RenderFlex overflow errors on small screens (lines 447 and 701 in main.dart)
   - Vote buttons too wide for mobile screens
   - Global stats header not displaying on mobile
   - App icons appear too small despite correct pixel dimensions

2. **Environment Configuration**
   - Dual approach causing confusion:
     - Local: Uses .env file with flutter_dotenv
     - Production: Uses --dart-define with String.fromEnvironment
   - Vercel build failing to inject environment variables properly

3. **Realtime Connection**
   - "RealtimeSubscribeException" errors appearing
   - Supabase realtime connection issues (may be configuration related)

4. **Responsive Design**
   - Layout not truly responsive for all screen sizes
   - Fixed widths causing overflow on mobile devices
   - No tablet-optimized layouts

## File Structure & Key Files

```
agnonymous_beta/
├── lib/
│   ├── main.dart              # Main app file (1000+ lines, needs refactoring)
│   ├── create_post_screen.dart # Post creation UI
│   └── env_config.dart        # Environment variable handler (deprecated)
├── web/
│   └── index.html             # Has hardcoded Supabase credentials
├── android/                   # Android-specific files
├── .env                       # Local environment variables
├── .env.example              # Template for environment setup
├── firebase.json             # Firebase hosting config
├── vercel.json              # Vercel deployment config
└── pubspec.yaml             # Flutter dependencies
```

## Environment Variables

```
SUPABASE_URL=https://ibgsloyjxdopkvwqcqwh.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

## Database Schema (Supabase)

### Tables:
1. **posts**
   - id, title, content, category, created_at, anonymous_user_id
   - Has computed field for comment_count

2. **comments**
   - id, post_id, content, created_at, anonymous_user_id

3. **truth_votes**
   - id, post_id, anonymous_user_id, vote_type (true/partial/false)

### RPC Functions:
- `get_post_vote_stats(post_id)` - Returns vote counts
- `get_global_stats()` - Returns total posts, votes, comments
- `get_trending_stats()` - Returns trending category and popular post
- `cast_user_vote(post_id, user_id, vote_type)` - Handles vote logic

## What Needs to Be Done

### Immediate Fixes
1. **Fix Android Layout Issues**
   - Implement proper responsive design using LayoutBuilder
   - Fix VoteButtons overflow (consider icons-only on mobile)
   - Fix GlobalStatsHeader visibility on mobile
   - Test on multiple screen sizes

2. **Standardize Environment Variables**
   - Choose one approach (recommend --dart-define for all platforms)
   - Update documentation
   - Fix Vercel deployment

3. **Fix App Icons**
   - Create properly sized icons without excess padding
   - Consider using flutter_launcher_icons package
   - Implement adaptive icons for Android

### Future Enhancements
1. **Code Refactoring**
   - Split main.dart into multiple files (widgets/, screens/, models/, services/)
   - Implement proper error handling
   - Add loading states for all async operations

2. **Features**
   - User profiles (while maintaining anonymity)
   - Post categories filtering
   - Search functionality (currently UI-only)
   - Image upload support
   - Push notifications

3. **Testing**
   - Add widget tests
   - Integration tests for Supabase operations
   - Test on various devices and screen sizes

4. **Performance**
   - Implement pagination for posts
   - Optimize real-time subscriptions
   - Add caching for better offline support

## Development Commands

```bash
# Run locally
flutter run -d chrome

# Run on Android with environment variables
flutter run -d emulator --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...

# Build for web
flutter build web

# Deploy to Firebase
firebase deploy

# Generate app icons
flutter pub run flutter_launcher_icons
```

## Known Quirks & Gotchas

1. The app uses anonymous auth - each browser/device gets a new anonymous user
2. Real-time features may not work in development due to Supabase connection limits
3. The .env file is listed in pubspec.yaml assets, which causes issues with web builds
4. Vote buttons use withAlpha(204) for transparency, which may not render consistently
5. The trending stats use a SQL view that may need optimization for larger datasets

## Next Steps for New AI Agent

1. **Priority 1**: Fix the Android overflow issues by implementing proper responsive design
2. **Priority 2**: Standardize environment variable handling across all platforms
3. **Priority 3**: Refactor main.dart into smaller, manageable components
4. **Priority 4**: Add proper error handling and loading states
5. **Priority 5**: Implement search and filtering functionality

## Contact & Resources

- Supabase Dashboard: Access needed for database schema changes
- Firebase Console: For hosting management
- Vercel Dashboard: For web deployment
- Design inspiration: Agricultural community needs simplicity and clarity

Remember: The farming community values practical, straightforward tools. Keep the UI simple and focused on core functionality.