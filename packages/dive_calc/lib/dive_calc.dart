/// 潜水通用计算 — 公共 API。
///
/// 翻译自 [gas-dive-mixer/shared/utils/dive-calc.ts]。
/// 对外暴露：
///
/// - 类：[DiveCalculator]、[DiveCalcConfig]、[GasMix]、[ZHL16CCompartment]
/// - 默认配置：[defaultDiveCalcConfig]
/// - 向后兼容的纯函数：[calcMOD]、[calcEND]、[calcEADD]、[calcNDL]
library dive_calc;

export 'src/constants.dart';
export 'src/types.dart';
export 'src/dive_calculator.dart';
