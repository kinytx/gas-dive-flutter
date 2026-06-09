# mixer_core

气体混合核心算法（理想气体 MVP），翻译自 [`gas-dive-mixer/shared/utils/mixer.ts`](../../../gas-dive-mixer/shared/utils/mixer.ts) 的简化子集。

## 范围

**MVP 纳入**：

- 当前气体（O₂/He/压力）→ 目标气体（O₂/He/压力）的 fillHe / fillO₂ / fillAir 计算
- 填充顺序：he-first（业内通用）/ o2-first（金侠表风格）
- 错误码：invalidInput / invalidTargetGas / invalidCurrentGas / targetPressureTooLow / needDrain
- 警告：lowResidualPressure

**MVP 不纳入**（V2+ 加）：

- Z 因子真实气体修正（useRealGases / per-step Z）
- 海拔修正（altitudeCorrection A/B/C/D）
- 温度 std 折算（pressureRef='std' + tempC）
- Drain 自动求解（V2 实现 drainToPressure 反解）

## 用法

```dart
import 'package:mixer_core/mixer_core.dart';

void main() {
  final mixer = GasMixer();
  final result = mixer.calculate(const CalculateMixParams(
    currentO2: 21, currentHe: 0, currentPressure: 50,
    targetO2: 32, targetHe: 0, targetPressure: 200,
  ));

  if (!result.success) {
    print('错误：${result.error}');
    return;
  }

  print('需要补：');
  print('  O₂  ${result.oxygenToFill.toStringAsFixed(1)} bar');
  print('  He  ${result.heliumToFill.toStringAsFixed(1)} bar');
  print('  Air ${result.airToFill.toStringAsFixed(1)} bar');

  print('填充顺序（${result.fillOrder.wire}）：');
  for (final step in result.fillSequence) {
    print('  ${step.step}. 充 ${step.gas.label} '
        '${step.fillBar.toStringAsFixed(1)} bar '
        '→ 表压 ${step.pressureBar.toStringAsFixed(1)} bar');
  }
}
```

## 跑测试

```bash
cd packages/mixer_core
dart pub get
dart test
```

测试预期值全部用 node 跑算法公式得出（不依赖心算），用例 17 个：成功 6 + 顺序 3 + 错误 4 + 警告 3 + 兼容性 1。

## V2 路线图

| 项 | 复杂度 | 优先级 |
|---|---|---|
| Drain 自动求解 | 中 | P0 |
| Z 因子真实气体（useRealGases）| 高 | P1 |
| 海拔修正（A/B/C/D 四档） | 高 | P1 |
| 温度 std 折算 | 低 | P2 |
| per-step Z（o2-first 场景）| 中 | P2 |
| O₂ 高残压警告 | 低 | P2 |
