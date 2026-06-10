// 天气服务 - 抽象接口 + Mock 实现 + ECS 实现
//
// 当前默认走 Mock（后端 ECS 接口未上线）。后端 /api/weather/ambient 完成后，
// 把 defaultWeatherProvider 切到 EcsWeatherProvider 即可。

import 'dart:convert';
import 'dart:io';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../models/weather_info.dart';

abstract class WeatherProvider {
  /// 拉取指定经纬度的天气信息
  Future<WeatherInfo> fetch(double lat, double lon);

  /// 是否需要 GPS 权限（Mock 不需要）
  bool get needsLocation;
}

// ════════════════════════════════════════════════════════════
// Mock：硬编码数据，无需权限 / 网络
// ════════════════════════════════════════════════════════════

class MockWeatherProvider implements WeatherProvider {
  @override
  bool get needsLocation => false;

  @override
  Future<WeatherInfo> fetch(double lat, double lon) async {
    // 模拟 800ms 网络延迟
    await Future.delayed(const Duration(milliseconds: 400));
    return WeatherInfo(
      location: GeoLocation(
        lat: 22.27,
        lon: 114.16,
        city: '香港',
        country: 'HK',
      ),
      current: const WeatherCurrent(
        tempC: 26,
        humidity: 78,
        windKmh: 12,
        condition: WeatherCondition.cloudy,
        description: '多云转阴',
      ),
      air: AirQuality(
        pm25: 18,
        pm10: 35,
        aqi: 45,
        level: AirQualityLevel.fromAqi(45),
      ),
      updatedAt: DateTime.now(),
    );
  }
}

// ════════════════════════════════════════════════════════════
// ECS：调后端 /api/weather/ambient
// ════════════════════════════════════════════════════════════

class EcsWeatherProvider implements WeatherProvider {
  final String baseUrl;
  final String? authToken;

  EcsWeatherProvider({required this.baseUrl, this.authToken});

  @override
  bool get needsLocation => true;

  @override
  Future<WeatherInfo> fetch(double lat, double lon) async {
    final uri = Uri.parse('$baseUrl/api/weather/ambient')
        .replace(queryParameters: {
      'lat': lat.toStringAsFixed(4),
      'lon': lon.toStringAsFixed(4),
    });
    final res = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
        if (authToken != null) 'Authorization': 'Bearer $authToken',
      },
    ).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw HttpException('Weather API ${res.statusCode}: ${res.body}');
    }
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    if (j['ok'] == false) {
      throw HttpException('Weather API error: ${j['error']}');
    }
    return WeatherInfo.fromJson(j);
  }
}

// ════════════════════════════════════════════════════════════
// 主服务：定位 + 缓存 + 降级
// ════════════════════════════════════════════════════════════

class WeatherService {
  static WeatherProvider _provider = MockWeatherProvider();
  static WeatherInfo? _cache;
  static DateTime? _cacheAt;

  /// 缓存 TTL（避免主页每次重建都调 API）
  static const Duration cacheTtl = Duration(minutes: 10);

  /// 切换底层 provider（启动时调一次，或开发时切换）
  static void setProvider(WeatherProvider p) {
    _provider = p;
    _cache = null;
    _cacheAt = null;
  }

  static WeatherProvider get provider => _provider;

  /// 获取当前位置的天气（带缓存）
  ///
  /// 流程：
  ///   1. 缓存有效 → 直接返回
  ///   2. 需要权限 → 申请 → 失败时降级到 Mock 默认坐标
  ///   3. 调 provider.fetch
  ///   4. 缓存结果
  static Future<WeatherInfo> getCurrent({bool forceRefresh = false}) async {
    if (!forceRefresh && _cache != null && _cacheAt != null) {
      if (DateTime.now().difference(_cacheAt!) < cacheTtl) {
        return _cache!;
      }
    }

    double lat = 22.27, lon = 114.16; // 默认香港
    if (_provider.needsLocation) {
      try {
        final pos = await _getLocation();
        lat = pos.latitude;
        lon = pos.longitude;
      } catch (_) {
        // 权限被拒 / GPS 关闭 / 超时 → 用默认坐标兜底
      }
    }

    final info = await _provider.fetch(lat, lon);
    _cache = info;
    _cacheAt = DateTime.now();
    return info;
  }

  /// 拿设备 GPS 位置
  static Future<Position> _getLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceDisabledException();
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const PermissionDeniedException('Location denied');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw const PermissionDeniedException('Location permanently denied');
    }
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low, // 城市级精度足够
        timeLimit: Duration(seconds: 6),
      ),
    );
  }

  /// 同步取缓存（如果有），不触发网络
  static WeatherInfo? get cached => _cache;
}
