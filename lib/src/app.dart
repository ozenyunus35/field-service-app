import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import 'format.dart';
import 'screens/profile.dart';
import 'screens/schedule.dart';
import 'screens/stock.dart';
import 'screens/today.dart';
import 'seed.dart';
import 'store.dart';
import 'theme.dart';

const sourceUrl = 'https://github.com/ozenyunus35/field-service-app';

class FieldlineApp extends StatelessWidget {
  const FieldlineApp({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      store: store,
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) => MaterialApp(
          title: 'Fieldline',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: store.themeMode,
          builder: (context, child) => DeviceStage(child: child!),
          home: const Shell(),
        ),
      ),
    );
  }
}

/// On a phone the app fills the screen. On a wide browser window it sits in a
/// phone-sized frame next to a short description of the demo.
class DeviceStage extends StatelessWidget {
  const DeviceStage({super.key, required this.child});
  final Widget child;

  static const phone = Size(390, 844);

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final wide = mq.size.width >= 900 && mq.size.height >= 640;
    if (!wide) return child;
    final t = context.t;
    final h = (mq.size.height - 48).clamp(600.0, phone.height);
    final screen = Size(phone.width, h);
    const statusBar = 44.0;
    return ColoredBox(
      color: t.bg,
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 380, child: _About()),
              const SizedBox(width: 72),
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1B1F),
                  borderRadius: BorderRadius.circular(54),
                  border: Border.all(color: const Color(0xFF2C2D33)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 40, offset: const Offset(0, 18))],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(46),
                  child: SizedBox.fromSize(
                    size: screen,
                    // A semantics container keeps the route's modal barrier from hiding the text next to the phone.
                    child: Semantics(
                      container: true,
                      child: MediaQuery(
                        data: mq.copyWith(
                          size: screen,
                          padding: const EdgeInsets.only(top: statusBar, bottom: 18),
                          viewPadding: const EdgeInsets.only(top: statusBar, bottom: 18),
                        ),
                        child: Stack(
                          children: [
                            Positioned.fill(child: child),
                            const Positioned(top: 0, left: 0, right: 0, height: statusBar, child: _StatusBar()),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar();

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final t = context.t;
    final c = Theme.of(context).brightness == Brightness.dark ? t.text : const Color(0xFF111111);
    final time = clock(s.nowMinutes).replaceAll(RegExp(r' (AM|PM)'), '');
    return ExcludeSemantics(
      child: Material(
        color: t.bg,
        child: Container(
          padding: const EdgeInsets.fromLTRB(34, 12, 28, 0),
          child: Row(
            children: [
              Text(
                time,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c, letterSpacing: -0.2),
              ),
              const Spacer(),
              Container(
                width: 96,
                height: 26,
                decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(14)),
              ),
              const Spacer(),
              Icon(s.offline ? LucideIcons.wifiOff : LucideIcons.wifi, size: 15, color: c),
              const SizedBox(width: 6),
              Container(
                width: 24,
                height: 11,
                padding: const EdgeInsets.all(1.5),
                decoration: BoxDecoration(
                  border: Border.all(color: c.withValues(alpha: 0.5)),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: 0.72,
                  child: ColoredBox(color: c),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _About extends StatelessWidget {
  const _About();

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final s = StoreScope.of(context);
    final tt = Theme.of(context).textTheme;
    Widget point(IconData i, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(i, size: 15, color: t.muted),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: tt.bodyMedium?.copyWith(color: t.muted)),
          ),
        ],
      ),
    );
    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const FieldlineMark(size: 28),
              const SizedBox(width: 10),
              Text('Fieldline', style: tt.titleMedium),
              const SizedBox(width: 8),
              Text('demo', style: tt.bodySmall),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            'Field service app',
            style: TextStyle(color: t.accent, fontWeight: FontWeight.w500, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text('The technician\'s day, in one app.', style: tt.headlineSmall?.copyWith(fontSize: 30, letterSpacing: -0.9)),
          const SizedBox(height: 12),
          Text(
            'Jobs for the day, the route, checklists, parts from the van, photos, the customer\'s signature and the invoice. Works offline and syncs when the signal is back.',
            style: tt.bodyLarge?.copyWith(color: t.muted),
          ),
          const SizedBox(height: 24),
          point(LucideIcons.smartphone, 'Built with Flutter. This is the web build; the same code runs on iOS and Android.'),
          point(LucideIcons.wifiOff, 'Turn on "Work offline" in Profile, make changes, then go online to watch them sync.'),
          point(LucideIcons.database, '$company and its customers are synthetic. Data stays in this browser and resets each day.'),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => launchUrl(Uri.parse(sourceUrl), webOnlyWindowName: '_blank'),
                icon: const Icon(LucideIcons.code, size: 15),
                label: const Text('Source code'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  s.reset();
                  toastAbout(context);
                },
                icon: const Icon(LucideIcons.rotateCcw, size: 15),
                label: const Text('Reset demo'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void toastAbout(BuildContext context) {
    final m = ScaffoldMessenger.maybeOf(context);
    m?.showSnackBar(const SnackBar(content: Text('Demo data was reset.')));
  }
}

class FieldlineMark extends StatelessWidget {
  const FieldlineMark({super.key, this.size = 24});
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: t.accent, borderRadius: BorderRadius.circular(size * 0.28)),
      child: Icon(LucideIcons.wrench, size: size * 0.55, color: t.onAccent),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final s = StoreScope.of(context);
    final t = context.t;
    final low = s.lowStock.where((p) => !p.restockRequested).length;
    return Scaffold(
      body: IndexedStack(
        index: index,
        children: [
          TodayScreen(onOpenProfile: () => setState(() => index = 3)),
          const ScheduleScreen(),
          const StockScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: t.border)),
        ),
        child: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) => setState(() => index = i),
          destinations: [
            const NavigationDestination(icon: Icon(LucideIcons.house), label: 'Today'),
            const NavigationDestination(icon: Icon(LucideIcons.calendarDays), label: 'Schedule'),
            NavigationDestination(
              icon: Badge(isLabelVisible: low > 0, label: Text('$low'), backgroundColor: t.warning, child: const Icon(LucideIcons.package)),
              label: 'Van stock',
            ),
            const NavigationDestination(icon: Icon(LucideIcons.user), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}
