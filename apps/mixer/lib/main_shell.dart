// 自适应导航外壳 —— 对齐小程序的同时按平台/屏宽切换导航位置：
//   手机 (<768)      → 底部 NavigationBar（像小程序 custom-tab-bar）
//   pad  (768–1200)  → 左侧 NavigationRail
//   PC/宽屏 (≥1200)  → 左侧 NavigationRail 展开版
//
// 断点复用 theme/breakpoints.dart。各页自带 Scaffold/AppBar，本壳只管导航容器。

import 'package:flutter/material.dart';

import 'pages/account_page.dart';
import 'pages/history_page.dart';
import 'pages/mix_calc_page.dart';
import 'package:dive_ui/dive_ui.dart';

class MainShell extends StatefulWidget {
  final MixerThemeMode currentTheme;
  final ValueChanged<MixerThemeMode> onThemeChanged;

  const MainShell({
    super.key,
    required this.currentTheme,
    required this.onThemeChanged,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const List<({IconData icon, IconData selected, String label})> _tabs = [
    (icon: Icons.gas_meter_outlined, selected: Icons.gas_meter, label: '混气'),
    (icon: Icons.history_outlined, selected: Icons.history, label: '历史'),
    (icon: Icons.build_outlined, selected: Icons.build, label: '工具'),
    (icon: Icons.person_outline, selected: Icons.person, label: '我的'),
  ];

  // 每次 build 重建以拿到最新主题；IndexedStack 复用 Element 保留各页状态。
  List<Widget> _pages() => [
        MixCalcPage(
          currentTheme: widget.currentTheme,
          onThemeChanged: widget.onThemeChanged,
        ),
        const HistoryPage(),
        const _ToolsPlaceholder(),
        const AccountPage(),
      ];

  void _select(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        if (w < Breakpoints.pad) return _bottomLayout(context);
        return _railLayout(context, extended: w >= 1200);
      },
    );
  }

  Widget _bottomLayout(BuildContext context) {
    final c = context.mixerColors;
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages()),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: c.bgCard,
          indicatorColor: c.tintCyan,
          labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: s.contains(WidgetState.selected)
                    ? c.accentCyan
                    : c.textMuted,
              )),
          iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
                size: 24,
                color: s.contains(WidgetState.selected)
                    ? c.accentCyan
                    : c.textMuted,
              )),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _select,
          height: 64,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            for (final t in _tabs)
              NavigationDestination(
                icon: Icon(t.icon),
                selectedIcon: Icon(t.selected),
                label: t.label,
              ),
          ],
        ),
      ),
    );
  }

  Widget _railLayout(BuildContext context, {required bool extended}) {
    final c = context.mixerColors;
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: extended,
            backgroundColor: c.bgCard,
            selectedIndex: _index,
            onDestinationSelected: _select,
            indicatorColor: c.tintCyan,
            minWidth: 72,
            minExtendedWidth: 180,
            labelType: extended
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.all,
            selectedIconTheme: IconThemeData(color: c.accentCyan),
            unselectedIconTheme: IconThemeData(color: c.textMuted),
            selectedLabelTextStyle:
                TextStyle(color: c.accentCyan, fontWeight: FontWeight.w600),
            unselectedLabelTextStyle: TextStyle(color: c.textMuted),
            leading: const SizedBox(height: 8),
            destinations: [
              for (final t in _tabs)
                NavigationRailDestination(
                  icon: Icon(t.icon),
                  selectedIcon: Icon(t.selected),
                  label: Text(t.label),
                ),
            ],
          ),
          VerticalDivider(width: 1, thickness: 1, color: c.border),
          Expanded(child: IndexedStack(index: _index, children: _pages())),
        ],
      ),
    );
  }
}

class _ToolsPlaceholder extends StatelessWidget {
  const _ToolsPlaceholder();

  @override
  Widget build(BuildContext context) {
    final c = context.mixerColors;
    return Scaffold(
      appBar: AppBar(title: const Text('工具')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.construction_outlined, size: 48, color: c.textMuted),
            const SizedBox(height: 12),
            Text(
              'Topoff · 配平 · 最佳混合气\n移植中，敬请期待',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textMuted, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
