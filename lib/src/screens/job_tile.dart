import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../ui.dart';
import 'job_detail.dart';

void openJob(BuildContext context, Job j) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => JobDetailScreen(jobId: j.id)));

/// One stop on a timeline: time on the left, a rail with a status dot, the job on the right.
class TimelineJob extends StatelessWidget {
  const TimelineJob({super.key, required this.job, this.first = false, this.last = false, this.highlight = false});
  final Job job;
  final bool first, last, highlight;

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final t = context.t;
    final c = s.customer(job.customerId);
    final look = statusLook(context, job.status);
    final time = clock(job.start).split(' ');
    return Semantics(
      button: true,
      label: '${clock(job.start)}, ${job.title}, ${c.name}, ${look.label}${job.urgent && !job.done ? ', urgent' : ''}',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => openJob(context, job),
        borderRadius: BorderRadius.circular(10),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 46,
                child: Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        time[0],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: job.done ? t.faint : t.text,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(time[1], style: TextStyle(fontSize: 10.5, color: t.faint)),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 28,
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    Positioned(
                      top: first ? 18 : 0,
                      bottom: last ? null : 0,
                      height: last ? 18 : null,
                      child: Container(width: 1.5, color: t.border),
                    ),
                    Positioned(
                      top: 14,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: job.done ? look.color : t.bg,
                          shape: BoxShape.circle,
                          border: Border.all(color: job.status == JobStatus.scheduled ? t.faint : look.color, width: 2),
                        ),
                        child: job.done ? Icon(LucideIcons.check, size: 7, color: t.bg) : null,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
                    decoration: BoxDecoration(
                      color: t.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: highlight ? t.accent.withValues(alpha: 0.55) : t.border),
                    ),
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
                                      job.title,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: job.done ? t.muted : t.text, letterSpacing: -0.15),
                                    ),
                                  ),
                                  if (job.urgent && !job.done) ...[const SizedBox(width: 6), Tag('Urgent', color: t.danger)],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${c.name} · ${c.street}',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12.5, color: t.muted),
                              ),
                              const SizedBox(height: 7),
                              Row(
                                children: [
                                  StatusPill(job.status),
                                  const SizedBox(width: 8),
                                  Icon(LucideIcons.clock3, size: 12, color: t.faint),
                                  const SizedBox(width: 4),
                                  Text(duration(job.duration), style: TextStyle(fontSize: 11.5, color: t.faint)),
                                  if (job.done) ...[
                                    const Spacer(),
                                    Text(
                                      money(s.invoice(job).total),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: t.muted,
                                        fontFeatures: const [FontFeature.tabularFigures()],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (!job.done) ...[const SizedBox(width: 8), Icon(LucideIcons.chevronRight, size: 16, color: t.faint)],
                      ],
                    ),
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
