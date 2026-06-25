import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class AmbientBackground extends StatefulWidget {
  final Widget child;

  const AmbientBackground({
    super.key,
    required this.child,
  });

  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground> with SingleTickerProviderStateMixin {
  ui.FragmentShader? _shader;
  late Ticker _ticker;
  double _elapsedTime = 0.0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadShader();
    _ticker = createTicker((elapsed) {
      setState(() {
        _elapsedTime = elapsed.inMilliseconds / 1000.0;
      });
    });
  }

  Future<void> _loadShader() async {
    try {
      final program = await ui.FragmentProgram.fromAsset(
        'assets/shaders/ambient_glow.frag',
      );
      if (mounted) {
        setState(() {
          _shader = program.fragmentShader();
          _loading = false;
        });
        _ticker.start();
      }
    } catch (e) {
      debugPrint('Failed to load ambient shader: $e');
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        color: const Color(0xFF0F100C),
        child: widget.child,
      );
    }

    if (_shader == null) {
      // Fallback to static gradient if shader failed to load (e.g. older browsers / fallback renderers)
      return DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF171812),
              Color(0xFF2D2419),
              Color(0xFF11130F),
            ],
          ),
        ),
        child: widget.child,
      );
    }

    return CustomPaint(
      painter: _ShaderPainter(
        shader: _shader!,
        time: _elapsedTime,
      ),
      child: widget.child,
    );
  }
}

class _ShaderPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final double time;

  _ShaderPainter({
    required this.shader,
    required this.time,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Set uniforms:
    // float 0: uSize.x
    // float 1: uSize.y
    // float 2: uTime
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    shader.setFloat(2, time);

    final paint = Paint()..shader = shader;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _ShaderPainter oldDelegate) {
    return oldDelegate.time != time;
  }
}
