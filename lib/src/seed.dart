import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'format.dart';
import 'models.dart';

/// Bump when the stored shape changes so old browsers re-seed.
const stateVersion = 1;
const company = 'Northbeam Heating & Plumbing';

/// Fee charged for every visit, labour rate per hour (billed in 15-minute steps,
/// at least 30 minutes) and sales tax on parts.
const callOutFee = 79.0;
const taxRate = 0.1025;

/// Small deterministic PRNG so the same day always produces the same demo.
class Rng {
  Rng(int seed) : _s = seed & 0x7fffffff;
  int _s;
  double next() {
    _s = (_s * 1103515245 + 12345) & 0x7fffffff;
    return _s / 0x7fffffff;
  }

  int below(int n) => (next() * n).floor() % n;
  T pick<T>(List<T> xs) => xs[below(xs.length)];
}

class _Tpl {
  const _Tpl(this.title, this.trade, this.minutes, this.descriptions, this.checklist, this.parts, {this.urgentShare = 0});
  final String title;
  final Trade trade;
  final int minutes;
  final List<String> descriptions;
  final List<(String, bool)> checklist;
  final List<String> parts;
  final double urgentShare;
}

const _templates = <_Tpl>[
  _Tpl(
    'Furnace tune-up',
    Trade.heating,
    60,
    [
      'Yearly tune-up before winter. Customer notices a slight burning smell on the first start of the day.',
      'Seasonal maintenance visit. Furnace is 9 years old, last serviced two winters ago.',
    ],
    [
      ('Replace air filter', true),
      ('Inspect heat exchanger for cracks', true),
      ('Test igniter and flame sensor', false),
      ('Measure CO at the flue', true),
      ('Check thermostat cycling', false),
    ],
    ['filter', 'flame-sensor'],
  ),
  _Tpl(
    'No heat',
    Trade.heating,
    75,
    [
      'Furnace clicks but never lights. Two young kids at home, house is down to 58°F.',
      'Heat stopped overnight. Blower runs, no flame. Customer reset the breaker twice.',
    ],
    [
      ('Check thermostat and power', true),
      ('Inspect hot surface igniter', true),
      ('Clean or replace flame sensor', false),
      ('Check pressure switch and venting', true),
      ('Confirm a full heating cycle', true),
    ],
    ['igniter', 'flame-sensor', 'pressure-switch'],
    urgentShare: 0.7,
  ),
  _Tpl(
    'Boiler service',
    Trade.heating,
    90,
    ['Annual boiler service. Radiators upstairs heat up slowly.', 'Boiler pressure drops every few days. Service and check for leaks.'],
    [
      ('Check system pressure', true),
      ('Bleed radiators', false),
      ('Inspect expansion tank', false),
      ('Test pressure relief valve', true),
      ('Check flue and CO', true),
    ],
    ['relief-valve', 'expansion-tank'],
  ),
  _Tpl(
    'Leaking pipe under sink',
    Trade.plumbing,
    45,
    [
      'Slow leak under the kitchen sink, cabinet floor is wet. Water is shut off at the valve.',
      'Drip from the bathroom vanity supply line. Customer put a bucket under it.',
    ],
    [('Shut off water supply', true), ('Find and repair the leak', true), ('Check cabinet for water damage', false), ('Pressure test after repair', true)],
    ['push-coupling', 'copper-elbow', 'ptfe-tape', 'p-trap'],
    urgentShare: 0.3,
  ),
  _Tpl(
    'Water heater replacement',
    Trade.plumbing,
    150,
    ['Replace a 40 gal gas water heater, tank is leaking at the base. Quote approved.'],
    [
      ('Shut off gas and water', true),
      ('Drain and remove old tank', true),
      ('Install new tank and relief valve', true),
      ('Leak test the gas line', true),
      ('Light and check water temperature', false),
      ('Haul away old unit', false),
    ],
    ['water-heater', 'relief-valve', 'expansion-tank', 'ptfe-tape'],
  ),
  _Tpl(
    'Drain cleaning',
    Trade.plumbing,
    60,
    ['Bathroom tub drain backs up. Customer already tried a plunger and drain cleaner.', 'Kitchen drain is slow and smells. Third time this year.'],
    [('Clear drain with auger', true), ('Camera check the line', false), ('Flow test', true)],
    ['p-trap'],
  ),
  _Tpl(
    'Smart thermostat install',
    Trade.controls,
    45,
    ['Replace an old dial thermostat with a smart thermostat and set up the schedule with the customer.'],
    [
      ('Turn off power at the furnace', true),
      ('Check for a C-wire', false),
      ('Mount and wire thermostat', true),
      ('Pair with Wi-Fi and the app', false),
      ('Test heat and fan', true),
    ],
    ['thermostat'],
  ),
  _Tpl(
    'Heat pump not heating',
    Trade.cooling,
    75,
    ['Heat pump runs but blows cool air. Outdoor unit iced over this morning.'],
    [('Check refrigerant pressures', true), ('Test capacitor and contactor', true), ('Inspect defrost control', false), ('Confirm heating mode', true)],
    ['capacitor', 'contactor', 'refrigerant'],
  ),
];

List<Part> seedParts() => [
  Part(id: 'filter', sku: 'FL-16251', name: 'MERV 11 air filter 16x25x1', price: 24, qty: 9, min: 4),
  Part(id: 'igniter', sku: 'IG-271', name: 'Hot surface igniter', price: 48, qty: 2, min: 2),
  Part(id: 'flame-sensor', sku: 'FS-110', name: 'Flame sensor', price: 22, qty: 5, min: 2),
  Part(id: 'pressure-switch', sku: 'PS-054', name: 'Furnace pressure switch', price: 64, qty: 1, min: 1),
  Part(id: 'capacitor', sku: 'CP-455', name: 'Run capacitor 45/5 µF', price: 32, qty: 4, min: 2),
  Part(id: 'contactor', sku: 'CT-30A', name: 'Contactor 30A, 1 pole', price: 38, qty: 3, min: 1),
  Part(id: 'refrigerant', sku: 'RF-410', name: 'R-410A refrigerant (per lb)', price: 65, qty: 6, min: 3),
  Part(id: 'copper-elbow', sku: 'CU-E12', name: 'Copper elbow 1/2"', price: 3.5, qty: 24, min: 10),
  Part(id: 'push-coupling', sku: 'PF-C12', name: 'Push-fit coupling 1/2"', price: 11, qty: 3, min: 4),
  Part(id: 'p-trap', sku: 'PT-112', name: 'P-trap kit 1-1/2"', price: 14, qty: 5, min: 2),
  Part(id: 'ptfe-tape', sku: 'TP-PTFE', name: 'PTFE thread tape', price: 2, qty: 12, min: 4),
  Part(id: 'relief-valve', sku: 'RV-075', name: 'Pressure relief valve 3/4"', price: 29, qty: 3, min: 2),
  Part(id: 'expansion-tank', sku: 'ET-2G', name: 'Expansion tank 2 gal', price: 58, qty: 2, min: 1),
  Part(id: 'thermostat', sku: 'TH-SM3', name: 'Smart thermostat', price: 189, qty: 2, min: 1),
  Part(id: 'water-heater', sku: 'WH-40G', name: 'Gas water heater 40 gal', price: 689, qty: 1, min: 0),
  Part(id: 'anode-rod', sku: 'AR-44', name: 'Magnesium anode rod', price: 42, qty: 2, min: 1),
];

const _first = [
  'Avery',
  'Jordan',
  'Priya',
  'Marcus',
  'Elena',
  'Hiro',
  'Noah',
  'Grace',
  'Mateo',
  'Leah',
  'Owen',
  'Zoe',
  'Felix',
  'Nadia',
  'Caleb',
  'Ines',
  'Rafael',
  'Maren',
  'Theo',
  'Simone',
  'Desmond',
  'Ruth',
  'Kofi',
  'Hannah',
  'Luca',
  'Mira',
  'Gideon',
  'Talia',
];
const _last = [
  'Calloway',
  'Brennan',
  'Okafor',
  'Lindqvist',
  'Marchetti',
  'Novak',
  'Ashford',
  'Delgado',
  'Fairbanks',
  'Ito',
  'Kowalczyk',
  'Pemberton',
  'Quint',
  'Rasmussen',
  'Sorensen',
  'Thackeray',
  'Vance',
  'Whitlock',
  'Yardley',
  'Abernathy',
  'Holloway',
  'Ferro',
];
const _streets = [
  'Wrenfield Ave',
  'Corran St',
  'Ashbury Ln',
  'Millbrook Rd',
  'Kestrel Ct',
  'Harlow Ave',
  'Dunmore St',
  'Linden Park Dr',
  'Garnet Way',
  'Oakhurst Ave',
  'Fenwick Pl',
  'Bramley St',
];
const _areas = ['Chicago, IL 60614', 'Chicago, IL 60618', 'Chicago, IL 60625', 'Chicago, IL 60640', 'Evanston, IL 60201'];
const _notes = [
  'Dog in the backyard, use the front door.',
  'Parking in the alley behind the garage.',
  'Prefers a text 15 minutes before arrival.',
  '',
  '',
  'Ring the side door, front bell is broken.',
  '',
];

List<Customer> seedCustomers(Rng r) {
  final used = <String>{};
  final out = <Customer>[];
  for (var i = 0; out.length < 48; i++) {
    final name = '${r.pick(_first)} ${r.pick(_last)}';
    if (!used.add(name)) continue;
    final n = out.length;
    out.add(
      Customer(
        id: 'c$n',
        name: name,
        phone: '(312) 555-01${(n % 100).toString().padLeft(2, '0')}',
        street: '${100 + r.below(4800)} ${r.pick(_streets)}',
        city: r.pick(_areas),
        since: 2016 + r.below(10),
        note: r.pick(_notes),
      ),
    );
  }
  return out;
}

Strokes syntheticSignature(Rng r) {
  final strokes = <List<Offset>>[];
  var x = 0.08 + r.next() * 0.05;
  final parts = 2 + r.below(2);
  for (var s = 0; s < parts; s++) {
    final pts = <Offset>[];
    final width = 0.22 + r.next() * 0.16;
    final f = 2.5 + r.next() * 2.5, amp = 0.16 + r.next() * 0.12, phase = r.next() * math.pi;
    for (var i = 0; i <= 28; i++) {
      final k = i / 28;
      pts.add(Offset(x + width * k, 0.52 + amp * math.sin(phase + k * f * math.pi) * (1 - 0.4 * k) - 0.06 * s));
    }
    strokes.add(pts);
    x += width + 0.04;
    if (x > 0.85) break;
  }
  return strokes;
}

class Seed {
  Seed(this.customers, this.parts, this.jobs);
  final List<Customer> customers;
  final List<Part> parts;
  final List<Job> jobs;
}

/// Today's route is fixed so the first screen always tells the same story:
/// two jobs done, an urgent no-heat call next, then the rest of the day.
const _today = [(480, 0), (555, 3), (630, 1), (750, 5), (840, 4), (1005, 6)];

Seed buildSeed(DateTime now) {
  final today = dateKey(now);
  final r = Rng(int.parse(today.replaceAll('-', '')));
  final customers = seedCustomers(r);
  final parts = seedParts();
  final jobs = <Job>[];
  var refNo = 2400;

  Job make(String date, int start, _Tpl tpl, {bool? urgent, required bool past}) {
    final c = r.pick(customers);
    final job = Job(
      id: 'j${jobs.length}',
      ref: 'NB-${refNo++}',
      customerId: c.id,
      title: tpl.title,
      trade: tpl.trade,
      date: date,
      start: start,
      duration: tpl.minutes,
      drive: 8 + r.below(22),
      description: r.pick(tpl.descriptions),
      urgent: urgent ?? r.next() < tpl.urgentShare,
      checklist: [for (final (label, req) in tpl.checklist) CheckItem(label, required: req)],
    );
    if (past) {
      for (final c in job.checklist) {
        c.done = c.required || r.next() < 0.7;
      }
      final count = 1 + r.below(math.min(2, tpl.parts.length));
      for (final id in tpl.parts.take(count)) {
        final p = parts.firstWhere((x) => x.id == id);
        job.parts.add(UsedPart(id, id == 'copper-elbow' ? 2 + r.below(3) : 1, p.price));
      }
      final d = parseKey(date);
      job
        ..status = JobStatus.completed
        ..startedAt = DateTime(d.year, d.month, d.day, 0, start - job.drive)
        ..arrivedAt = DateTime(d.year, d.month, d.day, 0, start + r.below(20))
        ..completedAt = DateTime(d.year, d.month, d.day, 0, start + tpl.minutes + 5 + r.below(25))
        ..labourMinutes = tpl.minutes + (r.below(3) - 1) * 15
        ..signature = syntheticSignature(r)
        ..signedBy = c.name;
      if (r.next() < 0.6) {
        job.photos.add(Photo(id: '${job.id}-p0', label: 'Before', at: job.arrivedAt!, seed: r.below(1000)));
        job.photos.add(Photo(id: '${job.id}-p1', label: 'After', at: job.completedAt!, seed: r.below(1000)));
      }
    }
    jobs.add(job);
    return job;
  }

  for (var offset = -14; offset <= 7; offset++) {
    final date = addDays(today, offset);
    final wd = weekday(date);
    if (offset == 0) {
      for (final (i, (start, tpl)) in _today.indexed) {
        make(date, start, _templates[tpl], urgent: tpl == 1, past: i < 2);
      }
      continue;
    }
    if (wd == 6) continue;
    final count = wd == 5 ? 1 + r.below(2) : (offset < 0 ? 5 + r.below(2) : 2 + r.below(3) + (offset == 1 ? 2 : 0));
    var t = 480 + r.below(3) * 15;
    for (var k = 0; k < count; k++) {
      final tpl = _templates[r.below(_templates.length)];
      // The working day ends at 6 PM.
      if (t + tpl.minutes > 1080) break;
      make(date, t, tpl, past: offset < 0);
      t += tpl.minutes + 30 + r.below(3) * 15;
      t = (t / 15).ceil() * 15;
    }
  }
  return Seed(customers, parts, jobs);
}
