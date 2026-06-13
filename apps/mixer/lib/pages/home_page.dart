// 主页：演示 dive_calc 包能跑通 + 主题切换。
//
// 这是 P0 阶段占位页，未来按 mixer 微信小程序的混气主页改造：
//   - 气瓶水容量 / 起始压 / 目标压输入
//   - 目标 O₂ / He 输入
//   - 显示混气方案（O₂/He/补气量 + bar 数）
//   - 显示 MOD@1.4 / MOD@1.6 / END / EADD 安全栏
//   - 历史记录入口

import 'package:dive_calc/dive_calc.dart';
import 'package:flutter/material.dart';

import 'package:dive_ui/dive_ui.dart';

class HomePage extends StatefulWidget {
  final MixerThemeMode currentTheme;
  final ValueChanged<MixerThemeMode> onThemeChanged;

  const HomePage({
    super.key,
    required this.currentTheme,
    required this.onThemeChanged,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // 演示数据：可调
  double _o2Pct = 32;
  double _hePct = 0;
  double _depth = 30;
  bool _saltWater = true;
  double _tempC = 24;

  final DiveCalculator _calc = DiveCalculator();

  @override
  Widget build(BuildContext context) {
    final mod14 = _calc.mod(MODInput(po2: 1.4, o2Pct: _o2Pct));
    final mod16 = _calc.mod(MODInput(po2: 1.6, o2Pct: _o2Pct));
    final end = _calc.end(ENDInput(
      gas: GasMix(o2Pct: _o2Pct, hePct: _hePct),
      depth: _depth,
    ));
    final eadd = _calc.eadd(EADDInput(
      gas: GasMix(o2Pct: _o2Pct, hePct: _hePct),
      depth: _depth,
    ));
    final ndl = _calc.ndl(NDLInput(
      o2Pct: _o2Pct,
      depthM: _depth,
      saltWater: _saltWater,
      tempC: _tempC,
    ));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dive Gas Mixer · POC'),
        actions: [
          PopupMenuButton<MixerThemeMode>(
            icon: const Icon(Icons.palette_outlined),
            tooltip: '切换主题',
            onSelected: widget.onThemeChanged,
            itemBuilder: (_) => MixerThemeMode.values
                .map((m) => PopupMenuItem(
                      value: m,
                      child: Row(
                        children: [
                          Icon(
                            m == widget.currentTheme
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(MixerTheme.nameOf(m)),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionTitle(context, '气体配比'),
            _slider(
              label: 'O₂ %',
              value: _o2Pct,
              min: 16,
              max: 100,
              onChanged: (v) => setState(() => _o2Pct = v),
            ),
            _slider(
              label: 'He %',
              value: _hePct,
              min: 0,
              max: 80,
              onChanged: (v) => setState(() => _hePct = v.clamp(0, 100 - _o2Pct)),
            ),
            const SizedBox(height: 16),
            _sectionTitle(context, '潜水条件'),
            _slider(
              label: '深度 (m)',
              value: _depth,
              min: 0,
              max: 80,
              onChanged: (v) => setState(() => _depth = v),
            ),
            SwitchListTile(
              title: const Text('海水（关闭=淡水）'),
              value: _saltWater,
              onChanged: (v) => setState(() => _saltWater = v),
              contentPadding: EdgeInsets.zero,
            ),
            _slider(
              label: '水温 (°C)',
              value: _tempC,
              min: -2,
              max: 32,
              onChanged: (v) => setState(() => _tempC = v),
            ),
            const SizedBox(height: 16),
            _sectionTitle(context, '算法结果（dive_calc）'),
            _resultCard(
              context,
              rows: [
                _ResultRow('MOD @ PO₂ 1.4', '$mod14 m'),
                _ResultRow('MOD @ PO₂ 1.6', '$mod16 m'),
                _ResultRow('END (@ $_depth m)', '$end m'),
                _ResultRow('EADD (@ $_depth m)', '$eadd m'),
                _ResultRow(
                  'NDL',
                  ndl >= 999 ? '∞ (浅水/无限制)' : '$ndl min',
                ),
              ],
            ),
            const SizedBox(height: 24),
            _devNote(context),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      );

  Widget _slider({
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 100,
              child: Text('$label  ${value.toStringAsFixed(0)}'),
            ),
            Expanded(
              child: Slider(
                value: value,
                min: min,
                max: max,
                divisions: (max - min).toInt(),
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      );

  Widget _resultCard(BuildContext context, {required List<_ResultRow> rows}) =>
      Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: rows
                .map((r) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(r.label),
                          Text(
                            r.value,
                            style:
                                Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ),
      );

  Widget _devNote(BuildContext context) => Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          '这是 P0 阶段的算法 POC 占位页 —— 验证 dive_calc Dart 包能在 Flutter 中正确调用。\n'
          '后续阶段会替换为完整的混气计算 UI（瓶压、补气量、安全栏等）。',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: Theme.of(context).hintColor,
              ),
        ),
      );
}

class _ResultRow {
  final String label;
  final String value;
  const _ResultRow(this.label, this.value);
}
