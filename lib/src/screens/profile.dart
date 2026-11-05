import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../format.dart';
import '../seed.dart';
import '../store.dart';
import '../theme.dart';
import '../ui.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final t = context.t;
    final tt = Theme.of(context).textTheme;
    final w = s.week();
    final daily = s.daily(7);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          Semantics(header: true, child: Text('Profile', style: tt.headlineSmall)),
          const SizedBox(height: 14),
          Panel(
            child: Row(
              children: [
                Avatar(s.tech.name, size: 48),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.tech.name, style: tt.titleMedium),
                      Text(s.tech.role, style: tt.bodySmall),
                      Text('$company · ${s.tech.van}', style: tt.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SyncStrip(),

          const _Today(),

          const SectionHeader('Last 7 days'),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Metric(label: 'Jobs', value: '${w.jobs}'),
                    ),
                    Expanded(
                      child: Metric(label: 'On site', value: '${(w.minutes / 60).round()} h'),
                    ),
                    Expanded(
                      child: Metric(label: 'Invoiced', value: money(w.revenue, cents: false)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('First-time fix ${(w.firstTimeFix * 100).round()}%', style: tt.bodySmall),
                const SizedBox(height: 14),
                SizedBox(
                  height: 120,
                  child: _Bars(daily: daily, today: s.today),
                ),
              ],
            ),
          ),

          const SectionHeader('Sync'),
          Panel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  value: s.offline,
                  onChanged: s.syncing ? null : s.setOffline,
                  title: const Text('Work offline', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  subtitle: Text('Pretend there is no signal. Changes wait on the phone until you go online.', style: tt.bodySmall),
                  secondary: Icon(s.offline ? LucideIcons.wifiOff : LucideIcons.wifi, size: 18, color: t.muted),
                ),
                Divider(height: 1, color: t.border),
                Semantics(
                  container: true,
                  child: ListTile(
                    leading: Icon(LucideIcons.building2, size: 18, color: t.muted),
                    title: const Text('Office changes', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    subtitle: Text(
                      s.officeQueue.isNotEmpty ? '${plural(s.officeQueue.length, 'change')} from the office waiting for the next sync.' : 'While offline, let the office cancel your current job, move the next one and add an urgent call. Go online to sync and see how clashes are handled.',
                      style: tt.bodySmall,
                    ),
                    trailing: s.offline && s.officeQueue.isEmpty
                        ? TextButton(
                            onPressed: () {
                              final err = s.simulateOfficeChanges();
                              toast(context, err ?? 'The office changed your day. Go online to sync.');
                            },
                            child: const Text('Simulate'),
                          )
                        : null,
                  ),
                ),
                Divider(height: 1, color: t.border),
                Semantics(
                  container: true,
                  child: ListTile(
                    leading: s.syncing
                        ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 1.8, color: t.accent))
                        : Icon(
                            s.pending.isEmpty ? LucideIcons.cloudCheck : LucideIcons.cloudUpload,
                            size: 18,
                            color: s.pending.isEmpty ? t.success : t.warning,
                          ),
                    title: Text(
                      s.syncing ? 'Syncing…' : (s.pending.isEmpty ? 'Everything is synced' : '${plural(s.pending.length, 'change')} waiting'),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(s.lastSync == null ? 'Not synced yet' : 'Last synced ${ago(s.lastSync!, s.now())}', style: tt.bodySmall),
                    trailing: !s.offline && (s.pending.isNotEmpty || s.officeQueue.isNotEmpty) && !s.syncing
                        ? TextButton(onPressed: s.sync, child: const Text('Sync now'))
                        : null,
                  ),
                ),
                if (s.pending.isNotEmpty) ...[
                  Divider(height: 1, color: t.border),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final p in s.pending.reversed.take(6))
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                Icon(LucideIcons.circleDashed, size: 12, color: t.faint),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(p.label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)),
                                ),
                                Text(clockOf(p.at), style: TextStyle(fontSize: 11.5, color: t.faint)),
                              ],
                            ),
                          ),
                        if (s.pending.length > 6) Text('and ${s.pending.length - 6} more', style: tt.bodySmall),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SectionHeader('Appearance'),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(LucideIcons.smartphone, size: 15)),
                ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(LucideIcons.sun, size: 15)),
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(LucideIcons.moon, size: 15)),
              ],
              selected: {s.themeMode},
              onSelectionChanged: (v) => s.setTheme(v.first),
            ),
          ),

          const SectionHeader('Demo'),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$company, its customers and jobs are synthetic (phone numbers are 555-01xx). Everything is stored on this device and starts fresh each day.',
                  style: tt.bodySmall,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _confirmReset(context, s),
                  icon: Icon(LucideIcons.rotateCcw, size: 15, color: t.danger),
                  label: Text('Reset demo data', style: TextStyle(color: t.danger)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, AppStore s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Reset demo data?'),
        content: const Text('Your changes to jobs, stock and settings are removed and today\'s demo route is restored.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Reset')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      s.reset();
      toast(context, 'Demo data was reset.');
    }
  }
}

/// Calm bar chart of invoiced totals per day.
class _Bars extends StatelessWidget {
  const _Bars({required this.daily, required this.today});
  final List<(String, double)> daily;
  final String today;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final max = daily.fold<double>(0, (m, d) => math.max(m, d.$2));
    return Semantics(
      label: 'Invoiced per day: ${daily.map((d) => '${weekdayShort(d.$1)} ${money(d.$2, cents: false)}').join(', ')}',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (date, v) in daily)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (v > 0) Text(moneyShort(v), style: TextStyle(fontSize: 9.5, color: t.faint)),
                    const SizedBox(height: 4),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: max == 0 ? 0 : v / max),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                      builder: (_, f, _) => Container(
                        height: math.max(2, 72 * f),
                        decoration: BoxDecoration(color: date == today ? t.accent : t.accent.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(3)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      weekdayShort(date),
                      style: TextStyle(fontSize: 11, color: date == today ? t.text : t.muted, fontWeight: date == today ? FontWeight.w600 : FontWeight.w400),
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

/// Today's hours (from the job times and breaks), money taken, and texts sent to customers.
class _Today extends StatelessWidget {
  const _Today();

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final t = context.t;
    final tt = Theme.of(context).textTheme;
    final sheet = s.timesheet();
    final money0 = s.takings();
    final onBreak = s.onBreak;
    final texts = s.messages.where((m) => dateKey(m.at) == s.today).toList().reversed.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          'Today\'s hours',
          trailing: TextButton.icon(
            onPressed: () {
              if (onBreak != null) {
                s.endBreak();
                toast(context, 'Break ended.');
              } else {
                final err = s.startBreak();
                toast(context, err ?? 'Break started. Customers see you as unavailable.');
              }
            },
            icon: Icon(onBreak != null ? LucideIcons.play : LucideIcons.coffee, size: 15),
            label: Text(onBreak != null ? 'End break' : 'Start break'),
            style: TextButton.styleFrom(minimumSize: const Size(0, 30), padding: const EdgeInsets.symmetric(horizontal: 8)),
          ),
        ),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Metric(
                      label: 'Worked',
                      value: duration(sheet.worked),
                      sub: sheet.clockIn == null ? 'Not started' : 'Since ${clockOf(sheet.clockIn!)}',
                    ),
                  ),
                  Expanded(
                    child: Metric(label: 'Driving', value: duration(sheet.travel)),
                  ),
                  Expanded(
                    child: Metric(label: 'On site', value: duration(sheet.onSite)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                [
                  'Breaks ${duration(sheet.breaks)}',
                  if (onBreak != null) 'on a break since ${clockOf(onBreak.start)}',
                  if (sheet.overtime > 0) 'overtime ${duration(sheet.overtime)}' else 'overtime starts after 8 h',
                ].join(' · '),
                style: tt.bodySmall?.copyWith(color: sheet.overtime > 0 ? t.warning : null),
              ),
            ],
          ),
        ),
        const SectionHeader('Taken today'),
        Panel(
          child: Row(
            children: [
              Expanded(
                child: Metric(label: 'Card', value: money(money0.card, cents: false)),
              ),
              Expanded(
                child: Metric(label: 'Cash', value: money(money0.cash, cents: false)),
              ),
              Expanded(
                child: Metric(label: 'To invoice', value: money(money0.invoice, cents: false)),
              ),
            ],
          ),
        ),
        if (texts.isNotEmpty) ...[
          const SectionHeader('Texts to customers'),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final m in texts.take(5))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${s.customer(m.customerId).name} · ${clockOf(m.at)}', style: tt.titleSmall),
                        Text(m.body, style: tt.bodySmall),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
