// 日志导入上层 API —— 发现设备 → 连接 → 下载 → 解析 → DiveLog。
// libdivecomputer FFI 实现后填充；当前是接口契约。

import 'models/dive_log.dart';
import 'transport.dart';

/// 下载进度回调（已下载 / 总数，总数未知时 total = -1）。
typedef ImportProgress = void Function(int current, int total);

/// 日志导入器。各 App（importer / plan）持有一个实例，驱动整个导入流程。
abstract class DiveImporter {
  /// 扫描可用设备（限定传输方式，或全部）。
  Stream<DiscoveredDevice> scan({Set<TransportKind>? kinds});

  /// 连接并下载某设备的潜水日志。
  /// [knownFingerprints]：已导入过的 fingerprint，用于增量下载（跳过旧记录）。
  Stream<DiveLog> download(
    DiscoveredDevice device, {
    Set<String> knownFingerprints = const {},
    ImportProgress? onProgress,
  });

  /// 取消当前下载并断开。
  Future<void> cancel();
}
