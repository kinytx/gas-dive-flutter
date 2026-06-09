// gas-dive-mixer Flutter App 入口
//
// 跑法：
//   cd apps/mixer
//   flutter create .        # 第一次跑：补齐 android/ ios/ 原生壳
//   flutter pub get
//   flutter run
//
// 详见 apps/mixer/README.md

import 'package:flutter/material.dart';

import 'app.dart';
import 'services/history_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HistoryService.init(); // Hive 初始化 + 打开 history box
  runApp(const MixerApp());
}
