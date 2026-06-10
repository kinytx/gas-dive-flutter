# gas-dive-flutter · ROADMAP

> 阶段化进度跟踪。每阶段标注 ✅ 完成 / 🟡 进行中 / ⚠️ 部分完成 / ❌ 未开始。
> 最新更新：2026-06-09

---

## P0 ✅ 项目骨架 + 算法 POC

**完成时间**：2026-06-06

- ✅ monorepo 目录结构（packages/ + apps/）
- ✅ Melos 配置（可选）
- ✅ `packages/dive_calc` 翻译 `shared/utils/dive-calc.ts` → Dart
  - MOD / END / EADD / NDL 算法
  - 31 个测试用例（边界 + 单调性 + 物理一致性）
- ✅ `apps/mixer` Flutter 骨架
  - 4 套主题 ThemeData（dark / light / macaron / candy）
  - 算法演示页（拖滑块看 MOD/END/NDL）
- ✅ 文档：SETUP / IOS_CONFIG / GIT_SETUP

---

## P1 ✅ 完整混气主页 UI (MVP)

**完成时间**：2026-06-07

- ✅ `packages/mixer_core` 翻译 `shared/utils/mixer.ts` 的「理想气体 + 简单分压」子集
- ✅ 三元一次方程组解 fillO₂ / fillHe / fillAir
- ✅ 填充顺序：he-first / o2-first
- ✅ 错误码：invalidInput / invalidTargetGas / targetPressureTooLow / needDrain
- ✅ 软警告：lowResidualPressure
- ✅ 17 个测试用例
- ✅ `apps/mixer/lib/pages/mix_calc_page.dart` 完整 UI
- ✅ 安全栏（MOD@1.4 / MOD@1.6 / END@30m）

---

## P2 ✅ Git + CI

**完成时间**：2026-06-08

- ✅ `.gitattributes`（LF 强制） + `.gitignore`（Flutter 标准）
- ✅ `.github/workflows/ci.yml`
  - Linux runner：dive_calc + mixer_core dart test + analyze
  - flutter analyze + build APK + 上传 artifact
  - macOS iOS 编译注释（P5 上架前启用）
- ✅ `docs/GIT_SETUP.md` git init 指南
- ⚠️ **CI 不能跑**：账号 billing locked，需升 paid 或仓库设 public（决策见 CLAUDE.md §6.4）

---

## V2a ✅ 算法补齐：drain + 海拔 + std 折算

**完成时间**：2026-06-08

- ✅ `atmosphere.dart` ICAO 1976 海拔 → 气压
- ✅ 算法切换到**绝对压差**（对齐 mixer.ts），fill 计算更精确
- ✅ Drain 自动求解（约束 LP 反解 drainToPressure）
- ✅ 海拔 4 种修正模式 (A 完整 / B 推荐 / C 不改 O₂ / D 线性)
- ✅ std → fill 温度折算（Gay-Lussac）
- ✅ 30+ 测试用例
- ✅ UI：高级选项 ExpansionTile + 海拔/温度/修正模式输入

---

## V2b ✅ Z 因子真实气体修正

**完成时间**：2026-06-09

- ✅ `eos.dart` Lee-Kesler-Plöcker (LKP) + He 维里方程 + 牛顿迭代
- ✅ `eos_constants.dart` 临界参数 + LKP 系数
- ✅ `z_factor.dart` Z 因子查询 wrapper（O₂ / He / N₂ / Air）
- ✅ 集成到 calculate()：fill 量 ÷ Z
- ✅ 20+ eos 测试 + 4 个 mixer_core 集成测试
- ✅ UI：高级选项加 `真实气体修正 (Z)` 开关 + 紫色 Z 回显卡片

**未做（V2c 选做，影响 <1%）**：perStepZ（按 fillOrder 拆 3 步分别查 Z）。

---

## V3 ✅ UI 优化（移动端 + 桌面）

**完成时间**：2026-06-09

### V3.1 ✅ Desktop 数字小键盘
- ✅ Windows 输入框输不进数字的 bug 修复（原因：ValueKey 让 widget 重建）
- ✅ 桌面端 num pad BottomSheet（屏幕点击 + 物理键盘双输入）

### V3.2 ✅ 移动端 picker + num pad
- ✅ 手机 O₂/He 用 CupertinoPicker 滚轮 BottomSheet
- ✅ 手机压力/海拔/温度用自定义数字键盘 BottomSheet
- ✅ 行式布局（节省横向空间）

### V3.3 ✅ 平台分支
- ✅ PickerField / NumberField 自动按平台切换
- ✅ 桌面端：inline TextField + ▲▼ 微调
- ✅ 手机端：弹层 picker / num pad
- ✅ 起始压改回输入框（mixer 微信版用 `<numeric-field>`，不是 picker）

### V3 对齐 mixer ✅
- ✅ O₂ 5-100 / He 0-100（之前是 16-100 / 0-80）
- ✅ 目标压 picker 150-300 步 5 + 232 特殊（European 12L 钢瓶）

---

## P3.1 ✅ 本地历史记录

**完成时间**：2026-06-09

- ✅ `models/history_entry.dart` schema 对齐 mixer 微信版 `HistoryEntry`
- ✅ `services/history_service.dart` Hive Box<String> CRUD
- ✅ `pages/history_page.dart` 列表 + 详情 + 左滑删除 + 星标置顶 + 清空
- ✅ 主页加保存按钮 + AppBar 历史入口
- ✅ 列表项点击 → pop 回主页 + 加载参数

**未做**：云端同步（依赖 P4 + 后端）。

---

## P3.2 ✅ Hero 天气 + 自动温度

**完成时间**：2026-06-09

- ✅ `models/weather_info.dart` 天气数据模型（GeoLocation / WeatherCurrent / AirQuality）
- ✅ `services/weather_service.dart` 抽象 + MockWeatherProvider + EcsWeatherProvider stub
- ✅ `widgets/hero_weather.dart` Hero UI（渐变背景 + 天气图标 + AQI chip + 刷新按钮）
- ✅ 8 种天气状况渐变（晴/多云/雨/雷暴/雾/雪/风/夜）
- ✅ 6 种 AQI 等级颜色
- ✅ 主页温度字段自动同步（用户手动改后不再覆盖）
- ✅ `docs/API_WEATHER_AMBIENT.md` 后端 API 设计

**待**：
- ⚠️ 后端 `/api/weather/ambient` 实现 → 切到 EcsWeatherProvider
- ⚠️ iOS / Android 位置权限配置（IOS_CONFIG.md 已备好文案）

---

## P4 ⚠️ 账号系统（Email + Google + Apple）

**前端框架完成时间**：2026-06-09

### 已完成 ✅
- ✅ `models/auth_user.dart` 用户数据模型
- ✅ `services/auth_service.dart` 抽象 + MockAuthProvider + EcsAuthProvider stub
- ✅ Hive 持久化 JWT + 用户 + CDID
- ✅ 启动自动 ensureAnonymous（无感知匿名注册）
- ✅ `pages/login_page.dart` 登录页（Email/Google/Apple）
- ✅ `pages/register_page.dart` 注册页 + 匿名升级
- ✅ `pages/account_page.dart` 账号详情（绑定状态 + 升级 + 退出）
- ✅ 主页 AppBar 加账号入口
- ✅ `docs/API_AUTH.md` 后端 API 设计（7 endpoints + DB schema）

### 待 ⚠️
- ❌ 后端 ECS 7 个 auth endpoint 实现
- ❌ Flutter 切到 EcsAuthProvider
- ❌ Google / Apple 原生 SDK 集成（`google_sign_in` / `sign_in_with_apple` 包）
- ❌ Apple Sign-In Xcode Capability 配置（IOS_CONFIG.md §3.2 已列）
- ❌ 历史 / 设置云同步（依赖账号系统）

---

## P2.5 ❌ tank-gauge 圆形气瓶压力表

**未开始**

- ❌ `widgets/tank_gauge.dart` CustomPaint 重写
- ❌ 显示当前压力 vs 目标压力的圆弧动画
- ❌ 集成到 hero 区或主页（设计待定）

参考：mixer 微信版 `shared/components/tank-gauge/`

---

## P5 ❌ 其它 shared 组件批量移植

**未开始**

| 组件 | 优先级 | 工作量 |
|---|---|---|
| `picker-chip-multi` 多选 chip | 中 | 半天 |
| `nav-home` 返回首页 | 低 | 半天 |
| `user-info-prompt` 用户提示 dialog | 低 | 半天 |
| `range-slider` 双端滑块 | 低 | 半天 |
| `scroll-ruler` 滚动尺（PADI 风格） | 中 | 1 天 |
| `vertical-ruler` 垂直尺 | 低 | 1 天 |
| `pressure-dial` 压力表盘 | 中 | 1-2 天 |
| `dive-profile` 潜水剖面 SVG 图 | plan App | 3-5 天 |
| `gf-chart` GF 曲线图 | plan App | 3-5 天 |
| `tissue-bar` / `tissue-series` 组织压力条 | plan App | 2-3 天 |

详见 [`gas-dive-mixer/shared/reference/docs/多端迁移调研_小程序_Flutter_原生.md`](../gas-dive-mixer/shared/reference/docs/多端迁移调研_小程序_Flutter_原生.md)。

---

## 未来阶段

### apps/plan/ - 潜水规划 App
- ❌ 翻译 `shared/utils/deco.ts` ZHL-16C + GF 减压模型
- ❌ 翻译 `shared/utils/ccr.ts` CCR 减压
- ❌ deco-result 页 UI

### 跨小程序联动失去后的补偿
- ❌ App 内集成混气 → 规划链路（mixer / plan 合并到一个 App？）
- ❌ 历史记录跨 mixer / plan 共享

### 蓝牙 / 潜水电脑下载
- ❌ `flutter_blue_plus` 集成
- ❌ libdivecomputer FFI（Subsurface 同款，C 库通过 dart:ffi 调）
- ❌ Shearwater / Suunto / Garmin / Mares / ScubaPro / Aqualung 主流支持

详见 [`gas-dive-mixer/shared/reference/docs/多端迁移调研_小程序_Flutter_原生.md`](../gas-dive-mixer/shared/reference/docs/多端迁移调研_小程序_Flutter_原生.md) §3.5 蓝牙/OTG 章节。

### 上架准备
- ❌ iOS App Store Connect 配置（IOS_CONFIG.md §2-§7）
- ❌ Android Google Play 控制台
- ❌ 隐私政策 URL
- ❌ App 图标 1024×1024 + 各尺寸截图
- ❌ TestFlight 内测

---

## 当前优先级（用户决策）

按用户上次选择的顺序（2026-06-09）：

1. ✅ P3.1 本地历史记录
2. ✅ P3.2 Hero 天气 + 自动温度（用 ECS 后端 API）
3. ✅ P4 账号系统（Email + Google + Apple）— 前端框架完成
4. ❌ P2.5 tank-gauge 圆形气瓶压力表
5. ❌ P5 其它小组件

P3.2 和 P4 卡在后端 endpoint。**用户决策点**：

- 后端 `/api/weather/ambient` 和 `/api/auth/*` 由谁实现？什么时候？
- 在等后端期间，是否推 P2.5（独立、立竿见影）？

---

## 算法对齐度

| 模块 | mixer.ts | Flutter | 差距 |
|---|---|---|---|
| dive-calc | ✅ | ✅ | 0% |
| atmosphere | ✅ | ✅ | 0% |
| mixer (分压配平 + 海拔 + std) | ✅ | ✅ | 0% |
| drain LP 求解 | ✅ | ✅ | 0% |
| Z 因子 LKP + He 维里 | ✅ | ✅ | 0% |
| perStepZ (3 步分别查 Z) | ✅ | ❌ | <1% 影响，V2c 选做 |
| deco.ts (减压模型) | ✅ | ❌ | plan App 才用 |
| ccr.ts (CCR 减压) | ✅ | ❌ | plan App 才用 |
