# API: 账号系统

> 后端待实现。mixer App 当前默认走 MockAuthProvider，所有登录/注册操作本地伪造。
> 后端按本文档实现 endpoints 后，Flutter 端在 `main.dart` 切换：
>
> ```dart
> AuthService.setProvider(EcsAuthProvider(baseUrl: 'https://api.diveplan.cn'));
> ```
>
> Flutter 端 service 框架：`apps/mixer/lib/services/auth_service.dart`。
> 数据模型：`apps/mixer/lib/models/auth_user.dart`。

---

## 设计原则

1. **每个设备开 App 就有账号**：首次启动自动调 `/anonymous` 注册匿名账号，本地存 CDID + JWT。**用户无感知**。
2. **匿名 → 实名"无缝升级"**：用户后期注册邮箱时把 CDID 带上，后端把匿名账号"实名化"——历史/设置全部继承，userId 不变。
3. **一个 user 多种登录方式**：同一个邮箱、Google、Apple 都可以绑同一 user，登录任一方式都进同一账号。
4. **匿名账号也算正式账号**：客服可以按 CDID 查所有数据；errors / history 都关联到 userId。

---

## 数据模型

### users 表

```sql
CREATE TABLE users (
  id BIGSERIAL PRIMARY KEY,
  user_id VARCHAR(64) UNIQUE NOT NULL,    -- 'anon_xxx' / 'usr_xxx' 前端展示用
  cdid VARCHAR(64) UNIQUE,                -- 设备匿名 ID（同设备稳定）
  email VARCHAR(255) UNIQUE,              -- 绑邮箱后填
  display_name VARCHAR(64),
  avatar_url TEXT,
  password_hash VARCHAR(255),             -- bcrypt，仅邮箱注册有
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX idx_users_cdid ON users(cdid);
CREATE INDEX idx_users_email ON users(email);
```

### user_auth_methods 表

一个 user 可以绑多个第三方登录方式：

```sql
CREATE TABLE user_auth_methods (
  id BIGSERIAL PRIMARY KEY,
  user_id BIGINT REFERENCES users(id) ON DELETE CASCADE,
  method VARCHAR(16) NOT NULL,            -- 'anonymous' / 'email' / 'google' / 'apple'
  provider_user_id VARCHAR(255),          -- Google sub / Apple sub / null (for email/anon)
  email VARCHAR(255),                     -- 三方账号关联的邮箱（仅展示）
  linked_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(method, provider_user_id)
);
CREATE INDEX idx_uam_user_id ON user_auth_methods(user_id);
```

### JWT payload

```json
{
  "sub": "usr_xxx",     // user_id（前端展示用）
  "uid": 12345,         // users.id（数据库主键）
  "cdid": "cdid-xxx",   // 仍持有设备匿名 ID（客服查问题用）
  "iat": 1717000000,
  "exp": 1719592000     // 30 天
}
```

---

## Endpoints

### `POST /api/auth/anonymous`

匿名注册或恢复。**首次开 App 必调**。

请求：

```json
{ "cdid": "cdid-abc-123" }
```

逻辑：
- 如果 `cdid` 已存在 users 表 → 返回该 user
- 否则新建 user_id=`anon_xxx`，cdid=入参，linked_methods=`{anonymous}`

响应：

```json
{
  "ok": true,
  "data": {
    "user": { ... },
    "jwt": "eyJ..."
  }
}
```

---

### `POST /api/auth/email/register`

Email + 密码注册。如果当前已是匿名用户（headers 带 JWT），自动升级。

请求：

```json
{
  "email": "you@example.com",
  "password": "min8chars",
  "displayName": "可选昵称"
}
```

Header（可选）：

```
Authorization: Bearer <匿名 JWT>
```

逻辑：
- 如果 email 已注册 → 400 `EMAIL_EXISTS`
- 如果 header 带匿名 JWT：
  - **升级匿名账号**：更新该 user 的 email/password_hash/display_name
  - linked_methods 加 'email'，**保留 'anonymous'**（历史关联仍有效）
- 否则新建 user（无 cdid）
- 返回 user + 新 JWT

---

### `POST /api/auth/email/login`

请求：

```json
{ "email": "...", "password": "..." }
```

逻辑：
- 验密码 → 返回 user + JWT
- 失败：400 `INVALID_CREDENTIALS`

---

### `POST /api/auth/google/login`

请求：

```json
{ "idToken": "eyJ...Google id_token..." }
```

逻辑：
1. 验 idToken 签名（用 Google JWKS）
2. 解出 `sub`（Google user id）+ `email`
3. 查 user_auth_methods (method='google', provider_user_id=sub)：
   - 命中 → 返回对应 user + JWT
   - 没命中：
     - 如果 header 带 JWT → 绑到当前 user
     - 否则按 email 查 users：命中就绑、没命中就新建
4. 返回 user + JWT

---

### `POST /api/auth/apple/login`

请求：

```json
{
  "identityToken": "eyJ...",
  "authorizationCode": "...",
  "nonce": "可选"
}
```

逻辑同 Google，验 Apple JWT 签名（用 Apple JWKS）。

⚠️ Apple 的 `email` 可能是 `xxx@privaterelay.appleid.com`（私有中继），后续邮件要发给该地址才能转发。

---

### `POST /api/auth/bind`

绑定额外登录方式到当前账号（需要登录态）。

Header：

```
Authorization: Bearer <JWT>
```

请求（绑邮箱）：

```json
{
  "method": "email",
  "email": "...",
  "password": "..."
}
```

请求（绑 Google）：

```json
{
  "method": "google",
  "idToken": "..."
}
```

逻辑：
- 把 method/provider 加到 user_auth_methods
- 如果该 method 已被其它 user 占用 → 400 `ALREADY_LINKED_TO_ANOTHER`

---

### `GET /api/auth/me`

拉自己信息。

Header：`Authorization: Bearer <JWT>`

响应：

```json
{
  "ok": true,
  "data": {
    "user": {
      "userId": "usr_xxx",
      "cdid": "cdid-xxx",
      "email": "you@example.com",
      "displayName": "...",
      "avatarUrl": "...",
      "linkedMethods": ["anonymous", "email"],
      "createdAt": "2026-06-01T12:00:00Z"
    }
  }
}
```

---

### `POST /api/auth/refresh`

JWT 续期（在 30 天有效期内）。

请求：`Authorization: Bearer <旧 JWT>`

响应：返回新 JWT（旧的可以并存或立即失效，看后端策略）。

---

### `POST /api/auth/logout`

清除服务端 session（如果有）。Flutter 端不强依赖（删本地 token 即可）。

---

## 错误码

| code | HTTP | 含义 |
|---|---|---|
| `EMAIL_EXISTS` | 400 | 邮箱已注册 |
| `INVALID_CREDENTIALS` | 400 | 邮箱/密码错误 |
| `ALREADY_LINKED_TO_ANOTHER` | 400 | 该三方账号已绑到其它 user |
| `INVALID_TOKEN` | 401 | JWT 过期 / 签名无效 |
| `INVALID_OAUTH_TOKEN` | 400 | Google / Apple token 验证失败 |
| `RATE_LIMIT_EXCEEDED` | 429 | 频繁登录尝试 |

---

## Flutter 端集成

### 当前阶段（Mock 模式）

`apps/mixer/lib/services/auth_service.dart` 默认 `MockAuthProvider`：

- 启动自动匿名登录
- 邮箱注册：本地内存账号库
- Google / Apple 直接 Mock 成功
- 所有数据 Hive 持久化

界面已实现：
- AppBar 账号 icon → AccountPage
- AccountPage：当前用户 + 已绑方式 chips + 绑定/退出按钮
- LoginPage：邮箱 / Google / Apple 三个按钮
- RegisterPage：邮箱 + 密码 + 昵称

### 后端就绪后切换

`main.dart`：

```dart
import 'services/auth_service.dart';

void main() async {
  ...
  AuthService.setProvider(EcsAuthProvider(baseUrl: 'https://api.diveplan.cn'));
  await AuthService.ensureAnonymous();
  ...
}
```

然后完成 `EcsAuthProvider` 类（目前全是 `UnimplementedError`）：

```dart
@override
Future<AuthResult> signInAnonymously({required String cdid}) async {
  final res = await http.post(
    Uri.parse('$baseUrl/api/auth/anonymous'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'cdid': cdid}),
  );
  final j = jsonDecode(res.body);
  if (j['ok'] == true) {
    return AuthResult.success(
      AuthUser.fromJson(j['data']['user']),
      j['data']['jwt'] as String,
    );
  }
  return AuthResult.failure(j['error'] as String? ?? 'unknown');
}
```

### Google / Apple 原生 SDK 集成

后端就绪后再加：

```yaml
# pubspec.yaml
dependencies:
  google_sign_in: ^6.2.1
  sign_in_with_apple: ^6.1.4
```

`auth_service.dart` 的 `signInWithGoogle()` 改成调 google_sign_in 拿 idToken 再上传后端。

---

## 安全

- **密码**：bcrypt cost ≥ 10，**永不**返回密码字段
- **JWT secret**：放 env，至少 256 位，每环境（dev/staging/prod）不同
- **Refresh token**：JWT 过期后用 refresh 续期，refresh token 单独存（DB 一表）
- **rate limit**：登录尝试 5 次/分钟/IP，超限锁 15 分钟
- **CSRF**：Bearer token 走 header，不依赖 cookie，天然无 CSRF
- **匿名升级时**：要验证 header 里的 anonymous JWT 跟入参 email 没冲突
