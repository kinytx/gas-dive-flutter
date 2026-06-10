// 语义色板 —— ThemeExtension，承载 ColorScheme 放不下的小程序 token。
//
// 色值 1:1 对齐 gas-mixer-shared/app.wxss 的 4 套主题（dark/light/macaron/candy）。
// 约束（来自 app.wxss 主题设计准则 + plan iPad 蓝图 §0）：
//   - accentWarn 安全红：跨主题恒定可识别，致命告警专用，不可弱化。
//   - accentHe 氦气橙：行业色标，每套主题保留可识别橙/珊瑚调，不可换语义。
//   - 数据文字一律 textPrimary；糖果系高饱和色只用于背景/卡片/装饰。
//
// 用法：Theme.of(context).extension<MixerColors>()!  或扩展 context.mixerColors。

import 'package:flutter/material.dart';

@immutable
class MixerColors extends ThemeExtension<MixerColors> {
  // 背景
  final Color bgDeep; // 页面底
  final Color bgCard; // 卡片
  final Color bgInput; // 输入凹陷

  // 强调
  final Color accentCyan; // 主色 / CTA
  final Color accentTeal; // 次色 / 渐变副色
  final Color accentHe; // 氦气（行业色标）
  final Color accentSuccess; // 成功 / 无需排气
  final Color accentWarn; // 警告 / 安全红线（跨主题恒定）

  // 文字
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textOnAccent; // CTA 按钮上的反色字

  // 边框
  final Color border;
  final Color borderActive;

  // tint（语义色浅高亮底，配实色 border 用）
  final Color tintCyan;
  final Color tintHe;
  final Color tintSuccess;
  final Color tintWarn;
  final Color tintNeutral;

  const MixerColors({
    required this.bgDeep,
    required this.bgCard,
    required this.bgInput,
    required this.accentCyan,
    required this.accentTeal,
    required this.accentHe,
    required this.accentSuccess,
    required this.accentWarn,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textOnAccent,
    required this.border,
    required this.borderActive,
    required this.tintCyan,
    required this.tintHe,
    required this.tintSuccess,
    required this.tintWarn,
    required this.tintNeutral,
  });

  @override
  MixerColors copyWith({
    Color? bgDeep,
    Color? bgCard,
    Color? bgInput,
    Color? accentCyan,
    Color? accentTeal,
    Color? accentHe,
    Color? accentSuccess,
    Color? accentWarn,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? textOnAccent,
    Color? border,
    Color? borderActive,
    Color? tintCyan,
    Color? tintHe,
    Color? tintSuccess,
    Color? tintWarn,
    Color? tintNeutral,
  }) {
    return MixerColors(
      bgDeep: bgDeep ?? this.bgDeep,
      bgCard: bgCard ?? this.bgCard,
      bgInput: bgInput ?? this.bgInput,
      accentCyan: accentCyan ?? this.accentCyan,
      accentTeal: accentTeal ?? this.accentTeal,
      accentHe: accentHe ?? this.accentHe,
      accentSuccess: accentSuccess ?? this.accentSuccess,
      accentWarn: accentWarn ?? this.accentWarn,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      textOnAccent: textOnAccent ?? this.textOnAccent,
      border: border ?? this.border,
      borderActive: borderActive ?? this.borderActive,
      tintCyan: tintCyan ?? this.tintCyan,
      tintHe: tintHe ?? this.tintHe,
      tintSuccess: tintSuccess ?? this.tintSuccess,
      tintWarn: tintWarn ?? this.tintWarn,
      tintNeutral: tintNeutral ?? this.tintNeutral,
    );
  }

  @override
  MixerColors lerp(ThemeExtension<MixerColors>? other, double t) {
    if (other is! MixerColors) return this;
    return MixerColors(
      bgDeep: Color.lerp(bgDeep, other.bgDeep, t)!,
      bgCard: Color.lerp(bgCard, other.bgCard, t)!,
      bgInput: Color.lerp(bgInput, other.bgInput, t)!,
      accentCyan: Color.lerp(accentCyan, other.accentCyan, t)!,
      accentTeal: Color.lerp(accentTeal, other.accentTeal, t)!,
      accentHe: Color.lerp(accentHe, other.accentHe, t)!,
      accentSuccess: Color.lerp(accentSuccess, other.accentSuccess, t)!,
      accentWarn: Color.lerp(accentWarn, other.accentWarn, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textOnAccent: Color.lerp(textOnAccent, other.textOnAccent, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderActive: Color.lerp(borderActive, other.borderActive, t)!,
      tintCyan: Color.lerp(tintCyan, other.tintCyan, t)!,
      tintHe: Color.lerp(tintHe, other.tintHe, t)!,
      tintSuccess: Color.lerp(tintSuccess, other.tintSuccess, t)!,
      tintWarn: Color.lerp(tintWarn, other.tintWarn, t)!,
      tintNeutral: Color.lerp(tintNeutral, other.tintNeutral, t)!,
    );
  }

  // ════════════════════════════════════════════════════════════
  // 4 套主题色值（对齐 app.wxss）
  // ════════════════════════════════════════════════════════════

  /// dark：默认深海主题
  static const MixerColors dark = MixerColors(
    bgDeep: Color(0xFF0A1628),
    bgCard: Color(0xFF0F2040),
    bgInput: Color(0xFF0D1F3A),
    accentCyan: Color(0xFF00D4FF),
    accentTeal: Color(0xFF00B8A9),
    accentHe: Color(0xFFF0A030),
    accentSuccess: Color(0xFF30D158),
    accentWarn: Color(0xFFFF3B30),
    textPrimary: Color(0xFFE8F4FD),
    textSecondary: Color(0xFF8AB4D4),
    textMuted: Color(0xFF6B8DB0),
    textOnAccent: Color(0xFF0A1628),
    border: Color.fromARGB(38, 0, 212, 255), // rgba(0,212,255,.15)
    borderActive: Color.fromARGB(128, 0, 212, 255), // .5
    tintCyan: Color.fromARGB(26, 0, 212, 255), // .10
    tintHe: Color.fromARGB(31, 240, 160, 48), // .12
    tintSuccess: Color.fromARGB(31, 48, 209, 88),
    tintWarn: Color.fromARGB(31, 255, 107, 53),
    tintNeutral: Color.fromARGB(38, 122, 156, 192), // .15
  );

  /// light：热带礁湖暖色
  static const MixerColors light = MixerColors(
    bgDeep: Color(0xFFFFFAEF),
    bgCard: Color(0xFFFFFFFF),
    bgInput: Color(0xFFEFFAF5),
    accentCyan: Color(0xFF4CB8A8),
    accentTeal: Color(0xFFF5A623),
    accentHe: Color(0xFFFF7E5F),
    accentSuccess: Color(0xFF7CC676),
    accentWarn: Color(0xFFE74C3C),
    textPrimary: Color(0xFF2A4A4D),
    textSecondary: Color(0xFF5A7A7D),
    textMuted: Color(0xFF9AB0B0),
    textOnAccent: Color(0xFFFFFFFF),
    border: Color.fromARGB(61, 76, 184, 168), // .24
    borderActive: Color.fromARGB(140, 76, 184, 168), // .55
    tintCyan: Color.fromARGB(36, 76, 184, 168), // .14
    tintHe: Color.fromARGB(36, 255, 126, 95),
    tintSuccess: Color.fromARGB(36, 124, 198, 118),
    tintWarn: Color.fromARGB(31, 231, 76, 60),
    tintNeutral: Color.fromARGB(36, 154, 176, 176),
  );

  /// macaron：马卡龙糖果系
  static const MixerColors macaron = MixerColors(
    bgDeep: Color(0xFFFFEAF2),
    bgCard: Color(0xFFFFF8FB),
    bgInput: Color(0xFFFFD6E2),
    accentCyan: Color(0xFFB8A8E8),
    accentTeal: Color(0xFFF5B8C8),
    accentHe: Color(0xFFFFB89E),
    accentSuccess: Color(0xFF9BE8B4),
    accentWarn: Color(0xFFFF9EA0),
    textPrimary: Color(0xFF3D3543),
    textSecondary: Color(0xFF6B5B73),
    textMuted: Color(0xFFA89AA5),
    textOnAccent: Color(0xFF3D3543),
    border: Color.fromARGB(82, 184, 168, 232), // .32
    borderActive: Color.fromARGB(153, 184, 168, 232), // .60
    tintCyan: Color.fromARGB(51, 184, 168, 232), // .20
    tintHe: Color.fromARGB(56, 255, 184, 158), // .22
    tintSuccess: Color.fromARGB(56, 155, 232, 180),
    tintWarn: Color.fromARGB(56, 255, 158, 160),
    tintNeutral: Color.fromARGB(51, 168, 154, 165),
  );

  /// candy：棒棒糖糖果系
  static const MixerColors candy = MixerColors(
    bgDeep: Color(0xFFE8F8FF),
    bgCard: Color(0xFFFFFFFF),
    bgInput: Color(0xFFD4F0FF),
    accentCyan: Color(0xFF4DC4FF),
    accentTeal: Color(0xFFFF7AB3),
    accentHe: Color(0xFF7ED957),
    accentSuccess: Color(0xFF7ED957),
    accentWarn: Color(0xFFFF5566),
    textPrimary: Color(0xFF1A3A4D),
    textSecondary: Color(0xFF4A6A85),
    textMuted: Color(0xFF7A9BB0),
    textOnAccent: Color(0xFFFFFFFF),
    border: Color.fromARGB(82, 77, 196, 255), // .32
    borderActive: Color.fromARGB(153, 77, 196, 255),
    tintCyan: Color.fromARGB(41, 77, 196, 255), // .16
    tintHe: Color.fromARGB(51, 126, 217, 87), // .20
    tintSuccess: Color.fromARGB(51, 126, 217, 87),
    tintWarn: Color.fromARGB(46, 255, 85, 102), // .18
    tintNeutral: Color.fromARGB(46, 122, 155, 176),
  );
}

/// 便捷读取：`context.mixerColors`
extension MixerColorsContext on BuildContext {
  MixerColors get mixerColors =>
      Theme.of(this).extension<MixerColors>() ?? MixerColors.dark;
}
