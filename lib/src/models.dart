import 'dart:ui' show Offset;

enum JobStatus { scheduled, travelling, onSite, completed }

enum Trade { heating, cooling, plumbing, controls }

class Technician {
  Technician({required this.name, required this.role, required this.van, required this.hourlyRate});
  final String name, role, van;
  final double hourlyRate;

  Map<String, dynamic> toJson() => {'name': name, 'role': role, 'van': van, 'hourlyRate': hourlyRate};
  factory Technician.fromJson(Map<String, dynamic> j) =>
      Technician(name: j['name'], role: j['role'], van: j['van'], hourlyRate: (j['hourlyRate'] as num).toDouble());
}

class Customer {
  Customer({required this.id, required this.name, required this.phone, required this.street, required this.city, required this.since, this.note = ''});
  final String id, name, phone, street, city, note;
  final int since;

  String get address => '$street, $city';

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'phone': phone, 'street': street, 'city': city, 'since': since, 'note': note};
  factory Customer.fromJson(Map<String, dynamic> j) =>
      Customer(id: j['id'], name: j['name'], phone: j['phone'], street: j['street'], city: j['city'], since: j['since'], note: j['note'] ?? '');
}

class Part {
  Part({required this.id, required this.sku, required this.name, required this.price, required this.qty, required this.min, this.restockRequested = false});
  final String id, sku, name;
  final double price;
  int qty;
  final int min;
  bool restockRequested;

  bool get low => qty <= min;

  Map<String, dynamic> toJson() => {'id': id, 'sku': sku, 'name': name, 'price': price, 'qty': qty, 'min': min, 'restock': restockRequested};
  factory Part.fromJson(Map<String, dynamic> j) => Part(
    id: j['id'],
    sku: j['sku'],
    name: j['name'],
    price: (j['price'] as num).toDouble(),
    qty: j['qty'],
    min: j['min'],
    restockRequested: j['restock'] ?? false,
  );
}

class CheckItem {
  CheckItem(this.label, {this.required = false, this.done = false});
  final String label;
  final bool required;
  bool done;

  Map<String, dynamic> toJson() => {'label': label, 'required': required, 'done': done};
  factory CheckItem.fromJson(Map<String, dynamic> j) => CheckItem(j['label'], required: j['required'], done: j['done']);
}

class UsedPart {
  UsedPart(this.partId, this.qty, this.price);
  final String partId;
  int qty;

  /// Price at the time it was used, so later price changes don't rewrite old invoices.
  final double price;

  Map<String, dynamic> toJson() => {'partId': partId, 'qty': qty, 'price': price};
  factory UsedPart.fromJson(Map<String, dynamic> j) => UsedPart(j['partId'], j['qty'], (j['price'] as num).toDouble());
}

class Photo {
  Photo({required this.id, required this.label, required this.at, required this.seed});
  final String id, label;
  final DateTime at;

  /// Drives the synthetic placeholder drawing (the demo has no camera roll).
  final int seed;

  Map<String, dynamic> toJson() => {'id': id, 'label': label, 'at': at.toIso8601String(), 'seed': seed};
  factory Photo.fromJson(Map<String, dynamic> j) => Photo(id: j['id'], label: j['label'], at: DateTime.parse(j['at']), seed: j['seed']);
}

/// A signature as strokes of points normalised to 0..1 inside the pad.
typedef Strokes = List<List<Offset>>;

class Job {
  Job({
    required this.id,
    required this.ref,
    required this.customerId,
    required this.title,
    required this.trade,
    required this.date,
    required this.start,
    required this.duration,
    required this.drive,
    required this.description,
    required this.checklist,
    this.urgent = false,
    List<UsedPart>? parts,
    List<Photo>? photos,
    this.notes = '',
    this.status = JobStatus.scheduled,
    this.startedAt,
    this.arrivedAt,
    this.completedAt,
    this.signature,
    this.signedBy,
    this.labourMinutes,
  }) : parts = parts ?? [],
       photos = photos ?? [];

  final String id, ref, customerId, title, description;
  final Trade trade;

  /// Local date key, "YYYY-MM-DD".
  final String date;

  /// Arrival window start in minutes after midnight; the window is one hour.
  final int start;

  /// Booked time on site, minutes.
  final int duration;

  /// Estimated drive from the previous stop, minutes.
  final int drive;
  final bool urgent;
  final List<CheckItem> checklist;
  final List<UsedPart> parts;
  final List<Photo> photos;
  String notes;
  JobStatus status;
  DateTime? startedAt, arrivedAt, completedAt;
  Strokes? signature;
  String? signedBy;
  int? labourMinutes;

  int get windowEnd => start + 60;
  bool get done => status == JobStatus.completed;
  bool get active => status == JobStatus.travelling || status == JobStatus.onSite;
  int get requiredLeft => checklist.where((c) => c.required && !c.done).length;
  int get checked => checklist.where((c) => c.done).length;

  Map<String, dynamic> toJson() => {
    'id': id,
    'ref': ref,
    'customerId': customerId,
    'title': title,
    'trade': trade.name,
    'date': date,
    'start': start,
    'duration': duration,
    'drive': drive,
    'description': description,
    'urgent': urgent,
    'checklist': checklist.map((c) => c.toJson()).toList(),
    'parts': parts.map((p) => p.toJson()).toList(),
    'photos': photos.map((p) => p.toJson()).toList(),
    'notes': notes,
    'status': status.name,
    'startedAt': startedAt?.toIso8601String(),
    'arrivedAt': arrivedAt?.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'signature': signature?.map((s) => s.map((o) => [o.dx, o.dy]).toList()).toList(),
    'signedBy': signedBy,
    'labourMinutes': labourMinutes,
  };

  factory Job.fromJson(Map<String, dynamic> j) {
    DateTime? d(String k) => j[k] == null ? null : DateTime.parse(j[k]);
    return Job(
      id: j['id'],
      ref: j['ref'],
      customerId: j['customerId'],
      title: j['title'],
      trade: Trade.values.byName(j['trade']),
      date: j['date'],
      start: j['start'],
      duration: j['duration'],
      drive: j['drive'],
      description: j['description'],
      urgent: j['urgent'] ?? false,
      checklist: [for (final c in j['checklist']) CheckItem.fromJson(c)],
      parts: [for (final p in j['parts']) UsedPart.fromJson(p)],
      photos: [for (final p in j['photos']) Photo.fromJson(p)],
      notes: j['notes'] ?? '',
      status: JobStatus.values.byName(j['status']),
      startedAt: d('startedAt'),
      arrivedAt: d('arrivedAt'),
      completedAt: d('completedAt'),
      signature: (j['signature'] as List?)?.map((s) => (s as List).map((p) => Offset((p[0] as num).toDouble(), (p[1] as num).toDouble())).toList()).toList(),
      signedBy: j['signedBy'],
      labourMinutes: j['labourMinutes'],
    );
  }
}

class PendingChange {
  PendingChange(this.label, this.at);
  final String label;
  final DateTime at;

  Map<String, dynamic> toJson() => {'label': label, 'at': at.toIso8601String()};
  factory PendingChange.fromJson(Map<String, dynamic> j) => PendingChange(j['label'], DateTime.parse(j['at']));
}

class Invoice {
  const Invoice({required this.labourMinutes, required this.labour, required this.parts, required this.tax, required this.callOut});
  final int labourMinutes;
  final double labour, parts, tax, callOut;

  double get subtotal => callOut + labour + parts;
  double get total => subtotal + tax;
}
