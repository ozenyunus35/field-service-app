import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../ui.dart';
import 'signature.dart';
import '../i18n.dart';

/// Ready-made quotes per trade, so a quote on site takes a few taps. Everything stays editable.
const quoteTemplates = <Trade, List<(String, int, List<(String, double)>)>>{
  Trade.heating: [
    ('New furnace, 96% efficient', 360, [('Gas furnace, 96% AFUE, 60k BTU', 2950), ('Flue and condensate kit', 180), ('Removal of the old furnace', 120)]),
    ('Igniter and flame sensor upgrade', 60, [('Hot surface igniter kit', 120), ('Flame sensor', 45)]),
  ],
  Trade.plumbing: [
    ('Water heater replacement', 240, [('Gas water heater, 50 gal', 1450), ('Expansion tank', 95), ('City permit', 85)]),
    ('Main shut-off valve', 90, [('Full-port ball valve, 1 in', 65)]),
  ],
  Trade.cooling: [
    ('AC capacitor and contactor', 60, [('Dual run capacitor', 55), ('Contactor 30A, 1 pole', 40)]),
    ('Refrigerant leak repair', 180, [('Leak search dye and sealant', 160), ('Refrigerant, 2 lb', 180)]),
  ],
  Trade.controls: [
    ('Smart thermostat upgrade', 60, [('Smart thermostat', 249), ('C-wire adapter', 35)]),
  ],
};

/// A quote for follow-up work: pick or build the items, then the customer signs to accept (the
/// work is booked on the first day with room) or declines. With [quoteId] it reopens a saved quote.
class QuoteScreen extends StatefulWidget {
  const QuoteScreen({super.key, required this.jobId, this.quoteId});
  final String jobId;
  final String? quoteId;

  @override
  State<QuoteScreen> createState() => _QuoteScreenState();
}

class _QuoteScreenState extends State<QuoteScreen> {
  late final AppStore s = StoreScope.read(context);
  late final Job j = s.job(widget.jobId);
  late final Quote? saved = widget.quoteId == null ? null : s.quotes.firstWhere((q) => q.id == widget.quoteId);
  late final title = TextEditingController(text: saved?.title ?? '');
  late final name = TextEditingController(text: s.customer(j.customerId).name);
  final label = TextEditingController();
  final price = TextEditingController();
  late int minutes = saved?.minutes ?? 60;
  late List<QuoteItem> items = [for (final i in saved?.items ?? <QuoteItem>[]) QuoteItem(i.label, i.qty, i.price)];
  Strokes signature = const [];

  bool get editable => saved == null;

  @override
  void dispose() {
    title.dispose();
    name.dispose();
    label.dispose();
    price.dispose();
    super.dispose();
  }

  void _use((String, int, List<(String, double)>) t) => setState(() {
    title.text = t.$1;
    minutes = t.$2;
    items = [for (final (l, p) in t.$3) QuoteItem(l, 1, p)];
  });

  void _addItem() {
    final p = double.tryParse(price.text.replaceAll(RegExp(r'[^\d.]'), ''));
    if (label.text.trim().isEmpty || p == null || p <= 0) {
      toast(context, 'Enter what the item is and its price.');
      return;
    }
    setState(() {
      items.add(QuoteItem(label.text.trim(), 1, p));
      label.clear();
      price.clear();
    });
  }

  /// Saves the draft as a quote (once) and returns it, or shows why it can't be saved.
  Quote? _save() {
    if (saved != null) return saved;
    final (q, err) = s.createQuote(j.id, title: title.text, minutes: minutes, items: items);
    if (err != null) toast(context, err);
    return q;
  }

  void _accept() {
    final q = _save();
    if (q == null) return;
    final err = s.acceptQuote(q.id, signature: signature, signedBy: name.text);
    if (err != null) {
      toast(context, err);
      return;
    }
    final booked = s.job(q.followUpJobId!);
    Navigator.of(context).pop();
    toast(context, 'Accepted. ${booked.ref} is booked for ${relativeDay(booked.date, s.today)}, ${window(booked.start, booked.windowEnd)}.');
  }

  void _decline() {
    final q = _save();
    if (q == null) return;
    s.declineQuote(q.id);
    Navigator.of(context).pop();
    toast(context, '${q.ref} declined. It stays on the job for the office.');
  }

  void _later() {
    final q = _save();
    if (q == null) return;
    Navigator.of(context).pop();
    toast(context, '${q.ref} saved. The customer can sign it later.');
  }

  @override
  Widget build(BuildContext context) {
    StoreScope.of(context);
    final t = context.t;
    final tt = Theme.of(context).textTheme;
    final draft = Quote(
      id: '',
      ref: '',
      jobId: j.id,
      customerId: j.customerId,
      title: title.text,
      trade: j.trade,
      minutes: AppStore.billable(minutes),
      items: items,
      createdAt: s.now(),
    );
    final total = s.quoteTotal(draft);
    final templates = [
      ...?quoteTemplates[j.trade],
      for (final e in quoteTemplates.entries)
        if (e.key != j.trade) ...e.value,
    ];

    return Scaffold(
      appBar: AppBar(title: Text(saved?.ref ?? tr('New quote'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Text('${s.customer(j.customerId).name} · ${j.ref}', style: tt.bodySmall),
          if (editable) ...[
            SectionHeader(tr('Start from')),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tpl in templates)
                  ActionChip(
                    label: Text(tpl.$1, style: const TextStyle(fontSize: 12.5)),
                    onPressed: () => _use(tpl),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: title,
              maxLength: 80,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: tr('Work to quote'), counterText: ''),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Semantics(header: true, child: Text(saved!.title, style: tt.titleLarge)),
          ],
          SectionHeader(tr('Items')),
          Panel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(tr('Pick a starting point above, or add items below.'), style: tt.bodySmall),
                  ),
                for (final (i, item) in items.indexed) ...[
                  if (i > 0) Divider(height: 1, color: t.border),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.label, style: const TextStyle(fontSize: 14)),
                              Text('${item.qty} × ${money(item.price)}', style: tt.bodySmall),
                            ],
                          ),
                        ),
                        if (editable) ...[
                          IconButton(
                            tooltip: tr('One less ${item.label}'),
                            onPressed: () => setState(() => item.qty > 1 ? item.qty-- : items.removeAt(i)),
                            icon: Icon(item.qty > 1 ? LucideIcons.minus : LucideIcons.trash2, size: 15),
                          ),
                          IconButton(
                            tooltip: tr('One more ${item.label}'),
                            onPressed: () => setState(() => item.qty++),
                            icon: const Icon(LucideIcons.plus, size: 15),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                if (editable) ...[
                  Divider(height: 1, color: t.border),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 4, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: label,
                            maxLength: 60,
                            decoration: InputDecoration(labelText: tr('Item'), counterText: ''),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: price,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(labelText: tr('Price'), prefixText: '\$'),
                          ),
                        ),
                        IconButton(tooltip: tr('Add item'), onPressed: _addItem, icon: const Icon(LucideIcons.plus, size: 17)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          SectionHeader(tr('Labour')),
          Panel(
            child: Row(
              children: [
                Expanded(child: Text('${duration(AppStore.billable(minutes))} at ${money(s.tech.hourlyRate, cents: false)}/h', style: tt.titleSmall)),
                if (editable) ...[
                  IconButton.outlined(
                    tooltip: tr('Less labour'),
                    onPressed: minutes > 30 ? () => setState(() => minutes -= 30) : null,
                    icon: const Icon(LucideIcons.minus, size: 15),
                  ),
                  const SizedBox(width: 6),
                  IconButton.outlined(
                    tooltip: tr('More labour'),
                    onPressed: minutes < 600 ? () => setState(() => minutes += 30) : null,
                    icon: const Icon(LucideIcons.plus, size: 15),
                  ),
                ],
              ],
            ),
          ),
          SectionHeader(tr('Total')),
          Panel(
            child: Column(
              children: [
                KeyValue(tr('Items'), money(total.items)),
                KeyValue(tr('Labour'), money(total.labour)),
                KeyValue(tr('Tax on items'), money(total.tax)),
                Divider(color: t.border, height: 16),
                KeyValue(tr('Total'), money(total.total), strong: true),
              ],
            ),
          ),
          SectionHeader(tr('Customer acceptance')),
          SignaturePad(onChanged: (v) => setState(() => signature = v)),
          const SizedBox(height: 10),
          TextField(
            controller: name,
            maxLength: AppStore.maxSignedBy,
            decoration: InputDecoration(labelText: tr('Accepted by'), counterText: ''),
          ),
          const SizedBox(height: 6),
          Text(tr('By signing, the customer accepts the quote. The work is booked on the first day with room.'), style: tt.bodySmall),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: BoxDecoration(
            color: t.surface,
            border: Border(top: BorderSide(color: t.border)),
          ),
          child: Row(
            children: [
              TextButton(onPressed: _decline, child: Text(tr('Declined'))),
              if (editable) TextButton(onPressed: _later, child: Text(tr('Save'))),
              const Spacer(),
              FilledButton.icon(
                onPressed: AppStore.signatureOk(signature) && items.isNotEmpty ? _accept : null,
                icon: const Icon(LucideIcons.signature, size: 16),
                label: Text(tr('Accept ${money(total.total, cents: false)}')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
