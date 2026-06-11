# API: 账号与鉴权

> 状态：后端已在 ECS 落地。本文按 `gas-dive-server` 当前实现整理，供 Flutter 端接入。
>
> Base URL：`https://api.diveplan.cn`
>
> Flutter 端服务建议仍放在 `apps/mixer/lib/services/auth_service.dart`，数据模型仍可放在 `apps/mixer/lib/models/auth_user.dart`。

---

## 当前后端模型

后端用户主键是 `Guid`，不是旧文档里的自增 `BIGSERIAL`。

核心表：

- `users`：一个真人账号一行。
- `user_identities`：一个账号可绑定多种登录方式。
- `email_verification_tokens`：邮箱验证码。
- `user_action_tokens`：高风险操作的临时授权 token。

当前 provider：

| provider | 用途 |
|---|---|
| `email` | 邮箱 + 密码 |
| `wechat_openid` | 微信小程序登录，区分 `app=dive/gas` |
| `wechat_unionid` | 微信开放平台 unionid |
| `wechat_web_openid` | Web 微信 OAuth 无 unionid 时兜底 |
| `google` | Web Google OAuth |
| `facebook` | Web Facebook OAuth |

暂未实现旧文档中的：

- `POST /api/auth/email/register`
- `POST /api/auth/email/login`
- `POST /api/auth/google/login` 直接上传 `idToken`
- `POST /api/auth/apple/login`
- `POST /api/auth/refresh`
- `POST /api/auth/logout`

---

## 鉴权方式

普通接口使用 Bearer JWT：

```http
Authorization: Bearer <jwt>
```

服务端 `AuthMiddleware` 解析顺序：

1. `x-wx-openid` / `x-wx-appid`，兼容微信云托管注入。
2. `Authorization: Bearer <jwt>`。
3. `X-Api-Key: dpk_...`。
4. 都没有则匿名继续，带 `[RequireUser]` 的接口返回 `401`。

WebSocket 也支持：

```text
wss://api.diveplan.cn/ws/dc-bridge?access_token=<jwt>
```

如果服务端开启 `AUTH_SESSION_TOKEN_REQUIRED=true`，部分写接口会额外要求临时 token：

```http
X-DivePlan-Session-Token: <sessionToken>
```

收到 `403 { "error": "session_token_required" }` 时，Flutter 端需要先调用 `/api/me/action-tokens` 获取临时 token，再重试原请求。

## 无感匿名账号流程

Flutter 首次启动时生成稳定 CDID，保存到安全存储，然后调用匿名登录接口。这个账号是正式 `users` 记录，历史混气、草稿、装备 OCR、潜水日志暂存都可以先挂在这个 userId 下。

### 匿名登录 / 恢复

`POST /api/auth/anonymous`

```json
{
  "cdid": "flutter-device-uuid-or-install-id",
  "sourceApp": "gas-flutter"
}
```

响应：

```json
{
  "token": "eyJ...",
  "userId": "4b8e4b8c-..."
}
```

后端逻辑：

1. 用 `cdid` 查 `user_identities(provider='anonymous_device')`。
2. 命中则复用原 userId，并刷新 `last_login_at`。
3. 未命中则创建 `users` + `anonymous_device` identity。
4. 返回 JWT。

Flutter 端要求：

- CDID 首次生成后必须稳定保存，不要每次启动重建。
- 推荐使用 `flutter_secure_storage`。
- 如果用户卸载 App，CDID 可能丢失；这类情况后续可以通过邮箱/微信登录找回正式账号。

### 匿名升级为邮箱账号

用户在匿名态注册邮箱时，请带当前匿名 JWT：

```http
Authorization: Bearer <anonymous jwt>
```

然后调用：

`POST /api/auth/register`

```json
{
  "email": "you@example.com",
  "password": "min8chars",
  "code": "123456"
}
```

如果当前 JWT 对应账号只有 `anonymous_device` identity，后端会在同一个 userId 上新增 `email` identity。也就是说：

- userId 不变
- 历史数据不迁移，天然保留
- 匿名 identity 继续保留，可用于同设备恢复

如果当前 JWT 已经是邮箱/微信等正式账号，则注册会创建新账号或返回邮箱冲突，具体按邮箱是否已注册判断。

---

## 邮箱登录流程

### 发送验证码

`POST /api/auth/send-code`

```json
{
  "email": "you@example.com",
  "purpose": "register"
}
```

`purpose` 支持：

- `register`
- `reset_password`
- `change_email`

响应：

```json
{
  "expiresInSec": 600
}
```

常见错误：

- `400 invalid_purpose`
- `429 too_frequent`

### 注册

`POST /api/auth/register`

```json
{
  "email": "you@example.com",
  "password": "min8chars",
  "code": "123456"
}
```

响应：

```json
{
  "token": "eyJ...",
  "userId": "4b8e4b8c-..."
}
```

常见错误：

- `400 invalid_or_expired_code`
- `409 email_already_registered`

### 登录

`POST /api/auth/login`

```json
{
  "email": "you@example.com",
  "password": "min8chars"
}
```

响应同注册：

```json
{
  "token": "eyJ...",
  "userId": "4b8e4b8c-..."
}
```

错误：

- `401 invalid_credentials`

### 重置密码

先 `send-code`，`purpose=reset_password`。

`POST /api/auth/reset-password`

```json
{
  "email": "you@example.com",
  "code": "123456",
  "newPassword": "new-min8chars"
}
```

成功响应为空 body 或 `{}`，以 HTTP 2xx 为准。

---

## 微信登录

### 微信小程序

`POST /api/auth/wechat/login`

```json
{
  "app": "gas",
  "code": "wx.login 返回的 code"
}
```

`app` 可选：

- `gas`
- `dive`

响应：

```json
{
  "token": "eyJ...",
  "userId": "4b8e4b8c-..."
}
```

Flutter App 如果不是微信小程序环境，不能直接使用 `wx.login()`，需要后续接微信开放平台原生 SDK 后再单独补移动端 OAuth 流程。

### Web 微信 OAuth

`POST /api/auth/wechat/web-login`

```json
{
  "code": "微信 Web OAuth code"
}
```

这是 Web 授权回调后使用的接口，不是 Flutter 原生 SDK 的完整流程。

---

## Web OAuth

当前 Google / Facebook 是浏览器跳转 OAuth，不是移动端直接提交 token。

### Google

```http
GET /api/auth/oauth/google/start?returnUrl=https://www.diveplan.cn/account
```

后端完成 OAuth callback 后，会重定向到 `returnUrl`，并在 hash 中附带：

```text
#oauthToken=<jwt>&userId=<guid>
```

### Facebook

```http
GET /api/auth/oauth/facebook/start?returnUrl=https://www.diveplan.cn/account
```

返回方式同 Google。

Flutter 原生 Google / Apple 登录要另开接口时，建议后端新增：

- `POST /api/auth/google/login`，body: `{ "idToken": "..." }`
- `POST /api/auth/apple/login`，body: `{ "identityToken": "...", "authorizationCode": "...", "nonce": "..." }`

---

## 当前用户接口

### 拉取自己

`GET /api/me`

Header：

```http
Authorization: Bearer <jwt>
```

响应：

```json
{
  "id": "4b8e4b8c-...",
  "displayName": "昵称",
  "isAdmin": false,
  "isSuperAdmin": false,
  "createdAt": "2026-06-01T12:00:00Z",
  "identities": [
    {
      "id": "91d2...",
      "provider": "email",
      "providerUid": "you@example.com",
      "isVerified": true,
      "lastLoginAt": "2026-06-11T09:00:00Z"
    }
  ]
}
```

### 已绑定登录方式

`GET /api/me/identities`

响应是 `IdentitySummary[]`。

### 解绑登录方式

`DELETE /api/me/identities/{id}`

不允许解绑最后一种登录方式。

错误：

- `404 identity_not_found`
- `400 cannot_unbind_last_identity`

### 改密码

`PUT /api/me/password`

```json
{
  "oldPassword": "old",
  "newPassword": "new-min8chars"
}
```

### 改邮箱

先 `POST /api/auth/send-code`，`purpose=change_email`，发到新邮箱。

`PUT /api/me/email`

```json
{
  "newEmail": "new@example.com",
  "code": "123456"
}
```

### 注销账号

`DELETE /api/me`

后端软删 `users`，删除 identities，并撤销 API keys。

---

## 临时操作 token

高风险接口可能需要 action token。

`POST /api/me/action-tokens`

```json
{
  "scope": "shop-write",
  "expiresInSeconds": 900
}
```

响应字段以服务端为准，Flutter 端只需要保存 token，并在后续请求带：

```http
X-DivePlan-Session-Token: <token>
```

如果调用业务接口收到：

```json
{
  "error": "session_token_required",
  "message": "Temporary session token required"
}
```

处理策略：

1. 请求 `/api/me/action-tokens`。
2. 把返回 token 存到内存或 session storage 等短期存储。
3. 重试原请求。

---

## Flutter 接入建议

### Token 存储

推荐使用 `flutter_secure_storage` 存：

- `diveplan.jwt`
- `diveplan.userId`

内存中保留一份当前 token，所有 API request 自动加：

```dart
headers['Authorization'] = 'Bearer $token';
```

收到 `401`：

1. 清本地 token。
2. 切回未登录态。
3. 引导用户重新登录。

当前后端没有 refresh token，不能静默续期。

### AuthProvider 最小实现

```dart
class EcsAuthProvider implements AuthProvider {
  EcsAuthProvider({required this.baseUrl});

  final String baseUrl;

  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (res.statusCode == 200) {
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      return AuthResult.success(
        AuthUser(id: j['userId'] as String, email: email),
        j['token'] as String,
      );
    }
    return AuthResult.failure(readError(res));
  }

  Future<AuthResult> registerWithEmail({
    required String email,
    required String password,
    required String code,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password, 'code': code}),
    );
    if (res.statusCode == 200) {
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      return AuthResult.success(
        AuthUser(id: j['userId'] as String, email: email),
        j['token'] as String,
      );
    }
    return AuthResult.failure(readError(res));
  }
}
```

`sendCode` 建议单独暴露：

```dart
Future<void> sendEmailCode(String email, String purpose) async {
  final res = await http.post(
    Uri.parse('$baseUrl/api/auth/send-code'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'email': email, 'purpose': purpose}),
  );
  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw Exception(readError(res));
  }
}
```

### API Client 重试 session token

伪代码：

```dart
Future<http.Response> authedRequest(Future<http.Response> Function(Map<String, String> headers) send) async {
  final headers = {
    'Authorization': 'Bearer $jwt',
    'Content-Type': 'application/json',
    if (sessionToken != null) 'X-DivePlan-Session-Token': sessionToken!,
  };
  var res = await send(headers);
  if (res.statusCode == 403 && res.body.contains('session_token_required')) {
    sessionToken = await issueActionToken(scope: 'auth-session');
    headers['X-DivePlan-Session-Token'] = sessionToken!;
    res = await send(headers);
  }
  return res;
}
```

---

## 错误码速查

| code | HTTP | 含义 |
|---|---:|---|
| `unauthenticated` | 401 | 需要登录 |
| `invalid_credentials` | 401 | 邮箱或密码错误 |
| `invalid_or_expired_code` | 400 | 验证码错误或过期 |
| `email_already_registered` | 409 | 邮箱已注册 |
| `email_not_found` | 404 | 找不到邮箱 |
| `too_frequent` | 429 | 验证码发送太频繁 |
| `session_token_required` | 403 | 需要临时操作 token |
| `forbidden_not_admin` | 403 | 需要管理员 |
| `forbidden_not_super_admin` | 403 | 需要超级管理员 |

---

## 安全约束

- 密码哈希由后端 `IPasswordHasher` 处理，客户端永不保存明文密码。
- JWT 只存安全存储，不写普通日志。
- 不在 crash log、analytics、debug toast 中输出 token。
- 当前后端 JWT 没有 refresh token，401 后必须重新登录。
- 管理员、店铺写操作、装备批量管理等接口可能需要 action token。
