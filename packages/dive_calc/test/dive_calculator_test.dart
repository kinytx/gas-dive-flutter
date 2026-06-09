// dive_calc 单元测试
//
// 验证：
// 1. 算法值跟 mixer/shared/utils/dive-calc.ts 行为一致
// 2. 类风格 (DiveCalculator) 与函数风格 (calcMOD 等) 完全等价
// 3. 边界 + 单调性
//
// 怎么跑：cd packages/dive_calc && dart test

import 'package:dive_calc/dive_calc.dart';
import 'package:test/test.dart';

void main() {
  group('MOD（最大操作深度）', () {
    final calc = DiveCalculator();

    test('Nitrox 32 @ PO₂ 1.4 ≈ 33m', () {
      // (1.4 / 0.32 - 1.013) * 10 = 33.62 → floor = 33
      expect(calc.mod(MODInput(po2: 1.4, o2Pct: 32)), 33);
    });

    test('Air (21) @ PO₂ 1.4 ≈ 56m', () {
      // (1.4 / 0.21 - 1.013) * 10 = 56.54 → floor = 56
      expect(calc.mod(MODInput(po2: 1.4, o2Pct: 21)), 56);
    });

    test('Air (21) @ PO₂ 1.6 ≈ 66m', () {
      // (1.6 / 0.21 - 1.013) * 10 = 66.06 → floor = 66
      expect(calc.mod(MODInput(po2: 1.6, o2Pct: 21)), 66);
    });

    test('纯 O₂ (100) @ PO₂ 1.4 ≈ 3m', () {
      // (1.4 / 1.0 - 1.013) * 10 = 3.87 → floor = 3
      expect(calc.mod(MODInput(po2: 1.4, o2Pct: 100)), 3);
    });

    test('Nitrox 50 @ PO₂ 1.6 ≈ 21m', () {
      // (1.6 / 0.5 - 1.013) * 10 = (3.2 - 1.013) * 10 = 21.87 → floor = 21
      expect(calc.mod(MODInput(po2: 1.6, o2Pct: 50)), 21);
    });

    test('O₂% = 0 时返回 0（保护性边界）', () {
      expect(calc.mod(MODInput(po2: 1.4, o2Pct: 0)), 0);
    });

    test('高海拔降低 MOD（pSurf=0.7 模拟 ~3000m）', () {
      // (1.4 / 0.32 - 0.7) * 10 = 36.75 → floor = 36
      expect(
        calc.mod(MODInput(po2: 1.4, o2Pct: 32, surfacePressure: 0.7)),
        36,
      );
    });
  });

  group('END（等效麻醉深度）', () {
    final calc = DiveCalculator();

    test('Air (21/0) @ 30m END ≈ 30m（air 自己的体系下 END = 深度）', () {
      // narcosis=0 时 O₂ 不算麻醉，但用 air 配比的 fN2 比例算下来 END 应非常接近 30
      final endVal = calc.end(ENDInput(
        gas: const GasMix(o2Pct: 21, hePct: 0),
        depth: 30,
      ));
      expect(endVal, inInclusiveRange(28, 30));
    });

    test('Trimix 18/45 @ 50m END ≈ 18m', () {
      // fN2=0.37, gasNarc=0.37*6.013=2.2248, endBar=2.8163, end=(2.8163-1.013)*10=18.03
      final endVal = calc.end(ENDInput(
        gas: const GasMix(o2Pct: 18, hePct: 45),
        depth: 50,
      ));
      expect(endVal, 18);
    });

    test('Heliox (10/90) @ 60m END ≈ 0m（几乎无 N₂，无麻醉风险）', () {
      final endVal = calc.end(ENDInput(
        gas: const GasMix(o2Pct: 10, hePct: 90),
        depth: 60,
      ));
      expect(endVal, lessThanOrEqualTo(2));
    });

    test('O₂ 麻醉系数 narcosis=1（O₂ 视为与 N₂ 同等麻醉）→ Air END = 深度', () {
      // narcosis=1 时，gasNarc = (fN2 + fO2) * pAmb = 1.0 * pAmb，airNarc=1.0
      final endVal = calc.end(ENDInput(
        gas: const GasMix(o2Pct: 21, hePct: 0),
        depth: 30,
        narcosis: 1,
      ));
      expect(endVal, 30);
    });
  });

  group('EADD（等效空气密度深度）', () {
    final calc = DiveCalculator();

    test('Air (21/0) @ 30m EADD = 30m（air 在自己体系下 EADD = 深度）', () {
      final eadd = calc.eadd(EADDInput(
        gas: const GasMix(o2Pct: 21, hePct: 0),
        depth: 30,
      ));
      expect(eadd, 30);
    });

    test('Trimix 18/45 @ 50m EADD ≈ 27m（He 显著降低呼吸密度）', () {
      final eadd = calc.eadd(EADDInput(
        gas: const GasMix(o2Pct: 18, hePct: 45),
        depth: 50,
      ));
      expect(eadd, 27);
    });

    test('Heliox 10/90 @ 60m EADD 很低（密度极轻）', () {
      final eadd = calc.eadd(EADDInput(
        gas: const GasMix(o2Pct: 10, hePct: 90),
        depth: 60,
      ));
      expect(eadd, lessThan(20));
    });
  });

  group('NDL（免减压极限）', () {
    final calc = DiveCalculator();

    test('深度 = 0 时返回 unlimitedNDL (999)', () {
      final ndl = calc.ndl(NDLInput(
        o2Pct: 21,
        depthM: 0,
        saltWater: true,
        tempC: 24,
      ));
      expect(ndl, 999);
    });

    test('Air @ 18m 海水 24°C → 应 > 30 min', () {
      final ndl = calc.ndl(NDLInput(
        o2Pct: 21,
        depthM: 18,
        saltWater: true,
        tempC: 24,
      ));
      expect(ndl, greaterThan(30));
    });

    test('Air @ 30m 海水 24°C → 通常 15-25 min', () {
      final ndl = calc.ndl(NDLInput(
        o2Pct: 21,
        depthM: 30,
        saltWater: true,
        tempC: 24,
      ));
      expect(ndl, inInclusiveRange(10, 30));
    });

    test('Nitrox 32 @ 30m NDL > Air @ 30m NDL（高 O₂ 延长免减压）', () {
      final ndlAir = calc.ndl(NDLInput(
        o2Pct: 21,
        depthM: 30,
        saltWater: true,
        tempC: 24,
      ));
      final ndlNx32 = calc.ndl(NDLInput(
        o2Pct: 32,
        depthM: 30,
        saltWater: true,
        tempC: 24,
      ));
      expect(ndlNx32, greaterThan(ndlAir));
    });

    test('深度单调性：30m NDL < 18m NDL', () {
      final ndl18 = calc.ndl(NDLInput(
        o2Pct: 21,
        depthM: 18,
        saltWater: true,
        tempC: 24,
      ));
      final ndl30 = calc.ndl(NDLInput(
        o2Pct: 21,
        depthM: 30,
        saltWater: true,
        tempC: 24,
      ));
      expect(ndl30, lessThan(ndl18));
    });

    test('海水比淡水 NDL 短（梯度更大）', () {
      final ndlSalt = calc.ndl(NDLInput(
        o2Pct: 21,
        depthM: 30,
        saltWater: true,
        tempC: 24,
      ));
      final ndlFresh = calc.ndl(NDLInput(
        o2Pct: 21,
        depthM: 30,
        saltWater: false,
        tempC: 24,
      ));
      expect(ndlSalt, lessThanOrEqualTo(ndlFresh));
    });

    test('低温缩短 NDL（5°C vs 25°C）', () {
      final ndlCold = calc.ndl(NDLInput(
        o2Pct: 21,
        depthM: 30,
        saltWater: true,
        tempC: 5,
      ));
      final ndlWarm = calc.ndl(NDLInput(
        o2Pct: 21,
        depthM: 30,
        saltWater: true,
        tempC: 25,
      ));
      expect(ndlCold, lessThan(ndlWarm));
    });

    test('低温修正不低于 minFactor (0.75)', () {
      final ndlExtreme = calc.ndl(NDLInput(
        o2Pct: 21,
        depthM: 30,
        saltWater: true,
        tempC: -50, // 超冷，触发 minFactor 下限
      ));
      final ndlWarm = calc.ndl(NDLInput(
        o2Pct: 21,
        depthM: 30,
        saltWater: true,
        tempC: 25,
      ));
      // minFactor=0.75，但最终结果经过 floor 取整：
      //   ndlWarm    = floor(raw × 1.0)
      //   ndlExtreme = floor(raw × 0.75)
      // floor 最坏可多吃 1，所以小 NDL 比值会偏离 0.75（约 0.65-0.75）。
      // 这里只验证 minFactor 起作用，比值大致接近 0.75，不严格到 0.74。
      expect(ndlExtreme / ndlWarm, greaterThanOrEqualTo(0.65));
      expect(ndlExtreme / ndlWarm, lessThanOrEqualTo(0.80));
    });
  });

  group('类风格 vs 函数风格 一致性', () {
    test('calcMOD == DiveCalculator().mod(...)', () {
      expect(
        calcMOD(1.4, 32),
        DiveCalculator().mod(MODInput(po2: 1.4, o2Pct: 32)),
      );
    });

    test('calcEND == DiveCalculator().end(...)', () {
      expect(
        calcEND(18, 45, 50),
        DiveCalculator().end(ENDInput(
          gas: const GasMix(o2Pct: 18, hePct: 45),
          depth: 50,
        )),
      );
    });

    test('calcEADD == DiveCalculator().eadd(...)', () {
      expect(
        calcEADD(18, 45, 50),
        DiveCalculator().eadd(EADDInput(
          gas: const GasMix(o2Pct: 18, hePct: 45),
          depth: 50,
        )),
      );
    });

    test('calcNDL == DiveCalculator().ndl(...)', () {
      expect(
        calcNDL(21, 30, true, 24),
        DiveCalculator().ndl(NDLInput(
          o2Pct: 21,
          depthM: 30,
          saltWater: true,
          tempC: 24,
        )),
      );
    });
  });

  group('Config 可定制', () {
    test('替换 surfacePressure 高海拔场景', () {
      final highAltCfg = defaultDiveCalcConfig.copyWith(surfacePressure: 0.7);
      final calc = DiveCalculator(highAltCfg);
      // (1.4 / 0.32 - 0.7) * 10 = 36.75 → floor 36
      expect(calc.mod(MODInput(po2: 1.4, o2Pct: 32)), 36);
    });

    test('替换 defaultNarcosis 影响 END 计算', () {
      final narcCfg = defaultDiveCalcConfig.copyWith(defaultNarcosis: 1.0);
      final calc = DiveCalculator(narcCfg);
      // Air 在 narcosis=1 下 END = 深度
      expect(
        calc.end(ENDInput(
          gas: const GasMix(o2Pct: 21, hePct: 0),
          depth: 30,
        )),
        30,
      );
    });
  });

  group('数据类 equality / hashCode', () {
    test('GasMix 相等', () {
      expect(
        const GasMix(o2Pct: 21, hePct: 0),
        const GasMix(o2Pct: 21, hePct: 0),
      );
    });

    test('GasMix 不同值不等', () {
      expect(
        const GasMix(o2Pct: 21, hePct: 0) ==
            const GasMix(o2Pct: 32, hePct: 0),
        isFalse,
      );
    });

    test('GasMix toString', () {
      expect(
        const GasMix(o2Pct: 21, hePct: 0).toString(),
        contains('O₂=21.0%'),
      );
    });
  });
}
