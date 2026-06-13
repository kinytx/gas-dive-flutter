// 设计 token（尺寸 / 圆角 / 间距 / 字号）—— 对齐 gas-mixer-shared/app.wxss。
// 换算：小程序 rpx → dp 约 ÷2。颜色 token 见 colors.dart。

/// 间距 / 圆角 (dp)。
class Dimens {
  Dimens._();

  static const double pagePadding = 14; // 页边 28rpx
  static const double cardPadding = 12; // 卡片内边距 24rpx
  static const double cardPaddingPad = 16; // pad 大屏收紧
  static const double cardGap = 8; // 卡间 16rpx
  static const double chipGap = 6; // chip 内 gap
  static const double splitGap = 12; // 分栏/双列列间距

  static const double radiusCard = 10; // 卡 20rpx
  static const double radiusSmall = 7; // 入口 12-14rpx
  static const double radiusAlert = 4; // 告警 8rpx
  static const double radiusPill = 999; // chip 全圆 100rpx
  static const double borderWidth = 0.5; // 描边 1rpx
}

/// 字号层级 (dp) —— 对齐 app.wxss 实际用值。
class FontSizes {
  FontSizes._();

  static const double muted = 10; // 20rpx 弱文字
  static const double section = 11; // 22rpx 区块标题
  static const double entry = 13; // 26rpx 入口标题
  static const double body = 14; // 28rpx 正文
  static const double alert = 15; // 30rpx 告警
  static const double hero = 16; // 32rpx hero 标题
  static const double dataLarge = 22; // 数据大字
}
