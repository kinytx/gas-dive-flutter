# iOS 一次性配置清单

> 你已是 Apple Developer 付费用户、Mac 在家。这份清单覆盖从「第一次跑通真机」到「上 App Store」的全部配置项。
>
> 建议第一次跑 `flutter create .` 之前先把 §1（Bundle ID）想清楚 —— 后期改名很麻烦（要重建 App ID、所有证书都要重发）。

---

## 1. Bundle ID 命名

### 1.1 命名规则

- 反向域名格式：`<TLD>.<organization>.<app>`
- 全小写，避免特殊字符
- 一旦上架就不能改

### 1.2 mixer 建议

| 用途 | Bundle ID |
|---|---|
| 主 App | `cn.diveplan.mixer` |
| Dev 版（同设备并存）| `cn.diveplan.mixer.dev` |
| Beta 版 | `cn.diveplan.mixer.beta` |

**重要**：mixer 跟 plan 用相同前缀 `cn.diveplan.*` 便于将来：

- App Groups 共享数据
- 统一管理 Push Notification Certs
- App Store Connect 里归同一个 organization

### 1.3 写入 Flutter 项目

跑 `flutter create .` 时直接指定：

```bash
flutter create . --org cn.diveplan --project-name mixer
```

生成的 `ios/Runner.xcodeproj/project.pbxproj` 里 `PRODUCT_BUNDLE_IDENTIFIER` 会是 `cn.diveplan.mixer`。

如果已经跑过 `flutter create`，要改 Bundle ID：

1. Xcode 打开 `ios/Runner.xcworkspace`
2. Runner → General → Identity → Bundle Identifier 改成 `cn.diveplan.mixer`
3. 同时改 Build Phases → 所有 target 的 Bundle ID

---

## 2. Apple Developer 后台一次性配置

> https://developer.apple.com/account

### 2.1 注册 App ID

1. Certificates, Identifiers & Profiles → Identifiers → ➕
2. App IDs → App
3. Description: `Dive Gas Mixer`
4. Bundle ID: `Explicit` → `cn.diveplan.mixer`
5. Capabilities 勾选（按需开，可后期改）：
   - **Push Notifications** ✅（保养提醒等用得到）
   - **Background Modes** ✅（蓝牙下载用）
   - **Associated Domains** ✅（如果做 Universal Links 跳转）
   - **Sign in with Apple** ✅（iOS 强制：如果 App 有微信/Google 等第三方登录，必须同时提供 Sign in with Apple）
   - **HealthKit** ❌（mixer 不需要，潜水 plan 才用）
   - **NFC Tag Reading** ✅（未来气瓶 NFC 标签预留）
   - **Bluetooth LE** ✅（潜水电脑下载）
6. Continue → Register

### 2.2 创建开发证书 + Profile（Xcode 自动管理）

最省事：让 Xcode 自动管理（推荐）

- Xcode → Runner → Signing & Capabilities
- ☑️ **Automatically manage signing**
- Team 选你的开发者团队
- Xcode 会自动创建 Development Certificate + Provisioning Profile

如果要手工管理（CI/CD 等场景）：

- Apple Developer → Certificates → ➕ → Apple Distribution（发布用）
- Profiles → ➕ → iOS App Development（开发用）+ App Store（上架用）

### 2.3 App Store Connect 新建 App 记录

https://appstoreconnect.apple.com/

1. My Apps → ➕ → New App
2. Platforms: iOS
3. Name: `Dive Gas Mixer` （这是上架展示名，可以中文）
4. Primary Language: 简体中文
5. Bundle ID 选 `cn.diveplan.mixer`（必须先在 §2.1 注册过）
6. SKU: `dive-mixer-001`（自己起，不展示，唯一即可）
7. User Access: Full Access

---

## 3. Xcode 项目配置（Signing & Capabilities）

跑完 `flutter create .` 后 Xcode 打开 `apps/mixer/ios/Runner.xcworkspace`：

### 3.1 Signing 区

- ☑️ Automatically manage signing
- Team: 你的 Apple Developer Team
- Bundle Identifier: `cn.diveplan.mixer`

### 3.2 Capabilities（➕ Capability 按钮加）

为 mixer 预备：

| Capability | 何时需要 | 配置 |
|---|---|---|
| **Background Modes** | 蓝牙下载潜水电脑日志 | 勾 `Uses Bluetooth LE accessories` |
| **Push Notifications** | 保养提醒、客户通知 | 无需额外配置，开了即可 |
| **Sign in with Apple** | 上架前必须（如有第三方登录）| 无配置 |
| **NFC Tag Reading** | 未来气瓶标签 | 无配置 |
| **App Groups** | 跟未来 plan App 共享数据 | 创建 `group.cn.diveplan.shared` |
| **Associated Domains** | Universal Links | 加 `applinks:diveplan.cn` |

### 3.3 Deployment Target

- Runner → General → Minimum Deployments → iOS 13.0 以上推荐
- iOS 13 覆盖率已 95%+，flutter_blue_plus 等 BLE 库都要求 iOS 13+

---

## 4. Info.plist 权限描述

iOS 强制要求：任何用到敏感能力的 App 必须在 `Info.plist` 写**用户可见的中文说明**，否则审核被打回。

**位置**：`apps/mixer/ios/Runner/Info.plist`

**预备好的权限描述**（按需启用，未来加功能时取消注释）：

```xml
<!-- 蓝牙：连接潜水电脑、气分仪等设备 -->
<key>NSBluetoothAlwaysUsageDescription</key>
<string>用于连接潜水电脑下载日志、连接气分仪读取实测气体浓度</string>

<key>NSBluetoothPeripheralUsageDescription</key>
<string>用于连接潜水电脑下载日志</string>

<!-- 相机：气瓶标签 OCR、潜水照片 -->
<key>NSCameraUsageDescription</key>
<string>用于扫描气瓶标签、识别水生生物</string>

<!-- 相册（保存计算结果、读潜水照片识别物种）-->
<key>NSPhotoLibraryUsageDescription</key>
<string>用于读取潜水照片识别生物</string>

<key>NSPhotoLibraryAddUsageDescription</key>
<string>用于保存潜水计划图到相册</string>

<!-- 位置：潜点天气、附近设施、海洋定位 -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>用于获取附近潜点的天气、潮汐、附近设施信息</string>

<!-- NFC：气瓶标签（未来）-->
<key>NFCReaderUsageDescription</key>
<string>用于读取气瓶上的 NFC 识别标签</string>

<!-- 麦克风：暂不用，留空。如果将来做语音备注潜水日志再开 -->

<!-- Face ID / Touch ID：子账号鉴权（潜店）-->
<key>NSFaceIDUsageDescription</key>
<string>用于潜店员工身份验证</string>

<!-- 本地网络：发现局域网设备（如果做填充站联机）-->
<key>NSLocalNetworkUsageDescription</key>
<string>用于发现局域网内的填充站设备</string>
```

**关键原则**：

- 描述要**明确具体**说用途，不要写"用于 App 功能"这种含糊的，会被打回
- 一定要用**中文**（如果 App 中文为主语言）
- 没用到的能力**不要**加，多加无用 key 会触发审核员问询

---

## 5. Runner.entitlements（如果用到 §3.2 的 Capabilities）

Xcode 加 Capability 时会自动生成 `apps/mixer/ios/Runner/Runner.entitlements`，大概长这样：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
        "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- 蓝牙后台保活 -->
    <key>UIBackgroundModes</key>
    <array>
        <string>bluetooth-central</string>
        <string>fetch</string>
    </array>

    <!-- 推送通知 -->
    <key>aps-environment</key>
    <string>development</string>  <!-- release 时改为 production -->

    <!-- App Groups -->
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.cn.diveplan.shared</string>
    </array>
</dict>
</plist>
```

---

## 6. 蓝牙特殊配置（蓝牙是 mixer 长期最关键的能力）

### 6.1 Info.plist 蓝牙后台模式

```xml
<key>UIBackgroundModes</key>
<array>
    <string>bluetooth-central</string>   <!-- 后台保持 BLE 连接 -->
    <string>bluetooth-peripheral</string> <!-- 不用 -->
</array>
```

⚠️ Apple 审核会问：**为什么需要蓝牙后台？** 准备好回答：「**因为下载潜水电脑日志需要 5-20 分钟，用户可能锁屏 / 切到其它 App。**」

### 6.2 iOS 13+ Background BLE 限制

- 后台**主动扫描**：必须知道目标设备的 Service UUID（不能扫所有）
- 后台**保持连接**：已配对设备可以保持
- 后台**唤醒**：BLE 设备发 notify 时系统会唤醒 App 处理（短时间窗口）

实战上，针对潜水电脑：

- 用户在前台手动启动连接 + 下载
- 下载过程中切到后台/锁屏：保持连接继续下载（用 background mode）
- 用户切回 App 看进度

flutter_blue_plus 的后台支持文档：https://pub.dev/packages/flutter_blue_plus#background-bluetooth

---

## 7. 第一次上架 App Store 流程

> 当 P5 阶段（约 3-4 个月后）需要上架时用。

### 7.1 准备物料

- App 图标：1024×1024 PNG（无圆角，无透明）
- 截图：iPhone 6.5"（1284×2778 或 1290×2796）至少 3 张
- 描述：中文 + 英文
- 关键词：100 字以内
- 隐私政策 URL：必须有（mixer 已有 plan/about-detail 页相关内容）
- 支持 URL：联系方式

### 7.2 提交流程

```bash
# 1. Mac 上构建 release ipa
cd apps/mixer
flutter build ipa --release

# 2. 用 Transporter App 上传 .ipa 到 App Store Connect
# Transporter: Mac App Store 免费下载
# 或用 Xcode → Product → Archive → Distribute App

# 3. App Store Connect → 你的 App → TestFlight
# 内部测试组：邀请你自己的 Apple ID 测试
# 测试 OK 后 → 提交审核

# 4. App Store Connect → App Store → 准备提交
# 填截图、描述、隐私、定价 → 提交
```

### 7.3 审核常见被打回理由（潜水类 App）

1. **「免责声明不够明显」** → 在启动页 / 关于页加显眼免责
2. **「医疗建议风险」** → 强调"仅供参考，请遵循认证机构标准"
3. **「蓝牙后台用途说明不足」** → 在 Info.plist 描述里写具体
4. **「Sign in with Apple 缺失」** → 如有第三方登录必须加
5. **「无可测试的演示内容」** → 准备测试账号交给审核员

---

## 8. 时间线建议

| 阶段 | 时机 | 动作 |
|---|---|---|
| **P0**（当前）| 现在 | §1 想清楚 Bundle ID，跑 `flutter create . --org cn.diveplan --project-name mixer` |
| **P1**（混气主页完成）| 1-2 周后 | Mac 上跑通 `flutter run` 真机调试 |
| **P2**（设置/关于完成）| 4-6 周后 | §2 注册 App ID + §3 Capabilities + §4 Info.plist 必要权限 |
| **P3**（ECS 接入完成）| 6-8 周后 | §2.3 App Store Connect 建 App 记录 + TestFlight 内测 |
| **P4**（蓝牙模块完成）| 10-14 周后 | §6 蓝牙特殊配置 + 后台模式联调 |
| **P5**（首次上架）| 16-20 周后 | §7 提交审核 |

---

## 9. 备份建议

Apple Developer 后台几样东西**丢了重发很麻烦**，建议异地备份：

- **私钥 .p12 文件**（开发证书 + 分发证书）—— 备份到 1Password / iCloud Keychain
- **Provisioning Profile** —— 可以重发，但建议存档
- **App-Specific Password**（用于 Transporter 上传）—— 用一次性强密码

---

## 10. 速查清单

跑 `flutter create .` 之后的最小可跑 iOS 真机检查：

- [ ] Bundle ID 是 `cn.diveplan.mixer`（不是默认的 `com.example.mixer`）
- [ ] Xcode → Signing & Capabilities → Team 已选
- [ ] iPhone 已 USB 连接 + 信任此电脑
- [ ] Xcode → Window → Devices and Simulators 看到 iPhone
- [ ] `flutter devices` 列出你的 iPhone
- [ ] `flutter run -d <你的 iPhone>` 跑通

跑通后 iPhone 上看到 mixer App 图标 + 启动后看到主页 = ✅
