// 数字输入组件 — 步进 +/- + 直接输入。
//
// 设计目标：
//   1. 修复原方案 `key: ValueKey('$label-$value')` 导致的输入 bug
//      （value 变化时 widget 重建 → 光标丢失 → 不能连续输入多位数字）
//   2. 适配移动端：大按钮、大字体、最少键盘输入
//   3. 兼容桌面：直接键盘输入也能用
//
// 用法：
//   NumberInput(
//     label: 'O₂',
//     suffix: '%',
//     value: o2,
//     min: 0, max: 100, step: 1,
//     onChanged: (v) => setState(() => _o2 = v),
//   )

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'num_pad.dart';

class NumberInput extends StatefulWidget {
  final String label;
  final String suffix;
  final double value;
  final double min;
  final double max;
  final double step;

  /// 大步长（双击 +/- 按钮触发，默认 = step×5）
  final double? bigStep;

  /// 显示精度（小数位）。null = 自动判断（整数显示 0 位，否则 1 位）
  final int? decimals;

  /// 颜色强调
  final Color? accentColor;
  final IconData? icon;

  final ValueChanged<double> onChanged;

  const NumberInput({
    super.key,
    required this.label,
    this.suffix = '',
    required this.value,
    this.min = 0,
    this.max = 1000,
    this.step = 1,
    this.bigStep,
    this.decimals,
    this.accentColor,
    this.icon,
    required this.onChanged,
  });

  @override
  State<NumberInput> createState() => _NumberInputState();
}

class _NumberInputState extends State<NumberInput> {
  late TextEditingController _ctrl;
  late FocusNode _focus;
  bool _userEditing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _fmt(widget.value));
    _focus = FocusNode();
    _focus.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(NumberInput old) {
    super.didUpdateWidget(old);
    // 用户正在编辑时不要打断
    if (_userEditing) return;
    // 外部 value 跟当前文本不一致时同步
    final parsed = double.tryParse(_ctrl.text);
    if (parsed == null || (parsed - widget.value).abs() > 1e-9) {
      _ctrl.text = _fmt(widget.value);
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focus.hasFocus) {
      _userEditing = true;
      // 聚焦时全选，便于直接覆盖输入
      _ctrl.selection = TextSelection(baseOffset: 0, extentOffset: _ctrl.text.length);
    } else {
      _userEditing = false;
      // 失焦时规范化显示
      _ctrl.text = _fmt(widget.value);
    }
  }

  String _fmt(double v) {
    final dec = widget.decimals ?? (v % 1 == 0 ? 0 : 1);
    return v.toStringAsFixed(dec);
  }

  void _bump(double delta) {
    final next = (widget.value + delta).clamp(widget.min, widget.max);
    widget.onChanged(next.toDouble());
    if (!_focus.hasFocus) {
      _ctrl.text = _fmt(next.toDouble());
    }
  }

  void _onTextChanged(String text) {
    final v = double.tryParse(text);
    if (v == null) return;
    if (v < widget.min || v > widget.max) return;
    widget.onChanged(v);
  }

  bool _isDesktop(BuildContext context) {
    if (kIsWeb) return false;
    final p = Theme.of(context).platform;
    return p == TargetPlatform.windows ||
        p == TargetPlatform.macOS ||
        p == TargetPlatform.linux;
  }

  Future<void> _openNumPad(BuildContext context) async {
    // 取消 TextField 聚焦避免双键盘
    _focus.unfocus();
    final decimals = widget.decimals ?? (widget.value % 1 == 0 ? 0 : 1);
    final result = await showNumPad(
      context,
      label: widget.label + (widget.suffix.isNotEmpty ? ' (${widget.suffix})' : ''),
      suffix: widget.suffix,
      initialValue: widget.value,
      min: widget.min,
      max: widget.max,
      decimals: decimals,
    );
    if (result != null) {
      widget.onChanged(result);
      if (mounted) {
        _ctrl.text = _fmt(result);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = widget.accentColor ?? scheme.primary;
    final big = widget.bigStep ?? widget.step * 5;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 2),
            child: Row(children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 14, color: accent),
                const SizedBox(width: 4),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ]),
          ),
          Row(
            children: [
              _stepBtn(
                icon: Icons.remove,
                onTap: () => _bump(-widget.step),
                onLongPress: () => _bump(-big),
              ),
              Expanded(
                child: _isDesktop(context)
                    // ─── Desktop: 点击弹数字键盘 BottomSheet ───
                    ? InkWell(
                        onTap: () => _openNumPad(context),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                _fmt(widget.value),
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: accent,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                ),
                              ),
                              if (widget.suffix.isNotEmpty) ...[
                                const SizedBox(width: 2),
                                Text(
                                  widget.suffix,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    // ─── Mobile/Web: TextField + 系统键盘 ───
                    : TextField(
                        controller: _ctrl,
                        focusNode: _focus,
                        textAlign: TextAlign.center,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true, signed: false),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}')),
                        ],
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 6),
                          suffixText:
                              widget.suffix.isNotEmpty ? widget.suffix : null,
                          suffixStyle: TextStyle(
                            fontSize: 13,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: accent,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        onChanged: _onTextChanged,
                      ),
              ),
              _stepBtn(
                icon: Icons.add,
                onTap: () => _bump(widget.step),
                onLongPress: () => _bump(big),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepBtn({
    required IconData icon,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: scheme.primary),
      ),
    );
  }
}

/// 预设气体 chip
class GasPresetChips extends StatelessWidget {
  /// (标签, o2%, he%)
  final List<(String, double, double)> presets;
  final void Function(double o2, double he) onPick;

  /// 当前选中的 (o2, he) — 用于高亮
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
