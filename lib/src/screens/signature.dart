import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

/// Draws strokes stored as 0..1 points, scaled to the canvas.
class SignaturePainter extends CustomPainter {
  SignaturePainter(this.strokes, {required this.color, this.revision = 0});
  final Strokes strokes;
  final Color color;
  final int revision;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final s in strokes) {
      if (s.isEmpty) continue;
      final pts = [for (final p in s) Offset(p.dx * size.width, p.dy * size.height)];
      if (pts.length == 1) {
        canvas.drawCircle(pts.first, 1.2, paint..style = PaintingStyle.fill);
        paint.style = PaintingStyle.stroke;
        continue;
      }
      // Smooth the line through midpoints.
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (var i = 1; i < pts.length - 1; i++) {
        final mid = Offset((pts[i].dx + pts[i + 1].dx) / 2, (pts[i].dy + pts[i + 1].dy) / 2);
        path.quadraticBezierTo(pts[i].dx, pts[i].dy, mid.dx, mid.dy);
      }
      path.lineTo(pts.last.dx, pts.last.dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(SignaturePainter old) => old.revision != revision || old.strokes != strokes || old.color != color;
}

/// A pad the customer signs with a finger.
class SignaturePad extends StatefulWidget {
  const SignaturePad({super.key, required this.onChanged});
  final ValueChanged<Strokes> onChanged;

  @override
  State<SignaturePad> createState() => SignaturePadState();
}

class SignaturePadState extends State<SignaturePad> {
  final Strokes _strokes = [];
  int _rev = 0;

  void clear() {
    setState(() {
      _strokes.clear();
      _rev++;
    });
    widget.onChanged(const []);
  }

  Offset _norm(Offset local, Size size) => Offset((local.dx / size.width).clamp(0, 1), (local.dy / size.height).clamp(0, 1));

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return LayoutBuilder(
      builder: (context, box) {
        final size = Size(box.maxWidth, 150);
        return Semantics(
          container: true,
          label: _strokes.isEmpty ? 'Signature pad, empty. Sign with a finger or the mouse.' : 'Signature pad, signed',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (d) => setState(() {
              _strokes.add([_norm(d.localPosition, size)]);
              _rev++;
            }),
            onPanUpdate: (d) => setState(() {
              _strokes.last.add(_norm(d.localPosition, size));
              _rev++;
            }),
            onPanEnd: (_) => widget.onChanged([for (final s in _strokes) List.of(s)]),
            child: Container(
              height: size.height,
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: t.border),
              ),
              child: Stack(
                children: [
                  Positioned(left: 16, right: 16, bottom: 36, child: Container(height: 1, color: t.border)),
                  Positioned(
                    left: 16,
                    bottom: 14,
                    child: Text('Customer signature', style: TextStyle(fontSize: 11.5, color: t.faint)),
                  ),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: SignaturePainter(_strokes, color: t.text, revision: _rev),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
