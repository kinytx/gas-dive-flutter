// 设备传输抽象 + 平台能力探测。
// 上层 API 不感知底层是 BLE / Serial / USB / ClassicBT；各平台实现把读写通道
// 塞进 libdivecomputer 的 custom-IO 回调。

import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;

/// 连接方式。
enum TransportKind { ble, classicBt, serial, usb }

/// 当前平台支持哪些传输 —— importer「智能匹配接口」的基础。
class PlatformCapabilities {
  final Set<TransportKind> supported;
  const PlatformCapabilities(this.supported);

  /// 运行时探测当前平台能力：
  ///   Android             : BLE + ClassicBT + Serial + USB
  ///   iOS                 : BLE（ClassicBT 仅 MFi 设备，默认不列）
  ///   Windows/macOS/Linux : BLE + ClassicBT + Serial + USB
  factory PlatformCapabilities.current() {
    if (kIsWeb) return const PlatformCapabilities({TransportKind.ble});
    if (Platform.isIOS) return const PlatformCapabilities({TransportKind.ble});
    return const PlatformCapabilities({
      TransportKind.ble,
      TransportKind.classicBt,
      TransportKind.serial,
      TransportKind.usb,
    });
  }

  bool supports(TransportKind k) => supported.contains(k);
}

/// 扫描发现、且已识别为潜水电脑的设备（非潜水设备不会出现）。
class DiscoveredDevice {
  /// BLE: mac/uuid；serial: 端口名（COM3 / /dev/ttyUSB0）。
  final String id;
  final String name;

  /// 这台设备当前可用的传输方式（可能多条，如同时支持 BLE 和 Serial）。
  final Set<TransportKind> transports;

  /// libdivecomputer 识别出的型号（如 "Shearwater Perdix"）。
  final String diveComputerModel;

  /// BLE 信号强度（其它传输为 null）。
  final int? rssi;

  const DiscoveredDevice({
    required this.id,
    required this.name,
    required this.transports,
    required this.diveComputerModel,
    this.rssi,
  });

  /// 一键导入用的最佳传输路径。
  /// 默认策略：有线更稳更快 → Serial > USB > BLE > ClassicBT。
  /// （移动端通常只有 BLE；策略后续可做成可配。）
  TransportKind get bestTransport {
    const priority = [
      TransportKind.serial,
      TransportKind.usb,
      TransportKind.ble,
      TransportKind.classicBt,
    ];
    return priority.firstWhere(transports.contains,
        orElse: () => transports.first);
  }
}

/// 一个已连接设备的双向字节通道。
/// libdivecomputer 的 custom-IO 通过 [incoming] / [send] 读写。
abstract class DeviceTransport {
  TransportKind get kind;
  bool get isConnected;

  Future<void> connect();
  Future<void> disconnect();

  /// 设备 → App 的字节流。
  Stream<Uint8List> get incoming;

  /// App → 设备。
  Future<void> send(Uint8List data);
}
