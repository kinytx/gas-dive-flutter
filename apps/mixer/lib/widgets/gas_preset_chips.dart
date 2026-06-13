// 气体预设 chips —— 点击一键填入 O₂% / He%。
// pill 样式对齐小程序 picker-chip：全圆 + 选中 tint 浅底 + cyan 文字 + 实色边。
//
// 例子: [Air] [EAN32] [EAN36] [Tx18/45] ...

import 'package:flutter/material.dart';

import 'package:dive_ui/dive_ui.dart';

class GasPresetChips extends StatelessWidget {
  /// (标签, o2%, he%)
  final List<(String, double, double)> presets;
  final void Function(double o2, double he) onPick;

  /// 当前的 (o2, he) — 用于高亮命中项
  final double currentO2;
  final double currentHe;

  const GasPresetChips({
    super.key,
    required this.presets,
    required this.onPick,
    required this.currentO2,
    required this.currentHe,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.mixerColors;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: presets.map((p) {
        final selected = (p.$2 - currentO2).abs() < 0.01 &&
            (p.$3 - currentHe).abs() < 0.01;
        return InkWell(
          onTap: () => onPick(p.$2, p.$3),
          borderRadius: BorderRadius.circular(Dimens.radiusPill),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? c.tintCyan : c.bgInput,
              borderRadius: BorderRadius.circular(Dimens.radiusPill),
              border: Border.all(
                color: selected ? c.borderActive : c.border,
              ),
            ),
            child: Text(
              p.$1,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? c.accentCyan : c.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
