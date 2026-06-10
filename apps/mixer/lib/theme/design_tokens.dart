// 设计 token（尺寸 / 圆角 / 间距 / 字号）—— 对齐 gas-mixer-shared/app.wxss。
//
// 换算约定：小程序 750rpx = 屏宽，iPhone 设计稿 1rpx ≈ 0.5dp，故 rpx→dp 约 ÷2。
// 颜色 token 不在这里，走主题（mixer_theme.dart + MixerColors ThemeExtension），
// 因为颜色随 4 套主题切换，而尺寸/字号跨主题恒定。
//
// 字号策略（vs plan 的 iPad「锁 px」）：flutter 用 dp，物理尺寸恒定、不随屏放大，
// 所以无需像小程序那样锁上限；这里给固定 dp，大屏顶多 +1~2 微调。

/// 间距 / 圆角 (dp)。
class Dimens {
  Dimens._();

  // ── 间距（mixer 页比全局 .card 更紧凑：app.wxss .container .card = 24/16rpx）──
  /// 页面左右边距 (28rpx)
  static const double pagePadding = 14;

  /// 卡片内边距 (mixer 页 24rpx)
  static const double cardPadding = 12;

  /// pad 大屏卡片内边距（plan 蓝图收紧到 ~22-24px）
  static const double cardPaddingPad = 16;

  /// 卡片间距 (16rpx)
  static const double cardGap = 8;

  /// chip / pill 内 gap (8-14rpx)
  static const double chipGap = 6;

  /// 分栏 / 双列网格列间距
  static const double splitGap = 12;

  // ── 圆角 (app.wxss) ──
  /// 卡片圆角 (20rpx)
  static const double radiusCard = 10;

  /// 小元素 / 入口圆角 (12-14rpx)
  static const double radiusSmall = 7;

  /// 告警圆角 (8rpx)
  static const double radiusAlert = 4;

  /// chip / pill 全圆 (100rpx)
  static const double radiusPill = 999;

  // ── 边框 ──
  /// 默认描边宽 (1rpx)
  static const double borderWidth = 0.5;
}

/// 字号层级 (dp) —— 对齐 app.wxss / mixer.wxss 实际用值。
class FontSizes {
  FontSizes._();

  /// 弱文字 / 副标 (20rpx)
  static const double muted = 10;

  /// 区块标题 section-title (22rpx，600，大写，字距)
  static const double section = 11;

  /// 入口标题 / 标签 (26rpx)
  static const double entry = 13;

  /// 正文基础 (28rpx)
  static const double body = 14;

  /// 致命告警 alert-critical (30rpx，700，跨设备恒定)
  static const double alert = 15;

  /// hero 标题 (32rpx，700)
  static const double hero = 16;

  /// 数据大字（填充量 / 压力读数等）
  static const double dataLarge = 22;
}
