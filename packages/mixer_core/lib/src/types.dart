/// 类型定义 — 对应 mixer.ts 的 interface。
///
/// V2a 扩展：加入 altitudeM / tempC / pressureRef / altitudeCorrection 字段
/// + AltitudeInfo 输出。
/// useRealGases / Z 因子相关字段是占位（V2b 实现）。
library;

import 'package:meta/meta.dart';

import 'z_factor.dart' show ZFactorSet;
export 'z_factor.dart' show ZFactorSet, GetZFactorsParams;

// ════════════════════════════════════════════════════════════
// 1. 枚举
// ════════════════════════════════════════════════════════════

/// 充气顺序。
enum FillOrder {
  heFirst('he-first'),
  o2First('o2-first');

  final String wire;
  const FillOrder(this.wire);
}

enum FillGas {
  o2('O₂'),
  he('He'),
  air('Air');

  final String label;
  const FillGas(this.label);
}

/// 海拔 O₂ 修正模式。
///
/// - `none`：不修正（与海平面行为一致）
/// - `A`：完整压力比修正——`adjustedO2 = targetO2 × (P_surf / P_local)`
/// - `B`（业内推荐）：per-gas K 系数修正（半强度压力比，对富 O₂ / 富 He 各有惩罚 / 补偿）
/// - `C`：不改 target O₂%，但用 P_local 重算分压（严谨但保守）
/// - `D`：线性修正——每 1000m +1% O₂
enum AltitudeMode {
  none,
  a,
  b,
  c,
  d,
}

/// 目标压力的温度基准。
enum PressureRef {
  /// 填充温度下的表压（默认）：表针停在 targetPressure 就结束
  fill,

  /// 21°C 标准温度下的压力：算法按 tempC 折算实际填充表压
  std,
}

// ════════════════════════════════════════════════════════════
// 2. 输入
// ════════════════════════════════════════════════════════════

@immutable
class CalculateMixParams {
  final double currentO2;
  final double currentHe;
  final double currentPressure;
  final double targetO2;
  final double targetHe;
  final double targetPressure;

  /// 充气顺序（默认 he-first）
  final FillOrder fillOrder;

  /// 填充地点海拔 (m, ≥ 0)。默认 0 = 海平面
  final double altitudeM;

  /// 海拔 O₂ 修正模式（默认 B，业内推荐）
  final AltitudeMode altitudeMode;

  /// 气体温度 (°C)。仅 pressureRef='std' 时影响 fill 表压
  final double tempC;

  /// 目标压力的温度基准（默认 fill）
  final PressureRef pressureRef;

  /// 是否启用 Z 因子真实气体修正（V2b 实现，目前占位）
  final bool useRealGases;

  const CalculateMixParams({
    required this.currentO2,
    required this.currentHe,
    required this.currentPressure,
    required this.targetO2,
    required this.targetHe,
    required this.targetPressure,
    this.fillOrder = FillOrder.heFirst,
    this.altitudeM = 0,
    this.altitudeMode = AltitudeMode.b,
    this.tempC = 20,
    this.pressureRef = PressureRef.fill,
    this.useRealGases = false,
  });
}

// ════════════════════════════════════════════════════════════
// 3. 输出
// ════════════════════════════════════════════════════════════

@immutable
class FillStep {
  final int step;
  final FillGas gas;
  final double pressureBar;
  final double fillBar;

  const FillStep({
    required this.step,
    required this.gas,
    required this.pressureBar,
    required this.fillBar,
  });
}

/// 海拔修正回显（altitudeM=0 时整个对象为 null）
@immutable
class AltitudeInfo {
  final double altitudeM;
  final AltitudeMode mode;

  /// 当地大气压 (bar)
  final double pLocalBar;

  /// 修正前的 target O₂%
  final double originalO2;
  final double originalHe;

  /// 修正后的 target O₂%（A/B/D 才有变化；C/none 等于 originalO2）
  final double adjustedO2;
  final double adjustedHe;

  const AltitudeInfo({
    required this.altitudeM,
    required this.mode,
    required this.pLocalBar,
    required this.originalO2,
    required this.originalHe,
    required this.adjustedO2,
    required this.adjustedHe,
  });
}

enum MixErrorCode {
  invalidInput,
  targetPressureTooLow,
  invalidTargetGas,
  invalidCurrentGas,
}

enum MixWarning {
  /// 残压 < lowResidualBar，气体成分可能不准
  lowResidualPressure,
}

@immutable
class MixResult {
  final String algorithmVersion;
  final bool success;
  final MixErrorCode? error;
  final List<MixWarning> warnings;

  /// 是否需要先放气
  final bool needToDrain;

  /// 应放气到的压力 (bar)；V2a 用约束 LP 求解
  final double drainToPressure;

  final double oxygenToFill;
  final double heliumToFill;
  final double airToFill;

  /// 实际填充时的目标表压（pressureRef='std' 时会偏离 targetPressure）
  final double fillGaugePressure;

  final FillOrder fillOrder;
  final List<FillStep> fillSequence;

  /// 海拔修正回显（altitudeM=0 时为 null）
  final AltitudeInfo? altitudeInfo;

  /// Z 因子真实气体修正回显（useRealGases=false 时为 null）
  final ZFactorSet? zFactors;

  const MixResult({
    required this.algorithmVersion,
    required this.success,
    this.error,
    this.warnings = const [],
    this.needToDrain = false,
    this.drainToPressure = 0,
    this.oxygenToFill = 0,
    this.heliumToFill = 0,
    this.airToFill = 0,
    this.fillGaugePressure = 0,
    this.fillOrder = FillOrder.heFirst,
    this.fillSequence = const [],
    this.altitudeInfo,
    this.zFactors,
  });

  factory MixResult.failure(MixErrorCode err) =>
      MixResult(algorithmVersion: GasMixerVersion.current, success: false, error: err);
}

class GasMixerVersion {
  GasMixerVersion._();
  static const String current = 'v2b-1.0.0-dart';
}
