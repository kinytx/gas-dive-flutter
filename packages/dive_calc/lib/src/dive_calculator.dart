/// 潜水通用计算器主体。
///
/// 翻译自 [gas-dive-mixer/shared/utils/dive-calc.ts]，保持类结构 + 向后兼容函数 API。
///
/// 所有方法都是纯函数（不读写实例状态、不触碰外部 IO），config 在构造时注入。
library;

import 'dart:math' as math;

import 'package:meta/meta.dart';

import 'constants.dart' as c;
import 'types.dart';

// ════════════════════════════════════════════════════════════
// 1. Config — 把所有常数（含原本散落的 magic number）集中起来
// ════════════════════════════════════════════════════════════

/// dive_calc 的可配置参数。所有字段都用 final，构造后不可变。
@immutable
class DiveCalcConfig {
  /// 海平面标准大气压 (bar)
  final double surfacePressure;

  /// 肺泡水蒸气分压 (bar)
  final double alveolarH2OPressure;

  /// 深度↔压力 换算因子 (m / bar)，原代码里硬编码为 10
  final double depthPerBar;

  /// 海水压力梯度 (bar/m)
  final double saltWaterGradient;

  /// 淡水压力梯度 (bar/m)
  final double freshWaterGradient;

  /// 空气中 N₂ 摩尔分数
  final double airN2Fraction;

  /// 空气中 O₂ 摩尔分数
  final double airO2Fraction;

  /// 气体摩尔质量 (g/L @ STP)
  final MolarMassMap molarMass;

  /// ZHL-16C N₂ 隔室表
  final List<ZHL16CCompartment> zhl16cN2Compartments;

  /// 温度修正：参考温度 (°C)
  final double tempCorrectionRef;

  /// 温度修正：每低 1°C 衰减比例
  final double tempCorrectionPerC;

  /// 温度修正：最低保留比例
  final double tempCorrectionMinFactor;

  /// END / EADD 计算时 O₂ 的默认麻醉系数（0 = 不计 O₂ 麻醉性）
  final double defaultNarcosis;

  /// NDL 视为无限制时返回的分钟数（原代码硬编码 999）
  final int unlimitedNDL;

  const DiveCalcConfig({
    required this.surfacePressure,
    required this.alveolarH2OPressure,
    required this.depthPerBar,
    required this.saltWaterGradient,
    required this.freshWaterGradient,
    required this.airN2Fraction,
    required this.airO2Fraction,
    required this.molarMass,
    required this.zhl16cN2Compartments,
    required this.tempCorrectionRef,
    required this.tempCorrectionPerC,
    required this.tempCorrectionMinFactor,
    required this.defaultNarcosis,
    required this.unlimitedNDL,
  });

  /// 复制构造，便于改某一两个字段。
  DiveCalcConfig copyWith({
    double? surfacePressure,
    double? alveolarH2OPressure,
    double? depthPerBar,
    double? saltWaterGradient,
    double? freshWaterGradient,
    double? airN2Fraction,
    double? airO2Fraction,
    MolarMassMap? molarMass,
    List<ZHL16CCompartment>? zhl16cN2Compartments,
    double? tempCorrectionRef,
    double? tempCorrectionPerC,
    double? tempCorrectionMinFactor,
    double? defaultNarcosis,
    int? unlimitedNDL,
  }) =>
      DiveCalcConfig(
        surfacePressure: surfacePressure ?? this.surfacePressure,
        alveolarH2OPressure: alveolarH2OPressure ?? this.alveolarH2OPressure,
        depthPerBar: depthPerBar ?? this.depthPerBar,
        saltWaterGradient: saltWaterGradient ?? this.saltWaterGradient,
        freshWaterGradient: freshWaterGradient ?? this.freshWaterGradient,
        airN2Fraction: airN2Fraction ?? this.airN2Fraction,
        airO2Fraction: airO2Fraction ?? this.airO2Fraction,
        molarMass: molarMass ?? this.molarMass,
        zhl16cN2Compartments: zhl16cN2Compartments ?? this.zhl16cN2Compartments,
        tempCorrectionRef: tempCorrectionRef ?? this.tempCorrectionRef,
        tempCorrectionPerC: tempCorrectionPerC ?? this.tempCorrectionPerC,
        tempCorrectionMinFactor:
            tempCorrectionMinFactor ?? this.tempCorrectionMinFactor,
        defaultNarcosis: defaultNarcosis ?? this.defaultNarcosis,
        unlimitedNDL: unlimitedNDL ?? this.unlimitedNDL,
      );
}

/// 默认配置：来源于 [constants.dart] 中的物理 / 算法常数。
final DiveCalcConfig defaultDiveCalcConfig = DiveCalcConfig(
  surfacePressure: c.pSurface,
  alveolarH2OPressure: c.pAlveolarH2O,
  depthPerBar: c.depthPerBar,
  saltWaterGradient: c.pgSaltWater,
  freshWaterGradient: c.pgFreshWater,
  airN2Fraction: c.airN2Fraction,
  airO2Fraction: c.airO2Fraction,
  molarMass: c.molarMass,
  zhl16cN2Compartments: c.zhl16cN2Compartments,
  tempCorrectionRef: c.tempCorrectionRef,
  tempCorrectionPerC: c.tempCorrectionPerC,
  tempCorrectionMinFactor: c.tempCorrectionMinFactor,
  defaultNarcosis: 0,
  unlimitedNDL: c.unlimitedNDL,
);

// ════════════════════════════════════════════════════════════
// 2. DiveCalculator — 把核心逻辑封装到类，无副作用
// ════════════════════════════════════════════════════════════

/// 潜水通用计算器。
///
/// 所有方法都是纯函数（不读写实例状态、不触碰外部 IO），
/// config 在构造时注入并作为不可变引用持有。
class DiveCalculator {
  final DiveCalcConfig _config;

  DiveCalculator([DiveCalcConfig? config])
      : _config = config ?? defaultDiveCalcConfig;

  /// 暴露当前使用的 config（只读），便于外部测试 / 调试。
  DiveCalcConfig get config => _config;

  /// MOD（最大操作深度）
  ///
  /// MOD = (PO2 / (O2%/100) − pSurf) × depthPerBar  单位：米
  ///   pSurf 默认为海平面 1.013 bar；高海拔时传换算后的 surfacePressure，
  ///   ambient pressure = depth × 0.1 + pSurf 模型下反解 depth。
  int mod(MODInput input) {
    final po2 = input.po2;
    final o2Pct = input.o2Pct;
    if (o2Pct <= 0) return 0;
    final pSurf = input.surfacePressure ?? _config.surfacePressure;
    return ((po2 / (o2Pct / 100) - pSurf) * _config.depthPerBar).floor();
  }

  /// END（等效麻醉深度）
  ///
  /// narcosis: O₂ 的麻醉系数（默认 config.defaultNarcosis = 0，即不计 O₂ 麻醉性）。
  int end(ENDInput input) {
    final cfg = _config;
    final gas = input.gas;
    final depth = input.depth;
    final narcosis = input.narcosis ?? cfg.defaultNarcosis;
    final pSurf = input.surfacePressure ?? cfg.surfacePressure;

    final fO2 = gas.o2Pct / 100;
    final fHe = gas.hePct / 100;
    final fN2 = 1 - fO2 - fHe;
    final airNarc = cfg.airN2Fraction + cfg.airO2Fraction * narcosis;
    final gasNarc = (fN2 + fO2 * narcosis) * (depth / cfg.depthPerBar + pSurf);
    final endBar = gasNarc / airNarc;
    return math.max(0, ((endBar - pSurf) * cfg.depthPerBar).floor());
  }

  /// EADD（等效空气密度深度）
  ///
  /// 衡量呼吸阻力，而非麻醉风险。
  int eadd(EADDInput input) {
    final cfg = _config;
    final gas = input.gas;
    final depth = input.depth;
    final pSurf = input.surfacePressure ?? cfg.surfacePressure;

    final fO2 = gas.o2Pct / 100;
    final fHe = gas.hePct / 100;
    final fN2 = 1 - fO2 - fHe;
    final gasDensity =
        fO2 * cfg.molarMass.o2 + fHe * cfg.molarMass.he + fN2 * cfg.molarMass.n2;
    final ambPressure = depth / cfg.depthPerBar + pSurf;
    final eaddVal =
        (gasDensity * ambPressure / cfg.molarMass.air - pSurf) * cfg.depthPerBar;
    return eaddVal.floor();
  }

  /// 免减压极限（分钟），ZHL-16C 表面 M 值法。
  ///
  /// - saltWater: 海水/淡水
  /// - tempC: 水温，每低于参考温度降低 NDL
  int ndl(NDLInput input) {
    final cfg = _config;
    final o2Pct = input.o2Pct;
    final depthM = input.depthM;
    final saltWater = input.saltWater;
    final tempC = input.tempC;
    final pSurf = input.surfacePressure ?? cfg.surfacePressure;

    if (depthM <= 0) return cfg.unlimitedNDL;

    final pg = saltWater ? cfg.saltWaterGradient : cfg.freshWaterGradient;
    final fN2 = (100 - o2Pct) / 100;
    final pAmb = depthM * pg + pSurf;
    final palvN2 = fN2 * (pAmb - cfg.alveolarH2OPressure);
    // 起始组织 N₂ 饱和：在当前海拔（pSurf）已饱和。高海拔时 pSurf < 1，
    // 表示组织在地面就处于较低的 N₂ 分压，下水时 driving pressure 略大但 NDL 反而短
    // （因为 M 值也被 pSurf 拉低，过饱和上限更快触及）。
    final pt0 = cfg.airN2Fraction * (pSurf - cfg.alveolarH2OPressure);

    double ndlMin = double.infinity;
    for (final comp in cfg.zhl16cN2Compartments) {
      final mSurf = comp.a + pSurf / comp.b;
      if (palvN2 <= mSurf) continue;
      final ratio = (mSurf - palvN2) / (pt0 - palvN2);
      if (ratio <= 0) return 0;
      final t = -(comp.ht / math.ln2) * math.log(ratio);
      if (t < ndlMin) ndlMin = t;
    }
    final raw = ndlMin.isFinite ? ndlMin : cfg.unlimitedNDL.toDouble();
    final tempFactor = math.max(
      cfg.tempCorrectionMinFactor,
      1 - math.max(0, cfg.tempCorrectionRef - tempC) * cfg.tempCorrectionPerC,
    );
    return (raw * tempFactor).floor();
  }
}

// ════════════════════════════════════════════════════════════
// 3. 向后兼容：保留原有的纯函数 API
// ════════════════════════════════════════════════════════════

/// 默认 calculator 单例。被下面四个 free function 复用。
final DiveCalculator _defaultCalculator = DiveCalculator();

/// See [DiveCalculator.mod].
int calcMOD(double po2, double o2Pct, [double pSurf = c.pSurface]) =>
    _defaultCalculator.mod(MODInput(po2: po2, o2Pct: o2Pct, surfacePressure: pSurf));

/// See [DiveCalculator.end].
int calcEND(
  double o2Pct,
  double hePct,
  double depth, [
  double narcosis = 0,
  double pSurf = c.pSurface,
]) =>
    _defaultCalculator.end(ENDInput(
      gas: GasMix(o2Pct: o2Pct, hePct: hePct),
      depth: depth,
      narcosis: narcosis,
      surfacePressure: pSurf,
    ));

/// See [DiveCalculator.eadd].
int calcEADD(
  double o2Pct,
  double hePct,
  double depth, [
  double pSurf = c.pSurface,
]) =>
    _defaultCalculator.eadd(EADDInput(
      gas: GasMix(o2Pct: o2Pct, hePct: hePct),
      depth: depth,
      surfacePressure: pSurf,
    ));

/// See [DiveCalculator.ndl].
int calcNDL(
  double o2Pct,
  double depthM,
  bool saltWater,
  double tempC, [
  double pSurf = c.pSurface,
]) =>
    _defaultCalculator.ndl(NDLInput(
      o2Pct: o2Pct,
      depthM: depthM,
      saltWater: saltWater,
      tempC: tempC,
      surfacePressure: pSurf,
    ));
