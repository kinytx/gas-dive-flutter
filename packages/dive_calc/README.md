# dive_calc

潜水通用计算（MOD / END / EADD / NDL），翻译自 [`gas-dive-mixer/shared/utils/dive-calc.ts`](../../../gas-dive-mixer/shared/utils/dive-calc.ts)。

## 安装

monorepo 内部直接用 path 引用，无需发布到 pub.dev：

```yaml
# apps/mixer/pubspec.yaml
dependencies:
  dive_calc:
    path: ../../packages/dive_calc
```

## 用法

```dart
import 'package:dive_calc/dive_calc.dart';

void main() {
  // 类风格（推荐）
  final calc = DiveCalculator();
  print(calc.mod(MODInput(po2: 1.4, o2Pct: 32)));            // 32% Nitrox @ PO₂ 1.4
  print(calc.ndl(NDLInput(o2Pct: 21, depthM: 30, saltWater: true, tempC: 24)));

  // 向后兼容的纯函数（与 TS 源一致）
  print(calcMOD(1.4, 32));
  print(calcEND(18, 45, 50));        // Trimix 18/45 在 50m 的 END
  print(calcEADD(18, 45, 50));       // Trimix 18/45 在 50m 的 EADD
  print(calcNDL(21, 30, true, 24));  // Air 在 30m 海水 24°C 的 NDL
}
```

## 跑测试

```bash
cd packages/dive_calc
dart test
```

## 跟 TS 源的对照

| TS（mixer） | Dart（这里） |
|---|---|
| `class DiveCalculator` | `class DiveCalculator` |
| `DEFAULT_DIVE_CALC_CONFIG` | `defaultDiveCalcConfig` |
| `P_SURFACE` (constants.ts) | `pSurface` (constants.dart) |
| `Math.LN2 / Math.log` | `dart:math` `ln2 / log` |
| `Math.floor` | `.floor()` 方法 |
| `??` | `??`（一致） |
| `interface GasMix { o2Pct, hePct }` | `class GasMix` (@immutable) |
| `readonly` interface | `final` 字段 + `@immutable` |

行为差异：**零**。通过 `test/dive_calculator_test.dart` 全套用例对比 TS 预期值。

## 后续

- [ ] 翻译 `deco.ts`（ZHL-16C + GF 减压）→ `packages/deco/`
- [ ] 翻译 `ccr.ts`（CCR 减压）→ `packages/ccr/`
- [ ] 翻译 `best-mix.ts`（最佳混合气推荐）→ `packages/best_mix/`
