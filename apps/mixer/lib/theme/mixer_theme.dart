// 主题 token + ThemeData 工厂。
//
// 复刻 mixer 微信小程序的 4 套主题：dark / light / macaron / candy
// 当前阶段仅占位，色值与小程序基本对齐；未来按 mixer 的 CSS 变量精修。

import 'package:flutter/material.dart';

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
  static String nameOf(MixerThemeMode mode) {
    switch (mode) {
      case MixerThemeMode.dark:
        return '深海';
      case MixerThemeMode.light:
        return '晴朗';
      case MixerThemeMode.macaron:
        return '马卡龙';
      case MixerThemeMode.candy:
        return '糖果';
    }
  }

  static ThemeData themeFor(MixerThemeMode mode) {
    switch (mode) {
      case MixerThemeMode.dark:
        return _dark();
      case MixerThemeMode.light:
        return _light();
      case MixerThemeMode.macaron:
        return _macaron();
      case MixerThemeMode.candy:
        return _candy();
    }
  }

  static ThemeData _dark() => ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1976D2),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0A1929),
        cardColor: const Color(0xFF132F4C),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0A1929),
          elevation: 0,
        ),
      );

  static ThemeData _light() => ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2196F3),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        cardColor: Colors.white,
      );

  static ThemeData _macaron() => ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE91E63),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFFFF1F5),
        cardColor: const Color(0xFFFFE6EE),
      );

  static ThemeData _candy() => ThemeData(
        brightness: Brightness.light,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF9800),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFFFF8E1),
        cardColor: const Color(0xFFFFECB3),
      );
}
