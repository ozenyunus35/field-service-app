import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'src/app.dart';
import 'src/store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // On the web, expose the accessibility tree so screen readers (and the browser tests) can see the app.
  if (kIsWeb) SemanticsBinding.instance.ensureSemantics();
  final store = await AppStore.open();
  runApp(FieldlineApp(store: store));
}
