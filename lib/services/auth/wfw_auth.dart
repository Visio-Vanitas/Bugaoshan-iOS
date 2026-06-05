import 'package:http/http.dart' as http;
import 'package:bugaoshan/services/auth/scu_auth.dart';

/// 微服务认证（第2层）
///
/// wfw.scu.edu.cn 使用 Bearer token 认证，不需要 cookie。
class WfwAuth {
  final ScuAuth _scuAuth;
  WfwAuth(this._scuAuth);

  /// 获取注入 Bearer token 的 HTTP Client。
  ///
  /// 如果 SCU 认证失败，[UnauthenticatedException] 自动穿透。
  Future<http.Client> getClient() async {
    final token = await _scuAuth.getAccessToken();
    return _WfwAuthClient(token);
  }
}

/// 自动注入 Authorization: Bearer 头的 HTTP Client。
class _WfwAuthClient extends http.BaseClient {
  final String _token;
  final http.Client _inner = http.Client();

  _WfwAuthClient(this._token);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_token';
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
