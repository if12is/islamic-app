import 'package:flutter/material.dart';

class CustomLoader extends StatefulWidget {
  const CustomLoader({Key? key}) : super(key: key);

  @override
  State<CustomLoader> createState() => _CustomLoaderState();
}

class _CustomLoaderState extends State<CustomLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Container(
            height: 4,
            width: 150, // Fixed width for general use in center
            decoration: BoxDecoration(
              color: const Color(0xFFEBECEE), // Light grey base
              borderRadius: BorderRadius.circular(2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final leftOffset = -width + (width * 2 * _animationController.value);
                  
                  return Stack(
                    children: [
                      Positioned(
                        left: leftOffset,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: width,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withOpacity(0.0),
                                const Color(0xFFF6D167), // Golden-yellow
                                Colors.white.withOpacity(0.5),
                                Colors.white.withOpacity(0.0),
                              ],
                              stops: const [0.0, 0.4, 0.6, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
