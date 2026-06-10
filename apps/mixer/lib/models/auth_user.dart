// 用户身份模型 - 对应 ECS auth 接口的用户结构。

import 'package:meta/meta.dart';

/// 已绑定的第三方登录方式
enum AuthMethod {
  /// 设备匿名 (CDID)
  anonymous,
  email,
  google,
  apple,
  wechat;

  String get labelZh => switch (this) {
        AuthMethod.anonymous => '匿名',
        AuthMethod.email => 'Email',
        AuthMethod.google => 'Google',
        AuthMethod.apple => 'Apple',
        AuthMethod.wechat => '微信',
      };
}

@immutable
class AuthUser {
  /// 服务器分配的稳定 ID（即使没绑邮箱也有）
  final String userId;

  /// 设备匿名 ID（同一设备稳定，可作为客服支持识别码）
  final String? cdid;

  /// 已绑定邮箱（绑定前为 null）
  final String? email;

  /// 显示名（昵称）
  final String? displayName;

  /// 头像 URL
  final String? avatarUrl;

  /// 已绑定的登录方式集合
  final Set<AuthMethod> linkedMethods;

  /// 是否仅匿名（即 linkedMethods == {anonymous}）
  bool get isAnonymous =>
      linkedMethods.length == 1 && linkedMethods.contains(AuthMethod.anonymous);

  /// 用户友好显示名
  String get displayLabel {
    if (displayName != null && displayName!.isNotEmpty) return displayName!;
    if (email != null) return email!;
    if (isAnonymous) return '匿名用户';
    return userId.substring(0, 6);
  }

  final DateTime createdAt;

  const AuthUser({
    required this.userId,
    this.cdid,
    this.email,
    this.displayName,
    this.avatarUrl,
    required this.linkedMethods,
    required this.createdAt,
  });

  AuthUser copyWith({
    String? email,
    String? displayName,
    String? avatarUrl,
    Set<AuthMethod>? linkedMethods,
  }) =>
      AuthUser(
        userId: userId,
        cdid: cdid,
        email: email ?? this.email,
        displayName: displayName ?? this.displayName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        linkedMethods: linkedMethods ?? this.linkedMethods,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'userId': userId,
        if (cdid != null) 'cdid': cdid,
        if (email != null) 'email': email,
        if (displayName != null) 'displayName': displayName,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
        'linkedMethods': linkedMethods.map((m) => m.name).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
        userId: j['userId'] as String,
        cdid: j['cdid'] as String?,
        email: j['email'] as String?,
        displayName: j['displayName'] as String?,
        avatarUrl: j['avatarUrl'] as String?,
        linkedMethods: ((j['linkedMethods'] as List?) ?? [])
            .map((s) => AuthMethod.values.firstWhere(
                  (m) => m.name == s,
                  orElse: () => AuthMethod.anonymous,
                ))
            .toSet(),
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

/// 登录 / 注册结果
@immutable
class AuthResult {
  final bool ok;
  final AuthUser? user;
  final String? jwt;
  final String? error;

  const AuthResult({required this.ok, this.user, this.jwt, this.error});

  factory AuthResult.success(AuthUser user, String jwt) =>
      AuthResult(ok: true, user: user, jwt: jwt);

  factory AuthResult.failure(String error) =>
      AuthResult(ok: false, error: error);
}
