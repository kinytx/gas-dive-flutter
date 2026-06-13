/// 潜水电脑日志导入核心库 —— importer App 与 plan App 复用。
///
/// 设备连接（BLE / Serial / USB / ClassicBT）+ libdivecomputer 解析 + 上传。
/// 设备识别支持云端可热更新规则（数据飞轮）。纯能力，无 UI。
library dive_import;

export 'src/device_ruleset.dart';
export 'src/importer.dart';
export 'src/models/dive_log.dart';
export 'src/transport.dart';
