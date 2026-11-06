import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../format.dart';
import '../models.dart';
import '../seed.dart';
import '../store.dart';
import '../theme.dart';
import '../ui.dart';
import 'job_detail.dart';
import 'job_tile.dart';
import '../i18n.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key, required this.onOpenProfile});
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final t = context.t;
    final tt = Theme.of(context).textTheme;
    final jobs = s.todayJobs;
    final current = s.current;
    final done = jobs.where((j) => j.done).toList();
    final live = jobs.where((j) => !j.cancelled).toList();
    final invoiced = done.fold<double>(0, (sum, j) => sum + s.invoice(j).total);
    final booked = live.fold<int>(0, (sum, j) => sum + j.duration);

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(dayLong(s.today), style: tt.bodySmall),
                        const SizedBox(height: 2),
                        Semantics(header: true, child: Text(tr('Today'), style: tt.headlineSmall)),
                      ],
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: tr('Profile, ${s.tech.name}'),
                    excludeSemantics: true,
                    child: InkWell(customBorder: const CircleBorder(), onTap: onOpenProfile, child: Avatar(s.tech.name, size: 38)),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(padding: EdgeInsets.only(top: 8), child: SyncStrip()),
          ),
          const SliverToBoxAdapter(child: SyncInbox()),
          const SliverToBoxAdapter(child: _RunningLate()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Panel(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Metric(label: tr('Jobs done'), value: tr('${done.length} of ${live.length}')),
                        ),
                        Expanded(
                          child: Metric(label: tr('Booked'), value: duration(booked)),
                        ),
                        Expanded(
                          child: Metric(label: tr('Invoiced'), value: money(invoiced, cents: false)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _DayBar(jobs: jobs),
                  ],
                ),
              ),
            ),
          ),
          if (current != null)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(current.active ? tr('In progress') : tr('Up next')),
                    _NextJob(job: current),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Panel(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(LucideIcons.circleCheckBig, size: 26, color: t.success),
                      const SizedBox(height: 10),
                      Text(tr('All jobs done for today'), style: tt.titleMedium),
                      const SizedBox(height: 4),
                      Text(tr('${plural(done.length, 'job')} completed, ${money(invoiced)} invoiced.'), style: tt.bodySmall, textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: SectionHeader(tr('Route'), trailing: Text(plural(jobs.length, 'stop'), style: tt.bodySmall)),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(10, 0, 16, 24),
            sliver: SliverList.builder(
              itemCount: jobs.length,
              itemBuilder: (_, i) => TimelineJob(job: jobs[i], first: i == 0, last: i == jobs.length - 1, highlight: jobs[i] == current),
            ),
          ),
        ],
      ),
    );
  }
}

/// The day as one bar: a segment per job, filled as jobs get done.
class _DayBar extends StatelessWidget {
  const _DayBar({required this.jobs});
  final List<Job> jobs;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return ExcludeSemantics(
      child: Row(
        children: [
          for (final (i, j) in jobs.indexed) ...[
            if (i > 0) const SizedBox(width: 3),
            Expanded(
              flex: j.duration,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 6,
                decoration: BoxDecoration(
                  color: switch (j.status) {
                    JobStatus.completed => t.accent,
                    JobStatus.cancelled => t.border,
                    JobStatus.onSite || JobStatus.travelling => t.accent.withValues(alpha: 0.45),
                    JobStatus.scheduled => t.surface2,
                  },
                  borderRadius: BorderRadius.circular(3),
                  border: j.status == JobStatus.scheduled ? Border.all(color: t.border) : null,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NextJob extends StatelessWidget {
  const _NextJob({required this.job});
  final Job job;

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final t = context.t;
    final tt = Theme.of(context).textTheme;
    final c = s.customer(job.customerId);
    final action = primaryAction(context, job);
    final late = job.status == JobStatus.scheduled && s.nowMinutes + job.drive > job.windowEnd;
    return Panel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => openJob(context, job),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TradeBadge(job.trade, size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(job.title, style: tt.titleMedium, overflow: TextOverflow.ellipsis),
                                ),
                                if (job.urgent) ...[const SizedBox(width: 6), Tag(tr('Urgent'), color: t.danger)],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text('${job.ref} · ${c.name}', style: tt.bodySmall),
                          ],
                        ),
                      ),
                      StatusPill(job.status),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    job.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodyMedium?.copyWith(color: t.muted),
                  ),
                  const SizedBox(height: 12),
                  _Fact(LucideIcons.mapPin, c.address),
                  const SizedBox(height: 6),
                  _Fact(
                    LucideIcons.clock3,
                    tr('Arrive ${window(job.start, job.windowEnd)}'),
                    trailing: late ? Tag(tr('Running late'), color: t.warning) : null,
                  ),
                  const SizedBox(height: 6),
                  _Fact(LucideIcons.car, tr('${job.drive} min drive · ${duration(job.duration)} on site')),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: t.border),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                _IconAction(
                  icon: LucideIcons.navigation,
                  label: tr('Directions to ${c.name}'),
                  onTap: () => toast(context, 'On a phone this opens Maps with directions to ${c.street}.'),
                ),
                const SizedBox(width: 8),
                _IconAction(icon: LucideIcons.phone, label: tr('Call ${c.name}'), onTap: () => toast(context, 'On a phone this calls ${c.phone}.')),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(onPressed: action.onPressed, icon: Icon(action.icon, size: 16), label: Text(action.label)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.icon, this.text, {this.trailing});
  final IconData icon;
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Row(
      children: [
        Icon(icon, size: 14, color: t.faint),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: t.text),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: SizedBox(
      width: 44,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
        child: Semantics(label: label, child: Icon(icon, size: 17)),
      ),
    ),
  );
}

/// Shown under the company name in a few places.
String companyLine(AppStore s) => '$company · ${s.tech.van}';

/// Customers who will be waiting past their arrival window, with one tap to text them the new time.
class _RunningLate extends StatelessWidget {
  const _RunningLate();

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final t = context.t;
    final tt = Theme.of(context).textTheme;
    final late = s.lateUntold;
    if (late.isEmpty) return const SizedBox(width: double.infinity);
    final eta = s.etas();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Panel(
        color: t.surface2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.clockAlert, size: 15, color: t.danger),
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(header: true, child: Text(tr('Running late'), style: tt.titleSmall)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            for (final j in late)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  tr('${s.customer(j.customerId).name}: arriving around ${clock(AppStore.roundEta(eta[j.id]!))}, window ${window(j.start, j.windowEnd)}'),
                  style: tt.bodyMedium,
                ),
              ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: () {
                  final n = s.notifyLate();
                  toast(context, '${plural(n, 'customer')} texted with the new arrival time.');
                },
                icon: const Icon(LucideIcons.messageSquareText, size: 16),
                label: Text(late.length == 1 ? tr('Text the customer') : tr('Text ${late.length} customers')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
