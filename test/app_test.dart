import 'package:fieldline/src/app.dart';
import 'package:fieldline/src/i18n.dart';
import 'package:fieldline/src/tr.dart';
import 'package:fieldline/src/models.dart';
import 'package:fieldline/src/screens/job_detail.dart';
import 'package:fieldline/src/screens/signature.dart';
import 'package:fieldline/src/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final thursday = DateTime(2026, 10, 29, 10);

Future<AppStore> pumpApp(WidgetTester tester, {Size size = const Size(390, 844)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final store = AppStore(await SharedPreferences.getInstance(), clock: () => thursday, syncDelay: const Duration(milliseconds: 300));
  await tester.pumpWidget(FieldlineApp(store: store));
  await tester.pumpAndSettle();
  return store;
}

/// Scrolls the screen's list until [f] is built, for items further down a long screen.
Future<void> reveal(WidgetTester tester, Finder f) async {
  if (f.evaluate().isEmpty) await tester.dragUntilVisible(f, find.byType(ListView).last, const Offset(0, -200));
}

Future<void> tapText(WidgetTester tester, String text) async {
  final f = find.text(text);
  await reveal(tester, f);
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

void main() {
  // Real fonts, so layout in tests matches the app.
  setUpAll(() async {
    WidgetController.hitTestWarningShouldBeFatal = true;
    final inter = FontLoader('Inter');
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      inter.addFont(rootBundle.load('assets/fonts/Inter-$w.ttf'));
    }
    await inter.load();
  });

  testWidgets('today opens on the route with the urgent job next', (tester) async {
    await pumpApp(tester);
    expect(find.text('Today'), findsWidgets);
    expect(find.text('Thursday, October 29'), findsOneWidget);
    expect(find.text('2 of 6'), findsOneWidget);
    expect(find.text('Up next'), findsOneWidget);
    expect(find.text('No heat'), findsWidgets);
    expect(find.text('Urgent'), findsWidgets);
    expect(find.text('6 stops'), findsOneWidget);
    expect(find.text('Start travel'), findsOneWidget);
  });

  testWidgets('start travel moves the job to in progress', (tester) async {
    final s = await pumpApp(tester);
    await tapText(tester, 'Start travel');
    expect(find.text('In progress'), findsOneWidget);
    expect(find.text('Arrived on site'), findsOneWidget);
    expect(find.textContaining('was told you are on the way'), findsOneWidget);
    expect(s.current!.status, JobStatus.travelling);
  });

  testWidgets('a job can be worked and signed off end to end', (tester) async {
    final s = await pumpApp(tester);
    final job = s.current!;
    await tester.tap(find.text(job.description));
    await tester.pumpAndSettle();
    expect(find.text(job.ref), findsOneWidget);

    await tapText(tester, 'Start travel');
    await tapText(tester, 'Arrived on site');

    // Gas appliance: the site safety check comes first.
    for (final label in AppStore.safetyChecks) {
      await tapText(tester, label);
    }
    await tapText(tester, 'Confirm safety check');
    expect(job.safetyCheckedAt, isNotNull);
    expect(find.text('Complete job'), findsOneWidget);

    // Required checks
    for (final c in job.checklist.where((c) => c.required)) {
      await tapText(tester, c.label);
    }
    expect(job.requiredLeft, 0);

    // A part from the van
    await tapText(tester, 'Add part');
    expect(find.text('Add from Van 07'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Search parts or SKU'), 'igniter');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hot surface igniter'));
    await tester.pumpAndSettle();
    expect(job.parts.single.partId, 'igniter');
    expect(s.part('igniter').qty, 1);

    // A photo
    await tapText(tester, 'Add photo');
    expect(job.photos, hasLength(1));

    await tapText(tester, 'Complete job');
    expect(find.text('Customer sign-off'), findsOneWidget);
    expect(find.text('Customer signature missing'), findsOneWidget);

    final pad = find.bySemanticsLabel(RegExp('Signature pad'));
    await tester.ensureVisible(pad);
    await tester.pumpAndSettle();
    // A signature, not a tap: one stroke with several points across the pad.
    final g = await tester.startGesture(tester.getCenter(pad) - const Offset(80, 0));
    for (var i = 0; i < 8; i++) {
      await g.moveBy(Offset(20, i.isEven ? 8 : -8));
      await tester.pump();
    }
    await g.up();
    await tester.pumpAndSettle();
    expect(find.text('Clear'), findsOneWidget);

    final submit = find.textContaining('Complete ·');
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('Job completed'), findsOneWidget);
    expect(job.done, isTrue);
    expect(job.signature, isNotEmpty);

    await tapText(tester, 'Back to today');
    expect(find.text('3 of 6'), findsOneWidget);
    expect(find.text('Up next'), findsOneWidget);
  });

  testWidgets('complete is blocked until the required checks are done', (tester) async {
    final s = await pumpApp(tester);
    s.arrive(s.current!.id);
    await tester.pumpAndSettle();
    await tapText(tester, 'Complete job');
    expect(find.text('Finish the required checks first'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.ancestor(of: find.textContaining('Complete ·'), matching: find.byWidgetPredicate((w) => w is FilledButton)),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('van stock filters low parts and requests a restock', (tester) async {
    final s = await pumpApp(tester);
    await tester.tap(find.text('Van stock'));
    await tester.pumpAndSettle();
    expect(find.text('Hot surface igniter'), findsOneWidget);
    expect(find.text('MERV 11 air filter 16x25x1'), findsOneWidget);
    await tester.tap(find.text('Low only'));
    await tester.pumpAndSettle();
    expect(find.text('MERV 11 air filter 16x25x1'), findsNothing);
    await tester.tap(find.bySemanticsLabel('Request restock of Hot surface igniter'));
    await tester.pumpAndSettle();
    expect(s.part('igniter').restockRequested, isTrue);
    expect(find.text('Received?'), findsOneWidget);
  });

  testWidgets('schedule shows other days', (tester) async {
    final s = await pumpApp(tester);
    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();
    final tomorrow = s.jobsOn('2026-10-30');
    await tester.tap(find.bySemanticsLabel(RegExp(r'^Fri, Oct 30')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Tomorrow · ${tomorrow.length} jobs'), findsOneWidget);
    expect(find.text(tomorrow.first.title), findsWidgets);
  });

  testWidgets('offline mode queues changes and syncs them', (tester) async {
    final s = await pumpApp(tester);
    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    await reveal(tester, find.text('Everything is synced'));
    expect(find.text('Everything is synced'), findsOneWidget);
    await tester.ensureVisible(find.text('Work offline'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Work offline'));
    await tester.pumpAndSettle();
    expect(s.offline, isTrue);

    await tester.tap(find.text('Today').last);
    await tester.pumpAndSettle();
    expect(find.text('Offline. Changes are saved on this phone.'), findsOneWidget);
    await tapText(tester, 'Start travel');
    // Back to the top of the list, where the offline strip is.
    await tester.fling(find.byType(CustomScrollView).first, const Offset(0, 800), 2000);
    await tester.pumpAndSettle();
    expect(find.text('Offline. 1 change waiting to sync.'), findsOneWidget);

    await tester.tap(find.text('Go online'));
    await tester.pump();
    expect(find.text('Syncing 1 change…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(s.pending, isEmpty);
    expect(find.textContaining('Offline'), findsNothing);
  });

  testWidgets('theme can be switched and reset restores the route', (tester) async {
    final s = await pumpApp(tester);
    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    await tapText(tester, 'Dark');
    expect(s.themeMode, ThemeMode.dark);
    expect(Theme.of(tester.element(find.text('Work offline'))).brightness, Brightness.dark);

    s.arrive(s.current!.id);
    await tapText(tester, 'Reset demo data');
    await tester.tap(find.widgetWithText(FilledButton, 'Reset'));
    await tester.pumpAndSettle();
    expect(s.todayJobs.where((j) => j.active), isEmpty);
    expect(find.text('Demo data was reset.'), findsOneWidget);
  });

  testWidgets('a wide window shows the app in a phone frame with a description', (tester) async {
    await pumpApp(tester, size: const Size(1440, 900));
    expect(find.text("The technician's day, in one app."), findsOneWidget);
    expect(find.text('Source code'), findsOneWidget);
    final shell = tester.getSize(find.byType(Shell));
    expect(shell.width, 390);
  });

  testWidgets('a completed job shows the invoice and signature, read only', (tester) async {
    final s = await pumpApp(tester);
    final done = s.todayJobs.first;
    final row = find.bySemanticsLabel(RegExp('^8:00 AM, ${done.title}'));
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.text('Add part'), findsNothing);
    final list = find.descendant(of: find.byType(JobDetailScreen), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.byWidgetPredicate((w) => w is CustomPaint && w.painter is SignaturePainter), 200, scrollable: list);
    expect(find.text('Total', skipOffstage: false), findsOneWidget);
    expect(find.text('Sign-off', skipOffstage: false), findsOneWidget);
    expect(find.text('Add part'), findsNothing);
    expect(find.text('Complete job'), findsNothing);
  });

  testWidgets('notes typed and left with the back button are kept', (tester) async {
    final s = await pumpApp(tester);
    final job = s.current!;
    await tester.tap(find.text(job.description));
    await tester.pumpAndSettle();
    final list = find.descendant(of: find.byType(JobDetailScreen), matching: find.byType(Scrollable)).first;
    final field = find.widgetWithText(TextField, 'Notes for the office');
    await tester.scrollUntilVisible(field, 200, scrollable: list);
    await tester.pumpAndSettle();
    await tester.tap(field);
    await tester.pump();
    await tester.enterText(field, 'Igniter cracked, replaced');
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(s.job(job.id).notes, 'Igniter cracked, replaced');
  });

  testWidgets('a quote with a custom item is accepted on the spot and books the work', (tester) async {
    final s = await pumpApp(tester);
    final job = s.current!;
    s.arrive(job.id);
    await tester.pumpAndSettle();
    await tester.tap(find.text(job.description));
    await tester.pumpAndSettle();
    await tapText(tester, 'New quote');
    expect(find.text('New quote'), findsWidgets);
    await tapText(tester, 'Igniter and flame sensor upgrade');
    await tester.enterText(find.widgetWithText(TextField, 'Item'), 'Draft inducer motor');
    await tester.enterText(find.widgetWithText(TextField, 'Price'), '310.50');
    await tester.tap(find.byTooltip('Add item'));
    await tester.pumpAndSettle();
    expect(find.text('Draft inducer motor'), findsOneWidget);

    final pad = find.bySemanticsLabel(RegExp('Signature pad'));
    await reveal(tester, pad);
    await tester.ensureVisible(pad);
    await tester.pumpAndSettle();
    final g = await tester.startGesture(tester.getCenter(pad) - const Offset(80, 0));
    for (var i = 0; i < 8; i++) {
      await g.moveBy(Offset(20, i.isEven ? 8 : -8));
      await tester.pump();
    }
    await g.up();
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Accept \$'));
    await tester.pumpAndSettle();

    final q = s.quotes.single;
    expect(q.status, QuoteStatus.accepted);
    expect(q.items.map((i) => i.label), contains('Draft inducer motor'));
    expect(s.quoteTotal(q).items, 120 + 45 + 310.5);
    final booked = s.job(q.followUpJobId!);
    expect(booked.title, 'Igniter and flame sensor upgrade');
    expect(find.textContaining('Accepted. ${booked.ref} is booked'), findsOneWidget);
  });

  testWidgets('cash chosen before signing: the change is shown and the job completes', (tester) async {
    final s = await pumpApp(tester);
    final job = s.current!;
    s.arrive(job.id);
    s.confirmSafety(job.id, const [true, true, true]);
    for (final (i, c) in job.checklist.indexed) {
      if (c.required) s.toggleCheck(job.id, i);
    }
    await tester.pumpAndSettle();
    await tester.tap(find.text(job.description));
    await tester.pumpAndSettle();
    await tapText(tester, 'Complete job');
    await tapText(tester, 'Cash');
    final hundred = find.textContaining(RegExp(r'^\$\d+00$'));
    await reveal(tester, hundred.last);
    await tester.tap(hundred.last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Change to give'), findsOneWidget);

    final pad = find.bySemanticsLabel(RegExp('Signature pad'));
    await reveal(tester, pad);
    await tester.ensureVisible(pad);
    await tester.pumpAndSettle();
    final g = await tester.startGesture(tester.getCenter(pad) - const Offset(80, 0));
    for (var i = 0; i < 8; i++) {
      await g.moveBy(Offset(20, i.isEven ? 8 : -8));
      await tester.pump();
    }
    await g.up();
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Complete · cash'));
    await tester.pumpAndSettle();
    expect(find.text('Job completed'), findsOneWidget);
    expect(find.text('Paid in cash'), findsOneWidget);
    expect(job.payment!.change, greaterThan(0));
  });

  testWidgets('the whole day works in Turkish', (tester) async {
    final s = await pumpApp(tester);
    trMisses.clear();
    s.setLang('tr');
    await tester.pumpAndSettle();
    expect(find.text('Rota'), findsOneWidget);
    final job = s.current!;

    // A job, worked end to end.
    await tester.tap(find.text(job.description));
    await tester.pumpAndSettle();
    await tapText(tester, 'Yola çık');
    await tapText(tester, 'Adrese vardım');
    for (final label in AppStore.safetyChecks) {
      await tapText(tester, trText[label]!);
    }
    await tapText(tester, 'Güvenlik kontrolünü onayla');
    for (final c in job.checklist.where((c) => c.required)) {
      await tapText(tester, c.label);
    }
    await tapText(tester, 'Parça ekle');
    await tester.tap(find.text('Hot surface igniter'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Fotoğraf ekle');
    await tapText(tester, 'İşi tamamla');
    expect(find.text('Müşteri imzası eksik'), findsOneWidget);
    await tapText(tester, 'Nakit');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    // The other tabs, offline mode and the office's changes.
    for (final tab in ['Program', 'Araç stoğu', 'Profil']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
    }
    // Offline, the office's changes and a break, set through the store; their buttons are tested in English.
    s.setOffline(true);
    s.simulateOfficeChanges();
    s.startBreak();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bugün').last);
    await tester.pumpAndSettle();
    await tester.fling(find.byType(CustomScrollView).first, const Offset(0, 800), 2000);
    await tester.pumpAndSettle();
    await tapText(tester, 'Çevrimiçi ol');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(trMisses, isEmpty);
    s.setLang('en');
    await tester.pumpAndSettle();
    expect(find.text('Van stock'), findsOneWidget);
    expect(find.text('Araç stoğu'), findsNothing);
  });
}
