import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:rubbish_plan/app.dart';
import 'package:rubbish_plan/injection/injector.dart';

void main() async {
  configureDependencies();
  if (!kIsWeb) {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
  }
  await ensureBasicDependencies();
  runApp(MyApp());
}
