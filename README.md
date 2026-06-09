# gas-dive-flutter · 潜水工具 Flutter monorepo

> mixer（气体填充）+ plan（潜水规划）的 Flutter 跨端版本，目标 iOS + Android。
> 微信小程序版本仍是当前主力（[gas-dive-mixer](../gas-dive-mixer/) / [gas-dive-plan](../gas-dive-plan/)），本仓库是「长期出海 + 蓝牙连潜水电脑」的备选方案。
>
> 建仓日期：2026-06-06 · 当前阶段：**P0 项目骨架 + 算法 POC**

---

## 为什么有这个仓库

详细调研：[`gas-dive-mixer/shared/reference/docs/多端迁移调研_小程序_Flutter_原生.md`](../gas-dive-mixer/shared/reference/docs/多端迁移调研_小程序_Flutter_原生.md)

结论一句话：mixer 想做潜水电脑数据下载、想离开微信生态出海、想用 Face ID / NFC 等系统能力，**必须脱离微信小程序**，Flutter 是性价比最高的方案。

---

## 目录结构

```
gas-dive-flutter/
├── README.md                          ← 你在这里
├── docs/
│   └── SETUP.md                       ← 本地环境搭建指南（Windows + Mac）
├── melos.yaml                         ← monorepo 配置
├── pubspec.yaml                       ← 顶层（仅 melos 依赖）
├── .gitignore
│
├── packages/                          ← 共享 Dart 包
│   └── dive_calc/                     ← MOD / END / EADD / NDL 等算法
│       ├── lib/
│       │   ├── dive_calc.dart         ← public API
│       │   └── src/
│       │       ├── constants.dart
│       │       ├── types.dart
│       │       └── dive_calculator.dart
│       ├── test/
│       │   └── dive_calculator_test.dart
│       └── pubspec.yaml
│
└── apps/                              ← Flutter 应用
    └── mixer/                         ← 气体填充 App
        ├── lib/
        │   ├── main.dart
        │   ├── app.dart
        │   ├── theme/
        │   └── pages/
        ├── pubspec.yaml
        └── README.md                  ← 启动指南：flutter create + run
```

未来计划补的：

- `packages/deco/` —— ZHL-16C + GF 减压模型（对应 mixer/plan 的 `shared/utils/deco.ts`）
- `packages/ccr/` —— CCR 减压计划（对应 `shared/utils/ccr.ts`）
- `packages/dive_api/` —— ECS REST API client（鉴权 + transport 抽象）
- `packages/dive_design_system/` —— 4 套主题 + 共享组件
- `apps/plan/` —— 潜水规划 App

---

## 快速上手

1. **第一次**：跟着 [`docs/SETUP.md`](docs/SETUP.md) 装 Flutter SDK + Android Studio + （Mac 上的）Xcode

2. **环境装好后**：

   ```bash
   # 在仓库根目录
   dart pub global activate melos
   melos bootstrap            # 等价于 flutter pub get 所有包

   cd apps/mixer
   flutter create .           # 第一次跑：补齐 android/ ios/ 等原生壳
   flutter pub get
   flutter run                # 默认跑当前连接的设备/模拟器
   ```

3. **跑算法单测**（不需要装 Android Studio 也能跑）：

   ```bash
   cd packages/dive_calc
   dart test
   ```

---

## 开发约定（待补，参照 mixer/plan 的 CLAUDE.md）

- **算法层永远公制**：m / bar / °C / L / kg；显示层转换在 UI
- **错误上报**：复刻 mixer 的匿名 CDID + LZ-String 压缩方案
- **主题**：4 套（dark / light / macaron / candy），ThemeData 实现
- **i18n**：复用 mixer/plan 的 10 种语言翻译表（key 复用）
- **后端**：ECS REST 主路径（与 mixer 共用 ECS API）

---

## 现状（持续更新）

| 模块 | 状态 |
|---|---|
| 顶层 monorepo | ✅ 骨架 |
| dive_calc 算法包 | 🟡 MOD/END/EADD/NDL（首批） |
| mixer App 骨架 | 🟡 占位主页 |
| ECS API client | ❌ 未启动 |
| 主题系统 | ❌ 仅 token 占位 |
| 蓝牙模块 | ❌ 未启动 |
| iOS 端编译 | ❌ 待 Mac 环境 |

---

## 相关仓库

- [gas-dive-mixer](../gas-dive-mixer/) —— 气体填充微信小程序（当前主力）
- [gas-dive-plan](../gas-dive-plan/) —— 潜水规划微信小程序（当前主力）
- [gas-dive-server](../gas-dive-server/) —— 后端 ECS（两端共用）
- gas-mixer-shared —— mixer + plan 共享 submodule（算法 + 错误上报 + lz-string）
