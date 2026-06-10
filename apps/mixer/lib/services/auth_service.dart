// 账号鉴权服务 - 抽象 + Mock + ECS 实现
//
// 设计：
//   - 启动时 ensureAnonymous() 自动注册/恢复匿名账号
//   - currentUser 是 ValueNotifier<AuthUser?>，UI 用 ValueListenableBuilder 订阅
//   - JWT 存 Hive Box（生产可换 flutter_secure_storage 加密）
//
// 当前默认 MockAuthProvider，所有操作不联网。后端就绪后 main.dart 切到 EcsAuthProvider。

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/auth_user.dart';

abstract class AuthProvider {
  /// 匿名注册或恢复（首次开 App 必调）
  Future<AuthResult> signInAnonymously({required String cdid});

  /// Email + 密码注册
  Future<AuthResult> registerEmail({
    required String email,
    required String password,
    String? displayName,
    String? linkAnonymousJwt, // 升级匿名账号时传入
  });

  /// Email + 密码登录
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  });

  /// Google 登录（id_token 由 google_sign_in 包获得，目前 Mock 略过）
  Future<AuthResult> signInWithGoogle({required String idToken});

  /// Apple 登录
  Future<AuthResult> signInWithApple({
    required String identityToken,
    required String authorizationCode,
    String? nonce,
  });

  /// 绑定新方式到当前账号
  Future<AuthResult> bindEmail({
    required String currentJwt,
    required String email,
    required String password,
  });

  /// 拉取自己信息
  Future<AuthUser?> me({required String jwt});
}

// ════════════════════════════════════════════════════════════
// Mock：所有数据本地伪造
// ════════════════════════════════════════════════════════════

class MockAuthProvider implements AuthProvider {
  // Mock 账号库（email → password）
  static final Map<String, _MockAccount> _accounts = {};

  @override
  Future<AuthResult> signInAnonymously({required String cdid}) async {
    await _simDelay();
    final user = AuthUser(
      userId: 'anon_${cdid.substring(0, 8)}',
      cdid: cdid,
      linkedMethods: {AuthMethod.anonymous},
      createdAt: DateTime.now(),
    );
    return AuthResult.success(user, _genJwt(user.userId));
  }

  @override
  Future<AuthResult> registerEmail({
    required String email,
    required String password,
    String? displayName,
    String? linkAnonymousJwt,
  }) async {
    await _simDelay();
    if (_accounts.containsKey(email)) {
      return AuthResult.failure('该邮箱已注册');
    }
    final user = AuthUser(
      userId: 'usr_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}',
      email: email,
      displayName: displayName ?? email.split('@').first,
      linkedMethods: {AuthMethod.email},
      createdAt: DateTime.now(),
    );
    _accounts[email] = _MockAccount(password: password, user: user);
    return AuthResult.success(user, _genJwt(user.userId));
  }

  @override
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _simDelay();
    final acc = _accounts[email];
    if (acc == null) return AuthResult.failure('邮箱未注册');
    if (acc.password != password) return AuthResult.failure('密码错误');
    return AuthResult.success(acc.user, _genJwt(acc.user.userId));
  }

  @override
  Future<AuthResult> signInWithGoogle({required String idToken}) async {
    await _simDelay();
    final user = AuthUser(
      userId: 'usr_google_${idToken.hashCode.toRadixString(16)}',
      email: 'mock-google-user@example.com',
      displayName: 'Mock Google User',
      linkedMethods: {AuthMethod.google},
      createdAt: DateTime.now(),
    );
    return AuthResult.success(user, _genJwt(user.userId));
  }

  @override
  Future<AuthResult> signInWithApple({
    required String identityToken,
    required String authorizationCode,
    String? nonce,
  }) async {
    await _simDelay();
    final user = AuthUser(
      userId: 'usr_apple_${identityToken.hashCode.toRadixString(16)}',
      email: 'mock-apple-user@privaterelay.appleid.com',
      displayName: 'Mock Apple User',
      linkedMethods: {AuthMethod.apple},
      createdAt: DateTime.now(),
    );
    return AuthResult.success(user, _genJwt(user.userId));
  }

  @override
  Future<AuthResult> bindEmail({
    required String currentJwt,
    required String email,
    required String password,
  }) async {
    await _simDelay();
    if (_accounts.containsKey(email)) {
      return AuthResult.failure('该邮箱已被使用');
    }
    final userId = _decodeJwt(currentJwt);
    final fakeUser = AuthUser(
      userId: userId,
      email: email,
      displayName: email.split('@').first,
      linkedMethods: {AuthMethod.anonymous, AuthMethod.email},
      createdAt: DateTime.now(),
    );
    _accounts[email] = _MockAccount(password: password, user: fakeUser);
    return AuthResult.success(fakeUser, currentJwt);
  }

  @override
  Future<AuthUser?> me({required String jwt}) async {
    await _simDelay();
    final userId = _decodeJwt(jwt);
    return AuthUser(
      userId: userId,
      cdid: userId.startsWith('anon_') ? userId.substring(5) : null,
      linkedMethods: userId.startsWith('anon_')
          ? {AuthMethod.anonymous}
          : {AuthMethod.email},
      createdAt: DateTime.now(),
    );
  }

  Future<void> _simDelay() =>
      Future.delayed(const Duration(milliseconds: 400));
  String _genJwt(String userId) => 'mock.jwt.$userId.${DateTime.now().millisecondsSinceEpoch}';
  String _decodeJwt(String jwt) {
    final parts = jwt.split('.');
    if (parts.length >= 3) return parts[2];
    return 'unknown';
  }
}

class _MockAccount {
  final String password;
  final AuthUser user;
  _MockAccount({required this.password, required this.user});
}

// ════════════════════════════════════════════════════════════
// ECS：调真实后端 (后端就绪后切换)
// ════════════════════════════════════════════════════════════

class EcsAuthProvider implements AuthProvider {
  final String baseUrl;

  EcsAuthProvider({required this.baseUrl});

  // 真实实现待后端 API 完成后填充。
  // schema 见 docs/API_AUTH.md
  @override
  Future<AuthResult> signInAnonymously({required String cdid}) =>
      throw UnimplementedError('ECS auth 待后端就绪');

  @override
  Future<AuthResult> registerEmail({
    required String email,
    required String password,
    String? displayName,
    String? linkAnonymousJwt,
  }) =>
      throw UnimplementedError();

  @override
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) =>
      throw UnimplementedError();

  @override
  Future<AuthResult> signInWithGoogle({required String idToken}) =>
      throw UnimplementedError();

  @override
  Future<AuthResult> signInWithApple({
    required String identityToken,
    required String authorizationCode,
    String? nonce,
  }) =>
      throw UnimplementedError();

  @override
  Future<AuthResult> bindEmail({
    required String currentJwt,
    required String email,
    required String password,
  }) =>
      throw UnimplementedError();

  @override
  Future<AuthUser?> me({required String jwt}) => throw UnimplementedError();
}

// ════════════════════════════════════════════════════════════
// 主服务
// ════════════════════════════════════════════════════════════

class AuthService {
  static const String _boxName = 'auth';
  static const String _kJwt = 'jwt';
  static const String _kUserJson = 'user';
  static const String _kCdid = 'cdid';

  static AuthProvider _provider = MockAuthProvider();

  /// 当前用户（null = 未初始化）
  static final ValueNotifier<AuthUser?> currentUser =
      ValueNotifier<AuthUser?>(null);

  static Box? _box;

  static Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);
    // 恢复缓存的 user（不验证 JWT 有效性，启动时只展示，进入受保护操作时再 me() 验证）
    final cachedUserJson = _box!.get(_kUserJson) as String?;
    if (cachedUserJson != null) {
      try {
        currentUser.value =
            AuthUser.fromJson(jsonDecode(cachedUserJson) as Map<String, dynamic>);
      } catch (_) {}
    }
  }

  static String? get jwt => _box?.get(_kJwt) as String?;
  static bool get isSignedIn => currentUser.value != null;
  static bool get isAnonymous => currentUser.value?.isAnonymous ?? false;

  static void setProvider(AuthProvider p) {
    _provider = p;
  }

  /// 启动时调用：如果没有用户信息，自动匿名注册
  static Future<void> ensureAnonymous() async {
    if (currentUser.value != null) return;
    var cdid = _box?.get(_kCdid) as String?;
    if (cdid == null) {
      cdid = _genCdid();
      await _box?.put(_kCdid, cdid);
    }
    final r = await _provider.signInAnonymously(cdid: cdid);
    if (r.ok) await _persist(r);
  }

  static Future<AuthResult> registerEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final r = await _provider.registerEmail(
      email: email,
      password: password,
      displayName: displayName,
      linkAnonymousJwt: isAnonymous ? jwt : null,
    );
    if (r.ok) await _persist(r);
    return r;
  }

  static Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final r = await _provider.signInWithEmail(email: email, password: password);
    if (r.ok) await _persist(r);
    return r;
  }

  static Future<AuthResult> signInWithGoogle() async {
    // 真实集成时调 google_sign_in 包拿 id_token
    final r = await _provider.signInWithGoogle(idToken: 'mock-id-token');
    if (r.ok) await _persist(r);
    return r;
  }

  static Future<AuthResult> signInWithApple() async {
    // 真实集成时调 sign_in_with_apple 包
    final r = await _provider.signInWithApple(
      identityToken: 'mock-identity-token',
      authorizationCode: 'mock-code',
    );
    if (r.ok) await _persist(r);
    return r;
  }

  static Future<AuthResult> bindEmail({
    required String email,
    required String password,
  }) async {
    final j = jwt;
    if (j == null) return AuthResult.failure('未登录');
    final r = await _provider.bindEmail(
      currentJwt: j,
      email: email,
      password: password,
    );
    if (r.ok) await _persist(r);
    return r;
  }

  static Future<void> signOut() async {
    await _box?.delete(_kJwt);
    await _box?.delete(_kUserJson);
    currentUser.value = null;
    // 立即恢复匿名（开发体验更平滑）
    await ensureAnonymous();
  }

  static Future<void> _persist(AuthResult r) async {
    if (r.user == null || r.jwt == null) return;
    await _box?.put(_kJwt, r.jwt!);
    await _box?.put(_kUserJson, jsonEncode(r.user!.toJson()));
    currentUser.value = r.user;
  }

  static String _genCdid() {
    final ts = DateTime.now().millisecondsSinceEpoch.toRadixString(16);
    final r = (DateTime.now().microsecondsSinceEpoch * 2654435761) & 0xFFFFFFFF;
    return 'cdid-$ts-${r.toRadixString(16)}';
  }
}
