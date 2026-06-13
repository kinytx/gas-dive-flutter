# gas-dive-flutter · 总体规划（MASTER PLAN）

> 三端 App（mixer / plan / importer）+ 共享库的整体架构与路线图。
> 单 App（mixer）的阶段进度见 [`ROADMAP.md`](ROADMAP.md)；本文管「三端格局 + 共享库」。
>
> **决策记录（2026-06-11）**：
> - 日志导入助手 = 独立 App，但核心做成公共库（plan 也复用）。
> - mixer / plan = 两个独立 App（不合并）。
> - 推进顺序：① 收尾 mixer → ② plan 骨架 → ③ 日志导入助手。

---

## 1. 格局：3 个独立 App + 共享 packages

| App | 定位 | 状态 |
|---|---|---|
| **mixer** | 气体填充计算（出海主力） | ✅ 已大量开发 |
| **plan** | 潜水规划（减压 / GF / 剖面） | 🆕 待建骨架 |
| **importer** | 潜水电脑日志导入助手 | 🆕 待建，UI 薄、能力全在 dive_import |

三个 App 各自独立分发、独立迭代，共用同一套 `packages/`。业务能力尽量下沉到 packages，App 只做 UI + 编排。

---

## 2. 共享 packages

| package | 职责 | 谁用 | 状态 |
|---|---|---|---|
| `dive_calc` | MOD / END / EADD / NDL | mixer, plan | ✅ |
| `mixer_core` | 混气配平 + drain + 海拔 + Z 因子 | mixer | ✅ |
| `dive_ui` | 设计系统：4 套主题 / token / 768 三档断点 / 自适应导航 | 全部 | ✅（今天抽出） |
| `deco` | 减压 ZHL-16C + GF（翻译 `deco.ts` 53KB） | plan | 🆕 |
| **`dive_import`** | **日志导入核心：设备发现 / 连接 / 下载 / 解析 / 上传** | **importer, plan** | 🆕 ★ |
| `dive_api` | ECS REST client（auth / weather / 记录 / 日志上传） | 全部 | 🆕 |

---

## 3. 依赖关系

```
        apps/mixer        apps/plan          apps/importer
           │                 │                    │
   ┌───────┼─────────┬───────┼──────────┬─────────┤
   ▼       ▼         ▼       ▼          ▼         ▼
dive_ui  mixer_core dive_ui deco      dive_ui   dive_import
dive_calc dive_api  dive_calc dive_import        dive_api
dive_api            dive_import dive_api
```

要点：
- `dive_ui` / `dive_api` 是三端通用底座。
- `dive_import` 被 **importer（独立助手）和 plan（导入日志→喂规划）** 共用 —— 这就是「核心做一次」。
- `deco` 仅 plan；`mixer_core` 仅 mixer。

---

## 4. ★ `dive_import` 核心库（重点）

**纯能力库，不含 UI。** 谁要导入日志就 `import dive_import`，自己配 UI。

### 分层

```
Dart 上层 API
  发现设备 → 连接 → 下载 → 解析成 DiveLog model → dive_api 上传
        │
Transport 抽象（统一接口，上层不感知底层）
  ├ BleTransport       → flutter_blue_plus（全平台）
  ├ SerialTransport    → 桌面 libserialport / Android USB host
  ├ UsbTransport       → Android USB host / 桌面 libusb
  └ ClassicBtTransport → Android SPP / iOS MFi / 桌面 SPP→串口
        │
libdivecomputer (C，via dart:ffi)  ← 设备协议 + 日志解析（不自己写）
```

### 传输 × 平台支持（选型现实）

| 传输 | Android | iOS | Win/Mac |
|---|---|---|---|
| BLE | ✅ | ✅ | ✅ |
| Classic BT | ✅ | ⚠️ 仅 MFi | ✅ |
| Serial | ✅ | ❌ | ✅ |
| USB-OTG | ✅ | ❌ | ✅ |

**iOS 现实**：第三方 App 只稳定开放 BLE；Classic BT 需设备 MFi 认证；Serial/USB 基本无解。→ iOS 端以 BLE 为主。

### 复用方式

- **importer App**：完整设备管理 UI（扫描 / 配对 / 批量下载 / 桌面串口选择）。
- **plan App**：内嵌「从潜水电脑导入」入口 → 拿到 DiveLog → 直接进规划/日志。

### 关键风险与首验

最大不确定性 = **libdivecomputer 的 dart:ffi 集成（移动端编译 + BLE custom-IO 桥接）**。
参考实现：仓库里的 **`subsurface`**（Qt + libdivecomputer + 平台 BLE 桥接）、`libdivecomputerjs`、`android-ble-probe`、`garmin-sidecar`。
**第一步只验一件事**：libdivecomputer FFI + 一台机器（如 Shearwater/Garmin）BLE 端到端下载跑通。

---

## 5. 路线图（按决策顺序）

### 阶段 ① 收尾 mixer（当前，固化基线）
- 验证 dive_ui 抽取（删旧 theme + melos bootstrap + analyze）
- 风格细化剩余（输入行 / 结果区卡片）+ 清 unused warning
- 账号接入：`EcsAuthProvider`（后端已实现 anonymous/email/me）+ 登录注册页验证码 UI + main.dart 切 ECS
- weather 切 `EcsWeatherProvider`（待后端 `/api/weather/ambient`）
- **commit 稳定基线**（算法 / UI+dive_ui 分批）

### 阶段 ② plan 骨架
- `flutter create apps/plan`，复用 dive_ui 自适应导航 + 4 主题
- 4 tab 占位（参照 gas-dive-plan 小程序：规划 / 日志 / 工具 / 我的）
- `packages/deco` 起手：翻译 `deco.ts`（ZHL-16C + GF），对拍验证
- deco-result 页 UI + 剖面/GF 图（P5 组件：dive-profile / gf-chart / tissue-bar）

### 阶段 ③ 日志导入助手
- `packages/dive_import` 起手：**先做 libdivecomputer FFI + 一台机 BLE 下载验证**
- Transport 抽象 + BLE（flutter_blue_plus）桥接
- 桌面 serial/usb（libdc 自带）→ Android USB host → Classic BT（按平台）
- `apps/importer` 独立助手 UI
- plan 内嵌导入入口
- 上传走 `dive_api`

### 横向（穿插各阶段）
- `packages/dive_api`：ECS client 抽象（auth / weather / records / 日志上传），三端共用
- 跨 App 数据：历史/日志同一 ECS userId 下（靠 dive_api + 后端 bind-codes 跨端绑定）

---

## 6. 当前进度快照（2026-06-11）

**已完成（本轮）**
- 算法 6 处对齐修复（海拔 K 系数 / drain / Z 因子）+ O₂ 高残压警告，node↔dart 对拍 0 差异
- `dive_ui` 共享设计系统抽出（4 主题 / token / 768 三档 / 自适应导航）
- mixer 风格对齐小程序（section-title 竖条 / hero 大屏收窄 / AppBar 简化 / chip pill）
- 后端 auth 已实现并对齐文档（anonymous + email + 升级 + bind-codes）

**进行中 / 待验证**
- dive_ui 抽取的本地验证（删旧 + bootstrap + analyze）
- 账号接入代码（EcsAuthProvider 已给，待贴 + UI）
- 整批 UI 改动待 commit

**待办**
- 阶段 ②③ 全部（plan / deco / dive_import / importer / dive_api）
- tank-gauge（P2.5）+ 其它 shared 组件（P5）
- 上架准备（iOS/Android）
