import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../format.dart';
import '../store.dart';
import '../theme.dart';
import '../ui.dart';
import 'job_tile.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  String? selected;
  final strip = ScrollController(initialScrollOffset: 6 * 52.0 - 40);

  @override
  void dispose() {
    strip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final t = context.t;
    final tt = Theme.of(context).textTheme;
    final day = selected ?? s.today;
    final days = [for (var i = -6; i <= 7; i++) addDays(s.today, i)];
    final jobs = s.jobsOn(day);
    final booked = jobs.fold<int>(0, (sum, j) => sum + j.duration);
    final done = jobs.where((j) => j.done).length;

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dayLong(day), style: tt.bodySmall),
                const SizedBox(height: 2),
                Semantics(header: true, child: Text('Schedule', style: tt.headlineSmall)),
              ],
            ),
          ),
          const Padding(padding: EdgeInsets.only(top: 8), child: SyncStrip()),
          SizedBox(
            height: 74,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              itemCount: days.length,
              controller: strip,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final d = days[i];
                final n = s.jobsOn(d).length;
                final on = d == day;
                final isToday = d == s.today;
                return Semantics(
                  button: true,
                  selected: on,
                  label: '${dayShort(d)}, ${plural(n, 'job')}',
                  excludeSemantics: true,
                  child: InkWell(
                    onTap: () => setState(() => selected = d),
                    borderRadius: BorderRadius.circular(9),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 46,
                      decoration: BoxDecoration(
                        color: on ? t.accent : t.surface,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: on ? t.accent : t.border),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            weekdayShort(d),
                            style: TextStyle(fontSize: 11, color: on ? t.onAccent.withValues(alpha: 0.8) : t.muted, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${dayOfMonth(d)}',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: on ? t.onAccent : t.text),
                          ),
                          const SizedBox(height: 3),
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: n == 0 ? Colors.transparent : (on ? t.onAccent : (isToday ? t.accent : t.faint)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Text(
              jobs.isEmpty
                  ? relativeDay(day, s.today)
                  : '${relativeDay(day, s.today)} · ${plural(jobs.length, 'job')} · ${duration(booked)}${done > 0 ? ' · $done done' : ''}',
              style: tt.titleSmall?.copyWith(color: t.muted),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: jobs.isEmpty
                  ? Center(
                      key: ValueKey('empty$day'),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.calendar, size: 22, color: t.faint),
                          const SizedBox(height: 8),
                          Text('No jobs on this day', style: tt.bodySmall),
                        ],
                      ),
                    )
                  : ListView.builder(
                      key: ValueKey(day),
                      padding: const EdgeInsets.fromLTRB(10, 6, 16, 24),
                      itemCount: jobs.length,
                      itemBuilder: (_, i) => TimelineJob(job: jobs[i], first: i == 0, last: i == jobs.length - 1),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
