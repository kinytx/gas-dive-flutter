// 解析后的潜水日志模型（libdivecomputer dc_parser 输出 → Dart）。

import 'package:meta/meta.dart';

/// 一次潜水的完整记录。
@immutable
class DiveLog {
  final DateTime startTime;
  final Duration duration;
  final double maxDepthM;
  final double? avgDepthM;
  final double? minTempC;

  /// 设备型号（如 "Shearwater Perdix"）。
  final String? deviceModel;

  /// libdivecomputer fingerprint —— 跨次下载去重用。
  final String? fingerprint;

  /// 时间序列采样。
  final List<DiveSample> samples;

  const DiveLog({
    required this.startTime,
    required this.duration,
    required this.maxDepthM,
    this.avgDepthM,
    this.minTempC,
    this.deviceModel,
    this.fingerprint,
    this.samples = const [],
  });
}

/// 单个采样点。
@immutable
class DiveSample {
  final Duration time;
  final double depthM;
  final double? tempC;

  /// 气瓶压力（有气源/AI 时）。
  final int? pressureBar;

  final List<DiveEvent> events;

  const DiveSample({
    required this.time,
    required this.depthM,
    this.tempC,
    this.pressureBar,
    this.events = const [],
  });
}

/// 事件（换气 / 警告 / 上升过快等）。
@immutable
class DiveEvent {
  final String type;
  final String? note;
  const DiveEvent({required this.type, this.note});
}
