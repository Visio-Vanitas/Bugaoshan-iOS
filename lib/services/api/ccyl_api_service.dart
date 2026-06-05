import 'package:bugaoshan/pages/campus/ccyl/models/ccyl_models.dart';
import 'package:bugaoshan/services/auth/ccyl_auth.dart';
import 'package:bugaoshan/services/ccyl/ccyl_service.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';

/// 第二课堂 API Service（第1层）
///
/// 通过 [CcylAuth] 获取 token，委托给 [CcylService] 的静态方法。
class CcylApiService {
  final CcylAuth _auth;
  CcylApiService(this._auth);

  /// 获取 token，未登录时自动尝试 reLogin，失败抛 [UnauthenticatedException]。
  Future<String> _ensureToken() async {
    if (_auth.isLoggedIn) return _auth.token!;
    final ok = await _auth.reLogin();
    if (!ok) throw const UnauthenticatedException('第二课堂未登录');
    return _auth.token!;
  }

  Future<List<CyclActivity>> searchActivities({
    int pageNum = 1,
    int pageSize = 10,
    String? name,
    String? level,
    String? scoreType,
    String? org,
    String? order,
    String? status,
    String? quality,
  }) async {
    final token = await _ensureToken();
    return CcylService.searchActivities(
      token: token,
      pageNum: pageNum,
      pageSize: pageSize,
      name: name ?? '',
      level: level ?? '',
      scoreType: scoreType ?? '',
      org: org ?? '',
      order: order ?? '',
      status: status ?? '',
      quality: quality ?? '',
    );
  }

  Future<List<CyclActivity>> getMyActivities({
    int pageNum = 1,
    int pageSize = 10,
  }) async {
    final token = await _ensureToken();
    return CcylService.getMyActivities(
      token: token,
      pageNum: pageNum,
      pageSize: pageSize,
    );
  }

  Future<List<CyclActivity>> getOrderedActivities({
    int pageNum = 1,
    int pageSize = 10,
    String? name,
  }) async {
    final token = await _ensureToken();
    return CcylService.getOrderedActivities(
      token: token,
      pageNum: pageNum,
      pageSize: pageSize,
      name: name ?? '',
    );
  }

  Future<List<CyclOrg>> getAllOrgs() async {
    final token = await _ensureToken();
    return CcylService.getAllOrgs(token: token);
  }

  Future<
    ({
      List<CyclActivity> activities,
      CyclActivityLib activityLib,
      bool subscribed,
    })
  >
  getActivityLibDetail(String id) async {
    final token = await _ensureToken();
    return CcylService.getActivityLibDetail(
      token: token,
      activityLibraryId: id,
    );
  }

  Future<void> subscribeActivity(String id) async {
    final token = await _ensureToken();
    return CcylService.subscribeActivity(token: token, activityLibraryId: id);
  }

  Future<void> cancelSubscribe(String id) async {
    final token = await _ensureToken();
    return CcylService.cancelSubscribe(token: token, activityLibraryId: id);
  }

  Future<List<CyclScoreType>> getActivityScoreTypes(String id) async {
    final token = await _ensureToken();
    return CcylService.getActivityScoreTypes(
      token: token,
      activityLibraryId: id,
    );
  }

  Future<void> signUpActivity(String activityId, String scoreType) async {
    final token = await _ensureToken();
    return CcylService.signUpActivity(
      token: token,
      activityId: activityId,
      scoreType: scoreType,
    );
  }

  Future<void> cancelSignUp(String activityId) async {
    final token = await _ensureToken();
    final userId = _auth.requireUserId();
    return CcylService.cancelSignUp(
      token: token,
      activityId: activityId,
      userId: userId,
    );
  }

  Future<
    ({
      CyclActivity activity,
      CyclActivityLib? activityLib,
      bool isXtwRole,
      bool signUp,
    })
  >
  getActivityDetail(String activityId) async {
    final token = await _ensureToken();
    return CcylService.getActivityDetail(token: token, activityId: activityId);
  }

  Future<List<CyclCredit>> getCreditList({
    int pageNum = 1,
    int pageSize = 10,
  }) async {
    final token = await _ensureToken();
    return CcylService.getCreditList(
      token: token,
      pageNum: pageNum,
      pageSize: pageSize,
    );
  }

  Future<String> exportCreditsToEmail(
    List<String> creditIds,
    String email,
  ) async {
    final token = await _ensureToken();
    return CcylService.exportCreditsToEmail(
      token: token,
      creditIds: creditIds,
      email: email,
    );
  }

  Future<Map<String, List<CyclDict>>> getDicts(List<String> groupCodes) async {
    final token = await _ensureToken();
    return CcylService.getDicts(token: token, groupCodes: groupCodes);
  }
}
