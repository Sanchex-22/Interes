import 'package:flame/game.dart';
import 'package:flutter/material.dart';

class InterestGame extends FlameGame {
  int level = 1;
  int roundsCompleted = 0;

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final paint = Paint()..color = const Color(0xFF2196F3);
    canvas.drawRect(Rect.fromLTWH(50, 100, 200, 30), paint);

    TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: 'Nivel: \$level | Vueltas: \$roundsCompleted',
        style: TextStyle(color: Colors.white, fontSize: 18),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(60, 105));
  }

  @override
  void update(double dt) {
    // Aquí puedes incluir lógica para el progreso por tiempo o eventos futuros
  }

  void completeRound() {
    roundsCompleted++;
    if (roundsCompleted % 5 == 0) {
      level++;
    }
  }
}
