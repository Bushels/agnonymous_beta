import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show OtpType;
import '../../widgets/glass_container.dart';
import '../../main.dart' show supabase, logger;
import 'login_screen.dart';

/// Screen shown when user needs to verify their email
/// Can be used after signup or when accessing features requiring verification
class VerifyEmailScreen extends StatefulWidget {
  final String? email;
  final bool showBackButton;

  const VerifyEmailScreen({
    super.key,
    this.email,
    this.showBackButton = true,
  });

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _isResending = false;
  bool _resendSuccess = false;
  String? _resendError;
  int _resendCooldown = 0;

  @override
  void initState() {
    super.initState();
    // Start cooldown timer if user just signed up
    _startCooldownTimer();
  }

  void _startCooldownTimer() {
    // 60 second cooldown between resends
    _resendCooldown = 60;
    _tick();
  }

  void _tick() {
    if (_resendCooldown > 0 && mounted) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() => _resendCooldown--);
          _tick();
        }
      });
    }
  }

  Future<void> _resendVerificationEmail() async {
    if (widget.email == null || widget.email!.isEmpty) {
      setState(() => _resendError = 'Email address not available');
      return;
    }

    setState(() {
      _isResending = true;
      _resendError = null;
      _resendSuccess = false;
    });

    try {
      await supabase.auth.resend(
        type: OtpType.signup,
        email: widget.email!,
      );

      if (mounted) {
        setState(() {
          _resendSuccess = true;
          _isResending = false;
        });
        _startCooldownTimer();
      }
    } catch (e) {
      logger.e('Resend verification error: $e');
      if (mounted) {
        String errorMsg = 'Failed to resend email.';
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('rate limit') || errorStr.contains('too many')) {
          errorMsg = 'Please wait before requesting another email.';
        }
        setState(() {
          _resendError = errorMsg;
          _isResending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF111827), Color(0xFF1F2937)],
              ),
            ),
          ),

          // Back button
          if (widget.showBackButton)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
              ),
            ),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: GlassContainer(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF84CC16).withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mark_email_unread_outlined,
                        size: 48,
                        color: Color(0xFF84CC16),
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      'Verify Your Email',
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'We sent a verification link to:',
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Text(
                      widget.email ?? 'your email address',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Info box
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue.shade300, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Why verify?',
                                  style: GoogleFonts.inter(
                                    color: Colors.blue.shade300,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '• Get the Verified badge on your posts\n'
                            '• Unlock full reputation features\n'
                            '• Recover your account if needed',
                            style: GoogleFonts.inter(
                              color: Colors.white60,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Resend feedback
                    if (_resendSuccess) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF84CC16).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF84CC16).withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle, color: Color(0xFF84CC16), size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Verification email sent!',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF84CC16),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (_resendError != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              _resendError!,
                              style: GoogleFonts.inter(
                                color: Colors.red.shade300,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Resend Button
                    OutlinedButton(
                      onPressed: (_isResending || _resendCooldown > 0 || widget.email == null)
                          ? null
                          : _resendVerificationEmail,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withOpacity(0.3)),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        disabledForegroundColor: Colors.white38,
                      ),
                      child: _isResending
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _resendCooldown > 0
                                  ? 'Resend in ${_resendCooldown}s'
                                  : 'Resend verification email',
                              style: GoogleFonts.inter(fontSize: 14),
                            ),
                    ),
                    const SizedBox(height: 16),

                    // Back to Login Button
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (route) => false,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF84CC16),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Back to Sign In',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Help text
                    Text(
                      'Check your spam folder if you don\'t see the email.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
