/// 气体混合算法主体（V2a：绝对压 + drain + 海拔修正 + 温度折算）。
///
/// 翻译自 [gas-dive-mixer/shared/utils/mixer.ts] 的 calculateMix 主流程，
/// 严格对齐其行为（含 max(0, ...) 钳位约定）。
///
/// V2b 待补：Z 因子真实气体修正（依赖 eos.dart）。
library;

import 'dart:math' as math;

import 'package:meta/meta.dart';

import 'atmosphere.dart' as atm;
import 'types.dart';
import 'z_factor.dart';

// ════════════════════════════════════════════════════════════
// 1. Config
// ════════════════════════════════════════════════════════════

@immutable
class GasMixerConfig {
  /// 残压警告阈值 (bar)
  final double lowResidualBar;

  /// 浮点容差（O₂/He 百分比越界判定）
  final double concentrationTolerance;

  /// fill 视为零的下界
  final double fillEpsilon;

  /// drain by O₂ excess 触发阈值
  final double drainO2Threshold;

  /// drain LP 分母 epsilon（避免除零）
  final double denomO2Epsilon;

  /// 空气中 O₂ 摩尔分数
  final double airO2Fraction;

  /// 空气中 N₂ 摩尔分数
  final double airN2Fraction;

  /// 海平面标准大气压 (bar)
  final double surfacePressure;

  /// 标准温度 (°C)
  final double standardTempC;

  /// 摄氏 → 开尔文偏移
  final double celsiusToKelvin;

  /// Plan B K 系数：base
  final double planBKBase;

  /// Plan B K 系数：O₂ 富氧惩罚
  final double planBKO2Penalty;
  final double planBKO2Threshold;

  /// Plan B K 系数：He 富氦补偿
  final double planBKHePenalty;
  final double planBKHeThreshold;

  /// Plan D 线性系数：每米 +N% O₂
  final double altitudeLinearK;

  const GasMixerConfig({
    this.lowResidualBar = 10,
    this.concentrationTolerance = 0.001,
    this.fillEpsilon = 0.001,
    this.drainO2Threshold = 0.001,
    this.denomO2Epsilon = 1e-6,
    this.airO2Fraction = 0.21,
    this.airN2Fraction = 0.79,
    this.surfacePressure = 1.013,
    this.standardTempC = 21,
    this.celsiusToKelvin = 273.15,
    this.planBKBase = 0.5,
    this.planBKO2Penalty = 0.005,
    this.planBKO2Threshold = 21,
    this.planBKHePenalty = 0.003,
    this.planBKHeThreshold = 0,
    this.altitudeLinearK = 0.0001,
  });
}

const GasMixerConfig defaultGasMixerConfig = GasMixerConfig();

// ════════════════════════════════════════════════════════════
// 2. 内部数据类型
// ════════════════════════════════════════════════════════════

@immutable
class _PartialPressures {
  final double o2;
  final double he;
  final double n2;
  const _PartialPressures(this.o2, this.he, this.n2);
}

@immutable
class _DrainResult {
  final bool needToDrain;
  final double drainToPressure;
  const _DrainResult(this.needToDrain, this.drainToPressure);
}

@immutable
class _AltitudeAdjustment {
  final double adjustedO2;
  final double adjustedHe;
  const _AltitudeAdjustment(this.adjustedO2, this.adjustedHe);
}

// ════════════════════════════════════════════════════════════
// 3. GasMixer
// ════════════════════════════════════════════════════════════

class GasMixer {
  final GasMixerConfig _config;
  final atm.Atmosphere _atmosphere;
  final ZFactorCalculator _zCalc;

  GasMixer([
    GasMixerConfig? config,
    atm.Atmosphere? atmosphere,
    ZFactorCalculator? zCalc,
  ])  : _config = config ?? defaultGasMixerConfig,
        _atmosphere = atmosphere ?? atm.defaultAtmosphere,
        _zCalc = zCalc ?? ZFactorCalculator();

  GasMixerConfig get config => _config;

  MixResult calculate(CalculateMixParams params) {
    final cfg = _config;
    final tol = cfg.concentrationTolerance;

    // ─── 1. 入参校验 ─────────────────────────────────
    if (params.currentO2 < 0 ||
        params.currentO2 > 100 + tol ||
        params.currentHe < 0 ||
        params.currentHe > 100 + tol ||
        params.targetO2 < 0 ||
        params.targetO2 > 100 + tol ||
        params.targetHe < 0 ||
        params.targetHe > 100 + tol ||
        params.currentPressure < 0 ||
        params.targetPressure <= 0 ||
        params.altitudeM < 0) {
      return MixResult.failure(MixErrorCode.invalidInput);
    }
    if (params.currentO2 + params.currentHe > 100 + tol) {
      return MixResult.failure(MixErrorCode.invalidCurrentGas);
    }
    if (params.targetO2 + params.targetHe > 100 + tol) {
      return MixResult.failure(MixErrorCode.invalidTargetGas);
    }
    if (params.targetPressure <= params.currentPressure) {
      return MixResult.failure(MixErrorCode.targetPressureTooLow);
    }

    // ─── 2. 软警告 ───────────────────────────────────
    final warnings = <MixWarning>[];
    if (params.currentPressure > 0 &&
        params.currentPressure < cfg.lowResidualBar) {
      warnings.add(MixWarning.lowResidualPressure);
    }

    // ─── 3. 海拔气压 ─────────────────────────────────
    final pLocal = params.altitudeM > 0
        ? _atmosphere.altitudeToSurfacePressure(params.altitudeM)
        : cfg.surfacePressure;

    // ─── 4. 海拔 O₂ 修正 ─────────────────────────────
    final altAdj = _applyAltitudeCorrection(
      params.targetO2,
      params.targetHe,
      params.altitudeM,
      params.altitudeMode,
      pLocal,
    );

    final altitudeInfo = params.altitudeM > 0
        ? AltitudeInfo(
            altitudeM: params.altitudeM,
            mode: params.altitudeMode,
            pLocalBar: pLocal,
            originalO2: params.targetO2,
            originalHe: params.targetHe,
            adjustedO2: altAdj.adjustedO2,
            adjustedHe: altAdj.adjustedHe,
          )
        : null;

    // ─── 5. 温度折算（std → fill 表压） ──────────────
    final fillGaugePressure = _convertToFillPressure(
      params.targetPressure,
      params.tempC,
      params.pressureRef,
    );

    // ─── 6. 分压（绝对压 = gauge + pLocal） ──────────
    final cur = _partialPressures(
      params.currentO2,
      params.currentHe,
      params.currentPressure + pLocal,
    );
    final tgt = _partialPressures(
      altAdj.adjustedO2,
      altAdj.adjustedHe,
      fillGaugePressure + pLocal,
    );

    // ─── 7. drain 判断 ───────────────────────────────
    final drain = _calcDrain(
      cur,
      tgt,
      params.currentO2,
      altAdj.adjustedO2,
      altAdj.adjustedHe,
      params.currentHe,
      fillGaugePressure,
      params.currentPressure,
    );

    final startPressure =
        drain.needToDrain ? drain.drainToPressure : params.currentPressure;

    // ─── 8. fill 计算（从 startPressure 起步） ───────
    final start = _partialPressures(
      params.currentO2,
      params.currentHe,
      startPressure + pLocal,
    );
    final n2Deficit = math.max(0.0, tgt.n2 - start.n2);
    var airToFill = n2Deficit / cfg.airN2Fraction;
    final o2FromAir = airToFill * cfg.airO2Fraction;
    var oxygenToFill = math.max(0.0, tgt.o2 - start.o2 - o2FromAir);
    var heliumToFill = math.max(0.0, tgt.he - start.he);

    // ─── 9. Z 因子真实气体修正（V2b） ─────────────────
    // 单 Z 路径（mixer.ts perStepZ=false 默认）：在目标终态 (P, 成分, 温度) 查一次 Z，
    // 三步 fill 量同时 /= Z。fillOrder 两种顺序输出完全一致（mixer.ts §6.1 §10）。
    ZFactorSet? zFactors;
    if (params.useRealGases) {
      zFactors = _zCalc.calculate(GetZFactorsParams(
        pressure: fillGaugePressure,
        o2Frac: altAdj.adjustedO2 / 100,
        heFrac: altAdj.adjustedHe / 100,
        tempC: params.tempC,
      ));
      // ÷ Z 约定：跟 mixer.ts 行为一致（见 mixer.ts §Z 方向调研注释）
      if (zFactors.oxygen > 0) oxygenToFill /= zFactors.oxygen;
      if (zFactors.helium > 0) heliumToFill /= zFactors.helium;
      if (zFactors.air > 0) airToFill /= zFactors.air;
    }

    // ─── 10. fillSequence ────────────────────────────
    final sequence = _buildSequence(
      params.fillOrder,
      startPressure,
      oxygenToFill,
      heliumToFill,
      airToFill,
    );

    return MixResult(
      algorithmVersion: GasMixerVersion.current,
      success: true,
      warnings: warnings,
      needToDrain: drain.needToDrain,
      drainToPressure: drain.drainToPressure,
      oxygenToFill: oxygenToFill,
      heliumToFill: heliumToFill,
      airToFill: airToFill,
      fillGaugePressure: fillGaugePressure,
      fillOrder: params.fillOrder,
      fillSequence: sequence,
      altitudeInfo: altitudeInfo,
      zFactors: zFactors,
    );
  }

  // ── 私有：分压 ────────────────────────────────────

  _PartialPressures _partialPressures(double o2Pct, double hePct, double pAbs) {
    return _PartialPressures(
      (o2Pct / 100) * pAbs,
      (hePct / 100) * pAbs,
      ((100 - o2Pct - hePct) / 100) * pAbs,
    );
  }

  // ── 私有：drain 求解 ──────────────────────────────

  _DrainResult _calcDrain(
    _PartialPressures cur,
    _PartialPressures tgt,
    double currentO2,
    double adjustedO2,
    double adjustedHe,
    double currentHe,
    double targetPressure,
    double currentPressure,
  ) {
    final cfg = _config;
    final fAirO2 = cfg.airO2Fraction;
    final fAirN2 = cfg.airN2Fraction;

    final drainByPartial = tgt.o2 < cur.o2 || tgt.he < cur.he || tgt.n2 < cur.n2;
    final airNeededIfNoDrain = math.max(0.0, (tgt.n2 - cur.n2) / fAirN2);
    final o2NeededIfNoDrain =
        tgt.o2 - cur.o2 - airNeededIfNoDrain * fAirO2;
    final drainByO2Excess = !drainByPartial &&
        (o2NeededIfNoDrain < -cfg.drainO2Threshold);
    final needToDrain = drainByPartial || drainByO2Excess;

    if (!needToDrain) return const _DrainResult(false, 0);

    // LP 约束求解（gauge 视图）
    final tO2g = (adjustedO2 / 100) * targetPressure;
    final tHeg = (adjustedHe / 100) * targetPressure;
    final tN2g = ((100 - adjustedO2 - adjustedHe) / 100) * targetPressure;
    final fO2c = currentO2 / 100;
    final fHec = currentHe / 100;
    final fN2c = 1 - fO2c - fHec;

    final constraints = <double>[currentPressure];
    if (fHec > 0) constraints.add(math.max(0.0, tHeg / fHec));
    if (fN2c > 0) constraints.add(math.max(0.0, tN2g / fN2c));
    final denomO2 = fO2c - fAirO2 + fAirO2 * fHec;
    if (denomO2 > cfg.denomO2Epsilon) {
      constraints.add(math.max(0.0, (fAirN2 * tO2g - fAirO2 * tN2g) / denomO2));
    }

    final drainToPressure = math.max(0.0, constraints.reduce(math.min));
    return _DrainResult(true, drainToPressure);
  }

  // ── 私有：海拔 O₂ 修正 ────────────────────────────

  _AltitudeAdjustment _applyAltitudeCorrection(
    double targetO2,
    double targetHe,
    double altitudeM,
    AltitudeMode mode,
    double pLocal,
  ) {
    final cfg = _config;
    if (altitudeM <= 0 ||
        mode == AltitudeMode.none ||
        mode == AltitudeMode.c) {
      return _AltitudeAdjustment(targetO2, targetHe);
    }

    final pRatio = cfg.surfacePressure / pLocal;
    double adjustedO2 = targetO2;
    double adjustedHe = targetHe;

    switch (mode) {
      case AltitudeMode.a:
        adjustedO2 = targetO2 * pRatio;
        break;
      case AltitudeMode.b:
        final kB = cfg.planBKBase -
            cfg.planBKO2Penalty *
                math.max(0.0, targetO2 - cfg.planBKO2Threshold) +
            cfg.planBKHePenalty *
                math.max(0.0, targetHe - cfg.planBKHeThreshold);
        adjustedO2 = targetO2 * (1 + (pRatio - 1) * kB);
        break;
      case AltitudeMode.d:
        adjustedO2 = targetO2 + altitudeM * cfg.altitudeLinearK;
        break;
      case AltitudeMode.none:
      case AltitudeMode.c:
        break;
    }
    adjustedO2 = adjustedO2.clamp(0.0, 100.0);

    // 含 He 气体的 He 反向调整
    if (targetHe > 0) {
      final deltaO2 = adjustedO2 - targetO2;
      if (mode == AltitudeMode.a || mode == AltitudeMode.b) {
        adjustedHe = math.max(0.0, targetHe - deltaO2);
      } else if (mode == AltitudeMode.d) {
        final targetN2 = 100 - targetO2 - targetHe;
        if (targetN2 >= deltaO2) {
          adjustedHe = targetHe;
        } else {
          adjustedHe = math.max(0.0, targetHe - (deltaO2 - targetN2));
        }
      }
    }

    // 兜底：O₂ + He ≤ 100
    if (adjustedO2 + adjustedHe > 100) {
      adjustedHe = math.max(0.0, 100 - adjustedO2);
    }

    return _AltitudeAdjustment(adjustedO2, adjustedHe);
  }

  // ── 私有：std → fill 折算（Gay-Lussac） ───────────

  double _convertToFillPressure(
    double targetPressure,
    double tempC,
    PressureRef ref,
  ) {
    if (ref != PressureRef.std) return targetPressure;
    final cfg = _config;
    final tFill = cfg.celsiusToKelvin + tempC;
    final tStd = cfg.celsiusToKelvin + cfg.standardTempC;
    return targetPressure * tFill / tStd;
  }

  // ── 私有：fillSequence 排序 ───────────────────────

  List<FillStep> _buildSequence(
    FillOrder order,
    double startPressure,
    double fillO2,
    double fillHe,
    double fillAir,
  ) {
    final steps = order == FillOrder.heFirst
        ? [(FillGas.he, fillHe), (FillGas.o2, fillO2), (FillGas.air, fillAir)]
        : [(FillGas.o2, fillO2), (FillGas.air, fillAir), (FillGas.he, fillHe)];
    final result = <FillStep>[];
    var cumulative = startPressure;
    var stepNum = 1;
    for (final (gas, fill) in steps) {
      cumulative += fill;
      result.add(FillStep(
        step: stepNum,
        gas: gas,
        pressureBar: cumulative,
        fillBar: fill,
      ));
      stepNum++;
    }
    return result;
  }
}

// ════════════════════════════════════════════════════════════
// 4. 向后兼容自由函数
// ════════════════════════════════════════════════════════════

final GasMixer _defaultMixer = GasMixer();

MixResult calculateMix(CalculateMixParams params) =>
    _defaultMixer.calculate(params);
