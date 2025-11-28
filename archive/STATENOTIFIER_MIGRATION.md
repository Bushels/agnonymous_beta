# StateNotifier to Notifier Migration

## Issue

The application was failing to compile with multiple errors related to `StateNotifier`:

```
Type 'StateNotifier' not found.
Method not found: 'StateNotifierProvider'.
The getter 'state' isn't defined for the type 'PaginatedPostsNotifier'.
The setter 'state' isn't defined for the type 'AuthNotifier'.
Superclass has no method named 'dispose'.
```

### Root Cause

The project uses `flutter_riverpod: ^3.0.3` (Riverpod 3.x). In Riverpod 2.0, `StateNotifier` was deprecated, and in **Riverpod 3.0, it was completely removed**.

The code was using the old `StateNotifier` pattern:
- `class AuthNotifier extends StateNotifier<AuthState>`
- `StateNotifierProvider<AuthNotifier, AuthState>`

## Solution

Migrated from `StateNotifier` to the new `Notifier` pattern introduced in Riverpod 2.0+.

### Migration Changes

#### 1. Class Definition

**Before:**
```dart
class PaginatedPostsNotifier extends StateNotifier<PaginatedPostsState> {
  PaginatedPostsNotifier(this.ref) : super(const PaginatedPostsState()) {
    _initRealTime();
    loadPostsForCategory('all', isInitial: true);
  }
  final Ref ref;
  // ...
}
```

**After:**
```dart
class PaginatedPostsNotifier extends Notifier<PaginatedPostsState> {
  @override
  PaginatedPostsState build() {
    _initRealTime();
    loadPostsForCategory('all', isInitial: true);
    return const PaginatedPostsState();
  }
  // Note: 'ref' is automatically available in Notifier classes
}
```

#### 2. Provider Declaration

**Before:**
```dart
final paginatedPostsProvider = StateNotifierProvider<PaginatedPostsNotifier, PaginatedPostsState>((ref) {
  return PaginatedPostsNotifier(ref);
});
```

**After:**
```dart
final paginatedPostsProvider = NotifierProvider<PaginatedPostsNotifier, PaginatedPostsState>(
  PaginatedPostsNotifier.new,
);
```

#### 3. Dispose Logic

**Before:**
```dart
@override
void dispose() {
  _postsChannel?.unsubscribe();
  super.dispose();
}
```

**After:**
```dart
@override
PaginatedPostsState build() {
  // ... initialization logic ...

  // Clean up when disposed
  ref.onDispose(() {
    _postsChannel?.unsubscribe();
  });

  return const PaginatedPostsState();
}
```

### Key Differences Between StateNotifier and Notifier

| Aspect | StateNotifier (deprecated) | Notifier (current) |
|--------|---------------------------|-------------------|
| Base class | `StateNotifier<T>` | `Notifier<T>` |
| Provider | `StateNotifierProvider` | `NotifierProvider` |
| Initial state | Passed to `super()` | Returned from `build()` |
| Ref access | Passed via constructor | Automatically available via `ref` |
| Disposal | Override `dispose()` | Use `ref.onDispose()` callback |
| Package | Required `state_notifier` | Built into `flutter_riverpod` |

### Files Modified

1. **lib/main.dart** (line ~367)
   - `PaginatedPostsNotifier` class migrated to `Notifier`
   - Provider declaration updated to `NotifierProvider`

2. **lib/providers/auth_provider.dart** (line ~39)
   - `AuthNotifier` class migrated to `Notifier`
   - Provider declaration updated to `NotifierProvider`

## References

- [Riverpod Migration Guide](https://riverpod.dev/docs/migration/from_state_notifier)
- [Notifier documentation](https://riverpod.dev/docs/providers/notifier_provider)
