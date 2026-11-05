import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'format.dart';
import 'models.dart';
import 'seed.dart';

const _key = 'fieldline:state';

/// The whole demo lives on the device: jobs, van stock and the offline queue are
/// stored locally and re-seeded around today's date each new day.
class AppStore extends ChangeNotifier {
  AppStore(this._prefs, {DateTime Function()? clock, this.syncDelay = const Duration(milliseconds: 1400)}) : _clock = clock ?? DateTime.now {
    _load();
  }

  final SharedPreferences _prefs;
  final DateTime Function() _clock;
  final Duration syncDelay;

  static Future<AppStore> open({DateTime Function()? clock}) async => AppStore(await SharedPreferences.getInstance(), clock: clock);

  final tech = Technician(name: 'Dana Whitfield', role: 'Senior service technician', van: 'Van 07', hourlyRate: 110);

  late String seededOn;
  late List<Customer> customers;
  late List<Part> parts;
  late List<Job> jobs;
  bool offline = false;
  bool syncing = false;
  DateTime? lastSync;
  List<PendingChange> pending = [];

  /// Changes the office made on the server, waiting for the next sync to reach the van.
  List<OfficeChange> officeQueue = [];

  /// Office changes that clash with work done offline, for the technician to settle.
  List<SyncConflict> conflicts = [];

  /// What the last sync brought in, shown until dismissed.
  List<String> syncNotes = [];

  /// The last sync stopped because the signal dropped; nothing was lost, it retries.
  bool syncInterrupted = false;
  ThemeMode themeMode = ThemeMode.system;

  DateTime now() => _clock();
  String get today => dateKey(now());
  int get nowMinutes => now().hour * 60 + now().minute;

  void _load() {
    final raw = _prefs.getString(_key);
    if (raw != null) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        if (j['version'] == stateVersion && j['seededOn'] == today) {
          seededOn = j['seededOn'];
          customers = [for (final c in j['customers']) Customer.fromJson(c)];
          parts = [for (final p in j['parts']) Part.fromJson(p)];
          jobs = [for (final x in j['jobs']) Job.fromJson(x)];
          offline = j['offline'] ?? false;
          pending = [for (final p in j['pending'] ?? []) PendingChange.fromJson(p)];
          officeQueue = [for (final c in j['office'] ?? []) OfficeChange.fromJson(c)];
          conflicts = [for (final c in j['conflicts'] ?? []) SyncConflict.fromJson(c)];
          syncNotes = [for (final n in j['syncNotes'] ?? []) n as String];
          lastSync = j['lastSync'] == null ? null : DateTime.parse(j['lastSync']);
          themeMode = ThemeMode.values.byName(j['theme'] ?? 'system');
          return;
        }
        themeMode = ThemeMode.values.byName(j['theme'] ?? 'system');
      } catch (_) {
        // Corrupt or old data: fall through and re-seed.
      }
    }
    _seed();
  }

  void _seed() {
    final s = buildSeed(now());
    seededOn = today;
    customers = s.customers;
    parts = s.parts;
    jobs = s.jobs;
    offline = false;
    pending = [];
    officeQueue = [];
    conflicts = [];
    syncNotes = [];
    syncInterrupted = false;
    lastSync = now();
    _save();
  }

  void _save() {
    _prefs.setString(
      _key,
      jsonEncode({
        'version': stateVersion,
        'seededOn': seededOn,
        'customers': customers.map((c) => c.toJson()).toList(),
        'parts': parts.map((p) => p.toJson()).toList(),
        'jobs': jobs.map((j) => j.toJson()).toList(),
        'offline': offline,
        'pending': pending.map((p) => p.toJson()).toList(),
        'office': officeQueue.map((c) => c.toJson()).toList(),
        'conflicts': conflicts.map((c) => c.toJson()).toList(),
        'syncNotes': syncNotes,
        'lastSync': lastSync?.toIso8601String(),
        'theme': themeMode.name,
      }),
    );
  }

  /// Every change goes through here: saved locally, then either synced or queued.
  /// A change with a [key] replaces the queued one with the same key; with [toggle], a second
  /// change to the same thing cancels the first (a box ticked and unticked is no change).
  void _commit(String label, {String? key, String? jobId, bool toggle = false}) {
    if (offline) {
      final i = key == null ? -1 : pending.indexWhere((p) => p.key == key);
      final change = PendingChange(label, now(), key: key, jobId: jobId);
      if (i >= 0 && toggle) {
        pending.removeAt(i);
      } else if (i >= 0) {
        pending[i] = change;
      } else {
        pending.add(change);
      }
    } else {
      lastSync = now();
    }
    _save();
    notifyListeners();
  }

  // Lookups

  Job job(String id) => jobs.firstWhere((j) => j.id == id);
  Customer customer(String id) => customers.firstWhere((c) => c.id == id);
  Part part(String id) => parts.firstWhere((p) => p.id == id);

  List<Job> jobsOn(String date) => jobs.where((j) => j.date == date).toList()..sort((a, b) => a.start.compareTo(b.start));
  List<Job> get todayJobs => jobsOn(today);

  /// The job to look at now: the one in progress, else the first one still to do.
  Job? get current {
    final list = todayJobs;
    for (final j in list) {
      if (j.active) return j;
    }
    for (final j in list) {
      if (!j.closed) return j;
    }
    return null;
  }

  /// The job on the way or on site, if any. A technician works one job at a time.
  Job? get activeJob => jobs.where((j) => j.active).firstOrNull;

  List<Job> history(String customerId, {String? except}) =>
      jobs.where((j) => j.customerId == customerId && j.done && j.id != except).toList()..sort((a, b) => b.date.compareTo(a.date));

  // Job flow

  /// Why a job can't be started now: it's on another day, closed, or another job is in progress.
  String? cannotStart(Job j) {
    if (j.cancelled) return 'Cancelled by the office';
    if (j.done) return 'Already completed';
    if (j.date.compareTo(today) > 0) return 'Scheduled for ${relativeDay(j.date, today)}';
    if (j.date != today) return 'This job was on ${dayShort(j.date)}';
    final other = activeJob;
    if (other != null && other.id != j.id) return 'Finish ${other.ref} first';
    return null;
  }

  /// Returns why the job can't be started, or null when it is now on the way.
  String? startTravel(String id) {
    final j = job(id);
    if (j.status != JobStatus.scheduled) return null;
    final why = cannotStart(j);
    if (why != null) return why;
    j
      ..status = JobStatus.travelling
      ..startedAt = now();
    _commit('${j.ref}: on the way', jobId: j.id);
    return null;
  }

  /// Returns why the technician can't be on site for this job, or null when they are.
  String? arrive(String id) {
    final j = job(id);
    if (j.closed || j.status == JobStatus.onSite) return null;
    if (j.status == JobStatus.scheduled) {
      final why = cannotStart(j);
      if (why != null) return why;
    }
    j.startedAt ??= now();
    j
      ..status = JobStatus.onSite
      ..arrivedAt = now();
    _commit('${j.ref}: arrived on site', jobId: j.id);
    return null;
  }

  void toggleCheck(String id, int index) {
    final j = job(id);
    if (j.closed) return;
    final c = j.checklist[index];
    c.done = !c.done;
    _commit('${j.ref}: ${c.done ? 'checked' : 'unchecked'} "${c.label}"', key: '${j.id}:check:$index', jobId: j.id, toggle: true);
  }

  /// Takes one unit from the van. Returns an error message when the van is out.
  String? addPart(String id, String partId) {
    final j = job(id);
    final p = part(partId);
    if (j.closed) return 'This job is already ${j.done ? 'completed' : 'cancelled'}.';
    if (p.qty <= 0) return '${p.name} is out of stock in ${tech.van}.';
    p.qty--;
    final used = j.parts.where((u) => u.partId == partId).firstOrNull;
    if (used != null) {
      used.qty++;
    } else {
      j.parts.add(UsedPart(partId, 1, p.price));
    }
    _commit('${j.ref}: used ${p.name}', jobId: j.id);
    return null;
  }

  /// Puts one unit back in the van.
  void removePart(String id, String partId) {
    final j = job(id);
    final used = j.parts.where((u) => u.partId == partId).firstOrNull;
    if (used == null || j.closed) return;
    part(partId).qty++;
    used.qty--;
    if (used.qty == 0) j.parts.remove(used);
    _commit('${j.ref}: returned ${part(partId).name}', jobId: j.id);
  }

  void addPhoto(String id) {
    final j = job(id);
    if (j.closed) return;
    final label = j.photos.isEmpty ? 'Before' : (j.photos.length == 1 ? 'During' : 'After');
    j.photos.add(Photo(id: '${j.id}-p${j.photos.length}-${now().millisecondsSinceEpoch}', label: label, at: now(), seed: now().millisecondsSinceEpoch % 1000));
    _commit('${j.ref}: added a photo', jobId: j.id);
  }

  void removePhoto(String id, String photoId) {
    final j = job(id);
    if (j.closed) return;
    j.photos.removeWhere((p) => p.id == photoId);
    _commit('${j.ref}: removed a photo', jobId: j.id);
  }

  static const maxNotes = 1000;
  static const maxSignedBy = 60;

  void setNotes(String id, String notes) {
    final j = job(id);
    final text = notes.trim();
    if (j.closed || j.notes == text) return;
    j.notes = text.length > maxNotes ? text.substring(0, maxNotes) : text;
    _commit('${j.ref}: updated notes', key: '${j.id}:notes', jobId: j.id);
  }

  /// A signature has to be more than a tap: a few points and some length on the pad.
  static bool signatureOk(Strokes? s) {
    if (s == null) return false;
    var points = 0;
    var length = 0.0;
    for (final stroke in s) {
      points += stroke.length;
      for (var i = 1; i < stroke.length; i++) {
        length += (stroke[i] - stroke[i - 1]).distance;
      }
    }
    return points >= 4 && length >= 0.25;
  }

  /// What is still missing before a job can be signed off.
  List<String> blockers(Job j, {Strokes? signature}) {
    final sig = signature ?? j.signature;
    return [
      if (j.requiredLeft > 0) '${plural(j.requiredLeft, 'required check')} not done',
      if (sig == null || sig.isEmpty) 'Customer signature missing' else if (!signatureOk(sig)) 'Signature is too short: ask the customer to sign in full',
    ];
  }

  /// Minutes on site so far (from arrival), or the booked time before arrival.
  int onSiteMinutes(Job j) => j.arrivedAt == null ? j.duration : math.max(1, now().difference(j.arrivedAt!).inMinutes);

  /// The labour to start the sign-off with: the real time on site, in billable steps.
  int suggestedLabour(Job j) => billable(onSiteMinutes(j));

  String? complete(String id, {required int labourMinutes, required Strokes signature, required String signedBy}) {
    final j = job(id);
    if (j.done) return 'This job is already completed.';
    if (j.cancelled) return 'The office cancelled this job.';
    if (j.status != JobStatus.onSite) return 'Arrive on site first.';
    final b = blockers(j, signature: signature);
    if (b.isNotEmpty) return b.first;
    if (signedBy.trim().isEmpty) return 'Enter the name of the person signing.';
    if (signedBy.trim().length > maxSignedBy) return 'Keep the name under $maxSignedBy characters.';
    j
      ..arrivedAt ??= now()
      ..startedAt ??= j.arrivedAt
      ..status = JobStatus.completed
      ..completedAt = now()
      ..labourMinutes = billable(labourMinutes)
      ..signature = signature
      ..signedBy = signedBy.trim();
    _commit('${j.ref}: completed, invoice ${money(invoice(j).total)}', jobId: j.id);
    return null;
  }

  // Money

  static int billable(int minutes) => (minutes.clamp(30, 600) / 15).ceil() * 15;

  Invoice invoice(Job j, {int? labourMinutes}) {
    final mins = billable(labourMinutes ?? j.labourMinutes ?? j.duration);
    final partsTotal = j.parts.fold<double>(0, (s, u) => s + u.price * u.qty);
    double round(double v) => (v * 100).roundToDouble() / 100;
    return Invoice(
      labourMinutes: mins,
      callOut: callOutFee,
      labour: round(tech.hourlyRate * mins / 60),
      parts: round(partsTotal),
      tax: round(partsTotal * taxRate),
    );
  }

  // Van stock

  void requestRestock(String partId) {
    final p = part(partId);
    if (p.restockRequested) return;
    p.restockRequested = true;
    _commit('Restock requested: ${p.name}');
  }

  /// The restock arrives: the van is filled back to three times its minimum.
  void receiveRestock(String partId) {
    final p = part(partId);
    if (!p.restockRequested) return;
    p
      ..qty = math.max(p.qty, p.min * 3)
      ..restockRequested = false;
    _commit('Restock received: ${p.name}');
  }

  List<Part> get lowStock => parts.where((p) => p.low).toList();

  // Offline and sync

  void setOffline(bool value) {
    if (offline == value) return;
    offline = value;
    _save();
    notifyListeners();
    if (!value && (pending.isNotEmpty || officeQueue.isNotEmpty)) unawaited(sync());
  }

  /// Sends the queued changes and takes in the office's. If the signal drops before the
  /// server confirms, nothing counts as sent: the whole queue stays for the next try.
  Future<void> sync() async {
    if (offline || syncing || (pending.isEmpty && officeQueue.isEmpty)) return;
    syncing = true;
    syncInterrupted = false;
    notifyListeners();
    final sending = pending.length;
    await Future<void>.delayed(syncDelay);
    syncing = false;
    if (offline) {
      syncInterrupted = true;
      _save();
      notifyListeners();
      return;
    }
    final touched = {for (final p in pending.take(sending)) ?p.jobId};
    pending = pending.sublist(sending);
    _takeOfficeChanges(touched);
    lastSync = now();
    _save();
    notifyListeners();
  }

  // The office

  /// Demo: what the dispatcher changes while the van has no signal. It reaches the van at the
  /// next sync: the current job is cancelled (the customer called), the next one moves by an
  /// hour, and an urgent job is added at the end of the day.
  String? simulateOfficeChanges() {
    if (!offline) return 'Turn on Work offline first.';
    if (officeQueue.isNotEmpty) return 'The office has already made changes. Go online to get them.';
    final open = todayJobs.where((j) => !j.closed).toList();
    if (open.isEmpty) return 'There is nothing left today for the office to change.';
    final at = now();
    final cur = current!;
    final next = open.where((j) => j.id != cur.id).firstOrNull;
    final last = todayJobs.last;
    final start = math.min(18 * 60, ((last.start + last.duration + 30) / 15).ceil() * 15);
    final n = jobs.length + 1;
    final c = customers[n % customers.length];
    final added = Job(
      id: 'office-$n',
      ref: 'NB-${2900 + n}',
      customerId: c.id,
      title: 'Burst pipe',
      trade: Trade.plumbing,
      date: today,
      start: start,
      duration: 60,
      drive: 20,
      description: 'Water coming through the kitchen ceiling. Customer has shut the main valve.',
      urgent: true,
      checklist: [
        CheckItem('Confirm water is off at the main', required: true),
        CheckItem('Find and repair the leak', required: true),
        CheckItem('Pressure test the repair', required: true),
        CheckItem('Advise on ceiling drying'),
      ],
    );
    officeQueue = [
      OfficeChange(id: 'oc-$n-1', kind: OfficeChangeKind.cancel, jobId: cur.id, at: at, reason: 'Customer called: it is working again'),
      if (next != null)
        OfficeChange(
          id: 'oc-$n-2',
          kind: OfficeChangeKind.reschedule,
          jobId: next.id,
          at: at,
          newStart: math.min(18 * 60, next.start + 60),
          reason: 'Customer asked for later',
        ),
      OfficeChange(id: 'oc-$n-3', kind: OfficeChangeKind.add, jobId: added.id, at: at, job: added, reason: 'Emergency call'),
    ];
    _save();
    notifyListeners();
    return null;
  }

  /// Applies the office's changes, keeping work done offline: a change to a job the technician
  /// started or changed while offline becomes a conflict for them to settle.
  void _takeOfficeChanges(Set<String> touched) {
    final notes = <String>[];
    for (final c in officeQueue) {
      if (c.kind == OfficeChangeKind.add) {
        if (!jobs.any((j) => j.id == c.jobId) && c.job != null) jobs.add(c.job!);
        notes.add('New urgent job ${c.job?.ref}: ${c.job?.title}, ${clock(c.job?.start ?? 0)}.');
        continue;
      }
      final j = jobs.where((x) => x.id == c.jobId).firstOrNull;
      if (j == null || j.cancelled) continue;
      final busy = j.done || j.active || touched.contains(j.id);
      if (c.kind == OfficeChangeKind.cancel) {
        if (busy) {
          conflicts.add(
            SyncConflict(
              c,
              j.done
                  ? 'The office cancelled ${j.ref} (${c.reason.toLowerCase()}), but you completed it while offline.'
                  : 'The office cancelled ${j.ref} (${c.reason.toLowerCase()}) while you were working on it.',
            ),
          );
        } else {
          _cancel(j, c.reason);
          notes.add('${j.ref} ${j.title} was cancelled: ${c.reason.toLowerCase()}.');
        }
      } else {
        if (busy) {
          conflicts.add(SyncConflict(c, 'The office moved ${j.ref} to ${clock(c.newStart!)}, but you have already ${j.done ? 'completed' : 'started'} it.'));
        } else {
          j.start = c.newStart!;
          notes.add('${j.ref} ${j.title} moved to ${window(j.start, j.windowEnd)}.');
        }
      }
    }
    officeQueue = [];
    if (notes.isNotEmpty) syncNotes = notes;
  }

  void _cancel(Job j, String reason) {
    for (final u in j.parts) {
      part(u.partId).qty += u.qty;
    }
    j.parts.clear();
    j
      ..status = JobStatus.cancelled
      ..cancelReason = reason;
  }

  /// Settles a conflict: keep the work done on the van (the office is told), or take the
  /// office's change. A completed job always keeps its invoice.
  void resolveConflict(int index, {required bool useOffice}) {
    final c = conflicts.removeAt(index);
    final j = jobs.where((x) => x.id == c.change.jobId).firstOrNull;
    if (useOffice && j != null && !j.done) {
      if (c.change.kind == OfficeChangeKind.cancel) {
        _cancel(j, c.change.reason);
      } else if (c.change.newStart != null) {
        j.start = c.change.newStart!;
      }
    }
    _commit(useOffice ? 'Accepted the office change to ${j?.ref}' : 'Kept your work on ${j?.ref}', jobId: j?.id);
  }

  void dismissSyncNotes() {
    syncNotes = [];
    _save();
    notifyListeners();
  }

  // Settings

  void setTheme(ThemeMode m) {
    themeMode = m;
    _save();
    notifyListeners();
  }

  void reset() {
    _seed();
    notifyListeners();
  }

  // Stats

  ({int jobs, int minutes, double revenue, double firstTimeFix}) week() {
    final from = addDays(today, -6);
    final done = jobs.where((j) => j.done && j.date.compareTo(from) >= 0 && j.date.compareTo(today) <= 0).toList();
    final revenue = done.fold<double>(0, (s, j) => s + invoice(j).total);
    final minutes = done.fold<int>(0, (s, j) => s + (j.labourMinutes ?? j.duration));
    // A job counts as fixed first time when no other visit for the same customer followed within a week.
    final repeats = done.where((j) => done.any((k) => k != j && k.customerId == j.customerId && k.date.compareTo(j.date) > 0)).length;
    return (jobs: done.length, minutes: minutes, revenue: revenue, firstTimeFix: done.isEmpty ? 1 : 1 - repeats / done.length);
  }

  /// Revenue per day for the last [days] days, oldest first.
  List<(String, double)> daily(int days) => [
    for (var i = days - 1; i >= 0; i--) (addDays(today, -i), jobsOn(addDays(today, -i)).where((j) => j.done).fold<double>(0, (s, j) => s + invoice(j).total)),
  ];
}

/// Gives widgets access to the store and rebuilds them when it changes.
class StoreScope extends InheritedNotifier<AppStore> {
  const StoreScope({super.key, required AppStore store, required super.child}) : super(notifier: store);

  static AppStore of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;
  static AppStore read(BuildContext context) => context.getInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}
