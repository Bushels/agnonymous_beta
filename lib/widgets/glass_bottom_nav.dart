import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

/// Bottom navigation item data
class BottomNavItem {
  final IconData icon;
  final String label;
  final bool isSpecial;

  const BottomNavItem({
    required this.icon,
    required this.label,
    this.isSpecial = false,
  });
}

/// Luxury Glassmorphism bottom navigation bar with ambient glow
class GlassBottomNav extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<BottomNavItem> items;

  const GlassBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  State<GlassBottomNav> createState() => _GlassBottomNavState();
}

class _GlassBottomNavState extends State<GlassBottomNav>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Subtle ambient glow animation - slow breathing effect
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.15, end: 0.35).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Special button pulse animation
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.4, end: 0.7).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        boxShadow: [
          // Soft upward shadow for depth
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 30,
            spreadRadius: -5,
            offset: const Offset(0, -8),
          ),
          // Subtle ambient glow from below
          BoxShadow(
            color: const Color(0xFF84CC16).withOpacity(0.05),
            blurRadius: 40,
            spreadRadius: 0,
            offset: const Offset(0, -15),
          ),
        ],
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            padding: EdgeInsets.only(bottom: bottomPadding + 8, top: 8),
            decoration: BoxDecoration(
              // Refined gradient background
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF1F2937).withOpacity(0.95),
                  const Color(0xFF111827).withOpacity(0.98),
                ],
              ),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withOpacity(0.08),
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(widget.items.length, (index) {
                final item = widget.items[index];
                final isSelected = widget.currentIndex == index;

                if (item.isSpecial) {
                  return _buildSpecialButton(item, () => widget.onTap(index));
                }

                return _buildNavItem(
                  item: item,
                  isSelected: isSelected,
                  onTap: () => widget.onTap(index),
                  index: index,
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BottomNavItem item,
    required bool isSelected,
    required VoidCallback onTap,
    required int index,
  }) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF84CC16).withOpacity(0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              // Ambient glow effect on unselected items
              boxShadow: !isSelected ? [
                BoxShadow(
                  color: const Color(0xFF84CC16).withOpacity(_glowAnimation.value * 0.15),
                  blurRadius: 20,
                  spreadRadius: -5,
                ),
              ] : [
                // Selected item gets a more prominent glow
                BoxShadow(
                  color: const Color(0xFF84CC16).withOpacity(0.25),
                  blurRadius: 16,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon with subtle glow
                Container(
                  decoration: !isSelected ? BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF84CC16).withOpacity(_glowAnimation.value * 0.3),
                        blurRadius: 12,
                        spreadRadius: -4,
                      ),
                    ],
                  ) : null,
                  child: FaIcon(
                    item.icon,
                    size: isSelected ? 22 : 20,
                    color: isSelected
                        ? const Color(0xFF84CC16)
                        : Color.lerp(
                            Colors.grey.shade600,
                            const Color(0xFF84CC16).withOpacity(0.6),
                            _glowAnimation.value,
                          ),
                  ),
                ),
                const SizedBox(height: 5),
                // Label with refined typography
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: GoogleFonts.inter(
                    fontSize: isSelected ? 11 : 10,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? const Color(0xFF84CC16)
                        : Color.lerp(
                            Colors.grey.shade500,
                            const Color(0xFF84CC16).withOpacity(0.5),
                            _glowAnimation.value * 0.5,
                          ),
                    letterSpacing: 0.3,
                  ),
                  child: Text(item.label),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSpecialButton(BottomNavItem item, VoidCallback onTap) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return GestureDetector(
          onTap: onTap,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              // Premium gradient with depth
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFA3E635), // Lighter lime
                  Color(0xFF84CC16), // Primary green
                  Color(0xFF65A30D), // Darker green
                ],
                stops: [0.0, 0.5, 1.0],
              ),
              shape: BoxShape.circle,
              // Multi-layered glow for luxury feel
              boxShadow: [
                // Outer ambient glow - pulsing
                BoxShadow(
                  color: const Color(0xFF84CC16).withOpacity(_pulseAnimation.value * 0.5),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
                // Middle glow layer
                BoxShadow(
                  color: const Color(0xFF84CC16).withOpacity(_pulseAnimation.value * 0.3),
                  blurRadius: 20,
                  spreadRadius: 0,
                ),
                // Inner shadow for depth
                BoxShadow(
                  color: const Color(0xFF65A30D).withOpacity(0.8),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // Inner highlight for glass effect
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.25),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5],
                ),
              ),
              child: Center(
                child: FaIcon(
                  item.icon,
                  size: 24,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Animated bottom nav item with scale and glow effects
class LuxuryNavItem extends StatefulWidget {
  final BottomNavItem item;
  final bool isSelected;
  final VoidCallback onTap;
  final Animation<double> glowAnimation;

  const LuxuryNavItem({
    super.key,
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.glowAnimation,
  });

  @override
  State<LuxuryNavItem> createState() => _LuxuryNavItemState();
}

class _LuxuryNavItemState extends State<LuxuryNavItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pressGlowAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOutCubic),
    );
    _pressGlowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _pressController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _pressController.reverse();
    widget.onTap();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pressController, widget.glowAnimation]),
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? const Color(0xFF84CC16).withOpacity(0.12)
                    : _isPressed
                        ? const Color(0xFF84CC16).withOpacity(0.08)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  if (!widget.isSelected)
                    BoxShadow(
                      color: const Color(0xFF84CC16).withOpacity(
                        widget.glowAnimation.value * 0.15 + _pressGlowAnimation.value * 0.2
                      ),
                      blurRadius: 20 + _pressGlowAnimation.value * 10,
                      spreadRadius: -5 + _pressGlowAnimation.value * 5,
                    ),
                  if (widget.isSelected)
                    BoxShadow(
                      color: const Color(0xFF84CC16).withOpacity(0.3),
                      blurRadius: 18,
                      spreadRadius: -2,
                    ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF84CC16).withOpacity(
                            widget.isSelected
                                ? 0.4
                                : widget.glowAnimation.value * 0.25 + _pressGlowAnimation.value * 0.3
                          ),
                          blurRadius: 14,
                          spreadRadius: -4,
                        ),
                      ],
                    ),
                    child: FaIcon(
                      widget.item.icon,
                      size: widget.isSelected ? 22 : 20,
                      color: widget.isSelected
                          ? const Color(0xFF84CC16)
                          : Color.lerp(
                              Colors.grey.shade600,
                              const Color(0xFF84CC16).withOpacity(0.7),
                              widget.glowAnimation.value + _pressGlowAnimation.value * 0.3,
                            ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    widget.item.label,
                    style: GoogleFonts.inter(
                      fontSize: widget.isSelected ? 11 : 10,
                      fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: widget.isSelected
                          ? const Color(0xFF84CC16)
                          : Color.lerp(
                              Colors.grey.shade500,
                              const Color(0xFF84CC16).withOpacity(0.6),
                              widget.glowAnimation.value * 0.5,
                            ),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Premium special action button with enhanced glow
class LuxurySpecialButton extends StatefulWidget {
  final BottomNavItem item;
  final VoidCallback onTap;
  final Animation<double> pulseAnimation;

  const LuxurySpecialButton({
    super.key,
    required this.item,
    required this.onTap,
    required this.pulseAnimation,
  });

  @override
  State<LuxurySpecialButton> createState() => _LuxurySpecialButtonState();
}

class _LuxurySpecialButtonState extends State<LuxurySpecialButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _pressController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _pressController.reverse();
    widget.onTap();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: Listenable.merge([_pressController, widget.pulseAnimation]),
        builder: (context, child) {
          final pulseValue = widget.pulseAnimation.value;
          final pressValue = _scaleAnimation.value;

          return Transform.scale(
            scale: pressValue,
            child: Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _isPressed
                      ? [
                          const Color(0xFF84CC16),
                          const Color(0xFF65A30D),
                          const Color(0xFF4D7C0F),
                        ]
                      : [
                          const Color(0xFFA3E635),
                          const Color(0xFF84CC16),
                          const Color(0xFF65A30D),
                        ],
                  stops: const [0.0, 0.5, 1.0],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  // Outer ambient glow
                  BoxShadow(
                    color: const Color(0xFF84CC16).withOpacity(pulseValue * 0.6),
                    blurRadius: 35,
                    spreadRadius: 3,
                  ),
                  // Middle glow
                  BoxShadow(
                    color: const Color(0xFFA3E635).withOpacity(pulseValue * 0.35),
                    blurRadius: 22,
                    spreadRadius: 0,
                  ),
                  // Inner depth shadow
                  BoxShadow(
                    color: const Color(0xFF4D7C0F).withOpacity(0.9),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(_isPressed ? 0.1 : 0.28),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.55],
                  ),
                ),
                child: Center(
                  child: FaIcon(
                    widget.item.icon,
                    size: 24,
                    color: Colors.white.withOpacity(_isPressed ? 0.9 : 1.0),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
