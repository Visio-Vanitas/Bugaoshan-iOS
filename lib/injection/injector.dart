import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:rubbish_plan/serivces/app_config_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'injector.config.dart';

final getIt = GetIt.instance;

@InjectableInit(
  initializerName: 'init', // default
  preferRelativeImports: true, // default
  asExtension: true, // default
)
void configureDependencies() {
  getIt.init();
  _configureAsyncDependencies();
}

void _configureAsyncDependencies() {
  getIt.registerSingletonAsync<SharedPreferences>(
    () => SharedPreferences.getInstance(),
  );
  getIt.registerSingletonAsync<AppConfigService>(() async {
    await getIt.isReady<SharedPreferences>();
    final prefs = getIt<SharedPreferences>();
    return AppConfigService(prefs);
  });
}

Future<void> ensureBasicDependencies() async {
  await getIt.isReady<AppConfigService>();
}
