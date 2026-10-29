import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'format.dart';
import 'models.dart';
import 'store.dart';
import 'theme.dart';

void toast(BuildContext context, String message) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(content: Text(message), duration: const Duration(milliseconds: 2600)));
}

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.onTap, this.color});
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final radius = BorderRadius.circular(10);
    return Material(
      color: color ?? t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: t.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : InkWell(
              onTap: onTap,
              child: Padding(padding: padding, child: child),
            ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 22, 2, 8),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: context.t.muted, letterSpacing: 0.1)),
        ),
        ?trailing,
      ],
    ),
  );
}

({String label, Color color}) statusLook(BuildContext context, JobStatus s) {
  final t = context.t;
  return switch (s) {
    JobStatus.scheduled => (label: 'Scheduled', color: t.faint),
    JobStatus.travelling => (label: 'On the way', color: t.accent),
    JobStatus.onSite => (label: 'On site', color: t.warning),
    JobStatus.completed => (label: 'Completed', color: t.success),
  };
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key});
  final JobStatus status;

  @override
  Widget build(BuildContext context) {
    final l = statusLook(context, status);
    final t = context.t;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: t.surface2,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: t.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: l.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            l.label,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: t.text),
          ),
        ],
      ),
    );
  }
}

class Tag extends StatelessWidget {
  const Tag(this.label, {super.key, this.color, this.icon});
  final String label;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final c = color ?? t.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(5)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 11, color: c), const SizedBox(width: 4)],
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c),
          ),
        ],
      ),
    );
  }
}

IconData tradeIcon(Trade t) => switch (t) {
  Trade.heating => LucideIcons.flame,
  Trade.cooling => LucideIcons.fan,
  Trade.plumbing => LucideIcons.droplets,
  Trade.controls => LucideIcons.thermometer,
};

class TradeBadge extends StatelessWidget {
  const TradeBadge(this.trade, {super.key, this.size = 36});
  final Trade trade;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: t.surface2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: t.border),
      ),
      child: Icon(tradeIcon(trade), size: size * 0.46, color: t.muted),
    );
  }
}

class Avatar extends StatelessWidget {
  const Avatar(this.name, {super.key, this.size = 36});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.surface2,
        shape: BoxShape.circle,
        border: Border.all(color: t.border),
      ),
      child: Text(
        initials(name),
        style: TextStyle(fontSize: size * 0.36, fontWeight: FontWeight.w600, color: t.muted),
      ),
    );
  }
}

class Metric extends StatelessWidget {
  const Metric({super.key, required this.label, required this.value, this.sub});
  final String label, value;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11.5, color: t.muted, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.4, color: t.text, fontFeatures: const [FontFeature.tabularFigures()]),
        ),
        if (sub != null) Text(sub!, style: TextStyle(fontSize: 11.5, color: t.faint)),
      ],
    );
  }
}

class KeyValue extends StatelessWidget {
  const KeyValue(this.k, this.v, {super.key, this.strong = false});
  final String k, v;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final style = TextStyle(fontSize: strong ? 15 : 14, fontWeight: strong ? FontWeight.w600 : FontWeight.w400, color: strong ? t.text : t.muted);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(k, style: style)),
          Text(
            v,
            style: style.copyWith(color: t.text, fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ],
      ),
    );
  }
}

/// Synthetic "photo" for the demo: a calm abstract scene, different per seed.
class PhotoArt extends StatelessWidget {
  const PhotoArt(this.photo, {super.key});
  final Photo photo;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Semantics(
      label: '${photo.label} photo, ${clockOf(photo.at)}',
      image: true,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _PhotoPainter(photo.seed, t)),
          Positioned(
            left: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(4)),
              child: Text(
                '${photo.label} · ${clockOf(photo.at)}',
                style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoPainter extends CustomPainter {
  _PhotoPainter(this.seed, this.t);
  final int seed;
  final Tokens t;

  @override
  void paint(Canvas canvas, Size size) {
    final hue = (seed * 37) % 360;
    final base = HSLColor.fromAHSL(1, hue.toDouble(), 0.12, 0.32).toColor();
    canvas.drawRect(Offset.zero & size, Paint()..color = base);
    // Wall and floor
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.68, size.width, size.height * 0.32),
      Paint()..color = HSLColor.fromAHSL(1, hue.toDouble(), 0.1, 0.22).toColor(),
    );
    // Appliance or pipe run
    final p = Paint()..color = HSLColor.fromAHSL(1, (hue + 20) % 360, 0.06, 0.72).toColor();
    final w = size.width * (0.28 + (seed % 7) / 40);
    final x = size.width * (0.18 + (seed % 5) / 14);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, size.height * 0.2, w, size.height * 0.56), const Radius.circular(4)), p);
    final pipe = Paint()
      ..color = HSLColor.fromAHSL(1, 28, 0.45, 0.5).toColor()
      ..strokeWidth = size.width * 0.035
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(x + w, size.height * 0.34)
      ..lineTo(size.width * 0.86, size.height * 0.34)
      ..lineTo(size.width * 0.86, size.height * (0.06 + (seed % 3) * 0.04));
    canvas.drawPath(path, pipe);
    // Gauge
    final c = Offset(x + w / 2, size.height * 0.36);
    canvas.drawCircle(c, w * 0.16, Paint()..color = HSLColor.fromAHSL(1, hue.toDouble(), 0.05, 0.92).toColor());
    final a = -math.pi * (0.2 + (seed % 9) / 12);
    canvas.drawLine(
      c,
      c + Offset(math.cos(a), math.sin(a)) * w * 0.13,
      Paint()
        ..color = const Color(0xFFC94545)
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_PhotoPainter old) => old.seed != seed;
}

/// Offline or waiting-to-sync strip shown at the top of each tab.
class SyncStrip extends StatelessWidget {
  const SyncStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final t = context.t;
    final visible = s.offline || s.syncing;
    final n = s.pending.length;
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      child: !visible
          ? const SizedBox(width: double.infinity)
          : Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: t.surface2,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: t.border),
              ),
              child: Row(
                children: [
                  if (s.syncing)
                    SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.8, color: t.accent))
                  else
                    Icon(LucideIcons.wifiOff, size: 15, color: t.warning),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s.syncing
                          ? 'Syncing ${plural(n, 'change')}…'
                          : (n == 0 ? 'Offline. Changes are saved on this phone.' : 'Offline. ${plural(n, 'change')} waiting to sync.'),
                      style: TextStyle(fontSize: 12.5, color: t.text),
                    ),
                  ),
                  if (!s.syncing)
                    TextButton(
                      onPressed: () => s.setOffline(false),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 26),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                      child: const Text('Go online'),
                    ),
                ],
              ),
            ),
    );
  }
}
