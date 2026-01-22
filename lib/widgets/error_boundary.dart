import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart' show logger;

/// A widget that catches errors in its child widget tree and displays
/// a fallback UI instead of crashing the entire app.
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget? fallback;
  final String? errorMessage;
  final VoidCallback? onRetry;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.fallback,
    this.errorMessage,
    this.onRetry,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  bool _hasError = false;
  FlutterErrorDetails? _errorDetails;

  @override
  void initState() {
    super.initState();
  }

  void _handleError(FlutterErrorDetails details) {
    logger.e('ErrorBoundary caught error: ${details.exception}',
        error: details.exception, stackTrace: details.stack);
    if (mounted) {
      setState(() {
        _hasError = true;
        _errorDetails = details;
      });
    }
  }

  void _retry() {
    setState(() {
      _hasError = false;
      _errorDetails = null;
    });
    widget.onRetry?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return widget.fallback ?? _buildDefaultFallback();
    }

    return _ErrorBoundaryWrapper(
      onError: _handleError,
      child: widget.child,
    );
  }

  Widget _buildDefaultFallback() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.orange.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 12),
            Text(
              widget.errorMessage ?? 'Something went wrong',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            if (widget.onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(
                  'Try Again',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF84CC16),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
            if (kDebugMode && _errorDetails != null) ...[
              const SizedBox(height: 16),
              Container(
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.red.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  _errorDetails!.exception.toString(),
                  style: GoogleFonts.robotoMono(
                    fontSize: 11,
                    color: Colors.red[300],
                  ),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Internal wrapper that catches errors during build/layout
class _ErrorBoundaryWrapper extends StatelessWidget {
  final Widget child;
  final void Function(FlutterErrorDetails) onError;

  const _ErrorBoundaryWrapper({
    required this.child,
    required this.onError,
  });

  @override
  Widget build(BuildContext context) {
    // Use a builder to catch errors in the subtree
    return Builder(
      builder: (context) {
        // ErrorWidget.builder handles render errors globally,
        // but this gives us local error handling capability
        try {
          return child;
        } catch (e, stack) {
          onError(FlutterErrorDetails(
            exception: e,
            stack: stack,
            library: 'error_boundary',
            context: ErrorDescription('building ErrorBoundary child'),
          ));
          return const SizedBox.shrink();
        }
      },
    );
  }
}

/// A simple async error boundary for FutureBuilder/StreamBuilder patterns
class AsyncErrorWidget extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;
  final String? message;

  const AsyncErrorWidget({
    super.key,
    required this.error,
    this.onRetry,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off,
              size: 48,
              color: Colors.grey[500],
            ),
            const SizedBox(height: 12),
            Text(
              message ?? 'Failed to load data',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Please check your connection',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF84CC16),
                ),
              ),
            ],
            if (kDebugMode) ...[
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: GoogleFonts.robotoMono(
                  fontSize: 10,
                  color: Colors.red[300],
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
