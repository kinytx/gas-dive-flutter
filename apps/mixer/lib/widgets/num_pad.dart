// 屏幕数字键盘 — 在 BottomSheet 里弹出 3×4 数字网格。
//
// 设计目标：
//   1. Windows / 桌面端 TextField 默认不弹系统键盘，物理键盘也不够触屏友好。
//      这里弹一个屏幕键盘让用户直接点。
//   2. 同时监听物理键盘事件 (KeyboardListener)：用户可以打字、按 Enter 提交、Esc 取消。
//   3. 输入实时显示在顶部大字体；点 ⌫ 退一位，点完成 → 校验 + 返回。
//
// 用法：
//   final v = await showNumPad(
//     context,
//     label: 'O₂',
//     suffix: '%',
//     initialValue: 32,
//     min: 0, max: 100, decimals: 0,
//   );

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 弹出数字键盘 BottomSheet，返回用户输入的值（null = 取消）。
Future<double?> showNumPad(
  BuildContext context, {
  required String label,
  String suffix = '',
  required double initialValue,
  double min = 0,
  double max = 999,
  int decimals = 0,
}) {
  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => OnScreenNumPad(
      label: label,
      suffix: suffix,
      initialValue: initialValue,
      min: min,
      max: max,
      decimals: decimals,
    ),
  );
}

class OnScreenNumPad extends StatefulWidget {
  final String label;
  final String suffix;
  final double initialValue;
  final double min;
  final double max;
  final int decimals;

  const OnScreenNumPad({
    super.key,
    required this.label,
    this.suffix = '',
    required this.initialValue,
    this.min = 0,
    this.max = 999,
    this.decimals = 0,
  });

  @override
  State<OnScreenNumPad> createState() => _OnScreenNumPadState();
}

class _OnScreenNumPadState extends State<OnScreenNumPad> {
  late String _buffer;
  bool _firstKey = true; // 第一次按键时清空旧值（覆盖式输入）
  late FocusNode _keyFocus;

  @override
  void initState() {
    super.initState();
    _buffer = _fmtInit(widget.initialValue);
    _keyFocus = FocusNode();
    // 延迟 requestFocus 确保 BottomSheet 完全展开
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _keyFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _keyFocus.dispose();
    super.dispose();
  }

  String _fmtInit(double v) {
    if (widget.decimals == 0) return v.toStringAsFixed(0);
    // 去掉尾随 0
    final s = v.toStringAsFixed(widget.decimals);
    return s.contains('.') ? s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '') : s;
  }

  void _press(String key) {
    setState(() {
      // 首次按键覆盖原值（除了 ⌫ 和 ✓）
      if (_firstKey && key != 'BS' && key != 'OK') {
        _buffer = '';
        _firstKey = false;
      }

      if (key == 'BS') {
        if (_buffer.isNotEmpty) _buffer = _buffer.substring(0, _buffer.length - 1);
        _firstKey = false;
      } else if (key == 'OK') {
        _submit();
      } else if (key == '.') {
        if (widget.decimals == 0) return; // 整数模式禁小数点
        if (!_buffer.contains('.')) _buffer = _buffer.isEmpty ? '0.' : '$_buffer.';
      } else if (key == 'CLEAR') {
        _buffer = '';
      } else {
        // 0-9
        if (_buffer.length >= 6) return; // 最多 6 位
        if (_buffer == '0') _buffer = key; // 前导 0 替换
        else _buffer = '$_buffer$key';
      }
    });
  }

  void _submit() {
    final v = double.tryParse(_buffer.isEmpty ? '0' : _buffer);
    if (v == null) return;
    final clamped = v.clamp(widget.min, widget.max).toDouble();
    Navigator.of(context).pop(clamped);
  }

  void _onKey(KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return;
    final ch = e.character;
    if (ch != null && RegExp(r'^\d$').hasMatch(ch)) {
      _press(ch);
    } else if (ch == '.') {
      _press('.');
    } else if (e.logicalKey == LogicalKeyboardKey.backspace) {
      _press('BS');
    } else if (e.logicalKey == LogicalKeyboardKey.enter ||
        e.logicalKey == LogicalKeyboardKey.numpadEnter) {
      _submit();
    } else if (e.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return KeyboardListener(
      focusNode: _keyFocus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 20,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 顶部 drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // 标签
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 14,
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 大字体显示当前输入
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    _buffer.isEmpty ? '0' : _buffer,
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (widget.suffix.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Text(
                      widget.suffix,
                      style: TextStyle(
                        fontSize: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '范围 ${_fmtInit(widget.min)} – ${_fmtInit(widget.max)}',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),

            // 数字网格 3×4
            _gridRow(['7', '8', '9']),
            _gridRow(['4', '5', '6']),
            _gridRow(['1', '2', '3']),
            _gridRow([widget.decimals > 0 ? '.' : 'CLEAR', '0', 'BS']),

            const SizedBox(height: 12),

            // 底部 取消 / 完成
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('完成'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '提示：物理键盘可直接输入 · Enter 确认 · Esc 取消 · Backspace 删除',
              style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _gridRow(List<String> keys) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: keys.map((k) => Expanded(child: _numKey(k))).toList(),
      ),
    );
  }

  Widget _numKey(String key) {
    final scheme = Theme.of(context).colorScheme;
    Widget child;
    Color? bg;
    Color? fg;

    if (key == 'BS') {
      child = const Icon(Icons.backspace_outlined, size: 22);
      bg = scheme.errorContainer.withValues(alpha: 0.5);
      fg = scheme.onErrorContainer;
    } else if (key == 'CLEAR') {
      child = const Text('C', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600));
      bg = scheme.surfaceContainerHigh;
      fg = scheme.onSurfaceVariant;
    } else {
      child = Text(
        key,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      );
      bg = scheme.surfaceContainerHighest;
      fg = scheme.onSurface;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _press(key),
          child: Container(
            height: 56,
            alignment: Alignment.center,
            child: DefaultTextStyle.merge(
              style: TextStyle(color: fg),
              child: IconTheme(
                data: IconThemeData(color: fg),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
