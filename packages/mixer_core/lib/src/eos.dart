/// 状态方程 (Equation of State) — 翻译自 [gas-dive-mixer/shared/utils/eos.ts]。
///
/// - O₂ / N₂ / Air：Lee-Kesler-Plöcker (LKP) 三参数对应态 (modified BWR)
/// - He：截断到 4 阶项的维里方程 + 牛顿迭代
///
/// 适用范围：温度 -50 ~ 100°C，压力 0 ~ 400 bar
/// 精度（vs NIST REFPROP）：O₂/N₂/Air ≤ 0.5%（高压 Pr>7 N₂ ~1%）；He ≤ 0.5%
library;

import 'dart:math' as math;

import 'package:meta/meta.dart';

import 'eos_constants.dart';

// ════════════════════════════════════════════════════════════
// Config
// ════════════════════════════════════════════════════════════

@immutable
class EOSConfig {
  /// Z 钳位下限
  final double zMin;

  /// Z 钳位上限
  final double zMax;

  /// 非物理 / 无效输入时的 Z 兜底值（理想气体）
  final double defaultZ;

  /// 压力 ≤ 此值时直接返回 defaultZ (bar)
  final double pressureZeroThreshold;

  /// LKP Vr 迭代最大次数
  final int lkpMaxIterations;

  /// LKP Vr 迭代阻尼系数（0.5 = 半步阻尼）
  final double dampingFactor;

  /// He 牛顿迭代最大次数
  final int heMaxIterations;

  /// Z 收敛容差
  final double convergenceTol;

  /// B (cm³/mol) -> L/mol
  final double virialBScale;

  /// C (cm⁶/mol²) -> L²/mol²
  final double virialCScale;

  /// D (cm⁹/mol³) -> L³/mol³
  final double virialDScale;

  final double gasConstantR;
  final double celsiusToKelvin;
  final double omegaRef;

  const EOSConfig({
    this.zMin = 0.80,
    this.zMax = 1.25,
    this.defaultZ = 1.0,
    this.pressureZeroThreshold = 0,
    this.lkpMaxIterations = 100,
    this.dampingFactor = 0.5,
    this.heMaxIterations = 50,
    this.convergenceTol = 1e-9,
    this.virialBScale = 1e-3,
    this.virialCScale = 1e-6,
    this.virialDScale = 1e-9,
    this.gasConstantR = 0.08314,
    this.celsiusToKelvin = 273.15,
    this.omegaRef = 0.3978,
  });
}

const EOSConfig defaultEOSConfig = EOSConfig();

// ════════════════════════════════════════════════════════════
// EOS
// ════════════════════════════════════════════════════════════

/// 压缩因子 Z(T, P) 计算器。
class EOS {
  final EOSConfig _config;

  EOS([EOSConfig? config]) : _config = config ?? defaultEOSConfig;

  EOSConfig get config => _config;

  /// 纯氧 O₂ 的 Z(T, P)
  double oxygen(double tempC, double pressureBar) {
    if (pressureBar <= _config.pressureZeroThreshold) return _config.defaultZ;
    return _clamp(_zLKP(critO2, tempC, pressureBar));
  }

  /// 纯氮 N₂ 的 Z(T, P)
  double nitrogen(double tempC, double pressureBar) {
    if (pressureBar <= _config.pressureZeroThreshold) return _config.defaultZ;
    return _clamp(_zLKP(critN2, tempC, pressureBar));
  }

  /// 纯氦 He 的 Z(T, P)
  double helium(double tempC, double pressureBar) {
    if (pressureBar <= _config.pressureZeroThreshold) return _config.defaultZ;
    return _clamp(_zHelium(tempC + _config.celsiusToKelvin, pressureBar));
  }

  /// 空气的 Z(T, P) — 用伪临界参数走 LKP
  double air(double tempC, double pressureBar) {
    if (pressureBar <= _config.pressureZeroThreshold) return _config.defaultZ;
    return _clamp(_zLKP(critAir, tempC, pressureBar));
  }

  // ── 私有 ──

  double _clamp(double z) {
    final cfg = _config;
    if (!z.isFinite) return cfg.defaultZ;
    if (z < cfg.zMin) return cfg.zMin;
    if (z > cfg.zMax) return cfg.zMax;
    return z;
  }

  /// 单个流体的 LKP-BWR 求解（迭代 Vr）
  double _zLKPSingle(LKCoefficients p, double tr, double pr) {
    final cfg = _config;
    final tr3 = tr * tr * tr;
    final b = p.b1 - p.b2 / tr - p.b3 / (tr * tr) - p.b4 / tr3;
    final c = p.c1 - p.c2 / tr + p.c3 / tr3;
    final d = p.d1 + p.d2 / tr;

    var vr = tr / pr;
    for (var iter = 0; iter < cfg.lkpMaxIterations; iter++) {
      final vr2 = vr * vr;
      final vr5 = vr2 * vr2 * vr;
      final invVr2 = 1 / vr2;
      final expT = math.exp(-p.gamma * invVr2);
      final last = (p.c4 / (tr3 * vr2)) * (p.beta + p.gamma * invVr2) * expT;
      final z = 1 + b / vr + c / vr2 + d / vr5 + last;
      final vrNew = tr * z / pr;
      if ((vrNew - vr).abs() < cfg.convergenceTol) return z;
      vr = vr + cfg.dampingFactor * (vrNew - vr);
    }
    final vr2 = vr * vr;
    final vr5 = vr2 * vr2 * vr;
    final invVr2 = 1 / vr2;
    final expT = math.exp(-p.gamma * invVr2);
    final last = (p.c4 / (tr3 * vr2)) * (p.beta + p.gamma * invVr2) * expT;
    return 1 + b / vr + c / vr2 + d / vr5 + last;
  }

  /// Pitzer 三参数 LKP 主入口
  double _zLKP(CriticalParams crit, double tempC, double pressureBar) {
    final cfg = _config;
    final tr = (tempC + cfg.celsiusToKelvin) / crit.tc;
    final pr = pressureBar / crit.pc;
    final z0 = _zLKPSingle(lkSimple, tr, pr);
    final zr = _zLKPSingle(lkReference, tr, pr);
    return z0 + (crit.omega / cfg.omegaRef) * (zr - z0);
  }

  /// He 的 Z：维里方程 Z = 1 + B(T)·ρ + C(T)·ρ² + D(T)·ρ³
  /// ρ = P/(Z·RT)，需迭代求解
  double _zHelium(double tempK, double pressureBar) {
    final cfg = _config;
    final tCelsius = tempK - cfg.celsiusToKelvin;
    final bL = (heVirial.bSlope + heVirial.bTempCoeff * tCelsius) * cfg.virialBScale;
    final cL2 = heVirial.c * cfg.virialCScale;
    final dL3 = heVirial.d * cfg.virialDScale;

    final rt = cfg.gasConstantR * tempK;
    var z = cfg.defaultZ;
    for (var i = 0; i < cfg.heMaxIterations; i++) {
      final rho = pressureBar / (z * rt);
      final zNew = 1 + bL * rho + cL2 * rho * rho + dL3 * rho * rho * rho;
      if ((zNew - z).abs() < cfg.convergenceTol) return zNew;
      z = zNew;
    }
    return z;
  }
}

// ════════════════════════════════════════════════════════════
// 向后兼容自由函数
// ════════════════════════════════════════════════════════════

final EOS _defaultEOS = EOS();

double zOxygen(double tempC, double pressureBar) =>
    _defaultEOS.oxygen(tempC, pressureBar);

double zNitrogen(double tempC, double pressureBar) =>
    _defaultEOS.nitrogen(tempC, pressureBar);

double zHelium(double tempC, double pressureBar) =>
    _defaultEOS.helium(tempC, pressureBar);

double zAir(double tempC, double pressureBar) =>
    _defaultEOS.air(tempC, pressureBar);
