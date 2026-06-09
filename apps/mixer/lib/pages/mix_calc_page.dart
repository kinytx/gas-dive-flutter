// 主页：完整混气计算 UI（P1 MVP）。
//
// 复刻 mixer 微信版核心流程：
//   1. 输入「当前气瓶」O₂/He/压力
//   2. 输入「目标气体」O₂/He/压力
//   3. 选择填充顺序 (he-first / o2-first)
//   4. 实时显示：fillHe / fillO₂ / fillAir + 填充步骤 + 安全栏 (MOD/END)
//   5. 错误友好提示（needDrain / invalidInput 等）
//
// 算法：packages/mixer_core 的 GasMixer（理想气体 MVP）
// 安全栏：packages/dive_calc 的 calcMOD / calcEND

import 'package:dive_calc/dive_calc.dart' as dc;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mixer_core/mixer_core.dart';

import '../theme/mixer_theme.dart';
import 'home_page.dart';

class MixCalcPage extends StatefulWidget {
  final MixerThemeMode currentTheme;
  final ValueChanged<MixerThemeMode> onThemeChanged;

  const MixCalcPage({
    super.key,
    required this.currentTheme,
    required this.onThemeChanged,
  });

  @override
  State<MixCalcPage> createState() => _MixCalcPageState();
}

class _MixCalcPageState extends State<MixCalcPage> {
  // 输入（默认值：经典场景 = 把 Air 残 50 bar 的瓶补成 Nitrox 32 满瓶 200 bar）
  double _currentO2 = 21;
  double _currentHe = 0;
  double _currentPressure = 50;
  double _targetO2 = 32;
  double _targetHe = 0;
  double _targetPressure = 200;
  FillOrder _fillOrder = FillOrder.heFirst;

  final GasMixer _mixer = GasMixer();

  @override
  Widget build(BuildContext context) {
    final result = _mixer.calculate(CalculateMixParams(
      currentO2: _currentO2,
      currentHe: _currentHe,
      currentPressure: _currentPressure,
      targetO2: _targetO2,
      targetHe: _targetHe,
      targetPressure: _targetPressure,
      fillOrder: _fillOrder,
    ));

    return Scaffold(
      appBar: AppBar(
        title: const Text('混气计算 · MVP'),
        actions: [
          IconButton(
            icon: const Icon(Icons.science_outlined),
            tooltip: '算法演示页',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => HomePage(
                currentTheme: widget.currentTheme,
                onThemeChanged: widget.onThemeChanged,
              ),
            )),
          ),
          PopupMenuButton<MixerThemeMode>(
            icon: const Icon(Icons.palette_outlined),
            tooltip: '切换主题',
            onSelected: widget.onThemeChanged,
            itemBuilder: (_) => MixerThemeMode.values
                .map((m) => PopupMenuItem(
                      value: m,
                      child: Row(children: [
                        Icon(
                          m == widget.currentTheme
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(MixerTheme.nameOf(m)),
                      ]),
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
            _gasCard(
              title: '当前气瓶',
              o2: _currentO2,
              he: _currentHe,
              pressure: _currentPressure,
              onO2: (v) => setState(() => _currentO2 = v),
              onHe: (v) => setState(() => _currentHe = v),
              onPressure: (v) => setState(() => _currentPressure = v),
              icon: Icons.battery_3_bar,
            ),
            const SizedBox(height: 12),
            _gasCard(
              title: '目标气体',
              o2: _targetO2,
              he: _targetHe,
              pressure: _targetPressure,
              onO2: (v) => setState(() => _targetO2 = v),
              onHe: (v) => setState(() => _targetHe = v),
              onPressure: (v) => setState(() => _targetPressure = v),
              icon: Icons.flag_outlined,
            ),
            const SizedBox(height: 12),
            _fillOrderCard(),
            const SizedBox(height: 16),
            _resultArea(result),
          ],
        ),
      ),
    );
  }

  Widget _gasCard({
    required String title,
    required double o2,
    required double he,
    required double pressure,
    required ValueChanged<double> onO2,
    required ValueChanged<double> onHe,
    required ValueChanged<double> onPressure,
    required IconData icon,
  }) =>
      Card(
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _numInput('O₂ %', o2, 0, 100, onO2)),
                const SizedBox(width: 12),
                Expanded(child: _numInput('He %', he, 0, 95, onHe)),
                const SizedBox(width: 12),
                Expanded(
                    child: _numInput('压力 bar', pressure, 0, 300, onPressure)),
              ]),
            ],
          ),
        ),
      );

  Widget _numInput(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return TextFormField(
      key: ValueKey('$label-$value'), // 切主题/重建时保留值
      initialValue: value.toStringAsFixed(value % 1 == 0 ? 0 : 1),
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true, signed: false),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
      ],
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      ),
      onChanged: (text) {
        final v = double.tryParse(text);
        if (v == null) return;
        onChanged(v.clamp(min, max));
      },
    );
  }

  Widget _fillOrderCard() => Card(
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            const Icon(Icons.swap_vert, size: 20),
            const SizedBox(width: 8),
            const Text('填充顺序'),
            const Spacer(),
            SegmentedButton<FillOrder>(
              segments: const [
                ButtonSegment(
                  value: FillOrder.heFirst,
                  label: Text('He → O₂ → Air'),
                ),
                ButtonSegment(
                  value: FillOrder.o2First,
                  label: Text('O₂ → Air → He'),
                ),
              ],
              selected: {_fillOrder},
              onSelectionChanged: (s) =>
                  setState(() => _fillOrder = s.first),
              showSelectedIcon: false,
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                textStyle: WidgetStateProperty.all(
                  const TextStyle(fontSize: 11),
                ),
              ),
            ),
          ]),
        ),
      );

  Widget _resultArea(MixResult result) {
    if (!result.success) {
      return _errorCard(result.error!);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (result.warnings.isNotEmpty) _warningCard(result.warnings),
        _fillSummaryCard(result),
        const SizedBox(height: 12),
        _stepsCard(result),
        const SizedBox(height: 12),
        _safetyCard(),
      ],
    );
  }

  Widget _errorCard(MixErrorCode err) {
    final (msg, hint) = _errorText(err);
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          const Icon(Icons.error_outline, color: Colors.redAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(msg,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                if (hint != null) ...[
                  const SizedBox(height: 4),
                  Text(hint, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ]),
      ),
    );
  }

  (String, String?) _errorText(MixErrorCode err) {
    switch (err) {
      case MixErrorCode.invalidInput:
        return ('输入越界', 'O₂ 或 He 百分比超出 0-100 范围，或压力为负');
      case MixErrorCode.invalidCurrentGas:
        return ('当前气体 O₂ + He > 100%', '物理上不可能，请检查输入');
      case MixErrorCode.invalidTargetGas:
        return ('目标气体 O₂ + He > 100%', '物理上不可能，请检查输入');
      case MixErrorCode.targetPressureTooLow:
        return ('目标压力 ≤ 当前压力', '无空间继续填充，请调高目标压力或先放气');
      case MixErrorCode.needDrain:
        return (
          '需要先放气',
          '当前混合气过富（O₂ 或 He 比目标多），无法靠"加气"配出目标。请先放气到较低压力再重新填充。'
        );
    }
  }

  Widget _warningCard(List<MixWarning> warnings) {
    final text = warnings.map(_warningText).join('、');
    return Card(
      color: Colors.orange.withOpacity(0.15),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ]),
      ),
    );
  }

  String _warningText(MixWarning w) {
    switch (w) {
      case MixWarning.lowResidualPressure:
        return '残压 < 10 bar，气体成分可能不准确';
    }
  }

  Widget _fillSummaryCard(MixResult r) => Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('需要充入',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      )),
              const SizedBox(height: 8),
              _summaryRow('He', r.heliumToFill, Colors.cyan),
              _summaryRow('O₂', r.oxygenToFill, Colors.lightBlueAccent),
              _summaryRow('Air', r.airToFill, Colors.grey),
              const Divider(),
              _summaryRow(
                '总计 (= 目标 - 当前)',
                r.heliumToFill + r.oxygenToFill + r.airToFill,
                null,
                bold: true,
              ),
            ],
          ),
        ),
      );

  Widget _summaryRow(String label, double bar, Color? color, {bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              if (color != null) ...[
                Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
              ],
              Text(label,
                  style: TextStyle(
                      fontWeight: bold ? FontWeight.w600 : FontWeight.normal)),
            ]),
            Text(
              '${bar.toStringAsFixed(1)} bar',
              style: TextStyle(
                fontFeatures: const [FontFeature.tabularFigures()],
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      );

  Widget _stepsCard(MixResult r) => Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Icon(Icons.format_list_numbered,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('填充步骤',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        )),
                const Spacer(),
                Text(
                  '起 ${_currentPressure.toStringAsFixed(0)} bar',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ]),
              const SizedBox(height: 8),
              ...r.fillSequence.map(_stepTile),
            ],
          ),
        ),
      );

  Widget _stepTile(FillStep s) {
    final color = switch (s.gas) {
      FillGas.he => Colors.cyan,
      FillGas.o2 => Colors.lightBlueAccent,
      FillGas.air => Colors.grey,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: color.withOpacity(0.2),
          child: Text(
            '${s.step}',
            style: TextStyle(
                color: color, fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text.rich(TextSpan(children: [
            const TextSpan(text: '充 '),
            TextSpan(
              text: s.gas.label,
              style: TextStyle(fontWeight: FontWeight.w600, color: color),
            ),
            TextSpan(text: '  ${s.fillBar.toStringAsFixed(1)} bar'),
          ])),
        ),
        Text('→ ${s.pressureBar.toStringAsFixed(0)} bar',
            style: TextStyle(
              fontFeatures: const [FontFeature.tabularFigures()],
              color: Theme.of(context).hintColor,
            )),
      ]),
    );
  }

  Widget _safetyCard() {
    final calc = dc.DiveCalculator();
    final mod14 =
        calc.mod(dc.MODInput(po2: 1.4, o2Pct: _targetO2));
    final mod16 =
        calc.mod(dc.MODInput(po2: 1.6, o2Pct: _targetO2));
    final end30 = calc.end(dc.ENDInput(
      gas: dc.GasMix(o2Pct: _targetO2, hePct: _targetHe),
      depth: 30,
    ));
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Icon(Icons.shield_outlined,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text('目标气体安全栏',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      )),
            ]),
            const SizedBox(height: 8),
            _safetyRow('MOD @ PO₂ 1.4', '$mod14 m', '安全最大深度'),
            _safetyRow('MOD @ PO₂ 1.6', '$mod16 m', '极限最大深度'),
            _safetyRow('END (@ 30m)', '$end30 m', '在 30m 的等效麻醉深度'),
          ],
        ),
      ),
    );
  }

  Widget _safetyRow(String label, String value, String hint) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label),
                  Text(hint,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).hintColor,
                          )),
                ],
              ),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
            ),
          ],
        ),
      );
}
