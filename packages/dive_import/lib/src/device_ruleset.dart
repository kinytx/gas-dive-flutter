// 可进化的设备识别规则 —— 在 libdivecomputer 静态设备库之上叠加一层
// 「云端可热更新」的规则。用户数据越多 → 后端推送的规则越准（数据飞轮）。

import 'transport.dart';

/// 一条设备识别规则（云端可下发）。
class DeviceRule {
  /// 识别出的型号（如 "Shearwater Teric"）。
  final String model;

  /// 这台设备支持的传输方式。
  final Set<TransportKind> transports;

  // ── 匹配条件（命中任一即识别为本规则）──
  final List<String> bleServiceUuids;
  final List<String> bleNamePatterns; // 前缀 / 正则
  final List<String> usbVidPids; // "0403:6001"

  /// 最佳路径覆盖（某设备 BLE 不稳时，规则可强制走 serial 等）。
  final TransportKind? preferredTransport;

  const DeviceRule({
    required this.model,
    required this.transports,
    this.bleServiceUuids = const [],
    this.bleNamePatterns = const [],
    this.usbVidPids = const [],
    this.preferredTransport,
  });
}

/// 一份规则集（版本化，从后端拉取、本地缓存）。
class DeviceRuleset {
  final int version;
  final List<DeviceRule> rules;
  const DeviceRuleset({required this.version, this.rules = const []});

  static const empty = DeviceRuleset(version: 0);
}

/// 规则集来源：本地缓存 + 后端更新（实现走 dive_api）。
abstract class RulesetSource {
  /// 取当前规则集（本地缓存优先，离线可用）。
  Future<DeviceRuleset> current();

  /// 问后端有没有更新版本；有则下载并替换本地缓存。
  Future<DeviceRuleset?> pullUpdate();
}

/// 扫描遥测（匿名，喂数据飞轮）—— 仅设备公开特征，无用户隐私/位置。
class ScanTelemetry {
  final String? bleServiceUuid;
  final String? bleName;
  final String? usbVidPid;

  /// 是否被识别为潜水电脑。
  final bool recognized;

  /// 命中的型号（未识别为 null —— 这类「未知设备」正是后端要学习的）。
  final String? matchedModel;

  /// 连接是否成功（识别后用户尝试导入）。
  final bool? connectOk;

  const ScanTelemetry({
    this.bleServiceUuid,
    this.bleName,
    this.usbVidPid,
    required this.recognized,
    this.matchedModel,
    this.connectOk,
  });
}
