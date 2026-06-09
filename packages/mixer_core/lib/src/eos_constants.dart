/// EOS 物理常数 — 翻译自 [gas-dive-mixer/shared/utils/constants.ts] 的 EOS 子集。
library;

// ─── 通用 ─────────────────────────────────────────────

/// 通用气体常数 R (L·bar/(mol·K))
const double gasConstantR = 0.08314;

/// 摄氏度 → 开尔文偏移量
const double celsiusToKelvin = 273.15;

// ─── EoS：Z 因子钳位范围 ──────────────────────────────

const double zFactorMin = 0.80;
const double zFactorMax = 1.25;

// ─── LKP 系数 ────────────────────────────────────────

class LKCoefficients {
  final double b1, b2, b3, b4;
  final double c1, c2, c3, c4;
  final double d1, d2;
  final double beta, gamma;

  const LKCoefficients({
    required this.b1,
    required this.b2,
    required this.b3,
    required this.b4,
    required this.c1,
    required this.c2,
    required this.c3,
    required this.c4,
    required this.d1,
    required this.d2,
    required this.beta,
    required this.gamma,
  });
}

/// 简单流体（Ar/Kr/Xe 类，ω≈0）
const LKCoefficients lkSimple = LKCoefficients(
  b1: 0.1181193, b2: 0.265728, b3: 0.154790, b4: 0.030323,
  c1: 0.0236744, c2: 0.0186984, c3: 0.0, c4: 0.042724,
  d1: 1.55488e-5, d2: 6.23689e-5,
  beta: 0.65392, gamma: 0.060167,
);

/// 参考流体（n-辛烷, ω_r = 0.3978）
const LKCoefficients lkReference = LKCoefficients(
  b1: 0.2026579, b2: 0.331511, b3: 0.027655, b4: 0.203488,
  c1: 0.0313385, c2: 0.0503618, c3: 0.016901, c4: 0.041577,
  d1: 4.8736e-5, d2: 7.40336e-6,
  beta: 1.226, gamma: 0.03754,
);

/// 参考流体偏心因子
const double lkOmegaR = 0.3978;

// ─── 临界参数 ────────────────────────────────────────

class CriticalParams {
  /// 临界温度 (K)
  final double tc;

  /// 临界压力 (bar)
  final double pc;

  /// 偏心因子
  final double omega;

  const CriticalParams({required this.tc, required this.pc, required this.omega});
}

const CriticalParams critO2 = CriticalParams(tc: 154.581, pc: 50.43, omega: 0.0222);
const CriticalParams critN2 = CriticalParams(tc: 126.192, pc: 33.96, omega: 0.0372);

/// Air 伪临界参数 (Sychev et al.)
const CriticalParams critAir = CriticalParams(tc: 132.5, pc: 37.7, omega: 0.0335);

// ─── He 维里方程系数 (Hurly-Moldover NIST 2000) ──────

class HeVirial {
  /// B 截距 (cm³/mol)
  final double bSlope;

  /// B 温度系数 (cm³/(mol·°C))
  final double bTempCoeff;

  /// C (cm⁶/mol²)，温度依赖很弱
  final double c;

  /// D (cm⁹/mol³)，4 阶项
  final double d;

  const HeVirial({
    required this.bSlope,
    required this.bTempCoeff,
    required this.c,
    required this.d,
  });
}

const HeVirial heVirial = HeVirial(
  bSlope: 11.66,
  bTempCoeff: 0.011,
  c: 113,
  d: 1500,
);

// ─── 迭代参数 ────────────────────────────────────────

const int lkpMaxIterations = 100;
const int heMaxIterations = 50;
const double zConvergenceTol = 1e-9;
