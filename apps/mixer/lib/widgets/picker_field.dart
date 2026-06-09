// 选项滚轮 picker — 对应 mixer 微信版的 <picker mode="selector">。
//
// 设计：
//   1. 点击 → 弹出 CupertinoPicker 滚轮 BottomSheet
//   2. 选项列表通过 options 传入（如 [16, 17, ..., 100]）
//   3. 行式布局：左标签 + 右当前值 + ▾ 箭头
//
// 跟 NumberField (num pad 数字键盘) 互补：
//   PickerField：固定选项里选（如 O₂%、He%）
//   NumberField：任意数字输入（如压力、海拔）

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'desktop_number_input.dart';

class PickerField extends StatelessWidget {
  final String label;
  final String suffix;
  final double value;
  final List<double> options;
  final Color? accentColor;
  final ValueChanged<double> onChanged;

  /// 显示值的格式化函数（默认整数 vs 小数自动判断）
  final String Function(double)? formatter;

  const PickerField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    this.suffix = '',
    this.accentColor,
    this.formatter,
    required this.onChanged,
  });

  String _fmt(double v) {
    if (formatter != null) return formatter!(v);
    return v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  }

  Future<void> _show(BuildContext context) async {
    // 找最接近 value 的 option 作为初始 index
    int initIdx = 0;
    double minDiff = double.infinity;
    for (var i = 0; i < options.length; i++) {
      final diff = (options[i] - value).abs();
      if (diff < minDiff) {
        minDiff = diff;
        initIdx = i;
      }
    }

    final result = await showModalBottomSheet<double>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PickerSheet(
        label: label,
        suffix: suffix,
        options: options,
        initIndex: initIdx,
        accentColor: accentColor ?? Theme.of(context).colorScheme.primary,
        formatter: _fmt,
      ),
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
      // 桌面端：键盘直接输入 TextField + 上下箭头微调，不弹滚轮 picker
      final sortedOptions = [...options]..sort();
      final step =
          sortedOptions.length >= 2 ? sortedOptions[1] - sortedOptions[0] : 1.0;
      return DesktopNumberInput(
        label: label,
        suffix: suffix,
        value: value,
        min: sortedOptions.first,
        max: sortedOptions.last,
        step: step,
        decimals: 0,
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
            Icon(Icons.arrow_drop_down, size: 22, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// 滚轮 BottomSheet
// ════════════════════════════════════════════════════════════

class _PickerSheet extends StatefulWidget {
  final String label;
  final String suffix;
  final List<double> options;
  final int initIndex;
  final Color accentColor;
  final String Function(double) formatter;

  const _PickerSheet({
    required this.label,
    required this.suffix,
    required this.options,
    required this.initIndex,
    required this.accentColor,
    required this.formatter,
  });

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  late int _idx;
  late FixedExtentScrollController _ctrl;

  @override
  void initState() {
    super.initState();
    _idx = widget.initIndex;
    _ctrl = FixedExtentScrollController(initialItem: widget.initIndex);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(widget.options[_idx]);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          // drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: scheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // 标签 + 当前选中预览
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 14,
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      widget.formatter(widget.options[_idx]),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: widget.accentColor,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (widget.suffix.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Text(
                        widget.suffix,
                        style: TextStyle(
                          fontSize: 14,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 滚轮选项
          SizedBox(
            height: 200,
            child: CupertinoPicker(
              scrollController: _ctrl,
              itemExtent: 40,
              looping: false,
              backgroundColor: Colors.transparent,
              onSelectedItemChanged: (i) => setState(() => _idx = i),
              children: widget.options.map((v) {
                return Center(
                  child: Text(
                    widget.formatter(v),
                    style: TextStyle(
                      fontSize: 20,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: scheme.onSurface,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // 取消 / 完成
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('完成'),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16 + MediaQuery.paddingOf(context).bottom),
        ],
      ),
    );
  }
}
