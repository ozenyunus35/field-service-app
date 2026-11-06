import 'tr.dart';

/// The interface language: 'en' or 'tr'. The store sets it on load and when the technician switches.
String appLang = 'en';

/// Text that reached [tr] without a Turkish version; a test asserts this stays empty.
final Set<String> trMisses = {};

String _fill(String s, Map<String, Object?> vars) =>
    vars.isEmpty ? s : s.replaceAllMapped(RegExp(r'\{(\w+)\}'), (m) => vars.containsKey(m[1]) ? '${vars[m[1]]}' : m[0]!);

class _Pattern {
  _Pattern(this.key, this.names, this.re, this.literal);
  final String key;
  final List<String> names;
  final RegExp re;
  final int literal;
}

/// Keys with {placeholders} also translate sentences built in code ("Arrive by 10:30 AM"):
/// the placeholders match any text, and the captured parts are translated again when they can be.
final List<_Pattern> _patterns = () {
  final out = <_Pattern>[];
  for (final key in trText.keys) {
    if (!key.contains('{')) continue;
    final names = <String>[];
    final buf = StringBuffer('^');
    var literal = 0;
    var last = 0;
    for (final m in RegExp(r'\{(\w+)\}').allMatches(key)) {
      final lit = key.substring(last, m.start);
      buf.write(RegExp.escape(lit));
      literal += lit.length;
      buf.write('(.+?)');
      names.add(m[1]!);
      last = m.end;
    }
    final tail = key.substring(last);
    buf.write(RegExp.escape(tail));
    literal += tail.length;
    buf.write(r'$');
    out.add(_Pattern(key, names, RegExp(buf.toString(), dotAll: true), literal));
  }
  out.sort((a, b) => b.literal.compareTo(a.literal));
  return out;
}();

/// English is the key. Returns the Turkish text when the interface is Turkish.
String tr(String en, [Map<String, Object?> vars = const {}]) {
  if (appLang == 'en' || en.isEmpty) return _fill(en, vars);
  final done = vars.isNotEmpty ? trText[en] : _try(en, 0);
  if (done != null) return _fill(done, vars);
  trMisses.add(en);
  return _fill(en, vars);
}

String? _try(String s, int depth) {
  final exact = trText[s];
  if (exact != null) return exact;
  if (!RegExp(r'\p{L}', unicode: true).hasMatch(s)) return s;
  if (depth > 4) return null;
  for (final sep in [' · ', '; ']) {
    if (!s.contains(sep)) continue;
    final parts = s.split(sep).map((x) => _try(x, depth + 1)).toList();
    if (parts.every((x) => x != null)) return parts.join(sep);
  }
  for (final p in _patterns) {
    final m = p.re.firstMatch(s);
    if (m == null) continue;
    final got = <String, Object?>{};
    for (var i = 0; i < p.names.length; i++) {
      final part = m[i + 1]!;
      got[p.names[i]] = _try(part, depth + 1) ?? part;
    }
    return _fill(trText[p.key]!, got);
  }
  return null;
}
