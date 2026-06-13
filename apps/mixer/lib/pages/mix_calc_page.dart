// 主页：完整混气计算 UI (V3.2 — 移动端 picker 布局)。
//
// V3.2 改动：
//   - 气瓶 O₂%/He% 改用 PickerField (CupertinoPicker 滚轮 BottomSheet)
//     对齐 mixer 微信版 <picker mode="selector"> 体验
//   - 压力 / 海拔 / 温度 用 NumberField (点击弹数字键盘)
//   - 废弃手机端 +/- 按钮（横向空间不够 + 不符合小程序习惯）
//   - 每参数行式布局：[O₂  21 % ▾] [He  0 % ▾] / [起始压  50 bar ✏]

import 'package:dive_calc/dive_calc.dart' as dc;
import 'package:flutter/material.dart';
import 'package:mixer_core/mixer_core.dart';

import '../models/history_entry.dart';
import '../models/weather_info.dart';
import '../services/history_service.dart';
import 'package:dive_ui/dive_ui.dart';
import '../widgets/gas_preset_chips.dart';
import '../widgets/hero_weather.dart';
import '../widgets/number_field.dart';
import '../widgets/picker_field.dart';
import 'account_page.dart';
import 'history_page.dart';
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
  double _currentO2 = 21;
  double _currentHe = 0;
  double _currentPressure = 50;
  double _targetO2 = 32;
  double _targetHe = 0;
  double _targetPressure = 200;
  FillOrder _fillOrder = FillOrder.heFirst;

  // 高级参数
  double _altitudeM = 0;
  AltitudeMode _altitudeMode = AltitudeMode.b;
  double _tempC = 20;
  PressureRef _pressureRef = PressureRef.fill;
  bool _advancedExpanded = false;
  bool _useRealGases = false;

  /// 用户是否手动改过温度（true 后天气更新不再覆盖）
  bool _userEditedTemp = false;

  final GasMixer _mixer = GasMixer();

  // Picker 选项列表（对齐 mixer 微信版 config/app.ts）
  /// O₂ 5-100，跟 mixer 的 O2_PICKER.{MIN_PCT,MAX_PCT} 一致
  static final List<double> _o2Options =
      List.generate(96, (i) => (i + 5).toDouble()); // 5-100

  /// He 0-100，跟 mixer 的 pctOptions 一致（Array.from(length: 101)）
  static final List<double> _heOptions =
      List.generate(101, (i) => i.toDouble()); // 0-100

  /// 目标压力 picker：150-300 步 5 + 232 特殊（mixer PRESSURE_PICKER）
  /// 232 bar = 232 ATM 是常见钢瓶工作压力（如 European 12L 232bar 钢瓶）
  static final List<double> _pressureOptions = _buildPressureOptions();

  static List<double> _buildPressureOptions() {
    final list = <double>[];
    for (var bar = 150; bar <= 300; bar += 5) {
      list.add(bar.toDouble());
      if (bar == 230) list.add(232); // 230 后插 232
    }
    return list;
  }

  /// 起始压（残气）picker：0-300 步 10（残气场景更粗）
  static final List<double> _currentPressureOptions =
      List.generate(31, (i) => (i * 10).toDouble()); // 0, 10, 20, ..., 300

  // 目标气体预设
  static const List<(String, double, double)> _targetPresets = [
    ('Air', 21, 0),
    ('EAN32', 32, 0),
    ('EAN36', 36, 0),
    ('EAN40', 40, 0),
    ('EAN50', 50, 0),
    ('O₂', 100, 0),
    ('Tx21/35', 21, 35),
    ('Tx18/45', 18, 45),
    ('Tx15/55', 15, 55),
    ('Tx10/70', 10, 70),
  ];

  // 当前气体预设
  static const List<(String, double, double)> _currentPresets = [
    ('空瓶', 21, 0),
    ('残 Air', 21, 0),
    ('残 EAN32', 32, 0),
  ];

  void _setCurrentO2(double v) => setState(() {
        _currentO2 = v;
        if (_currentO2 + _currentHe > 100) {
          _currentHe = (100 - _currentO2).clamp(0, 95);
        }
      });

  void _setCurrentHe(double v) => setState(() {
        _currentHe = v;
        if (_currentO2 + _currentHe > 100) {
          _currentO2 = (100 - _currentHe).clamp(0, 100);
        }
      });

  void _setTargetO2(double v) => setState(() {
        _targetO2 = v;
        if (_targetO2 + _targetHe > 100) {
          _targetHe = (100 - _targetO2).clamp(0, 95);
        }
      });

  void _setTargetHe(double v) => setState(() {
        _targetHe = v;
        if (_targetO2 + _targetHe > 100) {
          _targetO2 = (100 - _targetHe).clamp(0, 100);
        }
      });

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
      altitudeM: _altitudeM,
      altitudeMode: _altitudeMode,
      tempC: _tempC,
      pressureRef: _pressureRef,
      useRealGases: _useRealGases,
    ));

    return Scaffold(
      appBar: AppBar(
        title: const Text('气体填充'),
        actions: [
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final ws = windowSizeFor(
              constraints.maxWidth, MediaQuery.orientationOf(context));
          return switch (ws) {
            WindowSize.phone => _buildPhone(result),
            WindowSize.padPortrait => _buildPadPortrait(result),
            WindowSize.padLandscape => _buildPadLandscape(result),
          };
        },
      ),
    );
  }

  /// 天气加载完成，自动同步温度（用户未手动改过时）
  void _onWeatherLoaded(WeatherInfo info) {
    if (_userEditedTemp || !mounted) return;
    setState(() => _tempC = info.current.tempC.roundToDouble());
  }

  // ════════════════════════════════════════════════════════════
  // 当前气瓶卡片
  // ════════════════════════════════════════════════════════════

  Widget _currentGasCard() => _sectionCard(
        icon: Icons.battery_3_bar,
        title: '当前气瓶',
        accent: Colors.amber,
        children: [
          Row(children: [
            Expanded(child: PickerField(
              label: 'O₂', suffix: '%',
              value: _currentO2, options: _o2Options,
              accentColor: Colors.lightBlueAccent,
              onChanged: _setCurrentO2,
            )),
            const SizedBox(width: 8),
            Expanded(child: PickerField(
              label: 'He', suffix: '%',
              value: _currentHe, options: _heOptions,
              accentColor: Colors.cyan,
              onChanged: _setCurrentHe,
            )),
          ]),
          const SizedBox(height: 8),
          // 起始压：跟 mixer 微信版 <numeric-field> 一致，直接输入（手机弹 num pad，桌面 inline TextField）
          NumberField(
            label: '起始压', suffix: 'bar',
            value: _currentPressure, min: 0, max: 300, decimals: 0,
            accentColor: Colors.amber,
            onChanged: (v) => setState(() => _currentPressure = v),
          ),
          const SizedBox(height: 10),
          GasPresetChips(
            presets: _currentPresets,
            currentO2: _currentO2,
            currentHe: _currentHe,
            onPick: (o2, he) => setState(() {
              _currentO2 = o2;
              _currentHe = he;
            }),
          ),
        ],
      );

  // ════════════════════════════════════════════════════════════
  // 目标气体卡片
  // ════════════════════════════════════════════════════════════

  Widget _targetGasCard() => _sectionCard(
        icon: Icons.flag_outlined,
        title: '目标气体',
        accent: Theme.of(context).colorScheme.primary,
        children: [
          Row(children: [
            Expanded(child: PickerField(
              label: 'O₂', suffix: '%',
              value: _targetO2, options: _o2Options,
              accentColor: Colors.lightBlueAccent,
              onChanged: _setTargetO2,
            )),
            const SizedBox(width: 8),
            Expanded(child: PickerField(
              label: 'He', suffix: '%',
              value: _targetHe, options: _heOptions,
              accentColor: Colors.cyan,
              onChanged: _setTargetHe,
            )),
          ]),
          const SizedBox(height: 8),
          PickerField(
            label: '目标压', suffix: 'bar',
            value: _targetPressure, options: _pressureOptions,
            accentColor: Theme.of(context).colorScheme.primary,
            onChanged: (v) => setState(() => _targetPressure = v),
          ),
          const SizedBox(height: 10),
          GasPresetChips(
            presets: _targetPresets,
            currentO2: _targetO2,
            currentHe: _targetHe,
            onPick: (o2, he) => setState(() {
              _targetO2 = o2;
              _targetHe = he;
            }),
          ),
        ],
      );

  // ════════════════════════════════════════════════════════════
  // 高级选项
  // ════════════════════════════════════════════════════════════

  Widget _advancedCard() => Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
              color: Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  .withValues(alpha: 0.5)),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: _advancedExpanded,
            onExpansionChanged: (v) =>
                setState(() => _advancedExpanded = v),
            tilePadding: const EdgeInsets.symmetric(horizontal: 16),
            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            leading: const Icon(Icons.tune, size: 20),
            title: const Text('高级选项'),
            subtitle: _advancedSubtitle(),
            children: [
              Row(children: [
                Expanded(child: NumberField(
                  label: '海拔', suffix: 'm', icon: Icons.terrain,
                  value: _altitudeM, min: 0, max: 5000,
                  onChanged: (v) => setState(() => _altitudeM = v),
                )),
                const SizedBox(width: 8),
                Expanded(child: NumberField(
                  label: '温度', suffix: '°C', icon: Icons.thermostat,
                  value: _tempC, min: -20, max: 50,
                  onChanged: (v) => setState(() {
                    _tempC = v;
                    _userEditedTemp = true; // 用户手动改后不再被天气覆盖
                  }),
                )),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                const SizedBox(width: 72, child: Text('修正模式', style: TextStyle(fontSize: 12))),
                Expanded(
                  child: SegmentedButton<AltitudeMode>(
                    segments: const [
                      ButtonSegment(value: AltitudeMode.none, label: Text('无')),
                      ButtonSegment(value: AltitudeMode.a, label: Text('A')),
                      ButtonSegment(value: AltitudeMode.b, label: Text('B')),
                      ButtonSegment(value: AltitudeMode.c, label: Text('C')),
                      ButtonSegment(value: AltitudeMode.d, label: Text('D')),
                    ],
                    selected: {_altitudeMode},
                    onSelectionChanged: (s) => setState(() => _altitudeMode = s.first),
                    showSelectedIcon: false,
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 11)),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                const SizedBox(width: 72, child: Text('压力基准', style: TextStyle(fontSize: 12))),
                Expanded(
                  child: SegmentedButton<PressureRef>(
                    segments: const [
                      ButtonSegment(value: PressureRef.fill, label: Text('fill (填充温度)')),
                      ButtonSegment(value: PressureRef.std, label: Text('std (21°C)')),
                    ],
                    selected: {_pressureRef},
                    onSelectionChanged: (s) => setState(() => _pressureRef = s.first),
                    showSelectedIcon: false,
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 11)),
                    ),
                  ),
                ),
              ]),
              SwitchListTile(
                title: const Text('真实气体修正 (Z 因子)', style: TextStyle(fontSize: 13)),
                subtitle: const Text('200bar 时 ~2-3% 修正；CCR / 高压填充推荐开启',
                    style: TextStyle(fontSize: 11)),
                value: _useRealGases,
                onChanged: (v) => setState(() => _useRealGases = v),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ],
          ),
        ),
      );

  Widget? _advancedSubtitle() {
    final hasAlt = _altitudeM > 0;
    final hasStd = _pressureRef == PressureRef.std;
    if (!hasAlt && !hasStd && !_useRealGases) return null;
    final parts = <String>[];
    if (hasAlt) parts.add('海拔 ${_altitudeM.toStringAsFixed(0)}m·${_altitudeMode.name.toUpperCase()}');
    if (hasStd) parts.add('std @ ${_tempC.toStringAsFixed(0)}°C');
    if (_useRealGases) parts.add('Z 因子');
    return Text(
      parts.join(' · '),
      style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 11),
    );
  }

  // ════════════════════════════════════════════════════════════
  // 填充顺序
  // ════════════════════════════════════════════════════════════

  Widget _fillOrderCard() => Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            const Icon(Icons.swap_vert, size: 18),
            const SizedBox(width: 6),
            const Text('填充顺序', style: TextStyle(fontSize: 13)),
            const Spacer(),
            SegmentedButton<FillOrder>(
              segments: const [
                ButtonSegment(value: FillOrder.heFirst, label: Text('He→O₂→Air')),
                ButtonSegment(value: FillOrder.o2First, label: Text('O₂→Air→He')),
              ],
              selected: {_fillOrder},
              onSelectionChanged: (s) => setState(() => _fillOrder = s.first),
              showSelectedIcon: false,
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                textStyle: WidgetStateProperty.all(const TextStyle(fontSize: 10)),
              ),
            ),
          ]),
        ),
      );

  // ════════════════════════════════════════════════════════════
  // 结果区
  // ════════════════════════════════════════════════════════════

  Widget _resultArea(MixResult result) {
    if (!result.success) return _errorCard(result.error!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (result.warnings.isNotEmpty) _warningCard(result.warnings),
        if (result.needToDrain) _drainCard(result),
        if (result.altitudeInfo != null) _altitudeInfoCard(result.altitudeInfo!),
        if (result.fillGaugePressure != _targetPressure) _fillPressureCard(result),
        if (result.zFactors != null) _zFactorsCard(result.zFactors!),
        _fillSummaryCard(result),
        const SizedBox(height: 10),
        _stepsCard(result),
        const SizedBox(height: 10),
        _safetyCard(),
        const SizedBox(height: 14),
        Center(
          child: FilledButton.icon(
            onPressed: () => _saveToHistory(result),
            icon: const Icon(Icons.bookmark_add_outlined),
            label: const Text('保存到历史'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  // 响应式布局（三档：phone / padPortrait / padLandscape）
  // ════════════════════════════════════════════════════════════

  /// 输入卡片序列（三档复用）
  List<Widget> _inputCards() => [
        _currentGasCard(),
        const SizedBox(height: Dimens.cardGap),
        _targetGasCard(),
        const SizedBox(height: Dimens.cardGap),
        _advancedCard(),
        const SizedBox(height: Dimens.cardGap),
        _fillOrderCard(),
      ];

  /// 手机：单列纵向滚动（Hero 横跨 + 输入 + 结果）
  Widget _buildPhone(MixResult result) => SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HeroWeather(onLoaded: _onWeatherLoaded),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Dimens.pagePadding, 10, Dimens.pagePadding, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ..._inputCards(),
                  const SizedBox(height: 14),
                  _resultArea(result),
                ],
              ),
            ),
          ],
        ),
      );

  /// pad 竖屏：输入卡双列网格 + 结果全宽
  Widget _buildPadPortrait(MixResult result) => SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HeroWeather(onLoaded: _onWeatherLoaded),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Dimens.pagePadding, 10, Dimens.pagePadding, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _currentGasCard(),
                            const SizedBox(height: Dimens.cardGap),
                            _advancedCard(),
                          ],
                        ),
                      ),
                      const SizedBox(width: Dimens.splitGap),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _targetGasCard(),
                            const SizedBox(height: Dimens.cardGap),
                            _fillOrderCard(),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _resultArea(result),
                ],
              ),
            ),
          ],
        ),
      );

  /// pad 横屏 / 桌面：左输入滚动 | 右结果常驻滚动
  Widget _buildPadLandscape(MixResult result) => Column(
        children: [
          HeroWeather(onLoaded: _onWeatherLoaded),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: Breakpoints.landscapeInputFlex,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                        Dimens.pagePadding, 10, Dimens.cardGap, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _inputCards(),
                    ),
                  ),
                ),
                Container(
                    width: Dimens.borderWidth, color: context.mixerColors.border),
                Expanded(
                  flex: Breakpoints.landscapeResultFlex,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                        Dimens.cardGap, 10, Dimens.pagePadding, 20),
                    child: _resultArea(result),
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  // ════════════════════════════════════════════════════════════
  // 历史记录交互
  // ════════════════════════════════════════════════════════════

  CalculateMixParams _buildParams() => CalculateMixParams(
        currentO2: _currentO2,
        currentHe: _currentHe,
        currentPressure: _currentPressure,
        targetO2: _targetO2,
        targetHe: _targetHe,
        targetPressure: _targetPressure,
        fillOrder: _fillOrder,
        altitudeM: _altitudeM,
        altitudeMode: _altitudeMode,
        tempC: _tempC,
        pressureRef: _pressureRef,
        useRealGases: _useRealGases,
      );

  /// 匹配预设标签，没匹配上返回自定义标签
  String _detectPresetName() {
    for (final p in _targetPresets) {
      if (p.$2 == _targetO2 && p.$3 == _targetHe) return p.$1;
    }
    return '${_targetO2.toStringAsFixed(0)}/${_targetHe.toStringAsFixed(0)}';
  }

  Future<void> _saveToHistory(MixResult result) async {
    final entry = HistoryEntry.fromResult(
      params: _buildParams(),
      result: result,
      presetName: _detectPresetName(),
    );
    await HistoryService.save(entry);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
          const SizedBox(width: 8),
          Text('已保存：${entry.presetName} · ${entry.targetPressure.toStringAsFixed(0)} bar'),
        ]),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openHistory() async {
    final entry = await Navigator.of(context).push<HistoryEntry>(
      MaterialPageRoute(builder: (_) => const HistoryPage()),
    );
    if (entry != null && mounted) _applyHistoryEntry(entry);
  }

  void _applyHistoryEntry(HistoryEntry e) {
    setState(() {
      _currentO2 = e.currentO2;
      _currentHe = e.currentHe;
      _currentPressure = e.currentPressure;
      _targetO2 = e.targetO2;
      _targetHe = e.targetHe;
      _targetPressure = e.targetPressure;
      _useRealGases = e.useRealGases;
      _tempC = e.tempC;
      _pressureRef = e.pressureRef;
      _altitudeM = e.altitudeM;
      _altitudeMode = e.altitudeMode;
      _fillOrder = e.fillOrder;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已加载历史：${e.presetName} · ${_fmtRelTime(e.time)}'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _fmtRelTime(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return '刚刚';
    if (d.inHours < 1) return '${d.inMinutes} 分钟前';
    if (d.inDays < 1) return '${d.inHours} 小时前';
    return '${d.inDays} 天前';
  }

  Widget _errorCard(MixErrorCode err) {
    final (msg, hint) = _errorText(err);
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.errorContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          const Icon(Icons.error_outline, color: Colors.redAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
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
        return ('输入越界', 'O₂/He 百分比超出 0-100、压力为负、或海拔为负');
      case MixErrorCode.invalidCurrentGas:
        return ('当前气体 O₂ + He > 100%', '物理上不可能');
      case MixErrorCode.invalidTargetGas:
        return ('目标气体 O₂ + He > 100%', '物理上不可能');
      case MixErrorCode.targetPressureTooLow:
        return ('目标压力 ≤ 当前压力', '无空间继续填充');
    }
  }

  Widget _warningCard(List<MixWarning> warnings) {
    final text = warnings.map(_warningText).join('、');
    return _hintCard(
      icon: Icons.warning_amber_rounded,
      color: Colors.orange,
      title: text,
    );
  }

  String _warningText(MixWarning w) {
    switch (w) {
      case MixWarning.lowResidualPressure:
        return '残压 < 10 bar，气体成分可能不准确';
      case MixWarning.highResidualForO2Fill:                       // ← 加这两行
        return 'O₂ 填充起点瓶压偏高，建议先放气（绝热压缩自燃风险）';
    }
  }

  Widget _drainCard(MixResult r) => _hintCard(
        icon: Icons.water_drop_outlined,
        color: Colors.deepOrange,
        title: '需要先放气',
        subtitle: '当前混合气过富，放气到 ${r.drainToPressure.toStringAsFixed(1)} bar 后再开始填充',
      );

  Widget _altitudeInfoCard(AltitudeInfo info) {
    final changed = info.adjustedO2 != info.originalO2 || info.adjustedHe != info.originalHe;
    return _hintCard(
      icon: Icons.terrain,
      color: Theme.of(context).colorScheme.primary,
      title: '海拔 ${info.altitudeM.toStringAsFixed(0)}m · 当地大气压 ${info.pLocalBar.toStringAsFixed(3)} bar',
      subtitle: changed
          ? '修正模式 ${info.mode.name.toUpperCase()}: 目标从 '
              '${info.originalO2.toStringAsFixed(1)}/${info.originalHe.toStringAsFixed(0)} '
              '→ ${info.adjustedO2.toStringAsFixed(1)}/${info.adjustedHe.toStringAsFixed(0)}'
          : '模式 ${info.mode.name.toUpperCase()} 不改变目标 O₂/He',
    );
  }

  Widget _fillPressureCard(MixResult r) => _hintCard(
        icon: Icons.thermostat,
        color: Colors.teal,
        title: '温度折算：实际填到 ${r.fillGaugePressure.toStringAsFixed(1)} bar',
        subtitle: '${_tempC.toStringAsFixed(0)}°C → 21°C 时回到 ${_targetPressure.toStringAsFixed(0)} bar',
      );

  Widget _zFactorsCard(ZFactorSet z) => Card(
        elevation: 0,
        color: Colors.purple.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.functions, color: Colors.purple, size: 18),
                const SizedBox(width: 6),
                const Text('真实气体修正 (Z)', style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('@ ${_tempC.toStringAsFixed(0)}°C', style: Theme.of(context).textTheme.bodySmall),
              ]),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _zChip('O₂', z.oxygen, Colors.lightBlueAccent),
                  _zChip('He', z.helium, Colors.cyan),
                  _zChip('N₂', z.nitrogen, Colors.indigo),
                  _zChip('Air', z.air, Colors.grey),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _zChip(String label, double z, Color color) {
    final deviation = ((z - 1.0).abs() * 100).toStringAsFixed(1);
    return Column(
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: color, fontSize: 12)),
        const SizedBox(height: 2),
        Text(z.toStringAsFixed(3),
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()])),
        Text('$deviation%',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10)),
      ],
    );
  }

  Widget _hintCard({
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
  }) =>
      Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.30)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ]),
      );

  Widget _fillSummaryCard(MixResult r) => _sectionCard(
        icon: Icons.bolt,
        title: '需要充入',
        accent: Theme.of(context).colorScheme.primary,
        children: [
          _summaryRow('He', r.heliumToFill, Colors.cyan),
          _summaryRow('O₂', r.oxygenToFill, Colors.lightBlueAccent),
          _summaryRow('Air', r.airToFill, Colors.grey),
          const Divider(height: 16),
          _summaryRow(
            '总计',
            r.heliumToFill + r.oxygenToFill + r.airToFill,
            null,
            bold: true,
          ),
        ],
      );

  Widget _summaryRow(String label, double bar, Color? color, {bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              if (color != null) ...[
                Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
              ],
              Text(label, style: TextStyle(fontWeight: bold ? FontWeight.w600 : FontWeight.normal)),
            ]),
            Text(
              '${bar.toStringAsFixed(1)} bar',
              style: TextStyle(
                fontFeatures: const [FontFeature.tabularFigures()],
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                fontSize: bold ? 16 : 14,
              ),
            ),
          ],
        ),
      );

  Widget _stepsCard(MixResult r) {
    final startP = r.needToDrain ? r.drainToPressure : _currentPressure;
    return _sectionCard(
      icon: Icons.format_list_numbered,
      title: '填充步骤',
      accent: Theme.of(context).colorScheme.primary,
      trailing: Text('起 ${startP.toStringAsFixed(0)} bar${r.needToDrain ? '（放气后）' : ''}',
          style: Theme.of(context).textTheme.bodySmall),
      children: r.fillSequence.map(_stepTile).toList(),
    );
  }

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
          backgroundColor: color.withValues(alpha: 0.2),
          child: Text('${s.step}',
              style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text.rich(TextSpan(children: [
            const TextSpan(text: '充 '),
            TextSpan(text: s.gas.label, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
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
    final mod14 = calc.mod(dc.MODInput(po2: 1.4, o2Pct: _targetO2));
    final mod16 = calc.mod(dc.MODInput(po2: 1.6, o2Pct: _targetO2));
    final end30 = calc.end(dc.ENDInput(
      gas: dc.GasMix(o2Pct: _targetO2, hePct: _targetHe),
      depth: 30,
    ));
    return _sectionCard(
      icon: Icons.shield_outlined,
      title: '目标气体安全栏',
      accent: Theme.of(context).colorScheme.primary,
      children: [
        _safetyRow('MOD @ PO₂ 1.4', '$mod14 m', '安全最大深度'),
        _safetyRow('MOD @ PO₂ 1.6', '$mod16 m', '极限最大深度'),
        _safetyRow('END (@ 30m)', '$end30 m', '在 30m 的等效麻醉深度'),
      ],
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

  // ════════════════════════════════════════════════════════════
  // 共用：分块卡片
  // ════════════════════════════════════════════════════════════

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required Color accent,
    required List<Widget> children,
    Widget? trailing,
  }) =>
      Card(
        elevation: 0,
        color: context.mixerColors.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Dimens.radiusCard),
          side: BorderSide(color: context.mixerColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Dimens.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                // 小程序 section-title 左侧 accent 装饰条
                Container(
                  width: 3,
                  height: 14,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(icon, size: 16, color: accent),
                const SizedBox(width: 6),
                Text(title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: accent,
                      letterSpacing: 0.5,
                    )),
                if (trailing != null) ...[
                  const Spacer(),
                  trailing,
                ],
              ]),
              const SizedBox(height: 10),
              ...children,
            ],
          ),
        ),
      );
}
