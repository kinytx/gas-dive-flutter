// mixer_core V2a 单元测试
//
// V2 算法切换到「绝对压差」（gauge + pLocal），跟 mixer.ts 严格对齐。
// 跟 V1 「表压差」 比，多数用例差 0.1-1 bar（多 1.013 bar 在两端导致）。
//
// 所有预期值用 node 模拟 mixer.ts 全流程算出，含 drain LP 求解 + 海拔修正 + std 折算。
// 验算脚本附在文件末尾。
//
// 跑：cd packages/mixer_core && dart test

import 'package:mixer_core/mixer_core.dart';
import 'package:test/test.dart';

const _eps = 0.01; // 1 cbar 容差

void main() {
  final mixer = GasMixer();

  // ════════════════════════════════════════════════════════════
  // 基础路径（V1 用例，预期值按 V2 绝对压更新）
  // ════════════════════════════════════════════════════════════
  group('基础路径（V2 绝对压算法）', () {
    test('空瓶 → Nitrox 32 @ 200 bar', () {
      final r = mixer.calculate(const CalculateMixParams(
        currentO2: 21, currentHe: 0, currentPressure: 0,
        targetO2: 32, targetHe: 0, targetPressure: 200,
      ));
      expect(r.success, isTrue);
      expect(r.heliumToFill, closeTo(0, _eps));
      expect(r.oxygenToFill, closeTo(27.989, _eps));
      expect(r.airToFill, closeTo(172.011, _eps));
      expect(r.fillSequence.length, 3);
      expect(r.altitudeInfo, isNull);
    });

    test('空瓶 → Trimix 18/45 @ 200 bar', () {
      final r = mixer.calculate(const CalculateMixParams(
        currentO2: 21, currentHe: 0, currentPressure: 0,
        targetO2: 18, targetHe: 45, targetPressure: 200,
      ));
      expect(r.success, isTrue);
      expect(r.heliumToFill, closeTo(90.456, _eps));
      expect(r.oxygenToFill, closeTo(16.412, _eps));
      expect(r.airToFill, closeTo(93.132, _eps));
    });

    test('Nitrox 32 残 50 → 满 200 (同 O₂%，跟 V1 一致)', () {
      final r = mixer.calculate(const CalculateMixParams(
        currentO2: 32, currentHe: 0, currentPressure: 50,
        targetO2: 32, targetHe: 0, targetPressure: 200,
      ));
      expect(r.success, isTrue);
      expect(r.heliumToFill, closeTo(0, _eps));
      expect(r.oxygenToFill, closeTo(20.886, _eps));
      expect(r.airToFill, closeTo(129.114, _eps));
    });

    test('Air 残 50 → 满 200 (同气体，跟 V1 一致)', () {
      final r = mixer.calculate(const CalculateMixParams(
        currentO2: 21, currentHe: 0, currentPressure: 50,
        targetO2: 21, targetHe: 0, targetPressure: 200,
      ));
      expect(r.success, isTrue);
      expect(r.heliumToFill, closeTo(0, _eps));
      expect(r.oxygenToFill, closeTo(0, _eps));
      expect(r.airToFill, closeTo(150, _eps));
    });

    test('空瓶 → Heliox 10/90 (N₂=0 触发 drain)', () {
      final r = mixer.calculate(const CalculateMixParams(
        currentO2: 21, currentHe: 0, currentPressure: 0,
        targetO2: 10, targetHe: 90, targetPressure: 200,
      ));
      // 空瓶 1.013 bar 本底空气含 0.79 N₂，目标 Heliox 不含 N₂，需 drain
      expect(r.success, isTrue);
      expect(r.needToDrain, isTrue);
      expect(r.heliumToFill, closeTo(180.912, _eps));
      expect(r.oxygenToFill, closeTo(19.889, _eps));
      expect(r.airToFill, closeTo(0, _eps));
    });
  });

  // ════════════════════════════════════════════════════════════
  // Drain 路径
  // ════════════════════════════════════════════════════════════
  group('Drain 自动求解', () {
    test('He 过富 (50% He → 0% He)：drain 到 0 全部重填', () {
      final r = mixer.calculate(const CalculateMixParams(
        currentO2: 18, currentHe: 50, currentPressure: 100,
        targetO2: 21, targetHe: 0, targetPressure: 200,
      ));
      expect(r.success, isTrue);
      expect(r.needToDrain, isTrue);
      expect(r.drainToPressure, closeTo(0, _eps));
      expect(r.heliumToFill, closeTo(0, _eps));
      expect(r.oxygenToFill, closeTo(0, _eps));
      expect(r.airToFill, closeTo(200.603, _eps));
    });

    test('O₂ 过富 (50% O₂ → 21% O₂)：drainByO2Excess 触发', () {
      final r = mixer.calculate(const CalculateMixParams(
        currentO2: 50, currentHe: 0, currentPressure: 100,
        targetO2: 21, targetHe: 0, targetPressure: 200,
      ));
      expect(r.success, isTrue);
      expect(r.needToDrain, isTrue);
      expect(r.drainToPressure, closeTo(0, _eps));
      expect(r.airToFill, closeTo(200.372, _eps));
    });

    test('部分 drain (Trimix 30/30 → 18/45，drainByO2Excess)', () {
      // Nitrox→Nitrox 单 O₂ 场景下数学上 drain 只能到 0（残气比例不变，必须重头来）
      // 部分 drain 只在 Trimix→Trimix 出现：He 比例不一致时可保留部分残气
      // Tx30/30 100bar → Tx18/45 200bar：O₂ 富氧但 He 不足，drain 到 84.3 bar 后 top-off
      final r = mixer.calculate(const CalculateMixParams(
        currentO2: 30, currentHe: 30, currentPressure: 100,
        targetO2: 18, targetHe: 45, targetPressure: 200,
      ));
      expect(r.success, isTrue);
      expect(r.needToDrain, isTrue);
      expect(r.drainToPressure, closeTo(84.314, 0.05));
    });

    test('Nx40 100 → Nx32 200 不需要 drain (Air 顶气稀释足够)', () {
      // 100 bar Nx40 + 100 bar Air 配出 Nx30.5，差最终 Nx32 还少 1.5%
      // 算法继续小量 O₂ 补足，全部 fill ≥ 0，不触发 drain
      final r = mixer.calculate(const CalculateMixParams(
        currentO2: 40, currentHe: 0, currentPressure: 100,
        targetO2: 32, targetHe: 0, targetPressure: 200,
      ));
      expect(r.success, isTrue);
      expect(r.needToDrain, isFalse);
    });
  });

  // ════════════════════════════════════════════════════════════
  // 海拔修正
  // ════════════════════════════════════════════════════════════
  group('海拔 O₂ 修正', () {
    test('海拔 0m 不修正，altitudeInfo=null', () {
      final r = mixer.calculate(const CalculateMixParams(
        currentO2: 21, currentHe: 0, currentPressure: 0,
        targetO2: 32, targetHe: 0, targetPressure: 200,
        altitudeM: 0,
        altitudeMode: AltitudeMode.b,
      ));
      expect(r.success, isTrue);
      expect(r.altitudeInfo, isNull);
    });

    test('海拔 3000m mode A → adjustedO2 大幅上调', () {
      final r = mixer.calculate(const CalculateMixParams(
        currentO2: 21, currentHe: 0, currentPressure: 0,
        targetO2: 32, targetHe: 0, targetPressure: 200,
        altitudeM: 3000,
        altitudeMode: AltitudeMode.a,
      ));
      expect(r.success, isTrue);
      expect(r.altitudeInfo, isNotNull);
      // 3000m: pLocal ≈ 0.7012, pRatio ≈ 1.445
      // adjustedO2 = 32 × (1.013/0.7012) ≈ 46.23
      expect(r.altitudeInfo!.adjustedO2, closeTo(46.234, 0.01));
      expect(r.altitudeInfo!.pLocalBar, closeTo(0.7011, 0.001));
      expect(r.altitudeInfo!.originalO2, 32);
      expect(r.altitudeInfo!.mode, AltitudeMode.a);
    });

    test('海拔 3000m mode C: 不改 O₂%，但 altitudeInfo 仍填', () {
      final r = mixer.calculate(const CalculateMixParams(
        currentO2: 21, currentHe: 0, currentPressure: 0,
        targetO2: 32, targetHe: 0, targetPressure: 200,
        altitudeM: 3000,
        altitudeMode: AltitudeMode.c,
      ));
      expect(r.success, isTrue);
      expect(r.altitudeInfo, isNotNull);
      expect(r.altitudeInfo!.adjustedO2, 32);
      expect(r.altitudeInfo!.adjustedHe, 0);
    });

    test('海拔 3000m mode none: 跟海平面行为一致', () {
      final r = mixer.calculate(const CalculateMixParams(
        currentO2: 21, currentHe: 0, currentPressure: 0,
        targetO2: 32, targetHe: 0, targetPressure: 200,
        altitudeM: 3000,
        altitudeMode: AltitudeMode.none,
      ));
      expect(r.success, isTrue);
      expect(r.altitudeInfo, isNotNull); // 仍填充以显示 pLocal
      expect(r.altitudeInfo!.adjustedO2, 32);
    });

    test('Trimix 18/45 海拔 mode A: He 反向调整', () {
      final r = mixer.calculate(const CalculateMixParams(
        currentO2: 21, currentHe: 0, currentPressure: 0,
        targetO2: 18, targetHe: 45, targetPressure: 200,
        altitudeM: 2000,
        altitudeMode: AltitudeMode.a,
      ));
      expect(r.success, isTrue);
      // mode A 含 He 时 adjustedHe = targetHe - deltaO2
      // deltaO2 > 0，所以 adjustedHe < 45
      expect(r.altitudeInfo!.adjustedHe, lessThan(45));
      expect(r.altitudeInfo!.adjustedO2, greaterThan(18));
    });
  });

  // ════════════════════════════════════════════════════════════
  // std → fill 温度折算
  // ════════════════════════════════════════════════════════════
  group('温度折算 (pressureRef=std)', () {
    test('std 35°C: 实际填到 ~209.5 bar', () {
      final r = mixer.calculate(const CalculateMixParams(
        currentO2: 21, currentHe: 0, currentPressure: 0,
        targetO2: 32, targetHe: 0, targetPressure: 200,
        tempC: 35,
        pressureRef: PressureRef.std,
      ));
      expect(r.success, isTrue);
      // 200 × (273.15 + 35) / (273.15 + 21) = 209.519
      expect(r.fillGaugePressure, closeTo(209.519, 0.01));
      expect(r.oxygenToFill, closeTo(29.315, 0.05));
    });

    test('fill ref (默认): fillGaugePressure = targetPressure', () {
      final r = mixer.calculate(const CalculateMixParams(
        currentO2: 21, currentHe: 0, currentPressure: 0,
        targetO2: 32, targetHe: 0, targetPressure: 200,
        tempC: 35,
        pressureRef: PressureRef.fill,
      ));
      expect(r.fillGaugePressure, 200);
    });

    test('std 21°C (= 标准温度): 等于 fill 表压', () {
      final r = mixer.calculate(const CalculateMixParams(
        currentO2: 21, currentHe: 0, currentPressure: 0,
        targetO2: 32, targetHe: 0, targetPressure: 200,
        tempC: 21,
        pressureRef: PressureRef.std,
      ));
      expect(r.fillGaugePressure, closeTo(200, _eps));
    });
  });

  // ════════════════════════════════════════════════════════════
  // fillSequence 顺序
  // ════════════════════════════════════════════════════════════
  group('fillSequence 顺序', () {
    test('he-first: He → O₂ → Air', () {
      final r = mixer.calculate(const CalculateMixParams(
        currentO2: 21, currentHe: 0, currentPressure: 0,
        targetO2: 18, targetHe: 45, targetPressure: 200,
        fillOrder: FillOrder.heFirst,
      ));
      expect(r.fillSequence.map((s) => s.gas).toList(),
          [FillGas.he, FillGas.o2, FillGas.air]);
    });

    test('o2-first: O₂ → Air → He', () {
      final r = mixer.calculate(const CalculateMixParams(
        currentO2: 21, currentHe: 0, currentPressure: 0,
        targetO2: 18, targetHe: 45, targetPressure: 200,
        fillOrder: FillOrder.o2First,
      ));
      expect(r.fillSequence.map((s) => s.gas).toList(),
          [FillGas.o2, FillGas.air, FillGas.he]);
    });

    test('累计 pressureBar 递增到 targetPressure 附近', () {
      final r = mixer.calculate(const CalculateMixParams(
        currentO2: 21, currentHe: 0, currentPressure: 50,
        targetO2: 32, targetHe: 0, targetPressure: 200,
      ));
      // 最后一步累计 pressureBar = 50 + (fillHe+fillO2+fillAir)
      final total = r.heliumToFill + r.oxygenToFill + r.airToFill;
      expect(r.fillSequence.last.pressureBar, closeTo(50 + total, _eps));
    });
  });

  // ════════════════════════════════════════════════════════════
  // 错误路径
  // ════════════════════════════════════════════════════════════
  group('错误路径', () {
    test('O₂ 越界 → invalidInput', () {
      final r = mixer.calculate(const CalculateMixParams(
        currentO2: 200, currentHe: 0, currentPressure: 0,
        targetO2: 32, targetHe: 0, targetPressure: 200,
      ));
      expect(r.success, isFalse);
      expect(r.error, MixErrorCode.invalidInput);
    });

    test('目标 O₂+He > 100 → invalidTargetGas', () {
      final r = mixer.calculate(const CalculateMixParams(
        currentO2: 21, currentHe: 0, currentPressure: 0,
        targetO2: 60, targetHe: 60, targetPressure: 200,
      ));
      expect(r.error, MixErrorCode.invalidTargetGas);
    });

    test('targetPressure ≤ currentPressure → targetPressureTooLow', () {
      final r = mixer.calculate(const CalculateMixParams(
        currentO2: 32, currentHe: 0, currentPressure: 200,
        targetO2: 32, targetHe: 0, targetPressure: 150,
      ));
      expect(r.error, MixErrorCode.targetPressureTooLow);
    });

    test('海拔为负 → invalidInput', () {
      final r = mixer.calculate(const CalculateMixParams(
        currentO2: 21, currentHe: 0, currentPressure: 0,
        targetO2: 32, targetHe: 0, targetPressure: 200,
        altitudeM: -100,
      ));
      expect(r.error, MixErrorCode.invalidInput);
    });
  });

  // ════════════════════════════════════════════════════════════
  // 警告
  // ════════════════════════════════════════════════════════════
  group('软警告', () {
    test('残压 5 bar → lowResidualPressure', () {
      final r = mixer.calculate(const CalculateMixParams(
        currentO2: 21, currentHe: 0, currentPressure: 5,
        targetO2: 32, targetHe: 0, targetPressure: 200,
      ));
      expect(r.success, isTrue);
      expect(r.warnings, contains(MixWarning.lowResidualPressure));
    });

    test('残压 0 (空瓶) 不触发警告', () {
      final r = mixer.calculate(const CalculateMixParams(
        currentO2: 21, currentHe: 0, currentPressure: 0,
        targetO2: 32, targetHe: 0, targetPressure: 200,
      ));
      expect(r.warnings, isEmpty);
    });

    test('残压 30 不触发警告', () {
      final r = mixer.calculate(const CalculateMixParams(
        currentO2: 21, currentHe: 0, currentPressure: 30,
        targetO2: 32, targetHe: 0, targetPressure: 200,
      ));
      expect(r.warnings, isEmpty);
    });
  });

  // ════════════════════════════════════════════════════════════
  // V2b: Z 因子真实气体修正
  // ════════════════════════════════════════════════════════════
  group('Z 因子修正 (useRealGases)', () {
    test('useRealGases=false (默认): zFactors=null, 跟 V2a 一致', () {
      final r = mixer.calculate(const CalculateMixParams(
        currentO2: 21, currentHe: 0, currentPressure: 0,
        targetO2: 32, targetHe: 0, targetPressure: 200,
      ));
      expect(r.zFactors, isNull);
      expect(r.oxygenToFill, closeTo(27.989, _eps));
      expect(r.airToFill, closeTo(172.011, _eps));
    });

    test('useRealGases=true: fillO₂ / Z 略增、fillAir / Z 略减', () {
      // Nx32 200 useRealGases=true:
      //   Z(O₂ @ 64bar 20°C) ≈ 0.9625 → fillO₂ 27.989 / 0.9625 ≈ 29.08
      //   Z(Air @ 200bar 20°C) ≈ 1.0268 → fillAir 172.011 / 1.0268 ≈ 167.52
      //   Z(He @ 0bar) = 1.0 → fillHe 0 不变
      final r = mixer.calculate(const CalculateMixParams(
        currentO2: 21, currentHe: 0, currentPressure: 0,
        targetO2: 32, targetHe: 0, targetPressure: 200,
        useRealGases: true,
      ));
      expect(r.zFactors, isNotNull);
      expect(r.zFactors!.oxygen, closeTo(0.96253, 0.001));
      expect(r.zFactors!.air, closeTo(1.02680, 0.001));
      expect(r.zFactors!.helium, 1.0); // 0 bar 短路
      expect(r.oxygenToFill, closeTo(29.08, 0.05));
      expect(r.airToFill, closeTo(167.52, 0.05));
    });

    test('Trimix 18/45: Z(He) ≠ 1，fillHe 也修正', () {
      final r = mixer.calculate(const CalculateMixParams(
        currentO2: 21, currentHe: 0, currentPressure: 0,
        targetO2: 18, targetHe: 45, targetPressure: 200,
        useRealGases: true,
      ));
      expect(r.zFactors, isNotNull);
      // Z(He @ 0.45×200=90bar 20°C) > 1 (He 量子气体偏 ideal 方向反向)
      expect(r.zFactors!.helium, greaterThan(1.0));
      // V2a 下 fillHe = 90.456，V2b /Z 后会略小
      expect(r.heliumToFill, lessThan(90.456));
    });

    test('低压 (50 bar) Z 接近 1, V2a/V2b 差异在 1.5 bar 内', () {
      final v2a = mixer.calculate(const CalculateMixParams(
        currentO2: 21, currentHe: 0, currentPressure: 0,
        targetO2: 32, targetHe: 0, targetPressure: 50,
      ));
      final v2b = mixer.calculate(const CalculateMixParams(
        currentO2: 21, currentHe: 0, currentPressure: 0,
        targetO2: 32, targetHe: 0, targetPressure: 50,
        useRealGases: true,
      ));
      // 50 bar 下 Z(O₂@16bar)≈0.995, Z(Air@50)≈0.985，修正幅度 ~1-2%
      // fillAir≈42 bar / 0.985 多约 0.65 bar；放宽阈值到 1.5 bar
      expect((v2b.oxygenToFill - v2a.oxygenToFill).abs(), lessThan(1.5));
      expect((v2b.airToFill - v2a.airToFill).abs(), lessThan(1.5));
      // 200 bar 时 Z 偏离更大，所以反过来验证：50bar 修正比 200bar 修正小
      final r200 = mixer.calculate(const CalculateMixParams(
        currentO2: 21, currentHe: 0, currentPressure: 0,
        targetO2: 32, targetHe: 0, targetPressure: 200,
        useRealGases: true,
      ));
      final r200v2a = mixer.calculate(const CalculateMixParams(
        currentO2: 21, currentHe: 0, currentPressure: 0,
        targetO2: 32, targetHe: 0, targetPressure: 200,
      ));
      final diff50 = (v2b.airToFill - v2a.airToFill).abs();
      final diff200 = (r200.airToFill - r200v2a.airToFill).abs();
      expect(diff50, lessThan(diff200)); // 物理直觉：高压 Z 修正幅度更大
    });
  });

  // ════════════════════════════════════════════════════════════
  // 自由函数
  // ════════════════════════════════════════════════════════════
  group('向后兼容自由函数', () {
    test('calculateMix == GasMixer().calculate', () {
      const params = CalculateMixParams(
        currentO2: 21, currentHe: 0, currentPressure: 50,
        targetO2: 32, targetHe: 0, targetPressure: 200,
      );
      final a = calculateMix(params);
      final b = GasMixer().calculate(params);
      expect(a.oxygenToFill, b.oxygenToFill);
      expect(a.heliumToFill, b.heliumToFill);
      expect(a.airToFill, b.airToFill);
    });
  });

  // ════════════════════════════════════════════════════════════
  // Atmosphere 子模块
  // ════════════════════════════════════════════════════════════
  group('Atmosphere', () {
    test('海平面 0m → 1.01325 bar', () {
      expect(altitudeToSurfacePressure(0), 1.01325);
    });

    test('3000m → ~0.7011 bar', () {
      expect(altitudeToSurfacePressure(3000), closeTo(0.7011, 0.001));
    });

    test('海拔越高气压越低', () {
      final p1 = altitudeToSurfacePressure(1000);
      final p2 = altitudeToSurfacePressure(5000);
      expect(p2, lessThan(p1));
    });

    test('负海拔降级到 P0', () {
      expect(altitudeToSurfacePressure(-100), 1.01325);
    });
  });
}

// ════════════════════════════════════════════════════════════
// 验算脚本（node 跑出 V2a 所有预期值）：详见 V2_VERIFY_SCRIPT.md
// ════════════════════════════════════════════════════════════
