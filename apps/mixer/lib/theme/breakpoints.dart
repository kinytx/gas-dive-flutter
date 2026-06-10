// 响应式窗口档位 —— 对齐 gas-dive-plan 的 iPad 适配蓝图
// (gas-dive-plan/docs/IPAD_LAYOUT_PLAN.md §1.2)，保证 mixer 与 plan 行为一致。
//
// 断点 768 涵盖 iPad mini ~ iPad Pro 全系；≥768 再按屏幕方向分竖/横。
//   < 768            → phone         手机竖屏/横屏      → 单列
//   ≥ 768 && 竖屏     → padPortrait   pad 竖屏/分屏窄    → 卡片双列网格
//   ≥ 768 && 横屏     → padLandscape  pad 横屏/桌面窗口  → 左右分栏(输入|结果常驻)
//
// 注意：这里只管「整体版式」。单个输入控件的手机/桌面交互切割
// (num pad / 滚轮 vs inline 键盘) 由各 widget 内部 _isDesktop() 负责，二者正交。

import 'package:flutter/widgets.dart';

/// 窗口尺寸档位。
enum WindowSize {
  /// < 768：手机竖屏/横屏 —— 单列纵向滚动
  phone,

  /// ≥ 768 且竖屏：pad 竖屏 / 分屏窄 —— 卡片双列网格
  padPortrait,

  /// ≥ 768 且横屏：pad 横屏 / 桌面窗口 —— 左右分栏(左输入、右结果常驻)
  padLandscape;

  bool get isPhone => this == WindowSize.phone;
  bool get isPadPortrait => this == WindowSize.padPortrait;
  bool get isPadLandscape => this == WindowSize.padLandscape;

  /// 是否进入「大屏」(pad 竖或横，即非手机)。
  bool get isPad => this != WindowSize.phone;
}

/// 断点阈值与布局 token。
class Breakpoints {
  Breakpoints._();

  /// phone → pad 阈值 (dp)，对齐 plan 蓝图的 768。
  static const double pad = 768;

  /// 手机版式在大屏居中时的内容最大宽度 (dp)。
  static const double maxContentWidth = 600;

  /// pad 横屏分栏：左输入列 : 右结果列 占比 (对应 plan dive-plan 页 1fr:1fr)。
  static const int landscapeInputFlex = 1;
  static const int landscapeResultFlex = 1;
}

/// 由可用宽度 + 方向推出窗口档位。
WindowSize windowSizeFor(double width, Orientation orientation) {
  if (width < Breakpoints.pad) return WindowSize.phone;
  return orientation == Orientation.portrait
      ? WindowSize.padPortrait
      : WindowSize.padLandscape;
}

/// 便捷扩展：`context.windowSize`（按整窗尺寸 + 方向）。
extension WindowSizeContext on BuildContext {
  WindowSize get windowSize {
    final mq = MediaQuery.of(this);
    return windowSizeFor(mq.size.width, mq.orientation);
  }
}
