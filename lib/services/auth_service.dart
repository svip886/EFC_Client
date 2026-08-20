import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../models/ecfc_models.dart';

/// Login / session related requests. See docs/ECFC_API.md section 3.
class AuthService {
  AuthService(this._client);

  final ApiClient _client;

  /// [identifier]: phone number should be E.164 format (e.g. +8613xxxxxxxxx),
  /// email should be a plain email address.
  Future<void> login({
    required String identifierType, // 'phone' | 'email'
    required String identifier,
    required String password,
    String? phoneCountry,
  }) async {
    await _client.post(
      '/api/auth/login',
      data: {
        'identifierType': identifierType,
        'identifier': identifier,
        'password': password,
        if (phoneCountry != null) 'phoneCountry': phoneCountry,
      },
    );
  }

  Future<void> logout() async {
    await _client.post('/api/auth/logout');
  }

  /// Probe current login state. Throws [ApiException] (isUnauthorized=true)
  /// when not logged in or when the response shape is unexpected, so the
  /// caller can decide to navigate to the login page.
  ///
  /// Note: when not logged in, ECFC's `/api/auth/me` may still return HTTP
  /// 200 with a body like `{"ok":false,"code":"UNAUTHORIZED",...}` (no
  /// `user` field). We must not assume a 2xx status always carries `user`,
  /// otherwise a fresh install (no cookie yet) crashes right at startup.
  Future<EcfcUser> me() async {
    final resp = await _client.get('/api/auth/me');
    final data = resp.data;
    if (data is! Map || data['user'] is! Map) {
      throw const ApiException(
        statusCode: 401,
        code: 'UNAUTHORIZED',
        message: '请先登录',
      );
    }
    return EcfcUser.fromJson((data['user'] as Map).cast<String, dynamic>());
  }
}
