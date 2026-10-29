import 'dart:convert';

import 'package:fieldline/src/format.dart';
import 'package:fieldline/src/models.dart';
import 'package:fieldline/src/seed.dart';
import 'package:fieldline/src/store.dart';
import 'package:flutter/material.dart' show Offset, ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thursday 29 October 2026, 10:00.
final thursday = DateTime(2026, 10, 29, 10);

const Strokes sig = [
  [Offset(0.1, 0.5), Offset(0.3, 0.4), Offset(0.5, 0.6)],
];

Future<AppStore> fresh({DateTime? at}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return AppStore(prefs, clock: () => at ?? thursday, syncDelay: const Duration(milliseconds: 10));
}

void main() {
  group('seed', () {
    test('is the same for the same day', () {
      final a = buildSeed(thursday), b = buildSeed(thursday.add(const Duration(hours: 5)));
      expect(jsonEncode(a.jobs.map((j) => j.toJson()).toList()), jsonEncode(b.jobs.map((j) => j.toJson()).toList()));
    });

    test('changes from one day to the next', () {
      final a = buildSeed(thursday), b = buildSeed(thursday.add(const Duration(days: 1)));
      expect(a.customers.map((c) => c.name).join(), isNot(b.customers.map((c) => c.name).join()));
    });

    test('today has a fixed route: two jobs done, an urgent call next', () async {
      final s = await fresh();
      final today = s.todayJobs;
      expect(today, hasLength(6));
      expect(today.take(2).every((j) => j.done), isTrue);
      expect(today.skip(2).every((j) => j.status == JobStatus.scheduled), isTrue);
      expect(s.current!.title, 'No heat');
      expect(s.current!.urgent, isTrue);
      expect(clock(s.current!.start), '10:30 AM');
    });

    test('past days are completed and signed, future days scheduled, no Sundays', () {
      final seed = buildSeed(thursday);
      final today = dateKey(thursday);
      for (final j in seed.jobs) {
        expect(weekday(j.date), isNot(6), reason: '${j.date} is a Sunday');
        if (j.date.compareTo(today) < 0) {
          expect(j.done, isTrue);
          expect(j.signature, isNotEmpty);
          expect(j.requiredLeft, 0);
        }
        if (j.date.compareTo(today) > 0) expect(j.status, JobStatus.scheduled);
      }
    });

    test('jobs on a day never overlap and end by 6 PM', () {
      final seed = buildSeed(thursday);
      final byDay = <String, List<Job>>{};
      for (final j in seed.jobs) {
        byDay.putIfAbsent(j.date, () => []).add(j);
      }
      for (final list in byDay.values) {
        list.sort((a, b) => a.start.compareTo(b.start));
        for (var i = 1; i < list.length; i++) {
          expect(list[i].start, greaterThanOrEqualTo(list[i - 1].start + list[i - 1].duration));
        }
        expect(list.last.start + list.last.duration, lessThanOrEqualTo(18 * 60));
      }
    });

    test('contacts are clearly synthetic and refs are unique', () {
      final seed = buildSeed(thursday);
      expect(seed.customers.every((c) => RegExp(r'^\(312\) 555-01\d\d$').hasMatch(c.phone)), isTrue);
      expect(seed.jobs.map((j) => j.ref).toSet(), hasLength(seed.jobs.length));
      expect(seed.customers.map((c) => c.name).toSet(), hasLength(seed.customers.length));
    });
  });

  group('job flow', () {
    test('travel, arrive, then the job is the current one', () async {
      final s = await fresh();
      final j = s.current!;
      s.startTravel(j.id);
      expect(j.status, JobStatus.travelling);
      expect(j.startedAt, thursday);
      s.arrive(j.id);
      expect(j.status, JobStatus.onSite);
      expect(s.current, j);
    });

    test('a later scheduled job in progress becomes current', () async {
      final s = await fresh();
      final later = s.todayJobs.last;
      s.arrive(later.id);
      expect(s.current, later);
    });

    test('cannot complete with required checks open', () async {
      final s = await fresh();
      final j = s.current!;
      s.arrive(j.id);
      expect(s.complete(j.id, labourMinutes: 60, signature: sig, signedBy: 'A'), contains('required check'));
      expect(j.done, isFalse);
    });

    test('cannot complete without a signature or a name', () async {
      final s = await fresh();
      final j = s.current!;
      for (final (i, c) in j.checklist.indexed) {
        if (c.required) s.toggleCheck(j.id, i);
      }
      expect(s.complete(j.id, labourMinutes: 60, signature: const [], signedBy: 'A'), 'Customer signature missing');
      expect(s.complete(j.id, labourMinutes: 60, signature: sig, signedBy: '  '), contains('name'));
    });

    test('completes with checks, signature and billable labour', () async {
      final s = await fresh();
      final j = s.current!;
      s.arrive(j.id);
      for (final (i, c) in j.checklist.indexed) {
        if (c.required) s.toggleCheck(j.id, i);
      }
      expect(s.complete(j.id, labourMinutes: 70, signature: sig, signedBy: ' Elena '), isNull);
      expect(j.done, isTrue);
      expect(j.labourMinutes, 75);
      expect(j.signedBy, 'Elena');
      expect(j.completedAt, thursday);
      expect(s.current, isNot(j));
      expect(s.complete(j.id, labourMinutes: 70, signature: sig, signedBy: 'x'), contains('already'));
    });

    test('checklist and parts are locked once completed', () async {
      final s = await fresh();
      final done = s.todayJobs.first;
      final before = done.checklist.map((c) => c.done).toList();
      s.toggleCheck(done.id, 0);
      expect(done.checklist.map((c) => c.done).toList(), before);
      expect(s.addPart(done.id, 'filter'), contains('already'));
    });
  });

  group('parts and stock', () {
    test('using a part takes it out of the van and back again', () async {
      final s = await fresh();
      final j = s.current!;
      final p = s.part('flame-sensor');
      final start = p.qty;
      expect(s.addPart(j.id, p.id), isNull);
      expect(s.addPart(j.id, p.id), isNull);
      expect(p.qty, start - 2);
      expect(j.parts.single.qty, 2);
      s.removePart(j.id, p.id);
      s.removePart(j.id, p.id);
      expect(p.qty, start);
      expect(j.parts, isEmpty);
    });

    test('an empty van says so', () async {
      final s = await fresh();
      final j = s.current!;
      final p = s.part('water-heater');
      expect(s.addPart(j.id, p.id), isNull);
      expect(p.qty, 0);
      expect(s.addPart(j.id, p.id), contains('out of stock'));
    });

    test('low stock and restock requests', () async {
      final s = await fresh();
      final low = s.lowStock.map((p) => p.id);
      expect(low, containsAll(['igniter', 'push-coupling', 'pressure-switch']));
      s.requestRestock('igniter');
      expect(s.part('igniter').restockRequested, isTrue);
    });

    test('invoice adds call-out, labour, parts and tax on parts', () async {
      final s = await fresh();
      final j = s.current!;
      s.addPart(j.id, 'igniter');
      s.addPart(j.id, 'flame-sensor');
      final inv = s.invoice(j, labourMinutes: 75);
      expect(inv.callOut, 79);
      expect(inv.labour, 137.5);
      expect(inv.parts, 70);
      expect(inv.tax, 7.18);
      expect(inv.total, closeTo(293.68, 0.001));
    });

    test('labour is billed in 15 minute steps, at least 30', () {
      expect(AppStore.billable(10), 30);
      expect(AppStore.billable(31), 45);
      expect(AppStore.billable(75), 75);
      expect(AppStore.billable(76), 90);
    });

    test('a used part keeps the price it had', () async {
      final s = await fresh();
      final j = s.current!;
      s.addPart(j.id, 'filter');
      expect(j.parts.single.price, 24);
    });
  });

  group('offline and sync', () {
    test('changes wait while offline and sync when back online', () async {
      final s = await fresh();
      final j = s.current!;
      s.setOffline(true);
      s.startTravel(j.id);
      s.toggleCheck(j.id, 0);
      expect(s.pending.map((p) => p.label), ['${j.ref}: on the way', '${j.ref}: checked "${j.checklist[0].label}"']);
      s.setOffline(false);
      expect(s.syncing, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(s.syncing, isFalse);
      expect(s.pending, isEmpty);
      expect(s.lastSync, thursday);
    });

    test('online changes do not queue', () async {
      final s = await fresh();
      s.startTravel(s.current!.id);
      expect(s.pending, isEmpty);
    });
  });

  group('storage', () {
    test('state survives a restart the same day', () async {
      final s = await fresh();
      final j = s.current!;
      s.arrive(j.id);
      s.addPart(j.id, 'igniter');
      s.setOffline(true);
      s.setNotes(j.id, 'Replaced igniter');
      s.setTheme(ThemeMode.dark);
      final again = AppStore(await SharedPreferences.getInstance(), clock: () => thursday.add(const Duration(hours: 2)));
      final k = again.job(j.id);
      expect(k.status, JobStatus.onSite);
      expect(k.parts.single.partId, 'igniter');
      expect(k.notes, 'Replaced igniter');
      expect(again.part('igniter').qty, 1);
      expect(again.offline, isTrue);
      expect(again.pending, hasLength(1));
      expect(again.themeMode, ThemeMode.dark);
    });

    test('a new day starts a fresh route but keeps the theme', () async {
      final s = await fresh();
      s.arrive(s.current!.id);
      s.setTheme(ThemeMode.light);
      final tomorrow = AppStore(await SharedPreferences.getInstance(), clock: () => thursday.add(const Duration(days: 1)));
      expect(tomorrow.seededOn, '2026-10-30');
      expect(tomorrow.todayJobs.where((j) => j.active), isEmpty);
      expect(tomorrow.themeMode, ThemeMode.light);
    });

    test('broken storage re-seeds instead of crashing', () async {
      SharedPreferences.setMockInitialValues({'fieldline:state': '{not json'});
      final s = AppStore(await SharedPreferences.getInstance(), clock: () => thursday);
      expect(s.todayJobs, hasLength(6));
    });

    test('reset restores the demo route', () async {
      final s = await fresh();
      s.arrive(s.current!.id);
      s.addPart(s.current!.id, 'igniter');
      s.reset();
      expect(s.todayJobs.where((j) => j.active), isEmpty);
      expect(s.part('igniter').qty, 2);
    });

    test('jobs round-trip through JSON', () {
      final j = buildSeed(thursday).jobs.firstWhere((j) => j.photos.isNotEmpty);
      expect(jsonEncode(Job.fromJson(jsonDecode(jsonEncode(j.toJson()))).toJson()), jsonEncode(j.toJson()));
    });
  });

  group('stats', () {
    test('last 7 days', () async {
      final s = await fresh();
      final w = s.week();
      expect(w.jobs, greaterThan(15));
      expect(w.revenue, greaterThan(3000));
      expect(w.firstTimeFix, inInclusiveRange(0, 1));
      final d = s.daily(7);
      expect(d, hasLength(7));
      expect(d.last.$1, '2026-10-29');
      expect(d.fold<double>(0, (a, b) => a + b.$2), closeTo(w.revenue, 0.01));
    });

    test('customer history skips the current job and open jobs', () async {
      final s = await fresh();
      final j = s.todayJobs.first;
      final h = s.history(j.customerId, except: j.id);
      expect(h.every((x) => x.done && x.id != j.id && x.customerId == j.customerId), isTrue);
    });
  });

  group('format', () {
    test('times and windows', () {
      expect(clock(0), '12:00 AM');
      expect(clock(630), '10:30 AM');
      expect(clock(780), '1:00 PM');
      expect(window(630, 690), '10:30 – 11:30 AM');
      expect(window(690, 750), '11:30 AM – 12:30 PM');
    });

    test('dates', () {
      expect(dayShort('2026-10-29'), 'Thu, Oct 29');
      expect(dayLong('2026-10-29'), 'Thursday, October 29');
      expect(addDays('2026-10-31', 1), '2026-11-01');
      expect(addDays('2026-11-01', 1), '2026-11-02', reason: 'DST change in the US');
      expect(relativeDay('2026-10-30', '2026-10-29'), 'Tomorrow');
      expect(weekday('2026-11-01'), 6);
    });

    test('money and durations', () {
      expect(money(1234.5), '\$1,234.50');
      expect(money(468, cents: false), '\$468');
      expect(moneyShort(480), '\$480');
      expect(moneyShort(1250), '\$1.3k');
      expect(moneyShort(2000), '\$2k');
      expect(duration(45), '45 min');
      expect(duration(75), '1 h 15 min');
      expect(duration(120), '2 h');
      expect(initials('Dana Whitfield'), 'DW');
      expect(plural(1, 'job'), '1 job');
      expect(plural(3, 'job'), '3 jobs');
    });
  });
}
