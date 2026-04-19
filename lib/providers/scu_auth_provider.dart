import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bugaoshan/serivces/scu_auth_service.dart';

const _keyAccessToken = 'scu_access_token';
const _keyLoginTimestamp = 'scu_login_timestamp';
const _keyLastAppOpenTimestamp = 'scu_last_app_open_timestamp';
const _sessionDurationSeconds = 3600;

/// 持久化 SCU 登录状态的 Provider，注册为 singleton
class ScuAuthProvider extends ChangeNotifier {
  final SharedPreferences _prefs;
  final ScuAuthService _service = ScuAuthService();

  ScuAuthProvider(this._prefs) {
    _accessToken = _prefs.getString(_keyAccessToken);
    _loginTimestamp = _prefs.getInt(_keyLoginTimestamp);
    _updateLastAppOpenTimestamp();
  }

  String? _accessToken;
  int? _loginTimestamp;
  String? get accessToken => _accessToken;
  bool get isLoggedIn => _accessToken != null && !isExpired;
  bool get isExpired {
    if (_loginTimestamp == null) return false;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (now - _loginTimestamp! > _sessionDurationSeconds) return true;
    final lastAppOpen = _prefs.getInt(_keyLastAppOpenTimestamp);
    if (lastAppOpen != null && _loginTimestamp! < lastAppOpen) return true;
    return false;
  }

  ScuAuthService get service => _service;

  Future<void> _updateLastAppOpenTimestamp() async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _prefs.setInt(_keyLastAppOpenTimestamp, now);
  }

  Future<void> login({
    required String username,
    required String password,
    required String captchaCode,
    required String captchaText,
  }) async {
    await _service.login(
      username: username,
      password: password,
      captchaCode: captchaCode,
      captchaText: captchaText,
    );
    _accessToken = _service.accessToken;
    _loginTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _prefs.setString(_keyAccessToken, _accessToken!);
    await _prefs.setInt(_keyLoginTimestamp, _loginTimestamp!);
    notifyListeners();
  }

  Future<void> logout() async {
    _service.logout();
    _accessToken = null;
    _loginTimestamp = null;
    await _prefs.remove(_keyAccessToken);
    await _prefs.remove(_keyLoginTimestamp);
    notifyListeners();
  }
}
