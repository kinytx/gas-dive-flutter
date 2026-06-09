/// 气体混合算法主体（理想气体 MVP）。
///
/// 翻译自 [gas-dive-mixer/shared/utils/mixer.ts] 的简化子集——见 [mixer_core.dart] 文档。
library;

import 'package:meta/meta.dart';

import 'types.dart';

/// 配置项。所有阈值集中在此，便于单测时替换。
@immutable
class GasMixerConfig {
  /// "残气太低不可信"阈值，bar — 低于此值警告 lowResidualPressure
  final double lowResidualBar;

  /// 浮点容差（避免 100.001 被误判为越界）
  final double concentrationTolerance;

  /// 分压配平 fill 视为零的下界（小于此值当作 0 处理）
  final double fillEpsilon;

  /// 空气中 O₂ 摩尔分数
  final double airO2Fraction;

  /// 空气中 N₂ 摩尔分数
  final double airN2Fraction;

  /// 默认充气顺序
  final FillOrder defaultFillOrder;

  const GasMixerConfig({
    this.lowResidualBar = 10,
    this.concentrationTolerance = 0.001,
    this.fillEpsilon = 0.001,
    this.airO2Fraction = 0.21,
    this.airN2Fraction = 0.79,
    this.defaultFillOrder = FillOrder.heFirst,
  });
}

const GasMixerConfig defaultGasMixerConfig = GasMixerConfig();

/// 气体混合计算器。
///
/// 算法概要：
/// 1. 入参校验
/// 2. 解三元一次方程组：fillHe / fillO₂ / fillAir
/// 3. 检查 fill 是否均 ≥ 0（否则需先放气）
/// 4. 按 fillOrder 生成分步指令
/// 5. 软警告（低残压等）
class GasMixer {
  final GasMixerConfig _config;

  GasMixer([GasMixerConfig? config]) : _config = config ?? defaultGasMixerConfig;

  GasMixerConfig get config => _config;

  /// 计算填充方案。
  MixResult calculate(CalculateMixParams params) {
    final tol = _config.concentrationTolerance;

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
        params.targetPressure <= 0) {
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

    // ─── 2. 三组分压差（target - current） ──────────────
    final fO2c = params.currentO2 / 100;
    final fHec = params.currentHe / 100;
    final fN2c = 1.0 - fO2c - fHec;
    final fO2t = params.targetO2 / 100;
    final fHet = params.targetHe / 100;
    final fN2t = 1.0 - fO2t - fHet;

    final pO2Diff = fO2t * params.targetPressure - fO2c * params.currentPressure;
    final pHeDiff = fHet * params.targetPressure - fHec * params.currentPressure;
    final pN2Diff = fN2t * params.targetPressure - fN2c * params.currentPressure;

    // ─── 3. 解三元一次方程组 ─────────────────────────
    //   fillHe                              = pHeDiff
    //   fillO₂ + fillAir × airO2Fraction    = pO2Diff
    //   fillAir × airN2Fraction             = pN2Diff
    final fillHe = pHeDiff;
    final fillAir = pN2Diff / _config.airN2Fraction;
    final fillO2 = pO2Diff - fillAir * _config.airO2Fraction;

    // ─── 4. 校验 fill 全 ≥ 0 ─────────────────────────
    final eps = _config.fillEpsilon;
    if (fillHe < -eps || fillO2 < -eps || fillAir < -eps) {
      // V2 实现完整 drainToPressure 求解，MVP 直接报 needDrain。
      return MixResult(
        algorithmVersion: GasMixerVersion.current,
        success: false,
        error: MixErrorCode.needDrain,
        needToDrain: true,
        oxygenToFill: fillO2 < -eps ? fillO2 : 0,
        heliumToFill: fillHe < -eps ? fillHe : 0,
        airToFill: fillAir < -eps ? fillAir : 0,
        fillOrder: params.fillOrder,
      );
    }

    // 钳到 0（吸收小数值浮点误差）
    final fillHeClamped = fillHe < 0 ? 0.0 : fillHe;
    final fillO2Clamped = fillO2 < 0 ? 0.0 : fillO2;
    final fillAirClamped = fillAir < 0 ? 0.0 : fillAir;

    // ─── 5. 生成 fillSequence（按 fillOrder 排序） ─────
    final sequence = _buildSequence(
      params.fillOrder,
      params.currentPressure,
      fillO2Clamped,
      fillHeClamped,
      fillAirClamped,
    );

    // ─── 6. 软警告 ───────────────────────────────────
    final warnings = <MixWarning>[];
    if (params.currentPressure > 0 &&
        params.currentPressure < _config.lowResidualBar) {
      warnings.add(MixWarning.lowResidualPressure);
    }

    return MixResult(
      algorithmVersion: GasMixerVersion.current,
      success: true,
      warnings: warnings,
      oxygenToFill: fillO2Clamped,
      heliumToFill: fillHeClamped,
      airToFill: fillAirClamped,
      fillGaugePressure: params.targetPressure,
      fillOrder: params.fillOrder,
      fillSequence: sequence,
    );
  }

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
// 向后兼容自由函数（对应 mixer.ts 末尾的 calculateMix）
// ════════════════════════════════════════════════════════════

final GasMixer _defaultMixer = GasMixer();

/// 默认实例的 calculate 简写。
MixResult calculateMix(CalculateMixParams params) => _defaultMixer.calculate(params);
