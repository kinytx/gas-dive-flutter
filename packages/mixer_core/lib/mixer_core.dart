/// 气体混合核心算法 — 公共 API。
///
/// 翻译自 [gas-dive-mixer/shared/utils/mixer.ts] 的「理想气体 + 简单分压」子集
/// （MVP 版）。
///
/// **纳入**：current → target 的 O₂/He/Air 分步填充量 + 顺序 + 基本警告。
///
/// **不纳入**（V2+ 再加）：
/// - Z 因子真实气体修正
/// - 海拔 O₂ 修正
/// - 温度 std 折算
/// - per-step Z
/// - Drain 自动求解
library mixer_core;

export 'src/types.dart';
export 'src/gas_mixer.dart';
