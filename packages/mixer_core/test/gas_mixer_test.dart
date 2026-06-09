// mixer_core 单元测试
//
// 所有预期值用 node 跑算法公式得出（不再心算）—— 验算脚本附在文件末尾。
// 跑：cd packages/mixer_core && dart test

import 'package:mixer_core/mixer_core.dart';
import 'package:test/test.dart';

const _eps = 0.01; // 1 cbar 容差

void main() {
  final mixer = GasMixer();

  group('成功路径（fill ≥ 0）', () {
    test('空瓶 → Nitrox 32 @ 200 bar', () {
      final r = mixer.calculate(const CalculateMixParams(
        currentO2: 21, currentHe: 0, currentPressure: 0,
        targetO2: 32, targetHe: 0, targetPressure: 200,
      ));
      expect(r.success, isTrue);
      expect(r.error, isNull);
      expect(r.heliumToFill, closeTo(0, _eps));
      expect(r.oxygenToFill, closeTo(27.8481, _eps));
      expect(r.airToFill, closeTo(172.1519, _eps));
      expect(r.fillSequence.length, 3);
    });

    test('空瓶 → Trimix 18/45 @ 200 bar', () {
      final r = mixer.calculate(const CalculateMixParams(
        currentO2: 21, currentHe: 0, currentPressure: 0,
        targetO2: 18, targetHe: 45, targetPressure: 200,
      ));
      expect(r.success, isTrue);
      expect(r.heliumToFill, closeTo(90.0, _eps));
      expect(r.oxygenToFill, closeTo(16.3291, _eps));
      expect(r.airToFill, closeTo(93.6709, _eps));
    });

    test('Nitrox 32 残 50 bar → Nitrox 32 满 200 bar', () {
      final r = mixer.calculate(const CalculateMixParams(
        currentO2: 32, currentHe: 0, currentPressure: 50,
        targetO2: 32, targetHe: 0, targetPressure: 200,
      ));
      expect(r.success, isTrue);
      expect(r.heliumToFill, closeTo(0, _eps));
      expect(r.oxygenToFill, closeTo(20.8861, _eps));
      expect(r.airToFill, closeTo(129.1139, _eps));
    });

    test('Air 残 50 bar → Air 满 200 bar（纯气补纯气，O₂/He 全 0）', () {
      final r = mixer.calculate(const CalculateMixParams(
        currentO2: 21, currentHe: 0, currentPressure: 50,
        targetO2: 21, targetHe: 0, targetPressure: 200,
      ));
      expect(r.success, isTrue);
      expect(r.heliumToFill, closeTo(0, _eps));
      expect(r.oxygenToFill, closeTo(0, _eps));
      expect(r.airToFill, closeTo(150, _eps));
    });

    test('空瓶 → Heliox 10/90 @ 200 bar', () {
      final r = mixer.calculate(const CalculateMixParams(
        currentO2: 21, currentHe: 0, currentPressure: 0,
        targetO2: 10, targetHe: 90, targetPressure: 200,
      ));
      expect(r.success, isTrue);
      expect(r.heliumToFill, closeTo(180, _eps));
      expect(r.oxygenToFill, closeTo(20, _eps));
      expect(r.airToFill, closeTo(0, _eps));
    });

    test('fill 三步压力总和 = targetPressure - currentPressure', () {
      final r = mixer.calculate(const CalculateMixParams(
        currentO2: 21, currentHe: 0, currentPressure: 30,
        targetO2: 21, targetHe: 35, targetPressure: 220,
      ));
      expect(r.success, isTrue);
      expect(
        r.heliumToFill + r.oxygenToFill + r.airToFill,
        closeTo(220 - 30, _eps),
      );
    });
  });

  group('fillSequence（按 fillOrder 排序）', () {
    test('he-first: He → O₂ → Air', () {
      final r = mixer.calculate(const CalculateMixParams(
        currentO2: 21, currentHe: 0, currentPressure: 0,
        targetO2: 18, targetHe: 45, targetPressure: 200,
        fillOrder: FillOrder.heFirst,
      ));
      expect(r.fillSequence.map((s) => s.gas).toList(),
          [FillGas.he, FillGas.o2, FillGas.air]);
      // 累计压力递增到 targetPressure
      expect(r.fillSequence.first.pressureBar, closeTo(90, _eps));
      expect(r.fillSequence[1].pressureBar, closeTo(90 + 16.3291, _eps));
      expect(r.fillSequence.last.pressureBar, closeTo(200, _eps));
    });

    test('o2-first: O₂ → Air → He', () {
      final r = mixer.calculate(const CalculateMixParams(
        currentO2: 21, currentHe: 0, currentPressure: 0,
        targetO2: 18, targetHe: 45, targetPressure: 200,
        fillOrder: FillOrder.o2First,
      ));
      expect(r.fillSequence.map((s) => s.gas).toList(),
          [FillGas.o2, FillGas.air, FillGas.he]);
      expect(r.fillSequence.first.pressureBar, closeTo(16.3291, _eps));
      expect(r.fillSequence[1].pressureBar, closeTo(16.3291 + 93.6709, _eps));
      expect(r.fillSequence.last.pressureBar, closeTo(200, _eps));
    });

    test('两种顺序 fill 总量完全相等（数学交换律）', () {
      final he1 = mixer.calculate(const CalculateMixParams(
        currentO2: 30, currentHe: 0, currentPressure: 20,
        targetO2: 25, targetHe: 25, targetPressure: 210,
        fillOrder: FillOrder.heFirst,
      ));
      final o2 = mixer.calculate(const CalculateMixParams(
        currentO2: 30, currentHe: 0, currentPressure: 20,
        targetO2: 25, targetHe: 25, targetPressure: 210,
        fillOrder: FillOrder.o2First,
      ));
      expect(he1.oxygenToFill, closeTo(o2.oxygenToFill, _eps));
      expect(he1.heliumToFill, closeTo(o2.heliumToFill, _eps));
      expect(he1.airToFill, closeTo(o2.airToFill, _eps));
    });
  });

  group('错误路径', () {
    test('O₂ 越界 → invalidInput', () {
      final r = mixer.calculate(const CalculateMixParams(
        currentO2: 200, currentHe: 0, currentPressure: 0,
        targetO2: 32, targetHe: 0, targetPressure: 200,
      ));
      expect(r.success, isFalse);
      expect(r.error, MixErrorCode.invalidInput);
    });

    test('O₂ + He > 100 → invalidTargetGas', () {
      final r = mixer.calculate(const CalculateMixParams(
        currentO2: 21, currentHe: 0, currentPressure: 0,
        targetO2: 60, targetHe: 60, targetPressure: 200,
      ));
      expect(r.success, isFalse);
      expect(r.error, MixErrorCode.invalidTargetGas);
    });

    test('currentPressure ≥ targetPressure → targetPressureTooLow', () {
      final r = mixer.calculate(const CalculateMixParams(
        currentO2: 32, currentHe: 0, currentPressure: 200,
        targetO2: 32, targetHe: 0, targetPressure: 150,
      ));
      expect(r.success, isFalse);
      expect(r.error, MixErrorCode.targetPressureTooLow);
    });

    test('当前 He 比目标多 → needDrain', () {
      final r = mixer.calculate(const CalculateMixParams(
        currentO2: 18, currentHe: 50, currentPressure: 100,
        targetO2: 21, targetHe: 0, targetPressure: 200,
      ));
      expect(r.success, isFalse);
      expect(r.error, MixErrorCode.needDrain);
      expect(r.needToDrain, isTrue);
    });
  });

  group('警告路径', () {
    test('残压 < 10 bar → lowResidualPressure 警告', () {
      final r = mixer.calculate(const CalculateMixParams(
        currentO2: 21, currentHe: 0, currentPressure: 5,
        targetO2: 32, targetHe: 0, targetPressure: 200,
      ));
      expect(r.success, isTrue);
      expect(r.warnings, contains(MixWarning.lowResidualPressure));
    });

    test('残压 0（空瓶）不触发低残压警告', () {
      final r = mixer.calculate(const CalculateMixParams(
        currentO2: 21, currentHe: 0, currentPressure: 0,
        targetO2: 32, targetHe: 0, targetPressure: 200,
      ));
      expect(r.success, isTrue);
      expect(r.warnings, isEmpty);
    });

    test('残压 ≥ 10 bar 不触发警告', () {
      final r = mixer.calculate(const CalculateMixParams(
        currentO2: 21, currentHe: 0, currentPressure: 30,
        targetO2: 32, targetHe: 0, targetPressure: 200,
      ));
      expect(r.success, isTrue);
      expect(r.warnings, isEmpty);
    });
  });

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
}

// ════════════════════════════════════════════════════════════
// 验算脚本（node 端跑出预期值）：
//
// function calc(co2, che, cp, to2, the, tp) {
//   const fO2c = co2/100, fHec = che/100, fN2c = 1 - fO2c - fHec;
//   const fO2t = to2/100, fHet = the/100, fN2t = 1 - fO2t - fHet;
//   const pO2d = fO2t*tp - fO2c*cp;
//   const pHed = fHet*tp - fHec*cp;
//   const pN2d = fN2t*tp - fN2c*cp;
//   const fillHe = pHed;
//   const fillAir = pN2d / 0.79;
//   const fillO2 = pO2d - fillAir * 0.21;
//   return { fillHe, fillO2, fillAir };
// }
//
// 用例 → 预期：
//   calc(21,0,0,32,0,200)    = {fillHe:0,      fillO2:27.8481, fillAir:172.1519}
//   calc(21,0,0,18,45,200)   = {fillHe:90,     fillO2:16.3291, fillAir:93.6709}
//   calc(32,0,50,32,0,200)   = {fillHe:0,      fillO2:20.8861, fillAir:129.1139}
//   calc(21,0,50,21,0,200)   = {fillHe:0,      fillO2:0,       fillAir:150}
//   calc(21,0,0,10,90,200)   = {fillHe:180,    fillO2:20,      fillAir:0}
// ════════════════════════════════════════════════════════════
