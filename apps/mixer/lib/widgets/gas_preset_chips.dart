// 气体预设 chips —— 点击一键填入 O₂% / He%
//
// 例子: [Air] [EAN32] [EAN36] [Tx18/45] ...

import 'package:flutter/material.dart';

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
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: presets.map((p) {
        final selected = (p.$2 - currentO2).abs() < 0.01 &&
            (p.$3 - currentHe).abs() < 0.01;
        return InkWell(
          onTap: () => onPick(p.$2, p.$3),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Text(
              p.$1,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
