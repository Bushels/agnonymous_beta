import 'package:flutter_test/flutter_test.dart';
import 'package:agnonymous_beta/providers/auth_provider.dart';

void main() {
  group('AuthState', () {
    test('creates with default values', () {
      const state = AuthState();

      expect(state.user, isNull);
      expect(state.profile, isNull);
      expect(state.isLoading, false);
      expect(state.error, isNull);
    });

    test('creates with isLoading true', () {
      const state = AuthState(isLoading: true);

      expect(state.isLoading, true);
    });

    test('creates with error message', () {
      const state = AuthState(error: 'Test error');

      expect(state.error, 'Test error');
    });

    group('isAuthenticated', () {
      test('returns false when user is null', () {
        const state = AuthState();

        expect(state.isAuthenticated, false);
      });

      // Note: Testing with actual User object would require mocking
      // Supabase User class which is not straightforward
    });

    group('isGuest', () {
      test('returns true when user is null', () {
        const state = AuthState();

        expect(state.isGuest, true);
      });
    });

    group('copyWith', () {
      test('preserves values when no arguments passed', () {
        const state = AuthState(isLoading: true, error: 'existing error');
        final copy = state.copyWith();

        expect(copy.isLoading, true);
        // Note: copyWith clears error unless explicitly passed
        expect(copy.error, isNull);
      });

      test('updates isLoading', () {
        const state = AuthState(isLoading: false);
        final copy = state.copyWith(isLoading: true);

        expect(copy.isLoading, true);
      });

      test('updates error', () {
        const state = AuthState();
        final copy = state.copyWith(error: 'new error');

        expect(copy.error, 'new error');
      });

      test('clears error when copying without error', () {
        const state = AuthState(error: 'old error');
        final copy = state.copyWith(isLoading: true);

        expect(copy.error, isNull);
      });

      test('preserves isLoading when only updating error', () {
        const state = AuthState(isLoading: true);
        final copy = state.copyWith(error: 'new error');

        expect(copy.isLoading, true);
        expect(copy.error, 'new error');
      });
    });

    group('state transitions', () {
      test('loading to loaded state', () {
        const loadingState = AuthState(isLoading: true);
        final loadedState = loadingState.copyWith(isLoading: false);

        expect(loadingState.isLoading, true);
        expect(loadedState.isLoading, false);
      });

      test('clear state to loading', () {
        const clearState = AuthState();
        final loadingState = clearState.copyWith(isLoading: true);

        expect(clearState.isLoading, false);
        expect(loadingState.isLoading, true);
      });

      test('loading to error state', () {
        const loadingState = AuthState(isLoading: true);
        final errorState = loadingState.copyWith(
          isLoading: false,
          error: 'Authentication failed',
        );

        expect(errorState.isLoading, false);
        expect(errorState.error, 'Authentication failed');
      });

      test('error to retry (loading) state', () {
        const errorState = AuthState(error: 'Previous error');
        final retryState = errorState.copyWith(isLoading: true);

        expect(retryState.isLoading, true);
        expect(retryState.error, isNull); // Error cleared by copyWith behavior
      });
    });

    group('edge cases', () {
      test('handles empty error string', () {
        const state = AuthState(error: '');

        expect(state.error, '');
      });

      test('handles very long error message', () {
        final longError = 'Error: ${'a' * 1000}';
        final state = AuthState(error: longError);

        expect(state.error, longError);
      });
    });
  });
}
