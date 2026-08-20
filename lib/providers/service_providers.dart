import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../services/auth_service.dart';
import '../services/checkin_service.dart';
import '../services/forum_service.dart';

/// 应用启动时用 `overrideWithValue` 注入真正的 ApiClient
/// （因为初始化是异步的，见 main.dart）。
final apiClientProvider = Provider<ApiClient>((ref) {
  throw UnimplementedError('ApiClient 尚未初始化');
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(apiClientProvider));
});

final forumServiceProvider = Provider<ForumService>((ref) {
  return ForumService(ref.watch(apiClientProvider));
});

final checkinServiceProvider = Provider<CheckinService>((ref) {
  return CheckinService(ref.watch(apiClientProvider));
});
