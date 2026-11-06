import 'i18n.dart';

const _monthsTr = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
const _monthsLongTr = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
const _daysTr = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
const _daysLongTr = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
bool get _tr => appLang == 'tr';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _monthsLong = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _daysLong = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

String dateKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${_pad2(d.month)}-${_pad2(d.day)}';

DateTime parseKey(String k) {
  final p = k.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

String addDays(String key, int n) {
  final d = parseKey(key);
  return dateKey(DateTime(d.year, d.month, d.day + n));
}

/// Monday = 0.
int weekday(String key) => parseKey(key).weekday - 1;

String _pad2(int n) => n.toString().padLeft(2, '0');

/// "9:30 AM"
String clock(int minutes) {
  final h = minutes ~/ 60 % 24, m = minutes % 60;
  if (_tr) return '${_pad2(h)}:${_pad2(m)}';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:${_pad2(m)} ${h < 12 ? 'AM' : 'PM'}';
}

String clockOf(DateTime d) => clock(d.hour * 60 + d.minute);

/// "10:30 – 11:30 AM" style arrival window.
String window(int start, int end) {
  final a = clock(start), b = clock(end);
  if (_tr) return '$a – $b';
  final sameHalf = (start < 720) == (end < 720);
  return sameHalf ? '${a.substring(0, a.length - 3)} – $b' : '$a – $b';
}

/// "Thu, Oct 29"
String dayShort(String key) {
  final d = parseKey(key);
  if (_tr) return '${_daysTr[d.weekday - 1]} ${d.day} ${_monthsTr[d.month - 1]}';
  return '${_days[d.weekday - 1]}, ${_months[d.month - 1]} ${d.day}';
}

/// "Thursday, October 29"
String dayLong(String key) {
  final d = parseKey(key);
  if (_tr) return '${d.day} ${_monthsLongTr[d.month - 1]} ${_daysLongTr[d.weekday - 1]}';
  return '${_daysLong[d.weekday - 1]}, ${_monthsLong[d.month - 1]} ${d.day}';
}

String weekdayShort(String key) => (_tr ? _daysTr : _days)[weekday(key)];

int dayOfMonth(String key) => parseKey(key).day;

String relativeDay(String key, String today) {
  final diff = parseKey(key).difference(parseKey(today)).inDays;
  if (diff == 0) return _tr ? 'Bugün' : 'Today';
  if (diff == 1) return _tr ? 'Yarın' : 'Tomorrow';
  if (diff == -1) return _tr ? 'Dün' : 'Yesterday';
  return dayShort(key);
}

/// "1 h 30 min", "45 min"
String duration(int minutes) {
  final h = minutes ~/ 60, m = minutes % 60;
  final (mn, hr) = _tr ? ('dk', 'sa') : ('min', 'h');
  if (h == 0) return '$m $mn';
  if (m == 0) return '$h $hr';
  return '$h $hr $m $mn';
}

/// "$1,234.50"; [cents] false drops ".00".
String money(double v, {bool cents = true}) {
  final neg = v < 0;
  final fixed = v.abs().toStringAsFixed(cents ? 2 : 0);
  final parts = fixed.split('.');
  final whole = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => _tr ? '.' : ',');
  return '${neg ? '-' : ''}\$$whole${parts.length > 1 ? '${_tr ? ',' : '.'}${parts[1]}' : ''}';
}

/// "$480", "$1.2k"
String moneyShort(double v) {
  if (v < 1000) return money(v, cents: false);
  final k = (v / 1000).toStringAsFixed(1).replaceAll('.0', '');
  return _tr ? '\$${k.replaceAll('.', ',')} B' : '\$${k}k';
}

String initials(String name) {
  final p = name.trim().split(RegExp(r'\s+'));
  return (p.first[0] + (p.length > 1 ? p.last[0] : '')).toUpperCase();
}

/// "3 jobs"; in Turkish the noun is translated and takes no plural ending ("3 iş").
String plural(int n, String one, [String? many]) => _tr ? '$n ${tr(one)}' : '$n ${n == 1 ? one : (many ?? '${one}s')}';

String ago(DateTime then, DateTime now) {
  final s = now.difference(then).inSeconds;
  if (s < 45) return _tr ? 'az önce' : 'just now';
  final m = (s / 60).round();
  if (m < 60) return _tr ? '$m dk önce' : '$m min ago';
  final h = (m / 60).round();
  if (h < 24) return _tr ? '$h sa önce' : '$h h ago';
  return _tr ? '${(h / 24).round()} gün önce' : '${(h / 24).round()} d ago';
}
