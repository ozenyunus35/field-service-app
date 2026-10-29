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
    final invoiced = done.fold<double>(0, (sum, j) => sum + s.invoice(j).total);
    final booked = jobs.fold<int>(0, (sum, j) => sum + j.duration);

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
                        Semantics(header: true, child: Text('Today', style: tt.headlineSmall)),
                      ],
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Profile, ${s.tech.name}',
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
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Panel(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Metric(label: 'Jobs done', value: '${done.length} of ${jobs.length}'),
                        ),
                        Expanded(
                          child: Metric(label: 'Booked', value: duration(booked)),
                        ),
                        Expanded(
                          child: Metric(label: 'Invoiced', value: money(invoiced, cents: false)),
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
                    SectionHeader(current.active ? 'In progress' : 'Up next'),
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
                      Text('All jobs done for today', style: tt.titleMedium),
                      const SizedBox(height: 4),
                      Text('${plural(done.length, 'job')} completed, ${money(invoiced)} invoiced.', style: tt.bodySmall, textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: SectionHeader('Route', trailing: Text(plural(jobs.length, 'stop'), style: tt.bodySmall)),
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
                                if (job.urgent) ...[const SizedBox(width: 6), Tag('Urgent', color: t.danger)],
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
                  _Fact(LucideIcons.clock3, 'Arrive ${window(job.start, job.windowEnd)}', trailing: late ? Tag('Running late', color: t.warning) : null),
                  const SizedBox(height: 6),
                  _Fact(LucideIcons.car, '${job.drive} min drive · ${duration(job.duration)} on site'),
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
                  label: 'Directions to ${c.name}',
                  onTap: () => toast(context, 'On a phone this opens Maps with directions to ${c.street}.'),
                ),
                const SizedBox(width: 8),
                _IconAction(icon: LucideIcons.phone, label: 'Call ${c.name}', onTap: () => toast(context, 'On a phone this calls ${c.phone}.')),
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
