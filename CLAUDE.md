# gas-dive-flutter · 项目上下文

> 给新会话 / 接手开发者的快速上手文档。详细文档见 [`README.md`](README.md) 和 [`docs/`](docs/)。

---

## 1. 是什么

`gas-dive-flutter` 是 **mixer 微信小程序** (`gas-dive-mixer`) 的 Flutter 跨端版本，目标：

- iOS + Android 双端原生 App（出海上架 + 蓝牙连潜水电脑等长期路线）
- 共享 Dart 算法包（dive_calc / mixer_core），未来给潜水规划 (`apps/plan/`) 复用

微信小程序版本仍是当前主力。Flutter 版是「长期路线 + 摆脱微信生态限制」的备选 / 接替。**为什么做这个**：见 [`gas-dive-mixer/shared/reference/docs/多端迁移调研_小程序_Flutter_原生.md`](../gas-dive-mixer/shared/reference/docs/多端迁移调研_小程序_Flutter_原生.md)。

---

## 2. 目录结构

```
gas-dive-flutter/
├── CLAUDE.md                ← 你在这里
├── README.md                ← 顶层入口
├── ROADMAP.md               ← 当前进度（P0-P5）
├── pubspec.yaml             ← monorepo 顶层（仅 melos）
├── melos.yaml
├── .github/workflows/ci.yml ← Linux Dart test + Flutter build APK
├── .gitattributes / .gitignore
│
├── docs/
│   ├── SETUP.md             ← Windows + Mac 环境搭建
│   ├── GIT_SETUP.md         ← git init + GitHub Actions
│   ├── IOS_CONFIG.md        ← iOS Bundle ID + Capabilities + 上架清单
│   ├── API_WEATHER_AMBIENT.md  ← 后端 API 设计（天气）
│   └── API_AUTH.md          ← 后端 API 设计（账号）
│
├── packages/                ← 纯 Dart 算法包（不依赖 Flutter）
│   ├── dive_calc/           ← MOD / END / EADD / NDL + Atmosphere
│   │   ├── lib/src/
│   │   │   ├── constants.dart        ← 物理常数
│   │   │   ├── types.dart            ← GasMix / MODInput / ZHL16CCompartment
│   │   │   ├── dive_calculator.dart  ← 主算法类
│   │   │   └── atmosphere.dart       ← (V2a 新增到 mixer_core，dive_calc 没有)
│   │   └── test/                     ← 31 用例
│   │
│   └── mixer_core/          ← 气体混合算法 (V2b 完整对齐 mixer.ts)
│       ├── lib/src/
│       │   ├── atmosphere.dart       ← ICAO 1976 海拔→气压
│       │   ├── eos_constants.dart    ← LKP 系数 + 临界参数 + He 维里
│       │   ├── eos.dart              ← Lee-Kesler-Plöcker EOS + He 维里
│       │   ├── z_factor.dart         ← Z 因子查询 wrapper
│       │   ├── types.dart            ← AltitudeMode / FillOrder / MixResult ...
│       │   └── gas_mixer.dart        ← 主算法：绝对压 + drain LP + 海拔 + Z
│       └── test/
│           ├── gas_mixer_test.dart   ← 30+ 用例
│           └── eos_test.dart         ← 20+ 用例
│
└── apps/mixer/              ← Flutter App
    ├── lib/
    │   ├── main.dart                 ← runApp + 初始化
    │   ├── app.dart                  ← MaterialApp + 主题状态
    │   ├── theme/mixer_theme.dart    ← 4 套主题（dark/light/macaron/candy）
    │   ├── models/
    │   │   ├── history_entry.dart    ← 历史记录数据类
    │   │   ├── weather_info.dart     ← 天气数据类
    │   │   └── auth_user.dart        ← 用户数据类
    │   ├── services/
    │   │   ├── history_service.dart  ← Hive 本地 CRUD
    │   │   ├── weather_service.dart  ← Mock + ECS provider
    │   │   └── auth_service.dart     ← Mock + ECS provider + 匿名/Email/Google/Apple
    │   ├── widgets/
    │   │   ├── picker_field.dart        ← 手机滚轮 / 桌面 inline TextField
    │   │   ├── number_field.dart        ← 手机 num pad / 桌面 inline TextField
    │   │   ├── desktop_number_input.dart ← 桌面端通用数字输入
    │   │   ├── num_pad.dart             ← 手机数字键盘 BottomSheet
    │   │   ├── gas_preset_chips.dart    ← Air/EAN32/Tx18-45 等预设
    │   │   └── hero_weather.dart        ← 顶部 Hero 天气区
    │   └── pages/
    │       ├── mix_calc_page.dart    ← 主页（混气计算）
    │       ├── home_page.dart        ← 算法 demo 页（POC 遗产）
    │       ├── history_page.dart     ← 历史记录列表
    │       ├── account_page.dart     ← 账号详情
    │       ├── login_page.dart       ← 登录页
    │       └── register_page.dart    ← 注册页
    └── ios/ android/ web/ ...        ← 平台壳（由 flutter create 生成）
```

---

## 3. 当前状态

详见 [`ROADMAP.md`](ROADMAP.md)。一句话总结：

- ✅ **算法层 100% 对齐 mixer.ts**：MOD/END/EADD/NDL + 混气分压配平 + drain LP + 海拔 4 模式修正 + std/fill 温度折算 + Z 因子真实气体
- ✅ **UI**：移动端 picker + 桌面 inline TextField；4 套主题；预设 chips；Hero 天气区
- ✅ **本地存储**：Hive 历史记录 + 匿名账号 + JWT
- ✅ **账号系统框架**：Mock 模式 Email/Google/Apple 登录注册可跑通
- ⚠️ **待后端就绪**：weather / auth 切到 EcsXxxProvider，已有 stub 类
- ❌ **未做**：tank-gauge 圆形压力表、其它 shared 小组件、plan App 减压算法

---

## 4. 关键约定

### 4.1 平台分支

UI 组件按平台分两套行为：

| 平台 | NumberField | PickerField |
|---|---|---|
| **手机** (Android/iOS) | 点击弹自定义 num pad BottomSheet | 点击弹 CupertinoPicker 滚轮 |
| **桌面** (Windows/macOS/Linux) | inline TextField + ▲▼ 按钮，键盘可直接输入 | 同 NumberField（用 DesktopNumberInput） |

判断逻辑在每个 widget 内部：

```dart
bool _isDesktop(BuildContext context) {
  if (kIsWeb) return false;
  final p = Theme.of(context).platform;
  return p == TargetPlatform.windows || p == TargetPlatform.macOS || p == TargetPlatform.linux;
}
```

### 4.2 单位制

算法层永远公制（m / bar / °C / L / kg），跟 dive_calc / mixer_core 严格对齐 mixer 微信版。显示层将来加单位转换（mixer 微信版 §4.1 设计）。

### 4.3 算法 ↔ mixer.ts 映射

| Flutter | mixer 微信版 (TS) |
|---|---|
| `packages/dive_calc/lib/src/dive_calculator.dart` | `shared/utils/dive-calc.ts` |
| `packages/mixer_core/lib/src/gas_mixer.dart` | `shared/utils/mixer.ts` |
| `packages/mixer_core/lib/src/atmosphere.dart` | `shared/utils/atmosphere.ts` |
| `packages/mixer_core/lib/src/eos.dart` | `shared/utils/eos.ts` |
| `packages/mixer_core/lib/src/z_factor.dart` | `shared/utils/z-factor.ts` |
| 类型字段：`o2Pct`、`hePct`、`fillOrder.heFirst`、`AltitudeMode.b` 等 | 跟 TS 命名对齐，仅大小写按 Dart 习惯 |
| 常数：`pSurface`、`airN2Fraction` 等 | TS `P_SURFACE`、`AIR_N2_FRACTION` → Dart `lowerCamel`，注释里保留 TS 原名做对照 |

### 4.4 测试

所有预期值**用 node 跑算法公式得出**，不依赖心算（之前心算翻车两次，见 `dive_calculator_test.dart` 末尾验算脚本）。

```powershell
# 跑算法包测试（不需要 Flutter，纯 Dart）
cd packages/dive_calc && dart test
cd packages/mixer_core && dart test

# 跑 App widget test
cd apps/mixer && flutter test
```

### 4.5 数据存储

- **Hive box `history`**：历史记录（`HistoryService.init()` 在 main 启动时调）
- **Hive box `auth`**：JWT + 用户信息 + CDID（`AuthService.init()` 同上）

### 4.6 Mock / ECS 切换（weather / auth）

两个服务都用 provider 抽象，默认 Mock：

```dart
// main.dart 启动时切（后端就绪后）：
WeatherService.setProvider(EcsWeatherProvider(baseUrl: 'https://api.diveplan.cn'));
AuthService.setProvider(EcsAuthProvider(baseUrl: 'https://api.diveplan.cn'));
```

EcsXxxProvider 目前是 stub，按 [`docs/API_WEATHER_AMBIENT.md`](docs/API_WEATHER_AMBIENT.md) / [`docs/API_AUTH.md`](docs/API_AUTH.md) 实现 HTTP 调用即可。

---

## 5. 怎么继续

### 5.1 加新功能

按 [`ROADMAP.md`](ROADMAP.md) 当前优先级：

1. **P2.5 tank-gauge 圆形压力表**：`CustomPaint` 重写 mixer 微信版的 `shared/components/tank-gauge`
2. **P5 其它 shared 组件**：picker-chip-multi / nav-home / range-slider 等
3. **plan App**：`apps/plan/` 起手 + 翻译 `shared/utils/deco.ts`

### 5.2 跑测试

```powershell
cd S:\GMP\gas-dive-flutter\packages\mixer_core
dart test
# 期望：~50 用例全绿
```

### 5.3 跑 App

```powershell
cd S:\GMP\gas-dive-flutter\apps\mixer

# Windows 桌面
flutter run -d windows

# Chrome 浏览器
flutter run -d chrome

# Android 真机（USB 连接 + USB 调试）
flutter run -d <devicd id>
```

### 5.4 切到真实后端

详见 §4.6。

### 5.5 上架准备

按 [`docs/IOS_CONFIG.md`](docs/IOS_CONFIG.md) §3-§7 配置 Bundle ID / Signing / Capabilities / Info.plist / TestFlight。

---

## 6. 环境注意

### 6.1 bash mount 滞后

跟 `gas-dive-mixer` 一样：用 Read 工具读 Windows 文件，bash 经 Linux mount 读时偶尔陈旧。要 bash 验证就把内容写到 `outputs/` 新路径再跑。

### 6.2 Flutter 版本

当前用 **Flutter 3.44.1 stable**。CI 也固定到这个版本。

### 6.3 平台壳

`apps/mixer/android/` `ios/` `web/` `windows/` 等是 `flutter create .` 生成的，**已提交到 git**。后期 `flutter create .` 不需要再跑（除非要加新平台）。

### 6.4 GitHub Actions

当前是 private 仓库 + 账号 billing locked，CI 跑不了。要么：
- 升 paid plan
- 仓库设 public（free plan public 仓 Actions unlimited）
- 本地用 `act` 跑 .github/workflows/ci.yml

---

## 7. 相关仓库

- [`gas-dive-mixer`](../gas-dive-mixer/) - 气体填充微信小程序（当前主力 + 算法源头）
- [`gas-dive-plan`](../gas-dive-plan/) - 潜水规划微信小程序（含 `CLAUDE.md` 项目上下文）
- [`gas-dive-server`](../gas-dive-server/) - 后端 ECS（两端共用）
- [`gas-mixer-shared`](../gas-mixer-shared/) - mixer + plan 共享 submodule（算法 + 错误上报 + lz-string）

---

## 8. 文档地图

| 文档 | 用途 |
|---|---|
| [`README.md`](README.md) | 顶层入口 + 快速开始 |
| [`CLAUDE.md`](CLAUDE.md) | **你在这里** —— 项目上下文 |
| [`ROADMAP.md`](ROADMAP.md) | P0-P5 进度跟踪 |
| [`docs/SETUP.md`](docs/SETUP.md) | Windows + Mac 环境搭建 |
| [`docs/GIT_SETUP.md`](docs/GIT_SETUP.md) | git init + GitHub Actions |
| [`docs/IOS_CONFIG.md`](docs/IOS_CONFIG.md) | iOS Bundle ID / Capabilities / 上架清单 |
| [`docs/API_WEATHER_AMBIENT.md`](docs/API_WEATHER_AMBIENT.md) | 后端天气 API 设计 |
| [`docs/API_AUTH.md`](docs/API_AUTH.md) | 后端账号 API 设计 |
| [`apps/mixer/README.md`](apps/mixer/README.md) | mixer App 启动指南 |
| [`packages/dive_calc/README.md`](packages/dive_calc/README.md) | dive_calc 包说明 |
| [`packages/mixer_core/README.md`](packages/mixer_core/README.md) | mixer_core 包说明 |
