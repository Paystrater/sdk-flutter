// The Paystrater mark and wordmark and the checkout's small icons, painted
// from the same vector data as @paystrater/react (src/react/brand.tsx), so the
// package needs no SVG or image assets. They take a colour, so one drawing
// serves light and dark. Replace wordmarkPath when there is an official vector.
import 'package:flutter/widgets.dart';

/// Where "Powered by Paystrater" leads
const paystraterSite = 'https://paystrater.com';

/// "Paystrater" as one graphic, in a 640×112 box. Only M, L-pairs and Z.
const wordmarkPath =
    'M312 0 312 18 302 18 302 28 302 30 310 30 312 32 312 64 314 74 320 80 326 82 344 82 346 82 346 72 345 68 330 68 328 66 326 58 326 32 328 30 346 30 346 18 326 18 327 0ZM480 0 480 18 470 18 470 28 470 30 480 31 480 66 482 73 489 80 494 82 512 82 515 80 514 72 513 68 500 68 496 66 495 58 495 34 496 30 514 30 514 20 514 18 496 18 496 0ZM6 8 2 10 0 16 0 112 6 100 10 96 18 92 28 90 58 90 62 88 72 86 80 80 86 72 90 64 92 56 92 44 90 35 86 26 74 14 60 8ZM266 16 255 18 246 24 242 30 242 43 247 50 254 54 260 56 273 56 278 58 282 62 282 66 278 70 268 72 258 70 252 63 242 63 240 66 242 73 246 78 253 82 266 84 276 84 283 82 290 78 296 69 296 64 294 54 288 48 280 44 260 42 256 38 256 34 260 30 266 29 276 30 282 37 292 37 294 36 292 26 288 22 280 18ZM552 16 543 18 536 22 530 28 526 35 524 42 524 56 528 69 536 78 542 82 550 84 564 84 571 82 582 74 586 66 586 62 580 62 572 62 568 68 560 70 548 70 542 64 540 60 540 54 588 54 588 44 586 36 580 26 569 18 561 16ZM114 18 114 32 142 32 146 35 148 40 148 42 146 42 132 42 120 44 112 48 108 54 106 64 108 74 118 82 130 84 141 82 150 73 150 82 162 82 163 78 163 44 162 32 157 24 151 20 145 18ZM172 18 172 22 192 80 202 80 202 82 202 86 197 92 178 93 178 106 200 106 208 102 214 94 222 68 234 24 234 18 220 18 218 20 208 64 204 68 202 66 188 19ZM362 18 360 19 360 22 360 82 376 82 376 48 378 40 383 34 388 32 398 32 398 18 388 18 384 20 378 24 374 32 373 30 373 20 372 18ZM412 18 411 22 412 32 440 32 444 36 444 42 428 43 413 46 406 52 404 56 404 70 406 74 415 82 428 84 438 82 442 80 446 73 448 73 448 82 460 82 460 33 458 28 452 22 442 18ZM602 18 601 22 601 78 602 82 616 82 618 80 618 46 618 40 624 34 628 32 640 32 640 18 630 18 624 20 618 26 614 33 614 19ZM52 26 14 48 14 58 36 58 36 72 38 71 74 52 78 48 78 40 56 40 56 26ZM550 30 542 36 540 44 562 44 572 44 570 36 562 30ZM130 52 124 56 122 60 122 65 124 68 129 72 139 72 146 66 148 61 148 54 146 52ZM428 52 424 54 420 58 420 66 423 70 426 72 436 72 440 70 444 66 444 52Z';

/// The P mark is the wordmark's first glyph: this part of its box.
const _markBox = Rect.fromLTWH(0, 8, 92, 104);
const _wordmarkBox = Rect.fromLTWH(0, 0, 640, 112);

Path? _parsed;

/// The wordmark as a Path, parsed once: polygons of absolute points.
Path wordmark() {
  final cached = _parsed;
  if (cached != null) return cached;
  final path = Path()..fillType = PathFillType.evenOdd;
  for (final shape in RegExp(r'M([^Z]+)Z').allMatches(wordmarkPath)) {
    final n =
        shape.group(1)!.trim().split(RegExp(r'\s+')).map(double.parse).toList();
    for (var i = 0; i + 1 < n.length; i += 2) {
      if (i == 0) {
        path.moveTo(n[i], n[i + 1]);
      } else {
        path.lineTo(n[i], n[i + 1]);
      }
    }
    path.close();
  }
  return _parsed = path;
}

class _VectorPainter extends CustomPainter {
  _VectorPainter(this.color, this.box);

  final Color color;
  final Rect box;

  @override
  void paint(Canvas canvas, Size size) {
    // Fit the box in the middle of the size, keeping its shape
    final scale = (size.width / box.width) < (size.height / box.height)
        ? size.width / box.width
        : size.height / box.height;
    final dx = (size.width - box.width * scale) / 2;
    final dy = (size.height - box.height * scale) / 2;
    canvas
      ..save()
      ..clipRect(Offset.zero & size)
      ..translate(dx, dy)
      ..scale(scale)
      ..translate(-box.left, -box.top)
      ..clipRect(box)
      ..drawPath(wordmark(), Paint()..color = color)
      ..restore();
  }

  @override
  bool shouldRepaint(_VectorPainter old) =>
      old.color != color || old.box != box;
}

/// The P mark, [size] square.
class PaystraterMark extends StatelessWidget {
  const PaystraterMark({super.key, required this.color, this.size = 20});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
      child: CustomPaint(
          size: Size.square(size), painter: _VectorPainter(color, _markBox)));
}

/// The wordmark, [height] tall.
class PaystraterWordmark extends StatelessWidget {
  const PaystraterWordmark({super.key, required this.color, this.height = 15});

  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
      child: CustomPaint(
          size: Size(height * 640 / 112, height),
          painter: _VectorPainter(color, _wordmarkBox)));
}

enum CheckoutIcon { wallet, sparkle, arrowLeft, chevronRight }

/// The checkout's line icons on a 24-unit grid, as lucide draws them.
class CheckoutIconView extends StatelessWidget {
  const CheckoutIconView(this.icon,
      {super.key, required this.color, this.size = 20, this.stroke = 1.8});

  final CheckoutIcon icon;
  final Color color;
  final double size;
  final double stroke;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
      child: CustomPaint(
          size: Size.square(size), painter: _IconPainter(icon, color, stroke)));
}

class _IconPainter extends CustomPainter {
  _IconPainter(this.icon, this.color, this.stroke);

  final CheckoutIcon icon;
  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 24;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * k
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    Offset p(double x, double y) => Offset(x * k, y * k);
    switch (icon) {
      case CheckoutIcon.arrowLeft:
        canvas
          ..drawPath(
              Path()
                ..moveTo(p(12, 19).dx, p(12, 19).dy)
                ..lineTo(p(5, 12).dx, p(5, 12).dy)
                ..lineTo(p(12, 5).dx, p(12, 5).dy),
              paint)
          ..drawLine(p(19, 12), p(5, 12), paint);
      case CheckoutIcon.sparkle:
        // A four-point star with softened inner corners, and a small plus
        canvas
          ..drawPath(
              Path()
                ..moveTo(p(12, 3.5).dx, p(12, 3.5).dy)
                ..lineTo(p(13.8, 9).dx, p(13.8, 9).dy)
                ..quadraticBezierTo(p(14.1, 9.9).dx, p(14.1, 9.9).dy,
                    p(15, 10.2).dx, p(15, 10.2).dy)
                ..lineTo(p(20.5, 12).dx, p(20.5, 12).dy)
                ..lineTo(p(15, 13.8).dx, p(15, 13.8).dy)
                ..quadraticBezierTo(p(14.1, 14.1).dx, p(14.1, 14.1).dy,
                    p(13.8, 15).dx, p(13.8, 15).dy)
                ..lineTo(p(12, 20.5).dx, p(12, 20.5).dy)
                ..lineTo(p(10.2, 15).dx, p(10.2, 15).dy)
                ..quadraticBezierTo(p(9.9, 14.1).dx, p(9.9, 14.1).dy,
                    p(9, 13.8).dx, p(9, 13.8).dy)
                ..lineTo(p(3.5, 12).dx, p(3.5, 12).dy)
                ..lineTo(p(9, 10.2).dx, p(9, 10.2).dy)
                ..quadraticBezierTo(p(9.9, 9.9).dx, p(9.9, 9.9).dy,
                    p(10.2, 9).dx, p(10.2, 9).dy)
                ..close(),
              paint)
          ..drawLine(p(19, 3), p(19, 6), paint)
          ..drawLine(p(17.5, 4.5), p(20.5, 4.5), paint);
      case CheckoutIcon.chevronRight:
        canvas.drawPath(
            Path()
              ..moveTo(p(9, 18).dx, p(9, 18).dy)
              ..lineTo(p(15, 12).dx, p(15, 12).dy)
              ..lineTo(p(9, 6).dx, p(9, 6).dy),
            paint);
      case CheckoutIcon.wallet:
        // The body, open on the right where the clasp sits
        canvas.drawPath(
            Path()
              ..moveTo(p(19, 7).dx, p(19, 7).dy)
              ..lineTo(p(19, 5.5).dx, p(19, 5.5).dy)
              ..arcToPoint(p(17.5, 4),
                  radius: Radius.circular(1.5 * k), clockwise: false)
              ..lineTo(p(5.5, 4).dx, p(5.5, 4).dy)
              ..arcToPoint(p(4, 5.5),
                  radius: Radius.circular(1.5 * k), clockwise: false)
              ..lineTo(p(4, 18.5).dx, p(4, 18.5).dy)
              ..arcToPoint(p(5.5, 20),
                  radius: Radius.circular(1.5 * k), clockwise: false)
              ..lineTo(p(17.5, 20).dx, p(17.5, 20).dy)
              ..arcToPoint(p(19, 18.5),
                  radius: Radius.circular(1.5 * k), clockwise: false)
              ..lineTo(p(19, 17).dx, p(19, 17).dy),
            paint);
        // The clasp
        canvas.drawRRect(
            RRect.fromRectAndCorners(
                Rect.fromLTRB(13.5 * k, 9.5 * k, 21 * k, 14.5 * k),
                topLeft: Radius.circular(2.5 * k),
                bottomLeft: Radius.circular(2.5 * k)),
            paint);
        canvas.drawCircle(
            p(16.5, 12), 0.6 * k, paint..style = PaintingStyle.fill);
    }
  }

  @override
  bool shouldRepaint(_IconPainter old) =>
      old.icon != icon || old.color != color || old.stroke != stroke;
}
