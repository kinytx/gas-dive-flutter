# gas-dive-flutter 设计系统 + 响应式规范

> 来源：1:1 对齐微信小程序 `gas-mixer-shared/app.wxss` 的设计 token，
> 响应式策略对齐 `gas-dive-plan/docs/IPAD_LAYOUT_PLAN.md`（同产品族行为一致）。
> 代码落地：`apps/mixer/lib/theme/` 下 4 个文件。后续所有页面/组件都应走这套，不要再硬编码颜色/字号/圆角/间距。

---

## 1. 颜色 token —— `theme/mixer_colors.dart`

`MixerColors`（`ThemeExtension`）承载 `ColorScheme` 放不下的全部语义色，4 套主题各一份常量。组件用 `context.mixerColors` 读取。

**铁律（来自 app.wxss 主题准则）**：
- `accentWarn` 安全红：致命告警专用，跨 4 主题恒定可识别，不可弱化。
- `accentHe` 氦气色：行业色标，每套主题保留可识别橙/珊瑚调，不可换语义。
- 数据文字一律 `textPrimary`；糖果系高饱和色只用于背景/卡片/装饰，不染数据。

| token | dark | light | macaron | candy |
|---|---|---|---|---|
| bgDeep | #0A1628 | #FFFAEF | #FFEAF2 | #E8F8FF |
| bgCard | #0F2040 | #FFFFFF | #FFF8FB | #FFFFFF |
| bgInput | #0D1F3A | #EFFAF5 | #FFD6E2 | #D4F0FF |
| accentCyan(主) | #00D4FF | #4CB8A8 | #B8A8E8 | #4DC4FF |
| accentTeal(次) | #00B8A9 | #F5A623 | #F5B8C8 | #FF7AB3 |
| accentHe(氦) | #F0A030 | #FF7E5F | #FFB89E | #7ED957 |
| accentSuccess | #30D158 | #7CC676 | #9BE8B4 | #7ED957 |
| accentWarn(安全红) | #FF3B30 | #E74C3C | #FF9EA0 | #FF5566 |
| textPrimary | #E8F4FD | #2A4A4D | #3D3543 | #1A3A4D |
| textSecondary | #8AB4D4 | #5A7A7D | #6B5B73 | #4A6A85 |
| textMuted | #6B8DB0 | #9AB0B0 | #A89AA5 | #7A9BB0 |
| textOnAccent | #0A1628 | #FFFFFF | #3D3543 | #FFFFFF |

另含 `border` / `borderActive` 及 5 色 tint（`tintCyan/He/Success/Warn/Neutral`，语义色浅高亮底，配实色 border 用）。alpha 见源码 `Color.fromARGB`。

`mixer_theme.dart` 用各主题 `accentCyan` 作 seed 生成 Material 色阶，再覆盖关键语义色，并把 `MixerColors` 挂到 `extensions`。

---

## 2. 尺寸 token —— `theme/design_tokens.dart`

换算：小程序 750rpx=屏宽，1rpx≈0.5dp，故 **rpx→dp ÷2**。flutter 用 dp 物理尺寸恒定，无需像小程序「锁 px」。

**字号 `FontSizes`（dp）**

| 名 | dp | 小程序 | 用途 |
|---|---|---|---|
| muted | 10 | 20rpx | 弱文字/副标 |
| section | 11 | 22rpx | 区块标题(600/大写/字距) |
| entry | 13 | 26rpx | 入口标题/标签 |
| body | 14 | 28rpx | 正文基础 |
| alert | 15 | 30rpx | 致命告警(700，跨设备恒定) |
| hero | 16 | 32rpx | hero 标题(700) |
| dataLarge | 22 | — | 数据大字(填充量/压力) |

**间距/圆角 `Dimens`（dp）**

| 名 | dp | 来源 |
|---|---|---|
| pagePadding | 14 | 页边 28rpx |
| cardPadding | 12 | mixer 卡 24rpx |
| cardPaddingPad | 16 | pad 大屏收紧 ~22-24px |
| cardGap | 8 | 卡间 16rpx |
| splitGap | 12 | 分栏/双列列间距 |
| radiusCard | 10 | 卡 20rpx |
| radiusSmall | 7 | 入口 12-14rpx |
| radiusAlert | 4 | 告警 8rpx |
| radiusPill | 999 | chip 全圆 100rpx |
| borderWidth | 0.5 | 描边 1rpx |

---

## 3. 响应式三档 —— `theme/breakpoints.dart`

断点 **768 + 方向**（对齐 plan 蓝图 §1.2，768 涵盖 iPad mini~Pro 全系）：

| 档位 `WindowSize` | 条件 | 版式 |
|---|---|---|
| `phone` | width < 768 | 单列纵向滚动 |
| `padPortrait` | ≥768 且竖屏 | 卡片双列网格 |
| `padLandscape` | ≥768 且横屏 | 左右分栏（左输入 \| 右结果常驻） |

```dart
final ws = windowSizeFor(constraints.maxWidth, MediaQuery.orientationOf(context));
```

注意：这管「整体版式」。单个输入控件的手机/桌面交互切割（num pad/滚轮 vs inline 键盘）由各 widget 内部 `_isDesktop()` 负责，二者正交。

---

## 4. 主页三档布局（`mix_calc_page.dart` 已落地）

- **phone**：`HeroWeather` 横跨 + 输入卡单列 + 结果，整页滚动。
- **padPortrait**：`HeroWeather` 横跨；输入卡两列（左 当前气/高级，右 目标气/填充顺序）；`_resultArea` 全宽在下；整页滚动。
- **padLandscape**：`HeroWeather` 横跨顶部；下方 `Row` 左右分栏，左输入列与右结果列**各自独立滚动**，中间 `border` 分隔线（对应 plan two-pane 的 `var(--border)`）。比例 `Breakpoints.landscapeInputFlex : landscapeResultFlex`（当前 1:1，对应 plan dive-plan 页）。

输入卡序列抽成 `_inputCards()` 三档复用。

---

## 5. 后续页面套用约定

1. 页面顶层用 `LayoutBuilder` + `windowSizeFor(...)` 切三档，不写魔法数字。
2. 横屏分栏优先 master-detail：左导航/参数、右内容/结果常驻（参照 plan two-pane-layout）。
3. sidebar/分栏背景用 `mixerColors.bgCard`，分隔线 `mixerColors.border`，高亮态 `mixerColors.tintCyan + borderActive`。
4. 颜色一律 `context.mixerColors.*`，禁止 hex 硬编码；圆角/间距/字号一律 `Dimens.*` / `FontSizes.*`。
5. 安全红线（告警）视觉跨档位恒定，不被分栏压缩。

---

## 6. 落地状态

**已落地**：`breakpoints.dart`、`design_tokens.dart`、`mixer_colors.dart`、`mixer_theme.dart`(重写)、`mix_calc_page.dart`(三档布局)。

**待办**：
- 把 `number_field` / `picker_field` 等组件里硬编码的圆角(12)、padding(14/12)换成 `Dimens.*`（功能不受影响，仅统一）。
- 历史/账号/登录/注册页按本规范套三档。
- `tank-gauge` 等小程序共享组件移植（见 ROADMAP P2.5）。
- 本地 `flutter analyze` + `flutter run` 验证（沙箱无完整 Flutter SDK + 无显示器，未能验证编译/渲染）。
