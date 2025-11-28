# Agnonymous Beta - Implementation Plan

## Overview
Agricultural transparency platform undergoing major revamp with authentication, user profiles, and gamification systems.

---

## Testing Status

### What's Working
- [x] Database schema fully deployed
- [x] All auth screens rendering correctly
- [x] Auth provider state management functional
- [x] User profile model complete with reputation logic
- [x] Glassmorphism widgets implemented
- [x] StateNotifier → Notifier migration complete (Riverpod 3.x)

### Needs Testing
- [ ] End-to-end signup → verification → login flow
- [ ] Email verification link handling
- [ ] Integration with post/comment creation (Phase 4)
- [ ] Forgot password flow (not yet implemented)

### Known Issues
- [ ] Signup screen missing password confirmation field
- [ ] Not all USA states are listed in the dropdown

---

## File Structure

```
lib/
├── models/
│   └── user_profile.dart          ✅ Complete
├── providers/
│   └── auth_provider.dart         ✅ Complete
├── screens/
│   └── auth/
│       ├── login_screen.dart      ✅ Complete
│       ├── signup_screen.dart     ✅ Complete (needs fixes)
│       └── verify_email_screen.dart ✅ Complete
└── widgets/
    └── glass_container.dart       ✅ Complete
```

---

## Phase Breakdown

### Phase 1: Database ✅ COMPLETE (100%)
- Database schema deployed
- All tables and triggers in place

### Phase 2: Authentication ✅ MOSTLY COMPLETE (85%)
**Completed:**
- Login screen
- Signup screen
- Email verification screen
- Auth state management (Notifier pattern)
- User profile model

**TODO:**
- [ ] Forgot password flow
- [ ] Password confirmation on signup
- [ ] Complete USA states list

### Phase 2.5: Visible Authentication & Guest Restrictions ✅ COMPLETE
**HeaderBar Integration:**
- "Sign In / Join" button for guest users
- Profile Avatar for authenticated users → links to ProfileScreen

**Guest Restrictions:**
- Voting: Shows "Sign In Required" dialog
- Comments: Input hidden, replaced with "Sign in to join" button

**Navigation:**
- Sign In actions → LoginScreen
- LoginScreen → SignupScreen link

### Phase 3: User Profile System 🔄 NOT STARTED (0%)
- [ ] Create profile viewing screen
- [ ] Implement profile editing
- [ ] Display reputation level with progress bar
- [ ] Show user statistics (posts, comments, votes)

### Phase 4: Post/Comment Updates 🔄 NOT STARTED (0%)
- [ ] Add "Post as" toggle (@username vs Anonymous)
- [ ] Implement badge system for post/comment authors
- [ ] Link posts/comments to user_id
- [ ] Add auth checks before posting

### Phase 5: Gamification Implementation 🔄 NOT STARTED (0%)
- [ ] Implement point calculation triggers
- [ ] Add vote weighting logic
- [ ] Calculate truth meter scores
- [ ] Award reputation points for actions

---

## Progress Summary

| Phase | Status | Completion |
|-------|--------|------------|
| Phase 1: Database | ✅ Complete | 100% |
| Phase 2: Authentication | ✅ Complete | 85% |
| Phase 2.5: Guest UX | ✅ Complete | 100% |
| Phase 3: User Profiles | 🔄 Not Started | 0% |
| Phase 4: Post Updates | 🔄 Not Started | 0% |
| Phase 5: Gamification | 🔄 Not Started | 0% |

**Overall Progress: ~25% complete**

---

## Immediate Priorities

1. **Fix Signup Issues**
   - Add password confirmation field
   - Add all USA states to dropdown

2. **Test Auth Flow**
   - Complete signup → verification → login flow
   - Verify email handling

3. **Begin Phase 3**
   - Profile viewing screen
   - Profile editing capability

---

## Technical Notes

### Riverpod 3.x Migration
The project uses `flutter_riverpod: ^3.0.3`. All state management uses the new `Notifier` pattern (not deprecated `StateNotifier`).

### Database
- Supabase backend
- Real-time subscriptions active for posts
- User profiles table with reputation tracking

### UI Framework
- Glassmorphism design system
- Dark theme with agricultural green accents
- Responsive layout support
