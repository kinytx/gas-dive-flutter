// 顶部 Hero 区 - 显示当前位置 + 天气 + 空气质量
//
// 设计参考 mixer 微信版 §7.6 / pages/mixer/mixer-ambient.ts
// 数据源：WeatherService (默认 Mock，后端 ECS 完成后切到 EcsWeatherProvider)

import 'package:flutter/material.dart';

import '../models/weather_info.dart';
import '../services/weather_service.dart';

class HeroWeather extends StatefulWidget {
  /// 拿到天气后回调（用于把温度自动填到混气计算）
  final ValueChanged<WeatherInfo>? onLoaded;

  const HeroWeather({super.key, this.onLoaded});

  @override
  State<HeroWeather> createState() => _HeroWeatherState();
}

class _HeroWeatherState extends State<HeroWeather> {
  WeatherInfo? _weather;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final info = await WeatherService.getCurrent(forceRefresh: forceRefresh);
      if (!mounted) return;
      setState(() {
        _weather = info;
        _loading = false;
      });
      widget.onLoaded?.call(info);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 大屏(pad/PC)收窄 hero，少占垂直空间
        final compact = constraints.maxWidth >= 768;
        return Container(
          height: compact ? 124 : 180,
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: _gradientFor(_weather?.current.condition),
          ),
          child: Stack(
            children: [
              _backgroundDecoration(_weather?.current.condition),
              Padding(
                padding: EdgeInsets.all(compact ? 12 : 16),
                child: _buildContent(context, compact),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
                  tooltip: '刷新',
                  onPressed: () => _load(forceRefresh: true),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, bool compact) {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(Colors.white),
          ),
        ),
      );
    }
    if (_error != null || _weather == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, color: Colors.white70, size: 32),
            const SizedBox(height: 8),
            const Text(
              '天气加载失败',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            TextButton(
              onPressed: () => _load(forceRefresh: true),
              child: const Text(
                '重试',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    final w = _weather!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // 顶行：位置 + 时间
        Row(
          children: [
            const Icon(Icons.location_on_outlined,
                color: Colors.white, size: 16),
            const SizedBox(width: 4),
            Text(
              w.location.city ?? '未知位置',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _fmtUpdated(w.updatedAt),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
              ),
            ),
          ],
        ),
        // 中间：温度 + 天气描述
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(_iconFor(w.current.condition),
                color: Colors.white, size: compact ? 36 : 48),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      w.current.tempC.toStringAsFixed(0),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 30 : 42,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        height: 1.0,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        '°C',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  w.current.description ?? w.current.condition.labelZh,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
        // 底行：AQI / PM2.5 / 湿度
        Row(
          children: [
            if (w.air != null) ...[
              _aqiChip(w.air!),
              const SizedBox(width: 8),
              _statChip(
                  'PM2.5', '${w.air!.pm25?.toStringAsFixed(0) ?? '-'} μg'),
              const SizedBox(width: 8),
            ],
            if (w.current.humidity != null)
              _statChip(
                  '湿度', '${w.current.humidity!.toStringAsFixed(0)}%'),
          ],
        ),
      ],
    );
  }

  Widget _aqiChip(AirQuality a) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Color(a.level.color).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'AQI ${a.aqi}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              a.level.labelZh,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ],
        ),
      );

  Widget _statChip(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );

  String _fmtUpdated(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return '刚刚';
    if (d.inHours < 1) return '${d.inMinutes} 分钟前';
    return '${t.hour.toString().padLeft(2, '0')}:'
        '${t.minute.toString().padLeft(2, '0')}';
  }

  IconData _iconFor(WeatherCondition c) {
    switch (c) {
      case WeatherCondition.sunny:
        return Icons.wb_sunny;
      case WeatherCondition.cloudy:
        return Icons.cloud;
      case WeatherCondition.rain:
        return Icons.umbrella;
      case WeatherCondition.storm:
        return Icons.thunderstorm;
      case WeatherCondition.fog:
        return Icons.foggy;
      case WeatherCondition.snow:
        return Icons.ac_unit;
      case WeatherCondition.wind:
        return Icons.air;
      case WeatherCondition.night:
        return Icons.nightlight_round;
    }
  }

  LinearGradient _gradientFor(WeatherCondition? c) {
    switch (c ?? WeatherCondition.cloudy) {
      case WeatherCondition.sunny:
        return const LinearGradient(
          colors: [Color(0xFF1E88E5), Color(0xFF42A5F5), Color(0xFFFFB74D)],
          stops: [0, 0.6, 1],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case WeatherCondition.cloudy:
        return const LinearGradient(
          colors: [Color(0xFF455A64), Color(0xFF607D8B), Color(0xFF90A4AE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case WeatherCondition.rain:
        return const LinearGradient(
          colors: [Color(0xFF263238), Color(0xFF37474F), Color(0xFF546E7A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case WeatherCondition.storm:
        return const LinearGradient(
          colors: [Color(0xFF1A237E), Color(0xFF311B92), Color(0xFF4527A0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case WeatherCondition.fog:
        return const LinearGradient(
          colors: [Color(0xFF78909C), Color(0xFFB0BEC5), Color(0xFFCFD8DC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case WeatherCondition.snow:
        return const LinearGradient(
          colors: [Color(0xFF455A64), Color(0xFF90A4AE), Color(0xFFECEFF1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case WeatherCondition.wind:
        return const LinearGradient(
          colors: [Color(0xFF00838F), Color(0xFF26C6DA), Color(0xFF80DEEA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case WeatherCondition.night:
        return const LinearGradient(
          colors: [Color(0xFF0D1B2A), Color(0xFF1B263B), Color(0xFF415A77)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  Widget _backgroundDecoration(WeatherCondition? c) {
    // 大尺寸半透明图标作为装饰（占满右下）
    if (c == null) return const SizedBox.shrink();
    return Positioned(
      right: -10,
      bottom: -10,
      child: Icon(
        _iconFor(c),
        size: 140,
        color: Colors.white.withValues(alpha: 0.08),
      ),
    );
  }
}
