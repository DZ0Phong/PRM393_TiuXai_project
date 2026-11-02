import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Three dark, gold-inlaid dice styled after the Tài/Xỉu HTML dice dome.
class TaiXiuDice extends StatelessWidget {
  final List<dynamic> values;
  final double dieSize;

  const TaiXiuDice({super.key, required this.values, this.dieSize = 40});

  static const _tilts = [-6.0, 12.0, -3.0];

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var index = 0; index < values.length; index++) ...[
        if (index > 0) const SizedBox(width: 6),
        TaiXiuDieFace(
          value: values[index],
          size: dieSize,
          tiltDegrees: _tilts[index % _tilts.length],
        ),
      ],
    ],
  );
}

class TaiXiuDieFace extends StatelessWidget {
  final Object? value;
  final double size;
  final double tiltDegrees;

  const TaiXiuDieFace({
    super.key,
    required this.value,
    required this.size,
    this.tiltDegrees = 0,
  });

  static const _pipPositions = <int, Set<int>>{
    1: {4},
    2: {0, 8},
    3: {0, 4, 8},
    4: {0, 2, 6, 8},
    5: {0, 2, 4, 6, 8},
    6: {0, 2, 3, 5, 6, 8},
  };

  int get _face =>
      value is num ? (value as num).toInt() : int.tryParse('$value') ?? 0;

  Widget _pip(int index, Set<int> positions, int centerPip, double pipSize) {
    if (!positions.contains(index)) {
      return SizedBox(width: pipSize, height: pipSize);
    }
    final color = index == centerPip
        ? const Color(0xffa40217)
        : const Color(0xffffc174);
    return Container(
      width: pipSize,
      height: pipSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: .5), blurRadius: 3),
          const BoxShadow(
            color: Colors.black45,
            blurRadius: 1,
            offset: Offset(0, 1),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final face = _face;
    final positions = _pipPositions[face] ?? const <int>{};
    final centerPip = face.isOdd ? 4 : -1;
    final pipSize = size * .2;

    return Semantics(
      label: 'Xúc xắc $face',
      child: Transform.rotate(
        angle: tiltDegrees * math.pi / 180,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 380),
          switchInCurve: Curves.easeOutBack,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) => RotationTransition(
            turns: Tween<double>(begin: -.04, end: 0).animate(animation),
            child: ScaleTransition(scale: animation, child: child),
          ),
          child: Container(
            key: ValueKey(face),
            width: size,
            height: size,
            padding: EdgeInsets.all(size * .15),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xff272a31), Color(0xff0b0e14)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(size * .2),
              border: Border.all(color: const Color(0xff534434), width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black87,
                  blurRadius: 9,
                  offset: Offset(0, 4),
                ),
                BoxShadow(
                  color: Color(0x22ffc174),
                  blurRadius: 5,
                  spreadRadius: -2,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var row = 0; row < 3; row++)
                  SizedBox(
                    height: pipSize,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (var column = 0; column < 3; column++)
                          _pip(row * 3 + column, positions, centerPip, pipSize),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
