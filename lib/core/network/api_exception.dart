/// 统一的 API 异常。
///
/// ECFC 后端约定：失败时返回 `{"ok": false, "code": "...", "message": "..."}`
/// （未登录固定 code 为 UNAUTHORIZED）。部分旧接口失败时只有 `{"message": "..."}`。
class ApiException implements Exception {
  final int? statusCode;
  final String? code;
  final String message;

  const ApiException({required this.message, this.statusCode, this.code});

  bool get isUnauthorized => statusCode == 401 || code == 'UNAUTHORIZED';

  @override
  String toString() => 'ApiException($statusCode, $code, $message)';
}
