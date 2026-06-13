// 响应式窗口档位 —— 对齐 gas-dive-plan 的 iPad 适配蓝图（768 + 方向三档）。
//   < 768            → phone         手机竖屏/横屏      → 单列
//   ≥ 768 && 竖屏     → padPortrait   pad 竖屏/分屏窄    → 卡片双列网格
//   ≥ 768 && 横屏     → padLandscape  pad 横屏/桌面窗口  → 左右分栏 / 左侧 rail

import 'package:flutter/widgets.dart';

enum WindowSize {
  phone,
  padPortrait,
  padLandscape;

  bool get isPhone => this == WindowSize.phone;
  bool get isPadPortrait => this == WindowSize.padPortrait;
  bool get isPadLandscape => this == WindowSize.padLandscape;
  bool get isPad => this != WindowSize.phone;
}

class Breakpoints {
  Breakpoints._();

  /// phone → pad 阈值 (dp)
  static const double pad = 768;

  /// 单列内容最大宽度 (dp)
  static const double maxContentWidth = 600;

  /// 横屏分栏左右占比
  static const int landscapeInputFlex = 1;
  static const int landscapeResultFlex = 1;
}

WindowSize windowSizeFor(double width, Orientation orientation) {
  if (width < Breakpoints.pad) return WindowSize.phone;
  return orientation == Orientation.portrait
      ? WindowSize.padPortrait
      : WindowSize.padLandscape;
}

extension WindowSizeContext on BuildContext {
  WindowSize get windowSize {
    final mq = MediaQuery.of(this);
    return windowSizeFor(mq.size.width, mq.orientation);
  }
}
