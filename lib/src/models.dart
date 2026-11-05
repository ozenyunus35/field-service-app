import 'dart:ui' show Offset;

enum JobStatus { scheduled, travelling, onSite, completed, cancelled }

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
    this.cancelReason,
    this.payment,
    this.safetyCheckedAt,
  }) : parts = parts ?? [],
       photos = photos ?? [];

  final String id, ref, customerId, title, description;
  final Trade trade;

  /// Local date key, "YYYY-MM-DD".
  final String date;

  /// Arrival window start in minutes after midnight; the window is one hour. The office can move it.
  int start;

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

  /// Set when the office cancelled the job.
  String? cancelReason;

  /// How the customer paid at sign-off.
  Payment? payment;

  /// When the technician confirmed the site safety check (gas and heating jobs).
  DateTime? safetyCheckedAt;

  /// Gas appliances need a safety check before any work.
  bool get needsSafetyCheck => trade == Trade.heating;

  int get windowEnd => start + 60;
  bool get done => status == JobStatus.completed;
  bool get cancelled => status == JobStatus.cancelled;

  /// Completed or cancelled: nothing more to do on it.
  bool get closed => done || cancelled;
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
    'cancelReason': cancelReason,
    'payment': payment?.toJson(),
    'safetyCheckedAt': safetyCheckedAt?.toIso8601String(),
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
      cancelReason: j['cancelReason'],
      payment: j['payment'] == null ? null : Payment.fromJson(j['payment']),
      safetyCheckedAt: d('safetyCheckedAt'),
    );
  }
}

class PendingChange {
  PendingChange(this.label, this.at, {this.key, this.jobId});
  final String label;
  final DateTime at;

  /// Changes with the same key replace each other in the queue (a note edited twice is one change);
  /// for a checklist item, a second toggle cancels the first.
  final String? key;

  /// The job the change touches, so a sync can tell when the office changed the same job.
  final String? jobId;

  Map<String, dynamic> toJson() => {'label': label, 'at': at.toIso8601String(), 'key': key, 'jobId': jobId};
  factory PendingChange.fromJson(Map<String, dynamic> j) => PendingChange(j['label'], DateTime.parse(j['at']), key: j['key'], jobId: j['jobId']);
}

enum OfficeChangeKind { cancel, reschedule, add }

/// A change the office (dispatcher) made on the server, delivered to the van at the next sync.
class OfficeChange {
  OfficeChange({required this.id, required this.kind, required this.jobId, required this.at, this.reason = '', this.newStart, this.job});
  final String id;
  final OfficeChangeKind kind;
  final String jobId;
  final DateTime at;
  final String reason;

  /// For a reschedule: the new arrival window start, minutes after midnight.
  final int? newStart;

  /// For a new job.
  final Job? job;

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'jobId': jobId,
    'at': at.toIso8601String(),
    'reason': reason,
    'newStart': newStart,
    'job': job?.toJson(),
  };
  factory OfficeChange.fromJson(Map<String, dynamic> j) => OfficeChange(
    id: j['id'],
    kind: OfficeChangeKind.values.byName(j['kind']),
    jobId: j['jobId'],
    at: DateTime.parse(j['at']),
    reason: j['reason'] ?? '',
    newStart: j['newStart'],
    job: j['job'] == null ? null : Job.fromJson(j['job']),
  );
}

/// An office change that clashes with work done on the van while offline. The technician decides.
class SyncConflict {
  SyncConflict(this.change, this.message);
  final OfficeChange change;
  final String message;

  Map<String, dynamic> toJson() => {'change': change.toJson(), 'message': message};
  factory SyncConflict.fromJson(Map<String, dynamic> j) => SyncConflict(OfficeChange.fromJson(j['change']), j['message']);
}

class Invoice {
  const Invoice({required this.labourMinutes, required this.labour, required this.parts, required this.tax, required this.callOut});
  final int labourMinutes;
  final double labour, parts, tax, callOut;

  double get subtotal => callOut + labour + parts;
  double get total => subtotal + tax;
}

enum PayMethod { card, cash, invoice }

/// What the customer paid at sign-off. Card and cash are taken on site; "invoice" is billed later.
class Payment {
  Payment({required this.method, required this.amount, required this.at, required this.receipt, this.tendered});
  final PayMethod method;
  final double amount;
  final DateTime at;
  final String receipt;

  /// Cash handed over, so the receipt can show the change.
  final double? tendered;

  double get change => tendered == null ? 0 : ((tendered! - amount) * 100).roundToDouble() / 100;

  Map<String, dynamic> toJson() => {'method': method.name, 'amount': amount, 'at': at.toIso8601String(), 'receipt': receipt, 'tendered': tendered};
  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
    method: PayMethod.values.byName(j['method']),
    amount: (j['amount'] as num).toDouble(),
    at: DateTime.parse(j['at']),
    receipt: j['receipt'],
    tendered: (j['tendered'] as num?)?.toDouble(),
  );
}

/// An appliance at a customer's address, with its service record.
class Equipment {
  Equipment({
    required this.id,
    required this.customerId,
    required this.trade,
    required this.kind,
    required this.make,
    required this.model,
    required this.serial,
    required this.installed,
    this.lastService,
  });
  final String id, customerId, kind, make, model, serial;
  final Trade trade;
  final int installed;

  /// Date key of the last service, if any.
  String? lastService;

  Map<String, dynamic> toJson() => {
    'id': id,
    'customerId': customerId,
    'trade': trade.name,
    'kind': kind,
    'make': make,
    'model': model,
    'serial': serial,
    'installed': installed,
    'lastService': lastService,
  };
  factory Equipment.fromJson(Map<String, dynamic> j) => Equipment(
    id: j['id'],
    customerId: j['customerId'],
    trade: Trade.values.byName(j['trade']),
    kind: j['kind'],
    make: j['make'],
    model: j['model'],
    serial: j['serial'],
    installed: j['installed'],
    lastService: j['lastService'],
  );
}

class QuoteItem {
  QuoteItem(this.label, this.qty, this.price);
  final String label;
  int qty;
  final double price;

  Map<String, dynamic> toJson() => {'label': label, 'qty': qty, 'price': price};
  factory QuoteItem.fromJson(Map<String, dynamic> j) => QuoteItem(j['label'], j['qty'], (j['price'] as num).toDouble());
}

enum QuoteStatus { open, accepted, declined }

/// Follow-up work quoted on site. Accepted with the customer's signature, it becomes a booked job.
class Quote {
  Quote({
    required this.id,
    required this.ref,
    required this.jobId,
    required this.customerId,
    required this.title,
    required this.trade,
    required this.minutes,
    required this.items,
    required this.createdAt,
    this.status = QuoteStatus.open,
    this.signature,
    this.signedBy,
    this.decidedAt,
    this.followUpJobId,
  });
  final String id, ref, jobId, customerId, title;
  final Trade trade;

  /// Labour the work will take, minutes.
  final int minutes;
  final List<QuoteItem> items;
  final DateTime createdAt;
  QuoteStatus status;
  Strokes? signature;
  String? signedBy;
  DateTime? decidedAt;
  String? followUpJobId;

  Map<String, dynamic> toJson() => {
    'id': id,
    'ref': ref,
    'jobId': jobId,
    'customerId': customerId,
    'title': title,
    'trade': trade.name,
    'minutes': minutes,
    'items': items.map((i) => i.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'status': status.name,
    'signature': signature?.map((s) => s.map((o) => [o.dx, o.dy]).toList()).toList(),
    'signedBy': signedBy,
    'decidedAt': decidedAt?.toIso8601String(),
    'followUpJobId': followUpJobId,
  };
  factory Quote.fromJson(Map<String, dynamic> j) => Quote(
    id: j['id'],
    ref: j['ref'],
    jobId: j['jobId'],
    customerId: j['customerId'],
    title: j['title'],
    trade: Trade.values.byName(j['trade']),
    minutes: j['minutes'],
    items: [for (final i in j['items']) QuoteItem.fromJson(i)],
    createdAt: DateTime.parse(j['createdAt']),
    status: QuoteStatus.values.byName(j['status']),
    signature: (j['signature'] as List?)?.map((s) => (s as List).map((p) => Offset((p[0] as num).toDouble(), (p[1] as num).toDouble())).toList()).toList(),
    signedBy: j['signedBy'],
    decidedAt: j['decidedAt'] == null ? null : DateTime.parse(j['decidedAt']),
    followUpJobId: j['followUpJobId'],
  );
}

/// A text sent to a customer, such as "running late, new arrival around 2:15 PM".
class CustomerMessage {
  CustomerMessage({required this.customerId, required this.jobId, required this.at, required this.body});
  final String customerId, jobId, body;
  final DateTime at;

  Map<String, dynamic> toJson() => {'customerId': customerId, 'jobId': jobId, 'at': at.toIso8601String(), 'body': body};
  factory CustomerMessage.fromJson(Map<String, dynamic> j) =>
      CustomerMessage(customerId: j['customerId'], jobId: j['jobId'], at: DateTime.parse(j['at']), body: j['body']);
}

/// A break in the working day; [end] is null while it lasts.
class BreakTime {
  BreakTime(this.start, [this.end]);
  final DateTime start;
  DateTime? end;

  Map<String, dynamic> toJson() => {'start': start.toIso8601String(), 'end': end?.toIso8601String()};
  factory BreakTime.fromJson(Map<String, dynamic> j) => BreakTime(DateTime.parse(j['start']), j['end'] == null ? null : DateTime.parse(j['end']));
}
