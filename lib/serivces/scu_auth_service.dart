import 'dart:convert';
import 'dart:developer' as dev;
import 'package:http/http.dart' as http;
import 'package:Bugaoshan/utils/sm2_crypto.dart';

/// 四川大学统一身份认证 Service
class ScuAuthService {
  static const _base = 'https://id.scu.edu.cn';
  static const _clientId = '1371cbeda563697537f28d99b4744a973uDKtgYqL5B';
  static const _enterpriseId = 'scdx';

  static final Map<String, String> _headers = {
    'Accept': 'application/json, text/plain, */*',
    'Content-Type': 'application/json;charset=UTF-8',
    'Origin': _base,
    'Referer': '$_base/frontend/login',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36 Edg/131.0.0.0',
  };

  String? _accessToken;
  String? get accessToken => _accessToken;

  /// 获取验证码，返回 [CaptchaResult]
  Future<CaptchaResult> fetchCaptcha() async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final uri = Uri.parse(
      '$_base/api/public/bff/v1.2/one_time_login/captcha'
      '?_enterprise_id=$_enterpriseId&timestamp=$ts',
    );
    final resp = await http.get(uri, headers: _headers);
    dev.log('[SCU] captcha response: ${resp.body}', name: 'ScuAuth');

    final json = _parseJson(resp.body, 'captcha');
    final data = json['data'];
    if (data == null) {
      throw ScuLoginException('验证码接口返回异常: ${resp.body}');
    }
    final dataMap = data as Map<String, dynamic>;

    // 字段名可能是 captcha 或 image 或 img，做兼容
    final captchaImg =
        (dataMap['captcha'] ??
                dataMap['image'] ??
                dataMap['img'] ??
                dataMap['captchaImage'])
            ?.toString();
    final code = dataMap['code']?.toString();

    if (captchaImg == null || code == null) {
      throw ScuLoginException('验证码字段解析失败，实际响应: ${resp.body}');
    }
    return CaptchaResult(code: code, captchaBase64: captchaImg);
  }

  /// 登录，成功后 [accessToken] 会被保存
  Future<void> login({
    required String username,
    required String password,
    required String captchaCode,
    required String captchaText,
  }) async {
    // 1. 获取 SM2 公钥
    final sm2Resp = await http.post(
      Uri.parse('$_base/api/public/bff/v1.2/sm2_key'),
      headers: _headers,
      body: '{}',
    );
    dev.log('[SCU] sm2_key response: ${sm2Resp.body}', name: 'ScuAuth');

    final sm2Json = _parseJson(sm2Resp.body, 'sm2_key');
    final sm2Data = sm2Json['data'] as Map<String, dynamic>?;
    if (sm2Data == null) {
      throw ScuLoginException('SM2 公钥接口返回异常: ${sm2Resp.body}');
    }
    final publicKey = sm2Data['publicKey']?.toString();
    final sm2Code = sm2Data['code']?.toString();
    if (publicKey == null || sm2Code == null) {
      throw ScuLoginException('SM2 公钥字段缺失: ${sm2Resp.body}');
    }

    // 2. SM2 C1C2C3 加密密码
    final encryptedPassword = SM2Crypto.encryptWithBase64Key(
      password,
      publicKey,
    );

    // 3. 请求 token
    final payload = jsonEncode({
      'client_id': _clientId,
      'grant_type': 'password',
      'scope': 'read',
      'username': username,
      'password': encryptedPassword,
      '_enterprise_id': _enterpriseId,
      'sm2_code': sm2Code,
      'cap_code': captchaCode,
      'cap_text': captchaText,
    });

    final tokenResp = await http.post(
      Uri.parse('$_base/api/public/bff/v1.2/rest_token'),
      headers: _headers,
      body: payload,
    );
    dev.log('[SCU] rest_token response: ${tokenResp.body}', name: 'ScuAuth');

    final result = _parseJson(tokenResp.body, 'rest_token');
    if (result['success'] != true) {
      final msg =
          result['message']?.toString() ?? result['msg']?.toString() ?? '登录失败';
      throw ScuLoginException(msg);
    }

    final tokenData = result['data'] as Map<String, dynamic>?;
    final token = tokenData?['access_token']?.toString();
    if (token == null) {
      throw ScuLoginException('Token 字段缺失: ${tokenResp.body}');
    }
    _accessToken = token;
  }

  /// 将 token 绑定到服务端 session
  Future<void> bindSession() async {
    if (_accessToken == null) throw ScuLoginException('未登录');
    final resp = await http.post(
      Uri.parse('$_base/api/bff/v1.2/commons/session/save'),
      headers: {..._headers, 'Authorization': 'Bearer $_accessToken'},
      body: '{}',
    );
    final result = _parseJson(resp.body, 'session/save');
    if (result['success'] != true) {
      throw ScuLoginException('session/save 失败: ${resp.body}');
    }
  }

  void logout() {
    _accessToken = null;
  }

  /// 安全解析 JSON，失败时抛出带上下文的异常
  static Map<String, dynamic> _parseJson(String body, String api) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (e) {
      throw ScuLoginException('[$api] JSON 解析失败: $body');
    }
  }
}

class CaptchaResult {
  final String code;
  final String captchaBase64;
  const CaptchaResult({required this.code, required this.captchaBase64});
}

class ScuLoginException implements Exception {
  final String message;
  const ScuLoginException(this.message);
  @override
  String toString() => message;
}
