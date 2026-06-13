// 主题工厂 —— 4 套主题 ThemeData，色板 1:1 对齐小程序（见 mixer_colors.dart）。
//
// 改动（vs 旧占位版）：不再用随手挑的 seedColor，而是用 MixerColors 的真实
// 小程序色值构建 ColorScheme，并把完整语义色板挂到 MixerColors ThemeExtension，
// 供组件读取 He/安全红/四级文字/tint 等 ColorScheme 放不下的 token。

import 'package:flutter/material.dart';

import 'colors.dart';

enum MixerThemeMode {
  /// 深海（夜晚潜水站）
  dark,

  /// 晴朗（白日海面）
  light,

  /// 马卡龙（柔和粉蓝）
  macaron,

  /// 糖果（高饱和度童趣）
  candy,
}

class MixerTheme {
  MixerTheme._();

  /// 中文名（供 UI 显示）
  static String nameOf(MixerThemeMode mode) => switch (mode) {
        MixerThemeMode.dark => '深海',
        MixerThemeMode.light => '晴朗',
        MixerThemeMode.macaron => '马卡龙',
        MixerThemeMode.candy => '糖果',
      };

  /// 该主题的语义色板。
  static MixerColors colorsFor(MixerThemeMode mode) => switch (mode) {
        MixerThemeMode.dark => MixerColors.dark,
        MixerThemeMode.light => MixerColors.light,
        MixerThemeMode.macaron => MixerColors.macaron,
        MixerThemeMode.candy => MixerColors.candy,
      };

  static ThemeData themeFor(MixerThemeMode mode) {
    final c = colorsFor(mode);
    final brightness =
        mode == MixerThemeMode.dark ? Brightness.dark : Brightness.light;

    // 以小程序主色作 seed 生成完整 Material 色阶，再覆盖关键语义色对齐小程序。
    final scheme = ColorScheme.fromSeed(
      seedColor: c.accentCyan,
      brightness: brightness,
    ).copyWith(
      primary: c.accentCyan,
      onPrimary: c.textOnAccent,
      secondary: c.accentTeal,
      onSecondary: c.textOnAccent,
      error: c.accentWarn,
      surface: c.bgCard,
      onSurface: c.textPrimary,
      outline: c.border,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bgDeep,
      cardColor: c.bgCard,
      appBarTheme: AppBarTheme(
        backgroundColor: c.bgDeep,
        foregroundColor: c.textPrimary,
        elevation: 0,
      ),
      // 完整语义色板挂这里；组件用 context.mixerColors 读取。
      extensions: <ThemeExtension<dynamic>>[c],
    );
  }
}
