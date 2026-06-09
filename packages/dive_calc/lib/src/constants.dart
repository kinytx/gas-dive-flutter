/// 物理 / 化学 / 算法常数（dive_calc 子集）。
///
/// 翻译自 [gas-dive-mixer/shared/utils/constants.ts] 的对应字段——这里只搬 dive_calc
/// 实际用到的部分（VPM / Z 因子 / CCR 等暂未迁移）。
///
/// 命名说明：原 TS 用 `SCREAMING_SNAKE_CASE`，Dart 这里改成 `lowerCamelCase`
/// 并在 doc comment 末尾保留 TS 原名作交叉对照，方便回溯源。
library;

import 'types.dart';

// ─── 大气 / 水体 ────────────────────────────────────────────

/// 海平面标准大气压 (bar)。TS: `P_SURFACE`
const double pSurface = 1.013;

/// 肺泡水蒸气分压 (bar)。TS: `P_ALVEOLAR_H2O`
const double pAlveolarH2O = 0.0627;

/// 海水压力梯度 (bar/m)。TS: `PG_SALT_WATER`
const double pgSaltWater = 0.1025;

/// 淡水压力梯度 (bar/m)。TS: `PG_FRESH_WATER`
const double pgFreshWater = 0.0981;

// ─── 空气组成 ───────────────────────────────────────────────

/// 空气中 N₂ 摩尔分数。TS: `AIR_N2_FRACTION`
const double airN2Fraction = 0.79;

/// 空气中 O₂ 摩尔分数。TS: `AIR_O2_FRACTION`
const double airO2Fraction = 0.21;

// ─── 气体摩尔质量 (g/L @ STP) ────────────────────────────────

/// 气体摩尔质量（g/L @ STP）。TS: `MOLAR_MASS`
const MolarMassMap molarMass = MolarMassMap(
  o2: 1.43,
  he: 0.18,
  n2: 1.25,
  air: 1.2878,
);

// ─── ZHL-16C 减压模型 ───────────────────────────────────────

/// ZHL-16C 完整 16 隔室参数：[N2_ht, He_ht, N2_a, N2_b, He_a, He_b]。
/// TS: `ZHL16C_COMPARTMENTS`
const List<List<double>> zhl16cCompartments = [
  [5.0,   1.88,  1.1696, 0.5578, 1.6189, 0.4770],
  [8.0,   3.02,  1.0000, 0.6514, 1.3830, 0.5747],
  [12.5,  4.72,  0.8618, 0.7222, 1.1919, 0.6527],
  [18.5,  6.99,  0.7562, 0.7825, 1.0458, 0.7223],
  [27.0,  10.21, 0.6667, 0.8126, 0.9220, 0.7582],
  [38.3,  14.48, 0.5933, 0.8434, 0.8205, 0.7957],
  [54.3,  20.53, 0.5282, 0.8693, 0.7305, 0.8279],
  [77.0,  29.11, 0.4701, 0.8910, 0.6502, 0.8553],
  [109.0, 41.20, 0.4187, 0.9092, 0.5950, 0.8757],
  [146.0, 55.19, 0.3798, 0.9222, 0.5545, 0.8903],
  [187.0, 70.69, 0.3497, 0.9319, 0.5333, 0.8997],
  [239.0, 90.34, 0.3223, 0.9403, 0.5189, 0.9073],
  [305.0, 115.29, 0.2971, 0.9477, 0.5181, 0.9122],
  [390.0, 147.42, 0.2737, 0.9544, 0.5176, 0.9171],
  [498.0, 188.24, 0.2523, 0.9602, 0.5172, 0.9217],
  [635.0, 240.03, 0.2327, 0.9653, 0.5119, 0.9267],
];

/// ZHL-16C 仅 N₂ 隔室（NDL 计算用）：从完整表提取 {ht, a, b}。
/// TS: `ZHL16C_N2_COMPARTMENTS`
final List<ZHL16CCompartment> zhl16cN2Compartments = zhl16cCompartments
    .map((c) => ZHL16CCompartment(ht: c[0], a: c[2], b: c[3]))
    .toList(growable: false);

// ─── 温度修正 ───────────────────────────────────────────────

/// NDL / GF 温度修正：参考温度 (°C)。TS: `TEMP_CORRECTION_REF`
const double tempCorrectionRef = 25;

/// 每低 1°C 降低的比例。TS: `TEMP_CORRECTION_PER_C`
const double tempCorrectionPerC = 0.01;

/// 最低保留比例。TS: `TEMP_CORRECTION_MIN_FACTOR`
const double tempCorrectionMinFactor = 0.75;

// ─── 共享运行时默认值 ──────────────────────────────────────────

/// NDL 无限制哨兵值 (min)。TS: `UNLIMITED_NDL`
const int unlimitedNDL = 999;

/// 深度/压力换算：每 bar ≈ 10m 海水。TS: `DEPTH_PER_BAR`
const double depthPerBar = 10;
