import 'dart:async';
import 'dart:convert';

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
        'lastSync': lastSync?.toIso8601String(),
        'theme': themeMode.name,
      }),
    );
  }

  /// Every change goes through here: saved locally, then either synced or queued.
  void _commit(String label) {
    if (offline) {
      pending.add(PendingChange(label, now()));
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

  /// The job to look at now: the one in progress, else the first one not done.
  Job? get current {
    final list = todayJobs;
    for (final j in list) {
      if (j.active) return j;
    }
    for (final j in list) {
      if (!j.done) return j;
    }
    return null;
  }

  List<Job> history(String customerId, {String? except}) =>
      jobs.where((j) => j.customerId == customerId && j.done && j.id != except).toList()..sort((a, b) => b.date.compareTo(a.date));

  // Job flow

  void startTravel(String id) {
    final j = job(id);
    if (j.status != JobStatus.scheduled) return;
    j
      ..status = JobStatus.travelling
      ..startedAt = now();
    _commit('${j.ref}: on the way');
  }

  void arrive(String id) {
    final j = job(id);
    if (j.status == JobStatus.completed || j.status == JobStatus.onSite) return;
    j.startedAt ??= now();
    j
      ..status = JobStatus.onSite
      ..arrivedAt = now();
    _commit('${j.ref}: arrived on site');
  }

  void toggleCheck(String id, int index) {
    final j = job(id);
    if (j.done) return;
    final c = j.checklist[index];
    c.done = !c.done;
    _commit('${j.ref}: ${c.done ? 'checked' : 'unchecked'} "${c.label}"');
  }

  /// Takes one unit from the van. Returns an error message when the van is out.
  String? addPart(String id, String partId) {
    final j = job(id);
    final p = part(partId);
    if (j.done) return 'This job is already completed.';
    if (p.qty <= 0) return '${p.name} is out of stock in ${tech.van}.';
    p.qty--;
    final used = j.parts.where((u) => u.partId == partId).firstOrNull;
    if (used != null) {
      used.qty++;
    } else {
      j.parts.add(UsedPart(partId, 1, p.price));
    }
    _commit('${j.ref}: used ${p.name}');
    return null;
  }

  /// Puts one unit back in the van.
  void removePart(String id, String partId) {
    final j = job(id);
    final used = j.parts.where((u) => u.partId == partId).firstOrNull;
    if (used == null || j.done) return;
    part(partId).qty++;
    used.qty--;
    if (used.qty == 0) j.parts.remove(used);
    _commit('${j.ref}: returned ${part(partId).name}');
  }

  void addPhoto(String id) {
    final j = job(id);
    final label = j.photos.isEmpty ? 'Before' : (j.photos.length == 1 ? 'During' : 'After');
    j.photos.add(Photo(id: '${j.id}-p${j.photos.length}-${now().millisecondsSinceEpoch}', label: label, at: now(), seed: now().millisecondsSinceEpoch % 1000));
    _commit('${j.ref}: added a photo');
  }

  void removePhoto(String id, String photoId) {
    final j = job(id);
    j.photos.removeWhere((p) => p.id == photoId);
    _commit('${j.ref}: removed a photo');
  }

  void setNotes(String id, String notes) {
    final j = job(id);
    if (j.notes == notes) return;
    j.notes = notes;
    _commit('${j.ref}: updated notes');
  }

  /// What is still missing before a job can be signed off.
  List<String> blockers(Job j, {Strokes? signature}) => [
    if (j.requiredLeft > 0) '${plural(j.requiredLeft, 'required check')} not done',
    if ((signature ?? j.signature) == null || (signature ?? j.signature)!.isEmpty) 'Customer signature missing',
  ];

  String? complete(String id, {required int labourMinutes, required Strokes signature, required String signedBy}) {
    final j = job(id);
    if (j.done) return 'This job is already completed.';
    final b = blockers(j, signature: signature);
    if (b.isNotEmpty) return b.first;
    if (signedBy.trim().isEmpty) return 'Enter the name of the person signing.';
    j
      ..arrivedAt ??= now()
      ..startedAt ??= j.arrivedAt
      ..status = JobStatus.completed
      ..completedAt = now()
      ..labourMinutes = billable(labourMinutes)
      ..signature = signature
      ..signedBy = signedBy.trim();
    _commit('${j.ref}: completed, invoice ${money(invoice(j).total)}');
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

  List<Part> get lowStock => parts.where((p) => p.low).toList();

  // Offline and sync

  void setOffline(bool value) {
    if (offline == value) return;
    offline = value;
    _save();
    notifyListeners();
    if (!value && pending.isNotEmpty) unawaited(sync());
  }

  Future<void> sync() async {
    if (offline || syncing || pending.isEmpty) return;
    syncing = true;
    notifyListeners();
    await Future<void>.delayed(syncDelay);
    syncing = false;
    pending = [];
    lastSync = now();
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
