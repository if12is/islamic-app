import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class QiblaCompass extends StatefulWidget {
  final double qiblaBearing;
  final String alignedText;
  final String rotateText;

  const QiblaCompass({
    super.key,
    required this.qiblaBearing,
    required this.alignedText,
    required this.rotateText,
  });

  @override
  State<QiblaCompass> createState() => _QiblaCompassState();
}

class _QiblaCompassState extends State<QiblaCompass> {
  double _heading = 0;
  StreamSubscription<CompassEvent>? _compassSubscription;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _compassSubscription = FlutterCompass.events?.listen((event) {
        final heading = event.heading;
        if (heading == null) {
          return;
        }

        if (mounted) {
          setState(() {
            _heading = heading;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _compassSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final heading = _heading;
    final deviceAngle = -(heading * (math.pi / 180));
    final arrowAngle = ((widget.qiblaBearing - heading) * math.pi) / 180;

    double diff = (heading - widget.qiblaBearing).abs();
    if (diff > 180) diff = 360 - diff;
    final isFacingQibla = diff < 10;

    return Column(
      children: [
        Center(
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF0F2F1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF003527),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Transform.rotate(
                            angle: deviceAngle,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.1,
                                        ),
                                        width: 1,
                                        strokeAlign:
                                            BorderSide.strokeAlignCenter,
                                      ),
                                    ),
                                  ),
                                ),
                                const Positioned(
                                  top: 16,
                                  left: 0,
                                  right: 0,
                                  child: Center(
                                    child: Text(
                                      'N',
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                                const Positioned(
                                  bottom: 16,
                                  left: 0,
                                  right: 0,
                                  child: Center(
                                    child: Text(
                                      'S',
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                                const Positioned(
                                  right: 16,
                                  top: 0,
                                  bottom: 0,
                                  child: Center(
                                    child: Text(
                                      'E',
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                                const Positioned(
                                  left: 16,
                                  top: 0,
                                  bottom: 0,
                                  child: Center(
                                    child: Text(
                                      'W',
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        Center(
                          child: Transform.rotate(
                            angle: arrowAngle,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 4,
                                  height: 166,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFE088),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                Positioned(
                                  top: 6,
                                  child: Transform.rotate(
                                    angle: 0,
                                    child: const Icon(
                                      Icons.navigation_rounded,
                                      size: 30,
                                      color: Color(0xFFFFE088),
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFFFFE088),
                                      width: 3,
                                    ),
                                    color: const Color(
                                      0xFF003527,
                                    ).withValues(alpha: 0.9),
                                  ),
                                  child: Center(
                                    child: Transform.rotate(
                                      angle: -arrowAngle,
                                      child: const Icon(
                                        Icons.explore,
                                        color: Color(0xFFFFE088),
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -20,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color:
                        isFacingQibla ? const Color(0xFF003527) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Text(
                        isFacingQibla ? widget.alignedText : widget.rotateText,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color:
                              isFacingQibla
                                  ? Colors.white
                                  : const Color(0xFF1A1C1C),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              isFacingQibla
                                  ? const Color(0xFFFFE088)
                                  : const Color(0xFF735C00),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
