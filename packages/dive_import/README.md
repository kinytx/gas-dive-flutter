# dive_import · 潜水电脑日志导入核心库

> 三端共用（importer App + plan App），纯能力、无 UI。
> 通过 libdivecomputer（dart:ffi）解析，支持 BLE / ClassicBT / Serial / USB。

## 设计目标：智能自动导入

用户不用懂连接细节，App 自动完成「探测 → 扫描 → 过滤 → 一键导入」：

### 1. 平台能力自动探测 — `PlatformCapabilities.current()`
运行时判断当前平台支持哪些传输：

| 平台 | BLE | ClassicBT | Serial | USB |
|---|---|---|---|---|
| Android | ✅ | ✅ | ✅ | ✅ |
| iOS | ✅ | ⚠️ 仅 MFi | ❌ | ❌ |
| Windows/macOS/Linux | ✅ | ✅ | ✅ | ✅ |

### 2. 多传输并行扫描聚合 — `DiveImporter.scan()`
同时扫平台支持的所有传输（BLE 广播 + 串口枚举 + USB 设备 + 已配对 BT），
聚合成一个统一的设备流。

### 3. 潜水设备识别过滤（只列潜水相关）
从扫到的一堆设备里，只保留能被 libdivecomputer 认出的潜水电脑：
- **BLE**：按 service UUID / 设备名匹配 libdivecomputer 的 BLE 设备表
- **Serial/USB**：按 VID:PID / 端口特征匹配
- 识别出型号 → `DiscoveredDevice.diveComputerModel`；识别不出的不进列表

> 这是「智能」的核心难点，靠 libdivecomputer 的设备数据库（几百种机型）。

### 4. 最佳路径一键导入 — `DiscoveredDevice.bestTransport` + `download()`
一台设备可能多条连法（如同时有 BLE 和 Serial），自动选最佳路径连接、下载、
解析成 `DiveLog`，再交 `dive_api` 上传。增量下载靠 `fingerprint` 去重。

默认最佳路径策略：有线更稳更快 → `Serial > USB > BLE > ClassicBT`。

## 用户视角的流程

```
打开 App → 自动扫描（无需选传输方式）
        → 列表只显示潜水电脑（带型号 + 信号/连接方式标识）
        → 点一下「导入」→ 自动连接 + 下载 + 上传
```

## 实现状态

当前是**接口契约骨架**（transport / importer / dive_log）。
真实现（libdivecomputer FFI + 各平台传输）见 `docs/MASTER_PLAN.md` 阶段③。
**首验**：libdivecomputer FFI + 一台机器 BLE 端到端下载跑通。

参考：仓库内 `subsurface`（Qt + libdivecomputer + 平台 BLE 桥接）、
`libdivecomputerjs`、`android-ble-probe`、`garmin-sidecar`。
