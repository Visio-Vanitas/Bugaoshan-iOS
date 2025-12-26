import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

//define key
const String _keyLocale = 'locale';

class AppConfigService {
  final SharedPreferences _sharedPreferences;

  AppConfigService(this._sharedPreferences) {
    _loadLocale();
    _addSaveCallback();
  }

  //variable
  final ValueNotifier<Locale?> locale = ValueNotifier<Locale?>(null);

  void _loadLocale() {
    final localeString = _sharedPreferences.getString(_keyLocale);
    if (localeString != null) {
      locale.value = _parseLocale(localeString);
    }
  }

  void _addSaveCallback() {
    locale.addListener(() {
      if (locale.value != null) {
        _sharedPreferences.setString(_keyLocale, locale.toString());
      }
    });
  }

  void clearAll() {
    _sharedPreferences.clear();
    _loadLocale();
  }

  Locale? _parseLocale(String lang) {
    Locale? locale;

    var splitLang = lang.split("_");
    if (splitLang.length == 1) {
      locale = Locale(lang);
    } else if (splitLang.length == 2) {
      locale = Locale.fromSubtags(
        languageCode: splitLang[0],
        scriptCode: splitLang[1],
      );
    } else if (splitLang.length == 3) {
      locale = Locale.fromSubtags(
        languageCode: splitLang[0],
        scriptCode: splitLang[1],
        countryCode: splitLang[2],
      );
    }

    return locale;
  }
}
