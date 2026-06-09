// 桌面端数字输入字段 - 键盘直接编辑 + 上下箭头微调
//
// 设计：
//   - TextField 接受键盘输入（数字 + 小数点）
//   - 右侧两个小箭头 (▲▼) 增减 step
//   - 上下方向键也能调（焦点在 TextField 时）
//   - 离开焦点或回车时规范化显示
//
// 跟 PickerField / NumberField 不同：
//   - 不弹任何 BottomSheet
//   - 鼠标 + 键盘原生交互

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DesktopNumberInput extends StatefulWidget {
  final String label;
  final String suffix;
  final double value;
  final double min;
  final double max;
  final double step;
  final int decimals;
  final Color? accentColor;
  final IconData? icon;
  final ValueChanged<double> onChanged;

  const DesktopNumberInput({
    super.key,
    required this.label,
    this.suffix = '',
    required this.value,
    this.min = 0,
    this.max = 999,
    this.step = 1,
    this.decimals = 0,
    this.accentColor,
    this.icon,
    required this.onChanged,
  });

  @override
  State<DesktopNumberInput> createState() => _DesktopNumberInputState();
}

class _DesktopNumberInputState extends State<DesktopNumberInput> {
  late TextEditingController _ctrl;
  late FocusNode _focus;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _fmt(widget.value));
    _focus = FocusNode();
    _focus.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(DesktopNumberInput old) {
    super.didUpdateWidget(old);
    if (_editing) return;
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
      _editing = true;
      _ctrl.selection = TextSelection(
          baseOffset: 0, extentOffset: _ctrl.text.length);
    } else {
      _editing = false;
      _ctrl.text = _fmt(widget.value);
    }
  }

  String _fmt(double v) {
    if (widget.decimals == 0) return v.toStringAsFixed(0);
    final s = v.toStringAsFixed(widget.decimals);
    return s.contains('.')
        ? s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')
        : s;
  }

  void _bump(double delta) {
    final next = (widget.value + delta).clamp(widget.min, widget.max).toDouble();
    widget.onChanged(next);
    if (!_focus.hasFocus) _ctrl.text = _fmt(next);
  }

  void _onTextChanged(String text) {
    final v = double.tryParse(text);
    if (v == null) return;
    if (v < widget.min || v > widget.max) return;
    widget.onChanged(v);
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.arrowUp) {
      _bump(widget.step);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.arrowDown) {
      _bump(-widget.step);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = widget.accentColor ?? scheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          if (widget.icon != null) ...[
            Icon(widget.icon, size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
          ],
          Text(
            widget.label,
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 6),
          // 输入框
          Expanded(
            child: Focus(
              onKeyEvent: _onKey,
              child: TextField(
                controller: _ctrl,
                focusNode: _focus,
                textAlign: TextAlign.right,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: false),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: accent,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                onChanged: _onTextChanged,
                onSubmitted: (_) => _focus.unfocus(),
              ),
            ),
          ),
          if (widget.suffix.isNotEmpty) ...[
            const SizedBox(width: 2),
            Text(
              widget.suffix,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(width: 4),
          // 上下箭头微调
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _arrowBtn(Icons.arrow_drop_up, () => _bump(widget.step)),
              _arrowBtn(Icons.arrow_drop_down, () => _bump(-widget.step)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _arrowBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Icon(icon, size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}
