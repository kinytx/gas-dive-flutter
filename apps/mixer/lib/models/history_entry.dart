// 历史记录条目 - 翻译自 mixer 微信版 HistoryEntry (inter-app-types.ts L194-260)
//
// 简化策略（V1 本地版）：
//   - 保留核心输入/输出 + 元数据
//   - 暂不要 measurement / feedback / cloudRecordId（云同步阶段再加）
//   - 暂不要 agency 快照
// JSON 序列化用手写 toJson/fromJson，避免 codegen 依赖

import 'package:meta/meta.dart';
import 'package:mixer_core/mixer_core.dart';

@immutable
class HistoryEntry {
  /// 本地稳定 ID（UUID v4），云同步时用
  final String syncId;

  /// 最近修改时间（epoch ms），列表排序 + 云同步合并用
  final int syncUpdatedAt;

  /// 创建时间（ISO 字符串）
  final DateTime time;

  /// 预设名（"EAN32" / "Tx18/45" / "自定义" 等）
  final String presetName;

  // ─── 输入 ──────────────────────────────────────
  final double currentO2;
  final double currentHe;
  final double currentPressure;
  final double targetO2;
  final double targetHe;
  final double targetPressure;

  // ─── 高级 ──────────────────────────────────────
  final bool useRealGases;
  final double tempC;
  final PressureRef pressureRef;
  final double altitudeM;
  final AltitudeMode altitudeMode;
  final FillOrder fillOrder;

  // ─── 输出（主要值） ────────────────────────────
  final double oxygenToFill;
  final double heliumToFill;
  final double airToFill;
  final bool needToDrain;
  final double drainToPressure;
  final double fillGaugePressure;

  // ─── 元数据 ────────────────────────────────────
  /// 收藏置顶时间（epoch ms），非空 = 已置顶
  final int? starredAt;

  /// 用户备注（"马尔代夫 60m 用" 之类）
  final String? notes;

  /// 气瓶水容积 (L)，用于气体用量统计
  final double? tankVolumeL;

  const HistoryEntry({
    required this.syncId,
    required this.syncUpdatedAt,
    required this.time,
    required this.presetName,
    required this.currentO2,
    required this.currentHe,
    required this.currentPressure,
    required this.targetO2,
    required this.targetHe,
    required this.targetPressure,
    required this.useRealGases,
    required this.tempC,
    required this.pressureRef,
    required this.altitudeM,
    required this.altitudeMode,
    required this.fillOrder,
    required this.oxygenToFill,
    required this.heliumToFill,
    required this.airToFill,
    required this.needToDrain,
    required this.drainToPressure,
    required this.fillGaugePressure,
    this.starredAt,
    this.notes,
    this.tankVolumeL,
  });

  /// 从混气计算结果 + 输入参数生成历史记录
  factory HistoryEntry.fromResult({
    required CalculateMixParams params,
    required MixResult result,
    required String presetName,
    String? notes,
    double? tankVolumeL,
  }) {
    final now = DateTime.now();
    return HistoryEntry(
      syncId: _genUuidLike(),
      syncUpdatedAt: now.millisecondsSinceEpoch,
      time: now,
      presetName: presetName,
      currentO2: params.currentO2,
      currentHe: params.currentHe,
      currentPressure: params.currentPressure,
      targetO2: params.targetO2,
      targetHe: params.targetHe,
      targetPressure: params.targetPressure,
      useRealGases: params.useRealGases,
      tempC: params.tempC,
      pressureRef: params.pressureRef,
      altitudeM: params.altitudeM,
      altitudeMode: params.altitudeMode,
      fillOrder: params.fillOrder,
      oxygenToFill: result.oxygenToFill,
      heliumToFill: result.heliumToFill,
      airToFill: result.airToFill,
      needToDrain: result.needToDrain,
      drainToPressure: result.drainToPressure,
      fillGaugePressure: result.fillGaugePressure,
      notes: notes,
      tankVolumeL: tankVolumeL,
    );
  }

  HistoryEntry copyWith({
    String? presetName,
    int? syncUpdatedAt,
    int? starredAt,
    bool clearStarred = false,
    String? notes,
    double? tankVolumeL,
  }) =>
      HistoryEntry(
        syncId: syncId,
        syncUpdatedAt: syncUpdatedAt ?? this.syncUpdatedAt,
        time: time,
        presetName: presetName ?? this.presetName,
        currentO2: currentO2,
        currentHe: currentHe,
        currentPressure: currentPressure,
        targetO2: targetO2,
        targetHe: targetHe,
        targetPressure: targetPressure,
        useRealGases: useRealGases,
        tempC: tempC,
        pressureRef: pressureRef,
        altitudeM: altitudeM,
        altitudeMode: altitudeMode,
        fillOrder: fillOrder,
        oxygenToFill: oxygenToFill,
        heliumToFill: heliumToFill,
        airToFill: airToFill,
        needToDrain: needToDrain,
        drainToPressure: drainToPressure,
        fillGaugePressure: fillGaugePressure,
        starredAt: clearStarred ? null : (starredAt ?? this.starredAt),
        notes: notes ?? this.notes,
        tankVolumeL: tankVolumeL ?? this.tankVolumeL,
      );

  /// 转 Map（用于 JSON 序列化）。enum 字段存 wire 字符串便于跨版本兼容
  Map<String, dynamic> toJson() => {
        'syncId': syncId,
        'syncUpdatedAt': syncUpdatedAt,
        'time': time.toIso8601String(),
        'presetName': presetName,
        'currentO2': currentO2,
        'currentHe': currentHe,
        'currentPressure': currentPressure,
        'targetO2': targetO2,
        'targetHe': targetHe,
        'targetPressure': targetPressure,
        'useRealGases': useRealGases,
        'tempC': tempC,
        'pressureRef': pressureRef.name, // 'fill' | 'std'
        'altitudeM': altitudeM,
        'altitudeMode': altitudeMode.name, // 'none' | 'a' | ...
        'fillOrder': fillOrder.wire, // 'he-first' | 'o2-first'
        'oxygenToFill': oxygenToFill,
        'heliumToFill': heliumToFill,
        'airToFill': airToFill,
        'needToDrain': needToDrain,
        'drainToPressure': drainToPressure,
        'fillGaugePressure': fillGaugePressure,
        if (starredAt != null) 'starredAt': starredAt,
        if (notes != null) 'notes': notes,
        if (tankVolumeL != null) 'tankVolumeL': tankVolumeL,
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> j) => HistoryEntry(
        syncId: j['syncId'] as String,
        syncUpdatedAt: (j['syncUpdatedAt'] as num).toInt(),
        time: DateTime.parse(j['time'] as String),
        presetName: j['presetName'] as String,
        currentO2: (j['currentO2'] as num).toDouble(),
        currentHe: (j['currentHe'] as num).toDouble(),
        currentPressure: (j['currentPressure'] as num).toDouble(),
        targetO2: (j['targetO2'] as num).toDouble(),
        targetHe: (j['targetHe'] as num).toDouble(),
        targetPressure: (j['targetPressure'] as num).toDouble(),
        useRealGases: j['useRealGases'] as bool? ?? false,
        tempC: (j['tempC'] as num?)?.toDouble() ?? 20,
        pressureRef: PressureRef.values
            .firstWhere((e) => e.name == j['pressureRef'],
                orElse: () => PressureRef.fill),
        altitudeM: (j['altitudeM'] as num?)?.toDouble() ?? 0,
        altitudeMode: AltitudeMode.values
            .firstWhere((e) => e.name == j['altitudeMode'],
                orElse: () => AltitudeMode.b),
        fillOrder: FillOrder.values
            .firstWhere((e) => e.wire == j['fillOrder'],
                orElse: () => FillOrder.heFirst),
        oxygenToFill: (j['oxygenToFill'] as num).toDouble(),
        heliumToFill: (j['heliumToFill'] as num).toDouble(),
        airToFill: (j['airToFill'] as num).toDouble(),
        needToDrain: j['needToDrain'] as bool? ?? false,
        drainToPressure: (j['drainToPressure'] as num?)?.toDouble() ?? 0,
        fillGaugePressure: (j['fillGaugePressure'] as num?)?.toDouble() ??
            (j['targetPressure'] as num).toDouble(),
        starredAt: (j['starredAt'] as num?)?.toInt(),
        notes: j['notes'] as String?,
        tankVolumeL: (j['tankVolumeL'] as num?)?.toDouble(),
      );
}

/// 简化版 UUID-like（不依赖外部包）— 时间戳 + 随机
String _genUuidLike() {
  final ts = DateTime.now().millisecondsSinceEpoch.toRadixString(16);
  final r = (DateTime.now().microsecondsSinceEpoch * 2654435761) & 0xFFFFFFFF;
  return '$ts-${r.toRadixString(16)}';
}
