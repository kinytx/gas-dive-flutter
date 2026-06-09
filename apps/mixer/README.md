# mixer · 气体填充 Flutter App

> P0 占位版：算法 POC 演示页（调 dive_calc 包，显示 MOD / END / EADD / NDL + 主题切换）。
> 完整混气 UI 在 P1+ 阶段补。

---

## 第一次跑 (一次性初始化)

环境装好后（参见 [../../docs/SETUP.md](../../docs/SETUP.md)），按顺序：

### 1. 装 monorepo 依赖

```bash
# 在仓库根目录 S:\GMP\gas-dive-flutter\
dart pub global activate melos
melos bootstrap
```

### 2. 补齐 Android / iOS 原生壳

`apps/mixer/` 目前只有 Dart 代码，原生壳（`android/`, `ios/`）没生成。第一次跑用 `flutter create .` **在已有目录上补齐**——它不会覆盖 `pubspec.yaml` 和 `lib/`：

```bash
cd apps/mixer
flutter create . --org cn.diveplan --project-name mixer
```

参数说明：
- `--org cn.diveplan` —— 包名前缀（生成 `cn.diveplan.mixer` 包名）
- `--project-name mixer` —— 项目名
- `.` —— 在当前目录初始化（关键，否则它会新建目录）

期望看到：

```
Recreating project mixer...
  ios/Runner.xcodeproj/project.pbxproj (created)
  android/app/build.gradle (created)
  ...
```

⚠️ 它**不会**覆盖 `pubspec.yaml` / `lib/` / `analysis_options.yaml`，只生成 `android/` `ios/` `web/` 等平台目录。

### 3. 拉依赖

```bash
flutter pub get
```

### 4. 跑起来

**Android 模拟器**（Windows 上最便利）：

```bash
# 先在 Android Studio Device Manager 启动一个模拟器
flutter run
```

**真机调试**：

```bash
# Android 手机：USB 连接 + 开发者模式 + USB 调试
flutter devices              # 看连接设备
flutter run -d <deviceId>
```

**iOS 模拟器**（仅 Mac）：

```bash
open -a Simulator
flutter run
```

---

## 日常开发

```bash
# 改完代码热重载（已 flutter run 时按 r）
# 完全重建按 R
# 退出按 q

# 只跑 dive_calc 包的单元测试（不需要 flutter，纯 Dart 就行）
cd ../../packages/dive_calc
dart test

# 跑整个 monorepo 所有包的测试
cd ../..
melos run test
```

---

## 算法 POC 演示

跑起来后看到的页面：

- **气体配比**：拖 O₂ % 和 He %（自动约束 O₂ + He ≤ 100）
- **潜水条件**：深度 / 海水开关 / 水温
- **算法结果**：
  - MOD @ PO₂ 1.4 —— 安全最大深度
  - MOD @ PO₂ 1.6 —— 极限最大深度
  - END —— 等效麻醉深度
  - EADD —— 等效空气密度深度
  - NDL —— 免减压极限分钟数
- **主题切换**：右上角调色板图标，4 套主题切换（深海/晴朗/马卡龙/糖果）

预期值验证（拖到这些组合）：

| O₂ | He | 深度 | MOD@1.4 | END | NDL（海水 24°C）|
|---|---|---|---|---|---|
| 32 | 0 | 30 | 33 | ≈ 30 | > 20 min |
| 21 | 0 | 30 | 56 | 30 | ≈ 15 min |
| 18 | 45 | 50 | 67 | 18 | (深) |

跟 mixer 微信小程序的同条件结果对比，应**完全一致**（floor 取整规则相同）。

---

## 文件结构

```
apps/mixer/
├── pubspec.yaml           ← 包依赖（含 dive_calc path 引用）
├── analysis_options.yaml  ← lint 规则
├── lib/
│   ├── main.dart          ← runApp 入口
│   ├── app.dart           ← MaterialApp + 主题状态
│   ├── theme/
│   │   └── mixer_theme.dart   ← 4 套主题 ThemeData
│   └── pages/
│       └── home_page.dart ← POC 演示页
└── README.md              ← 你在这里

（flutter create . 之后会多出）
├── android/               ← Android 原生壳
├── ios/                   ← iOS 原生壳
├── web/                   ← Web 端（暂不用）
├── windows/               ← Windows 桌面（暂不用）
├── macos/                 ← macOS 桌面（暂不用）
├── linux/                 ← Linux 桌面（暂不用）
└── test/                  ← widget test（已有 lib/ 的 widget test 放这里）
```

---

## 常见问题

### Q1: `flutter create .` 报错说目录非空？

正常。继续往下看，它会跳过已存在的文件，只生成缺失的平台目录。如果它真的卡住，加 `--overwrite` 强制覆盖（**先确认它不会覆盖你的 lib/**）。

### Q2: `Target file "lib/main.dart" not found`？

确认在 `apps/mixer/` 目录下跑。

### Q3: `Package dive_calc not found`？

跑：
```bash
cd S:\GMP\gas-dive-flutter
melos bootstrap
```
melos 会生成 `pubspec_overrides.yaml` 让 path 引用生效。

### Q4: Android 模拟器卡死 / 慢？

- 用 x86_64 image（不要用 arm64 在 Intel 机器上）
- 开 HAXM（Intel CPU）或 AMD-V
- 或直接用 USB 连真机调

### Q5: iOS 真机第一次跑卡在 `Running Xcode build...`？

正常，第一次编译要装很多 Pod 依赖，5-15 分钟。后续会快很多。

### Q6: 改了 dive_calc 的代码 mixer 里没生效？

- monorepo path 引用本应即时生效；如果不行，跑 `flutter clean && flutter pub get`
- 严重情况：在 `S:\GMP\gas-dive-flutter\` 跑 `melos clean && melos bootstrap`

---

## 下一步路线图

| 阶段 | 内容 | 预计 |
|---|---|---|
| **P0**（当前） | 算法 POC + 主题切换 + 跑通双端 | ✅ |
| **P1** | 完整混气主页（瓶压输入 + 补气量计算）| 1-2 周 |
| **P2** | 历史记录 + 设置 + 关于 + i18n | 2-3 周 |
| **P3** | ECS API 接入（鉴权 + 同步）| 1-2 周 |
| **P4** | 蓝牙扫码气瓶（Android 先行）| 2-3 周 |
| **P5** | iOS 上架 + Android 上架 | 1-2 周 |
| **P6** | 潜水电脑数据下载（libdivecomputer FFI） | 4-6 周 |

详细路线在 monorepo 顶层 README + 调研文档。
