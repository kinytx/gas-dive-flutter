/// 类型定义 — 对应 mixer.ts 的 interface。
library;

import 'package:meta/meta.dart';

/// 充气顺序。
///
/// - `heFirst`（业内通用）：He → O₂ → Air；He 在底部加速对流混匀
/// - `o2First`（金侠表风格）：O₂ → Air → He；特定填充硬件 / 操作习惯
///
/// 算法层面 fill 总量两种顺序完全一致（数学交换律），只影响 [FillStep] 的排列与累计压力的数值含义。
enum FillOrder {
  heFirst('he-first'),
  o2First('o2-first');

  final String wire;
  const FillOrder(this.wire);
}

/// 计算混气的输入参数。
@immutable
class CalculateMixParams {
  /// 当前气瓶 O₂ % (0-100)
  final double currentO2;

  /// 当前气瓶 He % (0-100)
  final double currentHe;

  /// 当前气瓶压力 (bar)
  final double currentPressure;

  /// 目标 O₂ % (0-100)
  final double targetO2;

  /// 目标 He % (0-100)
  final double targetHe;

  /// 目标压力 (bar)
  final double targetPressure;

  /// 充气顺序（默认 he-first，业内通用）
  final FillOrder fillOrder;

  const CalculateMixParams({
    required this.currentO2,
    required this.currentHe,
    required this.currentPressure,
    required this.targetO2,
    required this.targetHe,
    required this.targetPressure,
    this.fillOrder = FillOrder.heFirst,
  });
}

/// 单步填充指令（按 fillOrder 排好序）。
@immutable
class FillStep {
  /// 第几步（1-based，给 UI 显示）
  final int step;

  /// 这一步充的是哪种气
  final FillGas gas;

  /// 这一步充完后的累计目标表压 (bar)
  final double pressureBar;

  /// 这一步充入的气量 (bar) = 本步 pressureBar - 上一步 pressureBar（首步则减 currentPressure）
  final double fillBar;

  const FillStep({
    required this.step,
    required this.gas,
    required this.pressureBar,
    required this.fillBar,
  });
}

enum FillGas {
  o2('O₂'),
  he('He'),
  air('Air');

  final String label;
  const FillGas(this.label);
}

/// 错误码（success=false 时设置）。
enum MixErrorCode {
  /// 入参校验失败（O₂/He 越界、压力非正等）
  invalidInput,

  /// 目标压力 ≤ 当前压力（无空间继续填充）
  targetPressureTooLow,

  /// 需要先放气（当前混合气过富，分压配平算出负 fill）
  needDrain,

  /// 目标 O₂ + He > 100（物理不可能）
  invalidTargetGas,

  /// 当前 O₂ + He > 100
  invalidCurrentGas,
}

/// 软警告码（不阻断计算，UI 用它显示橙色提示）。
enum MixWarning {
  /// 当前残压过低，气体成分不可信（低于 [GasMixerConfig.lowResidualBar]）
  lowResidualPressure,
}

/// calculateMix 的返回。
@immutable
class MixResult {
  /// 算法版本（跨语言对账用）
  final String algorithmVersion;

  /// 是否计算成功
  final bool success;

  /// 失败原因（success=false 时设置）
  final MixErrorCode? error;

  /// 软警告列表
  final List<MixWarning> warnings;

  /// 是否需要先放气
  final bool needToDrain;

  /// 应放气到的压力 (bar)；MVP 简化为 0（V2 再实现完整求解）
  final double drainToPressure;

  /// 需要充入的 O₂ 量 (bar)
  final double oxygenToFill;

  /// 需要充入的 He 量 (bar)
  final double heliumToFill;

  /// 需要充入的 Air 量 (bar)
  final double airToFill;

  /// 最终填充目标表压 = targetPressure（MVP 暂不区分 std/fill）
  final double fillGaugePressure;

  /// 用了哪种填充顺序
  final FillOrder fillOrder;

  /// 按 fillOrder 排好序的分步指令；UI 直接按数组顺序渲染
  final List<FillStep> fillSequence;

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
  });

  /// 失败结果工厂
  factory MixResult.failure(MixErrorCode err) =>
      MixResult(algorithmVersion: GasMixerVersion.current, success: false, error: err);
}

/// 算法版本号（前后端对账用，同 mixer.ts 的 GAS_CORE_ALGORITHM_VERSION）。
class GasMixerVersion {
  GasMixerVersion._();
  static const String current = 'mvp-1.0.0-dart';
}
