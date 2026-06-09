/// 大气模型 — ICAO 1976 海拔 → 表面气压换算。
///
/// 翻译自 [gas-dive-mixer/shared/utils/atmosphere.ts]。
/// 公式：P = P0 × (1 − L·h/T0)^exp
library;

import 'dart:math' as math;

import 'package:meta/meta.dart';

@immutable
class Atmosphere {
  /// 海平面标准大气压 (bar)
  final double p0;

  /// 对流层温度递减率 (K/m)
  final double lapseRate;

  /// 海平面标准温度 (K)
  final double t0;

  /// 气压指数 g·M/(R·L)
  final double exponent;

  const Atmosphere({
    this.p0 = 1.01325,
    this.lapseRate = 0.0065,
    this.t0 = 288.15,
    this.exponent = 5.255,
  });

  /// 海拔 (m) → 表面气压 (bar)。对流层（≤ 11 km）有效。
  /// 海平面 altM=0 → 1.01325 bar；3000m ≈ 0.701 bar。
  double altitudeToSurfacePressure(double altitudeM) {
    if (altitudeM <= 0) return p0;
    return p0 * math.pow(1 - lapseRate * altitudeM / t0, exponent).toDouble();
  }
}

const Atmosphere defaultAtmosphere = Atmosphere();

/// 自由函数形式，便于直接调用。
double altitudeToSurfacePressure(double altitudeM) =>
    defaultAtmosphere.altitudeToSurfacePressure(altitudeM);
