// 数字输入字段 - 行式布局（label .... value suffix ✏）
//
// 点击弹数字小键盘 BottomSheet（num_pad.dart）。
// 跟 PickerField 互补：
//   PickerField：固定选项里选（如 O₂%/He%）
//   NumberField：任意数字输入（如压力、海拔、温度）

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'desktop_number_input.dart';
import 'num_pad.dart';

class NumberField extends StatelessWidget {
  final String label;
  final String suffix;
  final double value;
  final double min;
  final double max;
  final int decimals;
  final Color? accentColor;
  final IconData? icon;
  final ValueChanged<double> onChanged;

  const NumberField({
    super.key,
    required this.label,
    this.suffix = '',
    required this.value,
    this.min = 0,
    this.max = 999,
    this.decimals = 0,
    this.accentColor,
    this.icon,
    required this.onChanged,
  });

  /// 根据范围猜步长：
  ///   海拔 (range≥2000)  → 100
  ///   压力 (range≥200)   → 10
  ///   温度等 (range≥50)  → 1   ← 温度 -20~50，range=70 用 1°C 步长
  ///   else              → 1
  double _stepForRange(double range) {
    if (range >= 2000) return 100;
    if (range >= 200) return 10;
    return 1;
  }

  String _fmt(double v) {
    if (decimals == 0) return v.toStringAsFixed(0);
    final s = v.toStringAsFixed(decimals);
    return s.contains('.')
        ? s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')
        : s;
  }

  Future<void> _show(BuildContext context) async {
    final result = await showNumPad(
      context,
      label: label + (suffix.isNotEmpty ? ' ($suffix)' : ''),
      suffix: suffix,
      initialValue: value,
      min: min,
      max: max,
      decimals: decimals,
    );
    if (result != null) onChanged(result);
  }

  bool _isDesktop(BuildContext context) {
    if (kIsWeb) return false;
    final p = Theme.of(context).platform;
    return p == TargetPlatform.windows ||
        p == TargetPlatform.macOS ||
        p == TargetPlatform.linux;
  }

  @override
  Widget build(BuildContext context) {
    if (_isDesktop(context)) {
      // 桌面端：键盘直接输入 + 上下箭头微调
      return DesktopNumberInput(
        label: label,
        suffix: suffix,
        value: value,
        min: min,
        max: max,
        step: _stepForRange(max - min),
        decimals: decimals,
        icon: icon,
        accentColor: accentColor,
        onChanged: onChanged,
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final accent = accentColor ?? scheme.primary;
    return InkWell(
      onTap: () => _show(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              _fmt(value),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: accent,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (suffix.isNotEmpty) ...[
              const SizedBox(width: 2),
              Text(
                suffix,
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(width: 4),
            Icon(Icons.edit_outlined, size: 16, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
