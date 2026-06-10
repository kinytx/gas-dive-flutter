# gas-dive-flutter · 潜水工具 Flutter monorepo

> mixer（气体填充）+ plan（潜水规划）的 Flutter 跨端版本。
> 当前主要做 mixer App；plan 阶段未启动。

---

## 🚀 三秒上手

**新会话 / 接手开发者**：先读 [`CLAUDE.md`](CLAUDE.md)（项目上下文）+ [`ROADMAP.md`](ROADMAP.md)（当前进度）。

**跑算法测试**（不需要装 Flutter，只要 Dart SDK）：

```powershell
cd packages/mixer_core && dart test
# 期望：50+ 用例全绿
```

**跑 App**：

```powershell
cd apps/mixer
flutter pub get
flutter run -d windows    # 或 -d chrome / -d <android device>
```

iOS 需要 Mac + 配置（详见 [`docs/IOS_CONFIG.md`](docs/IOS_CONFIG.md)）。

---

## 📦 模块

| 模块 | 内容 | 测试 |
|---|---|---|
| [`packages/dive_calc/`](packages/dive_calc/) | 潜水通用计算（MOD / END / EADD / NDL） | 31 用例 |
| [`packages/mixer_core/`](packages/mixer_core/) | 气体混合算法（绝对压 + drain + 海拔 + Z 因子） | 50+ 用例 |
| [`apps/mixer/`](apps/mixer/) | Flutter App（混气计算 + 历史 + 天气 + 账号） | widget test |

---

## ✅ 算法对齐度

跟 mixer 微信小程序 (`gas-dive-mixer`) **100% 对齐**：

- ✅ MOD / END / EADD / NDL（ZHL-16C 表面 M 值法）
- ✅ 混气分压配平（绝对压差，含 1.013 bar 本底空气）
- ✅ Drain 自动求解（约束 LP 反解）
- ✅ 海拔修正 4 模式（A 完整 / B 推荐 / C 严谨 / D 线性）
- ✅ std → fill 温度折算（Gay-Lussac）
- ✅ Z 因子真实气体（LKP + He 维里方程，200 bar 时 ~2-3% 修正）

---

## 📂 目录结构（一图速览）

```
gas-dive-flutter/
├── CLAUDE.md                 项目上下文（新会话必读）
├── ROADMAP.md                P0-P5 进度
├── README.md                 ← 你在这里
├── docs/
│   ├── SETUP.md              环境搭建
│   ├── IOS_CONFIG.md         iOS 上架清单
│   ├── GIT_SETUP.md          git 流程
│   ├── API_WEATHER_AMBIENT.md   后端天气 API 设计
│   └── API_AUTH.md           后端账号 API 设计
├── packages/                 纯 Dart 算法包
│   ├── dive_calc/
│   └── mixer_core/
└── apps/mixer/               Flutter App
    ├── lib/
    │   ├── models/           数据模型
    │   ├── services/         业务服务（Hive / Mock-ECS provider）
    │   ├── widgets/          UI 组件（picker/num pad/hero 等）
    │   └── pages/            页面（主页/历史/账号/登录注册）
    └── ios/ android/ web/ ...
```

详细：[`CLAUDE.md`](CLAUDE.md) §2

---

## 🏃 当前进度（截至 2026-06-09）

| 阶段 | 状态 |
|---|---|
| P0 项目骨架 + 算法 POC | ✅ |
| P1 混气主页 UI MVP | ✅ |
| P2 Git + CI | ✅（CI billing 待解，见 CLAUDE.md §6.4）|
| V2a drain + 海拔 + 温度折算 | ✅ |
| V2b Z 因子真实气体 | ✅ |
| V3 UI 优化（移动端 + 桌面分支） | ✅ |
| P3.1 本地历史记录 | ✅ |
| P3.2 Hero 天气 + 自动温度 | ✅（前端 Mock，后端 API 待实现）|
| P4 账号系统（Email + Google + Apple） | ⚠️（前端框架 Mock 完成，后端 API + 原生 SDK 待）|
| P2.5 tank-gauge 圆形压力表 | ❌ |
| P5 其它 shared 组件移植 | ❌ |

详细：[`ROADMAP.md`](ROADMAP.md)

---

## 📡 后端依赖

前端已写好 ECS provider stub，**等后端实现 endpoints 后切一行配置即可**：

```dart
// main.dart
WeatherService.setProvider(EcsWeatherProvider(baseUrl: 'https://api.diveplan.cn'));
AuthService.setProvider(EcsAuthProvider(baseUrl: 'https://api.diveplan.cn'));
```

后端要做的事：

- [`docs/API_WEATHER_AMBIENT.md`](docs/API_WEATHER_AMBIENT.md) - 天气 + 空气质量
- [`docs/API_AUTH.md`](docs/API_AUTH.md) - 账号注册 / 登录 / 绑定

---

## 🔗 相关仓库

- [`gas-dive-mixer`](../gas-dive-mixer/) - 气体填充微信小程序（当前主力 + 算法源头）
- [`gas-dive-plan`](../gas-dive-plan/) - 潜水规划微信小程序
- [`gas-dive-server`](../gas-dive-server/) - 后端 ECS
- [`gas-mixer-shared`](../gas-mixer-shared/) - 共享 submodule（算法 + 错误上报）

---

## 🤝 给新会话的话

按 [`CLAUDE.md`](CLAUDE.md) 上下文走。当前最重要的两个决策点：

1. **后端 API 谁实现？什么时候？** P3.2 天气 / P4 账号 都等这个
2. **是否推 P2.5 tank-gauge** 在等后端期间立竿见影做出可视化？

更多见 [`ROADMAP.md`](ROADMAP.md) 末尾「当前优先级（用户决策）」。
