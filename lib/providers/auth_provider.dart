import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_exception.dart';
import '../models/ecfc_models.dart';
import 'service_providers.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final EcfcUser? user;

  const AuthState({required this.status, this.user});

  const AuthState.unknown() : this(status: AuthStatus.unknown);

  bool get isAuthenticated => status == AuthStatus.authenticated;
}

/// 全局登录态。启动时调用 [restore] 探活；登录/登出后更新。
class AuthController extends StateNotifier<AuthState> {
  AuthController(this._ref) : super(const AuthState.unknown());

  final Ref _ref;

  Future<void> restore() async {
    try {
      final user = await _ref.read(authServiceProvider).me();
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } on ApiException {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> login({
    required String identifierType,
    required String identifier,
    required String password,
    String? phoneCountry,
  }) async {
    await _ref.read(authServiceProvider).login(
          identifierType: identifierType,
          identifier: identifier,
          password: password,
          phoneCountry: phoneCountry,
        );
    await restore();
  }

  Future<void> logout() async {
    try {
      await _ref.read(authServiceProvider).logout();
    } catch (_) {
      // 忽略网络错误，本地状态照样清掉。
    }
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref);
});
