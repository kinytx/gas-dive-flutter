/// Z 因子查询（适配层）— 翻译自 [gas-dive-mixer/shared/utils/z-factor.ts]。
///
/// 包装 EOS，给 GasMixer 提供「目标混合气在 (P, T) 下各组分 Z」的简单接口。
library;

import 'package:meta/meta.dart';

import 'eos.dart';

/// 4 种气体的 Z 系数集合。
@immutable
class ZFactorSet {
  /// O₂ 的 Z
  final double oxygen;

  /// He 的 Z
  final double helium;

  /// N₂ 的 Z
  final double nitrogen;

  /// 空气整体的 Z
  final double air;

  const ZFactorSet({
    required this.oxygen,
    required this.helium,
    required this.nitrogen,
    required this.air,
  });
}

@immutable
class GetZFactorsParams {
  /// 目标总压 (bar)
  final double pressure;

  /// 目标 O₂ 摩尔分数 (0-1)，例 0.32 表示 32%
  final double o2Frac;

  /// 目标 He 摩尔分数 (0-1)
  final double heFrac;

  /// 气体温度 (°C)
  final double tempC;

  const GetZFactorsParams({
    required this.pressure,
    required this.o2Frac,
    required this.heFrac,
    required this.tempC,
  });
}

class ZFactorCalculator {
  final EOS _eos;
  final double _n2FractionFloor;

  ZFactorCalculator({EOS? eos, double n2FractionFloor = 0})
      : _eos = eos ?? EOS(),
        _n2FractionFloor = n2FractionFloor;

  EOS get eos => _eos;

  /// 计算 4 种气体在目标混合气下的 Z 系数。
  /// 每个 Z 在该气体的"分压"上评估；Air 按总压评估。
  ZFactorSet calculate(GetZFactorsParams p) {
    // ignore: unused_local_variable
    final n2Frac = _n2FractionFloor > (1 - p.o2Frac - p.heFrac)
        ? _n2FractionFloor
        : (1 - p.o2Frac - p.heFrac);
    return ZFactorSet(
      oxygen: _eos.oxygen(p.tempC, p.o2Frac * p.pressure),
      helium: _eos.helium(p.tempC, p.heFrac * p.pressure),
      nitrogen: _eos.nitrogen(p.tempC, n2Frac * p.pressure),
      air: _eos.air(p.tempC, p.pressure),
    );
  }
}

// ════════════════════════════════════════════════════════════
// 自由函数
// ════════════════════════════════════════════════════════════

final ZFactorCalculator _defaultCalc = ZFactorCalculator();

ZFactorSet getZFactors(GetZFactorsParams params) => _defaultCalc.calculate(params);
