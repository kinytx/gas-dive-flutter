/// 数据结构（对应 TS interface）。
///
/// Dart 没有结构化类型 / 鸭子接口，用不可变 value class 实现。
/// 全部用 `const` 构造避免重复分配。
library;

import 'package:meta/meta.dart';

// ════════════════════════════════════════════════════════════
// 1. Interfaces — 关键数据结构
// ════════════════════════════════════════════════════════════

/// 气体混合配比（百分比，0-100）。
@immutable
class GasMix {
  /// O₂ 百分比
  final double o2Pct;

  /// He 百分比
  final double hePct;

  const GasMix({required this.o2Pct, required this.hePct});

  @override
  bool operator ==(Object other) =>
      other is GasMix && other.o2Pct == o2Pct && other.hePct == hePct;

  @override
  int get hashCode => Object.hash(o2Pct, hePct);

  @override
  String toString() => 'GasMix(O₂=${o2Pct.toStringAsFixed(1)}%, '
      'He=${hePct.toStringAsFixed(1)}%)';
}

/// ZHL-16C 单个隔室（仅 N₂，用于 NDL 计算）。
@immutable
class ZHL16CCompartment {
  /// 半衰期（分钟）
  final double ht;

  /// M 值参数 a
  final double a;

  /// M 值参数 b
  final double b;

  const ZHL16CCompartment({required this.ht, required this.a, required this.b});
}

/// 气体摩尔质量集合 (g/L @ STP)。
@immutable
class MolarMassMap {
  final double o2;
  final double he;
  final double n2;
  final double air;

  const MolarMassMap({
    required this.o2,
    required this.he,
    required this.n2,
    required this.air,
  });
}

// ════════════════════════════════════════════════════════════
// 2. 输入参数类（对应 TS *Input interface）
// ════════════════════════════════════════════════════════════

/// MOD（最大操作深度）计算输入。
@immutable
class MODInput {
  /// 目标 ppO₂ 上限 (bar)
  final double po2;

  /// O₂ 百分比 (0-100)
  final double o2Pct;

  /// 表面压力 (bar)，省略则使用 config.surfacePressure
  final double? surfacePressure;

  const MODInput({
    required this.po2,
    required this.o2Pct,
    this.surfacePressure,
  });
}

/// END（等效麻醉深度）计算输入。
@immutable
class ENDInput {
  final GasMix gas;

  /// 当前深度 (m)
  final double depth;

  /// O₂ 的麻醉系数（省略则使用 config.defaultNarcosis）
  final double? narcosis;

  final double? surfacePressure;

  const ENDInput({
    required this.gas,
    required this.depth,
    this.narcosis,
    this.surfacePressure,
  });
}

/// EADD（等效空气密度深度）计算输入。
@immutable
class EADDInput {
  final GasMix gas;
  final double depth;
  final double? surfacePressure;

  const EADDInput({required this.gas, required this.depth, this.surfacePressure});
}

/// NDL（免减压极限）计算输入。
@immutable
class NDLInput {
  final double o2Pct;

  /// 深度 (m)
  final double depthM;

  /// true = 海水，false = 淡水
  final bool saltWater;

  /// 水温 (°C)
  final double tempC;

  final double? surfacePressure;

  const NDLInput({
    required this.o2Pct,
    required this.depthM,
    required this.saltWater,
    required this.tempC,
    this.surfacePressure,
  });
}
