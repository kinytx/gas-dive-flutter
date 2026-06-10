// 天气 + 空气质量数据模型 - 对应 ECS API /api/weather/ambient 响应。
//
// schema 设计见 docs/API_WEATHER_AMBIENT.md。

import 'package:meta/meta.dart';

/// 天气状况大类（对应背景图选择）
enum WeatherCondition {
  sunny('晴', 'sun'),
  cloudy('多云', 'cloud'),
  rain('雨', 'rain'),
  storm('雷暴', 'storm'),
  fog('雾', 'fog'),
  snow('雪', 'snow'),
  wind('大风', 'wind'),
  night('夜晚', 'night');

  final String labelZh;
  final String iconKey;
  const WeatherCondition(this.labelZh, this.iconKey);

  static WeatherCondition parse(String? key) {
    if (key == null) return cloudy;
    for (final c in WeatherCondition.values) {
      if (c.iconKey == key.toLowerCase()) return c;
    }
    return cloudy;
  }
}

/// AQI 等级 → 颜色档（对齐 mixer 微信版 ambient 三色变色）
enum AirQualityLevel {
  good('优', 0xFF4CAF50),
  moderate('良', 0xFFCDDC39),
  lightlyUnhealthy('轻度', 0xFFFFC107),
  unhealthy('中度', 0xFFFF9800),
  veryUnhealthy('重度', 0xFFE91E63),
  hazardous('严重', 0xFF9C27B0);

  final String labelZh;
  final int color;
  const AirQualityLevel(this.labelZh, this.color);

  static AirQualityLevel fromAqi(int aqi) {
    if (aqi <= 50) return good;
    if (aqi <= 100) return moderate;
    if (aqi <= 150) return lightlyUnhealthy;
    if (aqi <= 200) return unhealthy;
    if (aqi <= 300) return veryUnhealthy;
    return hazardous;
  }
}

@immutable
class GeoLocation {
  final double lat;
  final double lon;
  final String? city;
  final String? country;

  const GeoLocation({
    required this.lat,
    required this.lon,
    this.city,
    this.country,
  });

  factory GeoLocation.fromJson(Map<String, dynamic> j) => GeoLocation(
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
        city: j['city'] as String?,
        country: j['country'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lon': lon,
        if (city != null) 'city': city,
        if (country != null) 'country': country,
      };
}

@immutable
class WeatherCurrent {
  final double tempC;
  final double? humidity; // 0-100 %
  final double? windKmh;
  final WeatherCondition condition;
  final String? description; // 详细文本（"小雨转晴" 等）

  const WeatherCurrent({
    required this.tempC,
    this.humidity,
    this.windKmh,
    required this.condition,
    this.description,
  });

  factory WeatherCurrent.fromJson(Map<String, dynamic> j) => WeatherCurrent(
        tempC: (j['tempC'] as num).toDouble(),
        humidity: (j['humidity'] as num?)?.toDouble(),
        windKmh: (j['windKmh'] as num?)?.toDouble(),
        condition: WeatherCondition.parse(j['icon'] as String?),
        description: j['condition'] as String? ?? j['description'] as String?,
      );
}

@immutable
class AirQuality {
  /// PM2.5 (μg/m³)
  final double? pm25;

  /// PM10 (μg/m³)
  final double? pm10;

  /// AQI 综合指数
  final int aqi;

  final AirQualityLevel level;

  const AirQuality({
    this.pm25,
    this.pm10,
    required this.aqi,
    required this.level,
  });

  factory AirQuality.fromJson(Map<String, dynamic> j) {
    final aqi = (j['aqi'] as num).toInt();
    return AirQuality(
      pm25: (j['pm25'] as num?)?.toDouble(),
      pm10: (j['pm10'] as num?)?.toDouble(),
      aqi: aqi,
      level: AirQualityLevel.fromAqi(aqi),
    );
  }
}

@immutable
class WeatherInfo {
  final GeoLocation location;
  final WeatherCurrent current;
  final AirQuality? air;
  final DateTime updatedAt;

  const WeatherInfo({
    required this.location,
    required this.current,
    this.air,
    required this.updatedAt,
  });

  factory WeatherInfo.fromJson(Map<String, dynamic> j) {
    final data = j['data'] as Map<String, dynamic>? ?? j;
    return WeatherInfo(
      location: GeoLocation.fromJson(data['location'] as Map<String, dynamic>),
      current: WeatherCurrent.fromJson(data['current'] as Map<String, dynamic>),
      air: data['air'] != null
          ? AirQuality.fromJson(data['air'] as Map<String, dynamic>)
          : null,
      updatedAt: DateTime.tryParse(data['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
