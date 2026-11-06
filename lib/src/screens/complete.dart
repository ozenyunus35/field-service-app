import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../format.dart';
import '../models.dart';
import '../seed.dart';
import '../store.dart';
import '../theme.dart';
import '../ui.dart';
import 'signature.dart';
import '../i18n.dart';

/// Sign-off: check what's missing, set the labour time, review the invoice, get a signature.
class CompleteScreen extends StatefulWidget {
  const CompleteScreen({super.key, required this.jobId});
  final String jobId;

  @override
  State<CompleteScreen> createState() => _CompleteScreenState();
}

class _CompleteScreenState extends State<CompleteScreen> {
  final pad = GlobalKey<SignaturePadState>();
  late final AppStore s = StoreScope.read(context);
  late final Job j = s.job(widget.jobId);
  // Start from the real time on site; the technician can still adjust it.
  late int labour = s.suggestedLabour(j);
  late final name = TextEditingController(text: s.customer(j.customerId).name);
  Strokes signature = const [];
  PayMethod pay = PayMethod.card;
  double? tendered;

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  void _submit() {
    final err = s.complete(j.id, labourMinutes: labour, signature: signature, signedBy: name.text, pay: pay, tendered: tendered);
    if (err != null) {
      toast(context, err);
      return;
    }
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => DoneScreen(jobId: j.id),
        transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    StoreScope.of(context);
    final t = context.t;
    final tt = Theme.of(context).textTheme;
    final inv = s.invoice(j, labourMinutes: labour);
    final blockers = s.blockers(j, signature: signature);

    return Scaffold(
      appBar: AppBar(title: Text(tr('Complete job'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Text('${j.title} · ${j.ref}', style: tt.titleMedium),
          Text(s.customer(j.customerId).address, style: tt.bodySmall),
          if (j.requiredLeft > 0) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: t.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: t.warning.withValues(alpha: 0.35)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(LucideIcons.triangleAlert, size: 16, color: t.warning),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('Finish the required checks first'),
                          style: TextStyle(fontWeight: FontWeight.w600, color: t.text, fontSize: 13.5),
                        ),
                        const SizedBox(height: 4),
                        for (final c in j.checklist.where((c) => c.required && !c.done)) Text('· ${c.label}', style: TextStyle(fontSize: 13, color: t.muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          SectionHeader(tr('Labour')),
          Panel(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(duration(labour), style: tt.titleMedium),
                      Text(
                        j.arrivedAt == null
                            ? tr('Booked ${duration(j.duration)} · ${money(s.tech.hourlyRate, cents: false)}/h')
                            : tr('On site ${duration(s.onSiteMinutes(j))} · booked ${duration(j.duration)} · ${money(s.tech.hourlyRate, cents: false)}/h'),
                        style: tt.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton.outlined(
                  tooltip: tr('Less labour time'),
                  onPressed: labour > 30 ? () => setState(() => labour -= 15) : null,
                  icon: const Icon(LucideIcons.minus, size: 15),
                  style: IconButton.styleFrom(
                    side: BorderSide(color: t.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.outlined(
                  tooltip: tr('More labour time'),
                  onPressed: labour < 600 ? () => setState(() => labour += 15) : null,
                  icon: const Icon(LucideIcons.plus, size: 15),
                  style: IconButton.styleFrom(
                    side: BorderSide(color: t.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),

          SectionHeader(tr('Invoice')),
          Panel(
            child: Column(
              children: [
                KeyValue(tr('Call-out'), money(inv.callOut)),
                KeyValue(tr('Labour, ${duration(inv.labourMinutes)}'), money(inv.labour)),
                for (final u in j.parts) KeyValue('${s.part(u.partId).name} × ${u.qty}', money(u.price * u.qty)),
                KeyValue(tr('Tax on parts (${(taxRate * 100).toStringAsFixed(2)}%)'), money(inv.tax)),
                Divider(color: t.border, height: 18),
                TweenAnimationBuilder<double>(
                  tween: Tween(end: inv.total),
                  duration: const Duration(milliseconds: 260),
                  builder: (_, v, _) => KeyValue(tr('Total'), money(v), strong: true),
                ),
              ],
            ),
          ),

          SectionHeader(tr('Payment')),
          Panel(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<PayMethod>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: PayMethod.card, label: Text(tr('Card')), icon: Icon(LucideIcons.creditCard, size: 15)),
                    ButtonSegment(value: PayMethod.cash, label: Text(tr('Cash')), icon: Icon(LucideIcons.banknote, size: 15)),
                    ButtonSegment(value: PayMethod.invoice, label: Text(tr('Invoice')), icon: Icon(LucideIcons.fileText, size: 15)),
                  ],
                  selected: {pay},
                  onSelectionChanged: (v) => setState(() {
                    pay = v.first;
                    tendered = pay == PayMethod.cash ? inv.total : null;
                  }),
                ),
                const SizedBox(height: 8),
                if (pay == PayMethod.card) Text(tr('Tap the card on the reader. In this demo the payment is simulated.'), style: tt.bodySmall),
                if (pay == PayMethod.invoice) Text(tr('The invoice is emailed with payment due in 30 days.'), style: tt.bodySmall),
                if (pay == PayMethod.cash) ...[
                  Text(tr('Cash received'), style: tt.bodySmall),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final amount in {inv.total, (inv.total / 10).ceil() * 10.0, (inv.total / 50).ceil() * 50.0, (inv.total / 100).ceil() * 100.0})
                        ChoiceChip(
                          label: Text(amount == inv.total ? tr('Exact ${money(amount)}') : money(amount, cents: false)),
                          selected: tendered == amount,
                          onSelected: (_) => setState(() => tendered = amount),
                        ),
                    ],
                  ),
                  if (tendered != null && tendered! > inv.total) ...[
                    const SizedBox(height: 6),
                    Text(tr('Change to give: ${money(tendered! - inv.total)}'), style: tt.titleSmall),
                  ],
                ],
              ],
            ),
          ),

          SectionHeader(
            tr('Customer sign-off'),
            trailing: signature.isEmpty
                ? null
                : TextButton.icon(
                    onPressed: () => pad.currentState?.clear(),
                    icon: const Icon(LucideIcons.eraser, size: 14),
                    label: Text(tr('Clear')),
                    style: TextButton.styleFrom(minimumSize: const Size(0, 30), padding: const EdgeInsets.symmetric(horizontal: 8)),
                  ),
          ),
          SignaturePad(key: pad, onChanged: (v) => setState(() => signature = v)),
          const SizedBox(height: 10),
          TextField(
            controller: name,
            maxLength: AppStore.maxSignedBy,
            decoration: InputDecoration(labelText: tr('Signed by'), counterText: ''),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Text(tr('By signing, the customer confirms the work and the total above.'), style: tt.bodySmall),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: BoxDecoration(
            color: t.surface,
            border: Border(top: BorderSide(color: t.border)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (blockers.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    blockers.map((b) => tr(b)).join(' · '),
                    style: TextStyle(fontSize: 12, color: t.muted),
                    textAlign: TextAlign.center,
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: blockers.isEmpty && name.text.trim().isNotEmpty ? _submit : null,
                  icon: const Icon(LucideIcons.send, size: 16),
                  label: Text(
                    tr('Complete · {method} {total}', {
                      'method': switch (pay) {
                        PayMethod.card => tr('card'),
                        PayMethod.cash => tr('cash'),
                        PayMethod.invoice => tr('invoice'),
                      },
                      'total': money(inv.total),
                    }),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DoneScreen extends StatelessWidget {
  const DoneScreen({super.key, required this.jobId});
  final String jobId;

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final t = context.t;
    final tt = Theme.of(context).textTheme;
    final j = s.job(jobId);
    final c = s.customer(j.customerId);
    final next = s.current;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.6, end: 1),
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutBack,
                builder: (_, v, child) => Transform.scale(scale: v, child: child),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(color: t.success.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Icon(LucideIcons.check, size: 30, color: t.success),
                ),
              ),
              const SizedBox(height: 18),
              Semantics(header: true, child: Text(tr('Job completed'), style: tt.headlineSmall)),
              const SizedBox(height: 8),
              Text(
                tr(
                  '${j.ref} for ${c.name}: invoice of ${money(s.invoice(j).total)} ${s.offline ? 'saved on this phone. It is sent when you are back online.' : 'sent to the customer.'}',
                ),
                textAlign: TextAlign.center,
                style: tt.bodyMedium?.copyWith(color: t.muted),
              ),
              if (j.payment != null) ...[
                const SizedBox(height: 16),
                Panel(
                  child: Column(
                    children: [
                      KeyValue(tr('Receipt'), j.payment!.receipt),
                      KeyValue(
                        switch (j.payment!.method) {
                          PayMethod.card => tr('Paid by card'),
                          PayMethod.cash => tr('Paid in cash'),
                          PayMethod.invoice => tr('To invoice, due in 30 days'),
                        },
                        money(j.payment!.amount),
                        strong: true,
                      ),
                      if (j.payment!.method == PayMethod.cash)
                        KeyValue(tr('Received · change'), '${money(j.payment!.tendered!)} · ${money(j.payment!.change)}'),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Text(tr('Demo: nothing is actually sent.'), style: tt.bodySmall),
              const Spacer(),
              if (next != null) ...[
                Panel(
                  child: Row(
                    children: [
                      TradeBadge(next.trade),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tr('Next: ${next.title}'), style: tt.titleSmall),
                            Text('${window(next.start, next.windowEnd)} · ${s.customer(next.customerId).street}', style: tt.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst), child: Text(tr('Back to today'))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
