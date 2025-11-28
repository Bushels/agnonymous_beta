import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Standard glassmorphism container with refined luxury aesthetics
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final Color color;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;
  final Gradient? gradient;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 10.0,
    this.opacity = 0.1,
    this.color = Colors.white,
    this.borderRadius,
    this.padding,
    this.margin,
    this.border,
    this.boxShadow,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(16);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: boxShadow ?? [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: -5,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              gradient: gradient,
              color: gradient == null ? color.withOpacity(opacity) : null,
              borderRadius: radius,
              border: border ?? Border.all(
                color: Colors.white.withOpacity(0.12),
                width: 1.0,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Luxury glass container with ambient glow and premium effects
class LuxuryGlassContainer extends StatefulWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final Color color;
  final Color? glowColor;
  final double glowIntensity;
  final bool enableGlow;
  final bool enableShimmer;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  const LuxuryGlassContainer({
    super.key,
    required this.child,
    this.blur = 15.0,
    this.opacity = 0.08,
    this.color = Colors.white,
    this.glowColor,
    this.glowIntensity = 0.3,
    this.enableGlow = true,
    this.enableShimmer = false,
    this.borderRadius,
    this.padding,
    this.margin,
    this.onTap,
  });

  @override
  State<LuxuryGlassContainer> createState() => _LuxuryGlassContainerState();
}

class _LuxuryGlassContainerState extends State<LuxuryGlassContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    if (widget.enableShimmer) {
      _shimmerController.repeat();
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(20);
    final effectiveGlowColor = widget.glowColor ?? const Color(0xFF84CC16);

    Widget container = Container(
      margin: widget.margin,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          // Depth shadow
          BoxShadow(
            color: Colors.black.withOpacity(_isPressed ? 0.3 : 0.2),
            blurRadius: _isPressed ? 15 : 25,
            spreadRadius: -8,
            offset: Offset(0, _isPressed ? 4 : 10),
          ),
          // Ambient glow
          if (widget.enableGlow)
            BoxShadow(
              color: effectiveGlowColor.withOpacity(widget.glowIntensity * 0.4),
              blurRadius: 30,
              spreadRadius: -10,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: widget.blur, sigmaY: widget.blur),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: widget.padding,
            decoration: BoxDecoration(
              // Subtle gradient fill
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  widget.color.withOpacity(widget.opacity * 1.2),
                  widget.color.withOpacity(widget.opacity * 0.8),
                ],
              ),
              borderRadius: radius,
              // Premium gradient border
              border: GradientBorder.uniform(
                width: 1.0,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.2),
                    Colors.white.withOpacity(0.05),
                    Colors.white.withOpacity(0.1),
                  ],
                ),
              ),
            ),
            child: widget.child,
          ),
        ),
      ),
    );

    // Add shimmer effect if enabled
    if (widget.enableShimmer) {
      container = AnimatedBuilder(
        animation: _shimmerController,
        builder: (context, child) {
          return ShaderMask(
            shaderCallback: (bounds) {
              return LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.0),
                  Colors.white.withOpacity(0.15),
                  Colors.white.withOpacity(0.0),
                ],
                stops: [
                  (_shimmerController.value - 0.3).clamp(0.0, 1.0),
                  _shimmerController.value,
                  (_shimmerController.value + 0.3).clamp(0.0, 1.0),
                ],
                transform: GradientRotation(math.pi / 4),
              ).createShader(bounds);
            },
            blendMode: BlendMode.srcATop,
            child: child,
          );
        },
        child: container,
      );
    }

    // Add tap handling
    if (widget.onTap != null) {
      container = GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap?.call();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: container,
        ),
      );
    }

    return container;
  }
}

/// Gradient border helper for premium glass effect
class GradientBorder extends BoxBorder {
  final Gradient gradient;
  final double width;

  const GradientBorder({
    required this.gradient,
    required this.width,
  });

  factory GradientBorder.uniform({
    required Gradient gradient,
    double width = 1.0,
  }) {
    return GradientBorder(gradient: gradient, width: width);
  }

  @override
  BorderSide get bottom => BorderSide.none;

  @override
  BorderSide get top => BorderSide.none;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(width);

  @override
  bool get isUniform => true;

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    TextDirection? textDirection,
    BoxShape shape = BoxShape.rectangle,
    BorderRadius? borderRadius,
  }) {
    final Paint paint = Paint()
      ..shader = gradient.createShader(rect)
      ..strokeWidth = width
      ..style = PaintingStyle.stroke;

    if (borderRadius != null) {
      canvas.drawRRect(
        borderRadius.toRRect(rect).deflate(width / 2),
        paint,
      );
    } else {
      canvas.drawRect(rect.deflate(width / 2), paint);
    }
  }

  @override
  ShapeBorder scale(double t) {
    return GradientBorder(
      gradient: gradient,
      width: width * t,
    );
  }
}

/// Frosted glass card with elegant styling
class FrostedCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? accentColor;
  final bool hasTopAccent;

  const FrostedCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 16,
    this.accentColor,
    this.hasTopAccent = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? const Color(0xFF84CC16);
    final radius = BorderRadius.circular(borderRadius);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: -5,
            offset: const Offset(0, 8),
          ),
          if (accentColor != null)
            BoxShadow(
              color: accent.withOpacity(0.15),
              blurRadius: 25,
              spreadRadius: -8,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: padding ?? const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1F2937).withOpacity(0.9),
                  const Color(0xFF111827).withOpacity(0.95),
                ],
              ),
              borderRadius: radius,
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
                width: 1,
              ),
            ),
            child: hasTopAccent
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 3,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              accent.withOpacity(0.0),
                              accent,
                              accent.withOpacity(0.0),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Flexible(child: child),
                    ],
                  )
                : child,
          ),
        ),
      ),
    );
  }
}

/// Glowing action button with luxury styling
class GlowingButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? color;
  final double? width;
  final double height;
  final BorderRadius? borderRadius;
  final bool isLoading;

  const GlowingButton({
    super.key,
    required this.child,
    this.onTap,
    this.color,
    this.width,
    this.height = 52,
    this.borderRadius,
    this.isLoading = false,
  });

  @override
  State<GlowingButton> createState() => _GlowingButtonState();
}

class _GlowingButtonState extends State<GlowingButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.4, end: 0.7).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final buttonColor = widget.color ?? const Color(0xFF84CC16);
    final radius = widget.borderRadius ?? BorderRadius.circular(14);

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return GestureDetector(
          onTapDown: widget.onTap != null ? (_) => setState(() => _isPressed = true) : null,
          onTapUp: widget.onTap != null
              ? (_) {
                  setState(() => _isPressed = false);
                  widget.onTap?.call();
                }
              : null,
          onTapCancel: widget.onTap != null ? () => setState(() => _isPressed = false) : null,
          child: AnimatedScale(
            scale: _isPressed ? 0.97 : 1.0,
            duration: const Duration(milliseconds: 100),
            child: Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                borderRadius: radius,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _isPressed
                      ? [
                          buttonColor.withOpacity(0.9),
                          Color.lerp(buttonColor, Colors.black, 0.2)!,
                        ]
                      : [
                          Color.lerp(buttonColor, Colors.white, 0.15)!,
                          buttonColor,
                        ],
                ),
                boxShadow: [
                  // Ambient glow
                  BoxShadow(
                    color: buttonColor.withOpacity(_glowAnimation.value * 0.5),
                    blurRadius: 25,
                    spreadRadius: -5,
                  ),
                  // Depth shadow
                  BoxShadow(
                    color: Color.lerp(buttonColor, Colors.black, 0.5)!.withOpacity(0.5),
                    blurRadius: 10,
                    offset: Offset(0, _isPressed ? 2 : 5),
                  ),
                ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  // Top highlight
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(_isPressed ? 0.05 : 0.2),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5],
                  ),
                ),
                child: Center(
                  child: widget.isLoading
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white.withOpacity(0.9),
                            ),
                          ),
                        )
                      : widget.child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Subtle glass divider with gradient
class GlassDivider extends StatelessWidget {
  final double height;
  final EdgeInsetsGeometry? margin;
  final Color? color;

  const GlassDivider({
    super.key,
    this.height = 1,
    this.margin,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: margin ?? const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            (color ?? Colors.white).withOpacity(0.1),
            (color ?? Colors.white).withOpacity(0.15),
            (color ?? Colors.white).withOpacity(0.1),
            Colors.transparent,
          ],
          stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
        ),
      ),
    );
  }
}

/// Glass text field with luxury styling
class GlassTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? hintText;
  final String? labelText;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final bool obscureText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;
  final int? maxLines;
  final int? minLines;

  const GlassTextField({
    super.key,
    this.controller,
    this.hintText,
    this.labelText,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixTap,
    this.obscureText = false,
    this.keyboardType,
    this.onChanged,
    this.validator,
    this.maxLines = 1,
    this.minLines,
  });

  @override
  State<GlassTextField> createState() => _GlassTextFieldState();
}

class _GlassTextFieldState extends State<GlassTextField> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.labelText != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              widget.labelText!,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade400,
                letterSpacing: 0.3,
              ),
            ),
          ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isFocused
                  ? const Color(0xFF84CC16).withOpacity(0.5)
                  : Colors.white.withOpacity(0.1),
              width: _isFocused ? 1.5 : 1.0,
            ),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: const Color(0xFF84CC16).withOpacity(0.15),
                      blurRadius: 15,
                      spreadRadius: -5,
                    ),
                  ]
                : [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1F2937).withOpacity(0.6),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextFormField(
                  controller: widget.controller,
                  obscureText: widget.obscureText,
                  keyboardType: widget.keyboardType,
                  onChanged: widget.onChanged,
                  validator: widget.validator,
                  maxLines: widget.maxLines,
                  minLines: widget.minLines,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                  ),
                  onTap: () => setState(() => _isFocused = true),
                  onEditingComplete: () => setState(() => _isFocused = false),
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    hintStyle: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 15,
                    ),
                    prefixIcon: widget.prefixIcon != null
                        ? Icon(
                            widget.prefixIcon,
                            color: _isFocused
                                ? const Color(0xFF84CC16)
                                : Colors.grey.shade500,
                            size: 20,
                          )
                        : null,
                    suffixIcon: widget.suffixIcon != null
                        ? GestureDetector(
                            onTap: widget.onSuffixTap,
                            child: Icon(
                              widget.suffixIcon,
                              color: Colors.grey.shade500,
                              size: 20,
                            ),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: widget.prefixIcon != null ? 0 : 16,
                      vertical: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
