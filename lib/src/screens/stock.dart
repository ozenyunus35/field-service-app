import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../ui.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  bool lowOnly = false;
  String q = '';

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final t = context.t;
    final tt = Theme.of(context).textTheme;
    final value = s.parts.fold<double>(0, (sum, p) => sum + p.price * p.qty);
    final low = s.lowStock;
    final list = s.parts.where((p) => (!lowOnly || p.low) && (q.isEmpty || p.name.toLowerCase().contains(q) || p.sku.toLowerCase().contains(q))).toList()
      ..sort((a, b) => (a.low == b.low) ? a.name.compareTo(b.name) : (a.low ? -1 : 1));

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.tech.van, style: tt.bodySmall),
                  const SizedBox(height: 2),
                  Semantics(header: true, child: Text('Van stock', style: tt.headlineSmall)),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(padding: EdgeInsets.only(top: 8), child: SyncStrip()),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Panel(
                child: Row(
                  children: [
                    Expanded(
                      child: Metric(label: 'Items', value: '${s.parts.fold<int>(0, (sum, p) => sum + p.qty)}', sub: plural(s.parts.length, 'part')),
                    ),
                    Expanded(
                      child: Metric(label: 'Running low', value: '${low.length}', sub: '${low.where((p) => p.restockRequested).length} requested'),
                    ),
                    Expanded(
                      child: Metric(label: 'Stock value', value: money(value, cents: false)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (v) => setState(() => q = v.trim().toLowerCase()),
                      decoration: const InputDecoration(prefixIcon: Icon(LucideIcons.search, size: 16), hintText: 'Search parts or SKU'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Low only'),
                    selected: lowOnly,
                    onSelected: (v) => setState(() => lowOnly = v),
                    showCheckmark: false,
                    labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: lowOnly ? t.text : t.muted),
                    selectedColor: t.accentSoft,
                    backgroundColor: t.surface,
                    side: BorderSide(color: t.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ],
              ),
            ),
          ),
          if (list.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text(lowOnly ? 'Nothing is running low.' : 'No parts match "$q".', style: tt.bodySmall)),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              sliver: SliverToBoxAdapter(
                child: Panel(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final (i, p) in list.indexed) ...[if (i > 0) Divider(height: 1, color: t.border), _PartRow(part: p)],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PartRow extends StatelessWidget {
  const _PartRow({required this.part});
  final Part part;

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final t = context.t;
    final p = part;
    final target = (p.min * 3).clamp(3, 30);
    final level = (p.qty / target).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        p.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
                      ),
                    ),
                    if (p.low) ...[const SizedBox(width: 6), Tag(p.qty == 0 ? 'Out' : 'Low', color: p.qty == 0 ? t.danger : t.warning)],
                  ],
                ),
                const SizedBox(height: 2),
                Text('${p.sku} · ${money(p.price)} · min ${p.min}', style: TextStyle(fontSize: 12, color: t.muted)),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: level),
                    duration: const Duration(milliseconds: 300),
                    builder: (_, v, _) => LinearProgressIndicator(
                      value: v,
                      minHeight: 3,
                      backgroundColor: t.surface2,
                      color: p.low ? t.warning : t.accent.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${p.qty}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()]),
              ),
              if (p.low)
                p.restockRequested
                    ? Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Requested',
                          style: TextStyle(fontSize: 11.5, color: t.success, fontWeight: FontWeight.w500),
                        ),
                      )
                    : TextButton(
                        onPressed: () {
                          s.requestRestock(p.id);
                          toast(context, 'Restock of ${p.name} requested from the warehouse.');
                        },
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 26),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Semantics(
                          label: 'Request restock of ${p.name}',
                          excludeSemantics: true,
                          child: const Text('Restock', style: TextStyle(fontSize: 12.5)),
                        ),
                      )
              else
                Text('in van', style: TextStyle(fontSize: 11.5, color: t.faint)),
            ],
          ),
        ],
      ),
    );
  }
}
