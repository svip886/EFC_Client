import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';

import '../constants.dart';
import 'api_exception.dart';

/// 封装 Dio + 持久化 CookieJar。
///
/// ECFC 用浏览器式 Cookie 会话鉴权（`eason_fans_session`），
/// 不是 Bearer token，所以这里核心工作是把 CookieJar 落盘、
/// 并把非 2xx 响应统一转换成 [ApiException]。
class ApiClient {
  ApiClient._(this._dio, this._cookieJar);

  final Dio _dio;
  final PersistCookieJar _cookieJar;

  static ApiClient? _instance;

  static Future<ApiClient> ensureInitialized() async {
    if (_instance != null) return _instance!;

    final dir = await getApplicationSupportDirectory();
    final cookieJar = PersistCookieJar(
      ignoreExpires: false,
      storage: FileStorage('${dir.path}/.cookies/'),
    );

    final dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        headers: const {'Accept': 'application/json'},
        // 后端对未登录 / 校验失败也会返回 200 之外的状态码，
        // 让 Dio 把所有状态码都当"正常返回"交给上层统一处理，
        // 避免真实的网络异常和业务异常混在一起不好区分。
        validateStatus: (_) => true,
      ),
    );
    dio.interceptors.add(CookieManager(cookieJar));

    _instance = ApiClient._(dio, cookieJar);
    return _instance!;
  }

  Dio get dio => _dio;

  /// 读取当前 CookieJar 对某 URI 会携带的 Cookie（给 WebSocket 握手用）。
  Future<List<Cookie>> loadCookiesFor(Uri uri) => _cookieJar.loadForRequest(uri);

  /// 是否存有 ECFC 的会话 Cookie（近似判断，真正是否有效以请求结果为准）。
  Future<bool> hasSessionCookie() async {
    final uri = Uri.parse(AppConstants.baseUrl);
    final cookies = await _cookieJar.loadForRequest(uri);
    return cookies.any((c) => c.name == AppConstants.sessionCookieName);
  }

  Future<void> clearCookies() async {
    await _cookieJar.deleteAll();
  }

  /// 用 WebView 同步来的 Cookie 覆盖写入持久化 jar。
  Future<void> importCookies(List<Cookie> cookies) async {
    if (cookies.isEmpty) return;
    final hosts = <Uri>{
      Uri.parse(AppConstants.baseUrl),
      Uri.parse('https://ecfc.fans/'),
      Uri.parse('https://www.ecfc.fans/'),
    };
    for (final uri in hosts) {
      await _cookieJar.saveFromResponse(uri, cookies);
    }
  }

  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) => _guard(() => _dio.get(path, queryParameters: query));

  Future<Response<dynamic>> post(String path, {Object? data}) =>
      _guard(() => _dio.post(path, data: data));

  /// 不抛业务异常的 GET（用于未读轮询等后台任务；网络失败仍抛）。
  Future<Response<dynamic>> getSoft(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    try {
      return await _dio.get(path, queryParameters: query);
    } on DioException catch (e) {
      if (e.response != null) return e.response!;
      throw ApiException(message: '网络连接失败：${e.message}');
    } on SocketException catch (e) {
      throw ApiException(message: '网络连接失败：$e');
    }
  }

  Future<Response<dynamic>> _guard(
    Future<Response<dynamic>> Function() run,
  ) async {
    try {
      final resp = await run();
      _throwIfError(resp);
      return resp;
    } on DioException catch (e) {
      if (e.response != null) {
        _throwIfError(e.response!);
        return e.response!;
      }
      throw ApiException(message: '网络连接失败：${e.message}');
    } on SocketException catch (e) {
      throw ApiException(message: '网络连接失败：$e');
    }
  }

  void _throwIfError(Response<dynamic> resp) {
    final status = resp.statusCode ?? 0;
    final data = resp.data;

    // 部分接口 HTTP 200 但 body.ok=false（未登录/业务失败）
    if (data is Map && data['ok'] == false) {
      final message = (data['message'] is String &&
              (data['message'] as String).isNotEmpty)
          ? data['message'] as String
          : '请求失败';
      final code = data['code'] is String ? data['code'] as String : null;
      final codeStatus = (code == 'UNAUTHORIZED') ? 401 : (status >= 400 ? status : 400);
      throw ApiException(statusCode: codeStatus, code: code, message: message);
    }

    if (status >= 200 && status < 300) return;

    String message = 'HTTP $status';
    String? code;
    if (data is Map) {
      final m = data['message'];
      if (m is String && m.isNotEmpty) message = m;
      final c = data['code'];
      if (c is String) code = c;
    }
    throw ApiException(statusCode: status, code: code, message: message);
  }
}
