// 应用根 widget。负责主题、路由、全局状态注入（未来加）。

import 'package:flutter/material.dart';

import 'pages/home_page.dart';
import 'theme/mixer_theme.dart';

class MixerApp extends StatefulWidget {
  const MixerApp({super.key});

  @override
  State<MixerApp> createState() => _MixerAppState();
}

class _MixerAppState extends State<MixerApp> {
  // 当前主题。未来接入持久化（shared_preferences）+ settings 页切换。
  MixerThemeMode _themeMode = MixerThemeMode.dark;

  void _setTheme(MixerThemeMode mode) {
    setState(() => _themeMode = mode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dive Gas Mixer',
      debugShowCheckedModeBanner: false,
      theme: MixerTheme.themeFor(_themeMode),
      home: HomePage(
        currentTheme: _themeMode,
        onThemeChanged: _setTheme,
      ),
    );
  }
}
