import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../format.dart';
import '../models.dart';
import '../seed.dart';
import '../store.dart';
import '../theme.dart';
import '../ui.dart';
import 'signature.dart';

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
  late int labour = AppStore.billable(j.duration);
  late final name = TextEditingController(text: s.customer(j.customerId).name);
  Strokes signature = const [];

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  void _submit() {
    final err = s.complete(j.id, labourMinutes: labour, signature: signature, signedBy: name.text);
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
      appBar: AppBar(title: const Text('Complete job')),
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
                          'Finish the required checks first',
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

          const SectionHeader('Labour'),
          Panel(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(duration(labour), style: tt.titleMedium),
                      Text('Booked ${duration(j.duration)} · ${money(s.tech.hourlyRate, cents: false)}/h', style: tt.bodySmall),
                    ],
                  ),
                ),
                IconButton.outlined(
                  tooltip: 'Less labour time',
                  onPressed: labour > 30 ? () => setState(() => labour -= 15) : null,
                  icon: const Icon(LucideIcons.minus, size: 15),
                  style: IconButton.styleFrom(
                    side: BorderSide(color: t.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.outlined(
                  tooltip: 'More labour time',
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

          const SectionHeader('Invoice'),
          Panel(
            child: Column(
              children: [
                KeyValue('Call-out', money(inv.callOut)),
                KeyValue('Labour, ${duration(inv.labourMinutes)}', money(inv.labour)),
                for (final u in j.parts) KeyValue('${s.part(u.partId).name} × ${u.qty}', money(u.price * u.qty)),
                KeyValue('Tax on parts (${(taxRate * 100).toStringAsFixed(2)}%)', money(inv.tax)),
                Divider(color: t.border, height: 18),
                TweenAnimationBuilder<double>(
                  tween: Tween(end: inv.total),
                  duration: const Duration(milliseconds: 260),
                  builder: (_, v, _) => KeyValue('Total', money(v), strong: true),
                ),
              ],
            ),
          ),

          SectionHeader(
            'Customer sign-off',
            trailing: signature.isEmpty
                ? null
                : TextButton.icon(
                    onPressed: () => pad.currentState?.clear(),
                    icon: const Icon(LucideIcons.eraser, size: 14),
                    label: const Text('Clear'),
                    style: TextButton.styleFrom(minimumSize: const Size(0, 30), padding: const EdgeInsets.symmetric(horizontal: 8)),
                  ),
          ),
          SignaturePad(key: pad, onChanged: (v) => setState(() => signature = v)),
          const SizedBox(height: 10),
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Signed by'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Text('By signing, the customer confirms the work and the total above.', style: tt.bodySmall),
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
                    blockers.join(' · '),
                    style: TextStyle(fontSize: 12, color: t.muted),
                    textAlign: TextAlign.center,
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: blockers.isEmpty && name.text.trim().isNotEmpty ? _submit : null,
                  icon: const Icon(LucideIcons.send, size: 16),
                  label: Text('Complete and send ${money(inv.total)}'),
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
              Semantics(header: true, child: Text('Job completed', style: tt.headlineSmall)),
              const SizedBox(height: 8),
              Text(
                '${j.ref} for ${c.name}: invoice of ${money(s.invoice(j).total)} ${s.offline ? 'saved on this phone. It is sent when you are back online.' : 'sent to the customer.'}',
                textAlign: TextAlign.center,
                style: tt.bodyMedium?.copyWith(color: t.muted),
              ),
              const SizedBox(height: 6),
              Text('Demo: nothing is actually sent.', style: tt.bodySmall),
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
                            Text('Next: ${next.title}', style: tt.titleSmall),
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
                child: FilledButton(onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst), child: const Text('Back to today')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
