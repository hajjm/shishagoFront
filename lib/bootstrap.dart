import 'package:flutter/material.dart';

import 'app.dart';
import 'config/app_environment.dart';

void bootstrap(AppEnvironment environment) {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ShishaGoApp(config: AppConfig.forEnvironment(environment)));
}
