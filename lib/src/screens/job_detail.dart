import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../ui.dart';
import 'complete.dart';
import 'signature.dart';

typedef JobAction = ({String label, IconData icon, VoidCallback? onPressed});

/// The one button that moves a job forward.
JobAction primaryAction(BuildContext context, Job j) {
  final s = StoreScope.read(context);
  return switch (j.status) {
    JobStatus.scheduled => (
      label: 'Start travel',
      icon: LucideIcons.car,
      onPressed: () {
        s.startTravel(j.id);
        toast(context, '${s.customer(j.customerId).name} was told you are on the way.');
      },
    ),
    JobStatus.travelling => (label: 'Arrived on site', icon: LucideIcons.mapPinned, onPressed: () => s.arrive(j.id)),
    JobStatus.onSite => (
      label: 'Complete job',
      icon: LucideIcons.circleCheck,
      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CompleteScreen(jobId: j.id))),
    ),
    JobStatus.completed => (label: 'Completed', icon: LucideIcons.check, onPressed: null),
  };
}

class JobDetailScreen extends StatelessWidget {
  const JobDetailScreen({super.key, required this.jobId});
  final String jobId;

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final t = context.t;
    final tt = Theme.of(context).textTheme;
    final j = s.job(jobId);
    final c = s.customer(j.customerId);
    final action = primaryAction(context, j);
    final history = s.history(c.id, except: j.id);
    final editable = !j.done;

    return Scaffold(
      appBar: AppBar(
        title: Text(j.ref),
        actions: [Padding(padding: const EdgeInsets.only(right: 14), child: StatusPill(j.status))],
      ),
      body: Column(
        children: [
          const SyncStrip(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TradeBadge(j.trade, size: 42),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(header: true, child: Text(j.title, style: tt.titleLarge)),
                          const SizedBox(height: 3),
                          Text('${relativeDay(j.date, s.today)} · ${window(j.start, j.windowEnd)} · ${duration(j.duration)}', style: tt.bodySmall),
                        ],
                      ),
                    ),
                    if (j.urgent && !j.done) Tag('Urgent', color: t.danger),
                  ],
                ),
                const SizedBox(height: 16),
                _Steps(status: j.status),
                const SizedBox(height: 14),
                Text(j.description, style: tt.bodyMedium),

                const SectionHeader('Customer'),
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Avatar(c.name, size: 38),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c.name, style: tt.titleMedium),
                                Text('Customer since ${c.since} · ${plural(history.length, 'past visit')}', style: tt.bodySmall),
                              ],
                            ),
                          ),
                          IconButton.outlined(
                            tooltip: 'Call ${c.name}',
                            onPressed: () => toast(context, 'On a phone this calls ${c.phone}.'),
                            icon: const Icon(LucideIcons.phone, size: 16),
                            style: IconButton.styleFrom(
                              side: BorderSide(color: t.border),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _Line(LucideIcons.mapPin, c.address),
                      _Line(LucideIcons.phone, c.phone),
                      if (c.note.isNotEmpty) _Line(LucideIcons.stickyNote, c.note),
                    ],
                  ),
                ),

                SectionHeader('Checklist', trailing: Text('${j.checked} of ${j.checklist.length}', style: tt.bodySmall)),
                Panel(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      for (final (i, item) in j.checklist.indexed)
                        CheckboxListTile(
                          value: item.done,
                          onChanged: editable ? (_) => s.toggleCheck(j.id, i) : null,
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                          title: Text(item.label, style: TextStyle(fontSize: 14, color: item.done ? t.muted : t.text)),
                          subtitle: item.required
                              ? Text(
                                  'Required',
                                  style: TextStyle(fontSize: 11.5, color: t.faint, fontWeight: FontWeight.w500),
                                )
                              : null,
                        ),
                    ],
                  ),
                ),

                SectionHeader(
                  'Parts used',
                  trailing: editable
                      ? TextButton.icon(
                          onPressed: () => showPartPicker(context, j.id),
                          icon: const Icon(LucideIcons.plus, size: 15),
                          label: const Text('Add part'),
                          style: TextButton.styleFrom(minimumSize: const Size(0, 30), padding: const EdgeInsets.symmetric(horizontal: 8)),
                        )
                      : null,
                ),
                Panel(
                  padding: EdgeInsets.zero,
                  child: j.parts.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(LucideIcons.packageOpen, size: 16, color: t.faint),
                              const SizedBox(width: 10),
                              Expanded(child: Text('No parts yet. Parts come out of ${s.tech.van} stock.', style: tt.bodySmall)),
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            for (final (i, u) in j.parts.indexed) ...[
                              if (i > 0) Divider(height: 1, color: t.border),
                              _PartLine(job: j, used: u, editable: editable),
                            ],
                          ],
                        ),
                ),

                SectionHeader('Photos', trailing: Text(plural(j.photos.length, 'photo'), style: tt.bodySmall)),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: [
                    for (final p in j.photos)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            PhotoArt(p),
                            if (editable)
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Material(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: () => s.removePhoto(j.id, p.id),
                                    child: Semantics(
                                      label: 'Remove ${p.label} photo',
                                      button: true,
                                      child: const Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Icon(LucideIcons.x, size: 12, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    if (editable)
                      Semantics(
                        button: true,
                        label: 'Add photo',
                        excludeSemantics: true,
                        child: InkWell(
                          onTap: () {
                            s.addPhoto(j.id);
                            toast(context, 'Photo added. The demo uses a drawn placeholder instead of the camera.');
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: t.border),
                              color: t.surface,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(LucideIcons.camera, size: 18, color: t.muted),
                                const SizedBox(height: 6),
                                Text(
                                  'Add photo',
                                  style: TextStyle(fontSize: 12, color: t.muted, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                const SectionHeader('Notes'),
                _Notes(job: j, enabled: editable),

                if (j.done) ...[const SectionHeader('Sign-off'), _SignOff(job: j)],

                if (history.isNotEmpty) ...[
                  const SectionHeader('Previous visits'),
                  Panel(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (final (i, h) in history.take(4).indexed) ...[
                          if (i > 0) Divider(height: 1, color: t.border),
                          ListTile(
                            dense: true,
                            leading: TradeBadge(h.trade, size: 30),
                            title: Text(h.title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500)),
                            subtitle: Text('${dayShort(h.date)} · ${h.ref}', style: tt.bodySmall),
                            trailing: Text(
                              money(s.invoice(h).total),
                              style: TextStyle(fontSize: 13, color: t.muted, fontFeatures: const [FontFeature.tabularFigures()]),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: j.done
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                decoration: BoxDecoration(
                  color: t.surface,
                  border: Border(top: BorderSide(color: t.border)),
                ),
                child: FilledButton.icon(onPressed: action.onPressed, icon: Icon(action.icon, size: 17), label: Text(action.label)),
              ),
            ),
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps({required this.status});
  final JobStatus status;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    const labels = ['Scheduled', 'On the way', 'On site', 'Completed'];
    final at = status.index;
    return Semantics(
      label: 'Progress: ${labels[at]}, step ${at + 1} of 4',
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 0; i < 4; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < 3 ? 4 : 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 4,
                      decoration: BoxDecoration(color: i <= at ? t.accent : t.surface2, borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      labels[i],
                      style: TextStyle(fontSize: 11, fontWeight: i == at ? FontWeight.w600 : FontWeight.w400, color: i <= at ? t.text : t.faint),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 14, color: t.faint),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5))),
        ],
      ),
    );
  }
}

class _PartLine extends StatelessWidget {
  const _PartLine({required this.job, required this.used, required this.editable});
  final Job job;
  final UsedPart used;
  final bool editable;

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final t = context.t;
    final p = s.part(used.partId);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500)),
                Text('${p.sku} · ${money(used.price)} each', style: TextStyle(fontSize: 12, color: t.muted)),
              ],
            ),
          ),
          if (editable) ...[
            _Step(icon: LucideIcons.minus, label: 'Return one ${p.name}', onTap: () => s.removePart(job.id, p.id)),
            SizedBox(
              width: 28,
              child: Text(
                '${used.qty}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()]),
              ),
            ),
            _Step(
              icon: LucideIcons.plus,
              label: 'Add one ${p.name}',
              onTap: () {
                final err = s.addPart(job.id, p.id);
                if (err != null) toast(context, err);
              },
            ),
          ] else
            Text('× ${used.qty}', style: TextStyle(color: t.muted)),
          const SizedBox(width: 6),
          SizedBox(
            width: 64,
            child: Text(
              money(used.price * used.qty),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, fontFeatures: [FontFeature.tabularFigures()]),
            ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: label,
    onPressed: onTap,
    icon: Icon(icon, size: 14),
    visualDensity: VisualDensity.compact,
    style: IconButton.styleFrom(
      side: BorderSide(color: context.t.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      minimumSize: const Size(30, 30),
    ),
  );
}

class _Notes extends StatefulWidget {
  const _Notes({required this.job, required this.enabled});
  final Job job;
  final bool enabled;

  @override
  State<_Notes> createState() => _NotesState();
}

class _NotesState extends State<_Notes> {
  late final controller = TextEditingController(text: widget.job.notes);
  final focus = FocusNode();

  @override
  void initState() {
    super.initState();
    focus.addListener(() {
      if (!focus.hasFocus) _save();
    });
  }

  void _save() => StoreScope.read(context).setNotes(widget.job.id, controller.text.trim());

  @override
  void dispose() {
    controller.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    focusNode: focus,
    enabled: widget.enabled,
    minLines: 2,
    maxLines: 5,
    onTapOutside: (_) => focus.unfocus(),
    style: const TextStyle(fontSize: 14),
    decoration: const InputDecoration(hintText: 'What you found and what you did', labelText: 'Notes for the office'),
  );
}

class _SignOff extends StatelessWidget {
  const _SignOff({required this.job});
  final Job job;

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final t = context.t;
    final inv = s.invoice(job);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KeyValue('Call-out', money(inv.callOut)),
          KeyValue('Labour, ${duration(inv.labourMinutes)}', money(inv.labour)),
          KeyValue('Parts', money(inv.parts)),
          KeyValue('Tax on parts', money(inv.tax)),
          Divider(color: t.border, height: 16),
          KeyValue('Total', money(inv.total), strong: true),
          const SizedBox(height: 12),
          if (job.signature != null)
            Container(
              height: 86,
              width: double.infinity,
              decoration: BoxDecoration(color: t.surface2, borderRadius: BorderRadius.circular(8)),
              child: Semantics(
                label: 'Signature of ${job.signedBy}',
                image: true,
                child: CustomPaint(painter: SignaturePainter(job.signature!, color: t.text)),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Signed by ${job.signedBy ?? '-'}${job.completedAt != null ? ' at ${clockOf(job.completedAt!)}' : ''}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet listing what is in the van.
Future<void> showPartPicker(BuildContext context, String jobId) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _PartPicker(jobId: jobId),
);

class _PartPicker extends StatefulWidget {
  const _PartPicker({required this.jobId});
  final String jobId;

  @override
  State<_PartPicker> createState() => _PartPickerState();
}

class _PartPickerState extends State<_PartPicker> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final t = context.t;
    final list = s.parts.where((p) => q.isEmpty || p.name.toLowerCase().contains(q) || p.sku.toLowerCase().contains(q)).toList();
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.72,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                Expanded(child: Text('Add from ${s.tech.van}', style: Theme.of(context).textTheme.titleMedium)),
                IconButton(tooltip: 'Close', onPressed: () => Navigator.pop(context), icon: const Icon(LucideIcons.x, size: 18)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: false,
              onChanged: (v) => setState(() => q = v.trim().toLowerCase()),
              decoration: const InputDecoration(prefixIcon: Icon(LucideIcons.search, size: 16), hintText: 'Search parts or SKU'),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: list.isEmpty
                ? Center(child: Text('No parts match "$q".', style: Theme.of(context).textTheme.bodySmall))
                : ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, _) => Divider(height: 1, indent: 16, endIndent: 16, color: t.border),
                    itemBuilder: (_, i) {
                      final p = list[i];
                      final out = p.qty <= 0;
                      return ListTile(
                        enabled: !out,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        title: Text(p.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                        subtitle: Text('${p.sku} · ${money(p.price)}', style: TextStyle(fontSize: 12, color: t.muted)),
                        trailing: Text(
                          out ? 'Out of stock' : '${p.qty} in van',
                          style: TextStyle(fontSize: 12, color: out ? t.danger : (p.low ? t.warning : t.muted), fontWeight: FontWeight.w500),
                        ),
                        onTap: () {
                          final err = s.addPart(widget.jobId, p.id);
                          toast(context, err ?? 'Added ${p.name}.');
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
