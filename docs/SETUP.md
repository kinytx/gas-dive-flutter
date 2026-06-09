# 本地开发环境搭建指南

> 目标：Windows 开发 + 调试 Android；Mac 开发 + 调试 iOS。
> 团队配置：你在 Windows 上日常开发；iOS 发布前借/买一台 Mac 跑编译 + 上架。

---

## 0. 心理预期

| 任务 | Windows | macOS | Linux |
|---|---|---|---|
| Flutter SDK 安装 | ✅ | ✅ | ✅ |
| Dart 语法检查 / 单测 | ✅ | ✅ | ✅ |
| Android 模拟器 / 真机调试 | ✅ | ✅ | ✅ |
| iOS 模拟器 | ❌ | ✅（必须）| ❌ |
| iOS 真机调试 | ❌ | ✅ | ❌ |
| iOS 编译 + 上 App Store | ❌ | ✅（必须）| ❌ |
| 写 Dart / UI 代码 | ✅ | ✅ | ✅ |

🔑 **关键**：Windows 上你能完成 90% 的日常开发；只是最后 iOS 编译 + 上架那一步必须借 Mac。

---

## 1. Windows 端安装步骤

### 1.1 装 Flutter SDK（10-15 分钟）

1. 下载：访问 https://docs.flutter.dev/install/windows 下载最新稳定版（Flutter 3.x 当前）
2. 解压到 `C:\src\flutter\`（避免放 `C:\Program Files\`，权限麻烦）
3. 把 `C:\src\flutter\bin` 加到系统 **PATH** 环境变量
   - Win 开始菜单搜「环境变量」→ 编辑系统环境变量 → 环境变量 → PATH → 新建
4. 验证：开新 PowerShell 跑 `flutter --version`，应输出版本号
5. 跑 `flutter doctor`，看缺什么；下面几步是补齐它报的问题

### 1.2 装 Android Studio + Android SDK（30 分钟，含下载）

1. 下载：https://developer.android.com/studio
2. 安装时默认勾「Android SDK」「Android SDK Platform」「Android Virtual Device」
3. 装好后打开 Android Studio：
   - **More Actions → SDK Manager**：勾上 **Android SDK Command-line Tools**（Flutter 必需）
   - **More Actions → Virtual Device Manager**：创建一个 Pixel 7 模拟器（API 34 / Android 14）
4. 装 Flutter 插件：
   - Android Studio → Settings → Plugins → 搜「Flutter」→ Install
   - 装好会自动连带装 Dart 插件
5. 接受 Android licenses（一次性）：
   ```powershell
   flutter doctor --android-licenses
   ```
   一路按 `y`

### 1.3 装 VS Code（可选，但强烈推荐用作日常编辑器）

1. 下载 https://code.visualstudio.com/
2. 装两个插件：
   - **Flutter** by Dart Code（必装）
   - **Dart** by Dart Code（自动随 Flutter 装上）
3. 设置：Ctrl+, → 搜 `dart.flutterSdkPath`，填 `C:\src\flutter`

### 1.4 验收

```powershell
flutter doctor
```

期望看到这些全 ✅：

```
[✓] Flutter (Channel stable, 3.x.x, on Microsoft Windows ...)
[✓] Windows Version (Installed version of Windows is ...)
[✓] Android toolchain - develop for Android devices (Android SDK version 34.0.0)
[✓] Chrome - develop for the web
[✓] Visual Studio - develop Windows apps  ← 可选，做桌面端才需要
[✓] Android Studio (version 2024.x)
[✓] VS Code (version 1.x)
[✓] Connected device (n available)
[✓] Network resources
```

`!` 警告可以暂时忽略；`✗` 必须解决。

### 1.5 跑第一个项目（验证）

```powershell
cd C:\
mkdir flutter_test
cd flutter_test
flutter create hello_world
cd hello_world
flutter run        # 选 Android 模拟器
```

应该看到一个计数器 demo。

---

## 2. Mac 端（iOS 编译）

**你的情况**：Mac 在家、已是 Apple Developer 付费用户（$99/年）。这意味着：

- 不用走"免费账号每 7 天重签"的麻烦
- 可以直接 TestFlight 内测、推送通知、上 App Store
- iOS 真机调试时长不限

接下来 Mac 上需要装的东西，跟 Windows 完全是两套，但你可以**两台机器同步开发**（Windows 主写代码 + Mac 仅做 iOS 编译/上架，见 §2.6）。

### 2.1 Mac 环境硬件要求

- macOS 13 Ventura 或更新
- Apple Silicon（M1+）或 Intel Mac
- 至少 50GB 可用空间（Xcode 装下来 30GB+）

### 2.2 装 Xcode（必须，1-2 小时含下载）

1. App Store 搜 **Xcode** 直接装（10+ GB 下载，慢）
2. 装完打开一次，接受 license：
   ```bash
   sudo xcodebuild -license
   ```
3. 装 CocoaPods（iOS 依赖管理）：
   ```bash
   sudo gem install cocoapods
   ```
4. 装 command-line tools：
   ```bash
   xcode-select --install
   ```

### 2.3 装 Flutter SDK（Mac）

```bash
# 用 Homebrew（简单）
brew install --cask flutter

# 或手工下载
# https://docs.flutter.dev/install/macos
```

### 2.4 验收

```bash
flutter doctor
```

期望看到：

```
[✓] Flutter (Channel stable, 3.x.x, on macOS ...)
[✓] Android toolchain - ...     ← Mac 上也可以同时开发 Android
[✓] Xcode - develop for iOS and macOS (Xcode 15.x)
[✓] Chrome - develop for the web
[✓] Android Studio (version 2024.x)
[✓] VS Code (version 1.x)
[✓] Connected device (1 available)
[✓] Network resources
```

### 2.5 iOS 真机调试

你已是付费开发者，直接：

1. Xcode → Settings → Accounts → Add Apple ID → 用你的开发者账号登录
2. 在 Xcode 里打开项目（`apps/mixer/ios/Runner.xcworkspace`，注意是 **.xcworkspace 不是 .xcodeproj**）
3. Project → Runner → Signing & Capabilities → Team 选你的 Apple Developer Team
4. iPhone 连 USB → 选设备 → ▶️ Run

第一次跑会让 iPhone「信任此开发者」：iPhone → 设置 → 通用 → VPN 与设备管理 → 信任你的 Apple ID。

签名 + 上 App Store 的完整一次性配置：见 [`IOS_CONFIG.md`](IOS_CONFIG.md)。

### 2.6 双机协作 git workflow

推荐 Windows 主开发 + Mac 仅做 iOS 编译/上架的工作流：

**Windows 端**（日常）：

```powershell
# 写 Dart 代码 + Android 验证 + 跑 dart test
git add . && git commit -m "feat: ..."
git push
```

**Mac 端**（需要 iOS 编译 / 上架时回家做）：

```bash
git pull
cd apps/mixer
flutter pub get        # 拉新依赖
flutter run -d iPhone  # 或在 Xcode 里 ▶️ Run
# 上架前
flutter build ipa --release
# 用 Transporter App 上传 .ipa 到 App Store Connect
```

**几个会绊住你的坑**：

- **iOS Pods 不在 git 里**：`apps/mixer/ios/Pods/` 和 `Podfile.lock` 在 `.gitignore` 里。每次拉新代码后 Mac 上要跑 `cd ios && pod install`（其实 `flutter pub get` 通常会自动跑）。
- **行尾换行**：Windows 默认 CRLF，Mac 是 LF。在仓库根加 `.gitattributes`：
  ```
  * text=auto eol=lf
  *.bat eol=crlf
  ```
- **大小写敏感**：macOS 默认大小写不敏感，Linux 服务器是敏感的。文件名引用大小写要严格一致，否则 Windows/Mac 上跑通但 CI 报 404。
- **flutter create 平台壳**：你在 Windows 跑 `flutter create .` 会生成 `android/ ios/ windows/ web/` 全套，提交到 git 后 Mac 端拉下来直接能用，不用再 create 一次。

---

## 3. 常见问题排查

### 3.1 `flutter` 命令不识别

PATH 没生效，**关掉所有终端重开**（或重启电脑）。如果还不行，手动检查 `echo $PATH`（Mac/Linux）或 `echo $env:PATH`（Windows PowerShell）。

### 3.2 `flutter doctor` 提示 Android licenses not accepted

```bash
flutter doctor --android-licenses
```

### 3.3 Android 模拟器超慢

- 启用 Intel HAXM（Intel CPU）或 AMD Hypervisor（AMD CPU）—— Android Studio SDK Manager 里勾
- 或用真机（USB 连手机 + 开发者模式 + USB 调试）

### 3.4 中国网络问题

如果在国内：

```powershell
# Windows PowerShell（临时，新终端要重设）
$env:PUB_HOSTED_URL = "https://pub.flutter-io.cn"
$env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"
```

```bash
# Mac/Linux ~/.zshrc or ~/.bashrc
export PUB_HOSTED_URL=https://pub.flutter-io.cn
export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
```

### 3.5 Mac M1/M2 装 CocoaPods 报错

```bash
sudo arch -x86_64 gem install ffi
```

### 3.6 iOS 真机调试「Untrusted Developer」

iPhone：设置 → 通用 → VPN 与设备管理 → 信任你的 Apple ID

---

## 4. 推荐工具链速查

| 用途 | 工具 |
|---|---|
| 主编辑器 | VS Code + Flutter/Dart 插件 |
| 模拟器管理 | Android Studio Device Manager |
| 真机调试 | Pixel 6+（Android）/ iPhone 12+（iOS）|
| 包管理 | Melos（已配，跑 `melos bootstrap`）|
| API 调试 | Postman / HTTPie |
| 蓝牙调试 | LightBlue / nRF Connect（手机端 BLE 调试 App）|
| 性能 profiling | Flutter DevTools（`flutter pub global activate devtools`）|

---

## 5. 下一步

环境装完 → 回 [顶层 README](../README.md) 的「快速上手」章节跑 `melos bootstrap` + `flutter run`。

第一次跑 mixer App：

```bash
cd apps/mixer
flutter create .                          # 补齐 android/ ios/ 原生壳（一次性）
flutter pub get
flutter run                               # 选你创建的模拟器
```

如果 `flutter run` 报错，先跑 `flutter doctor` 看缺什么。
