// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get rubbishPlan => '混沌课表';

  @override
  String get selfLanguage => '中文';

  @override
  String get course => '课程';

  @override
  String get profile => '我的';
}

/// The translations for Chinese, as used in Switzerland, using the Han script (`zh_Hans_CH`).
class AppLocalizationsZhHansCh extends AppLocalizationsZh {
  AppLocalizationsZhHansCh() : super('zh_Hans_CH');

  @override
  String get selfLanguage => '中文-简体';
}
