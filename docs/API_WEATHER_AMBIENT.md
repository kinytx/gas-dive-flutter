# API: /api/weather/ambient

> 后端待实现。mixer App 首页 Hero 区调用此接口拿当前位置的天气 + 空气质量。
> Flutter 端 `services/weather_service.dart` 已经按这个 schema 写好 client (`EcsWeatherProvider`)。
> 目前 App 端默认走 `MockWeatherProvider` 占位，后端就绪后切到 ECS 即可。

---

## 路由

```
GET /api/weather/ambient?lat={lat}&lon={lon}
```

**鉴权**：建议 JWT bearer（同 mixer 微信版 ECS auth）。匿名 CDID token 也应支持（首次打开 App 时无登录账号）。

**Query 参数**：

| 名 | 类型 | 说明 |
|---|---|---|
| `lat` | float | 纬度（-90 ~ 90），4 位小数足够 |
| `lon` | float | 经度（-180 ~ 180），4 位小数足够 |
| `lang` | string optional | `zh` (默认) / `en`，影响 city / description 字段语言 |

---

## 响应 schema

成功 (HTTP 200)：

```json
{
  "ok": true,
  "data": {
    "location": {
      "lat": 22.27,
      "lon": 114.16,
      "city": "香港",
      "country": "HK"
    },
    "current": {
      "tempC": 26.3,
      "humidity": 78,
      "windKmh": 12,
      "condition": "多云转阴",
      "icon": "cloudy",
      "description": "多云转阴"
    },
    "air": {
      "pm25": 18,
      "pm10": 35,
      "aqi": 45,
      "level": "good"
    },
    "updatedAt": "2026-06-09T12:00:00Z"
  }
}
```

失败 (HTTP 200 + `ok: false` **或** HTTP 4xx/5xx)：

```json
{
  "ok": false,
  "error": "WEATHER_UPSTREAM_TIMEOUT",
  "message": "上游天气源超时"
}
```

---

## 字段说明

### `data.location`

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `lat` / `lon` | float | ✅ | 回显（可被服务器纠偏，如 IP 地理位置降级时） |
| `city` | string | 推荐 | 中文城市名（zh） / 英文（en）|
| `country` | string | 可选 | ISO 3166-1 alpha-2（如 `CN` / `HK` / `US`） |

### `data.current`

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `tempC` | float | ✅ | 当前气温 (°C)，1 位小数 |
| `humidity` | float | 可选 | 相对湿度 0-100 (%) |
| `windKmh` | float | 可选 | 风速 (km/h) |
| `condition` | string | 推荐 | 中文/英文描述（"多云转阴"）|
| `icon` | string | ✅ | 大类标签，**枚举**：见 §icon |
| `description` | string | 可选 | 同 `condition`，给端解析 |

#### icon 枚举（前端按这切背景渐变 + 图标）

| 值 | 含义 |
|---|---|
| `sunny` | 晴 / 大部晴朗 |
| `cloudy` | 多云 / 阴 |
| `rain` | 雨（各类雨：小雨/中雨/大雨/雷阵雨）|
| `storm` | 雷暴 / 暴雨 |
| `fog` | 雾 / 霾 |
| `snow` | 雪 |
| `wind` | 大风（无降水但风速 > 30 km/h）|
| `night` | 夜间（晴朗夜，仅当 `is_day=false` 且 condition=sunny 时使用）|

如果上游天气源返回的 WMO weather code 复杂细分，**后端负责映射** 到上面 8 类之一。前端不做二次映射。

### `data.air`（可选块）

如果上游不支持空气质量（部分海外地区），整个 `air` 字段可为 `null`，前端会自动隐藏空气质量 chip。

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `pm25` | float | 可选 | PM2.5 浓度 (μg/m³) |
| `pm10` | float | 可选 | PM10 浓度 (μg/m³) |
| `aqi` | int | ✅ | AQI 综合指数（中国 GB3095 或美标 EPA 都行，后端选一种即可）|
| `level` | string | 可选 | 前端会按 aqi 自动分级，这个字段是兜底回显，可缺省 |

### `data.updatedAt`

ISO 8601 字符串，UTC 时区。前端用相对时间显示（"5 分钟前"）。

---

## 实现建议

### 数据源（同时也跟 mixer 微信版策略一致）

| 部分 | 上游 |
|---|---|
| 天气 / 温度 / 湿度 / 风 | **Open-Meteo** (https://open-meteo.com/) — 免费、无 key |
| 空气质量 AQI / PM2.5 | **Open-Meteo Air Quality API** 或 **和风天气 QWeather**（国内推荐）|
| 城市名（lat/lon 反向 geocode） | **Open-Meteo geocoding** 或 **腾讯地图逆地址** |

### 缓存

- 同坐标（圆整到 0.01°，约 1km 网格）+ 同小时 → 缓存命中
- TTL 建议 10 分钟
- 实现：Redis 或 DB（`weather_cache` 表）

### 限流

- 单用户每分钟 ≤ 6 次请求（Flutter 端已有 10 分钟客户端缓存）
- 超限返回 HTTP 429

### 性能

- 命中缓存：< 50ms
- 未命中：500ms-2s（取决于上游响应）

---

## 错误码

| code | HTTP | 含义 |
|---|---|---|
| `WEATHER_UPSTREAM_TIMEOUT` | 200 (ok:false) | 上游超时 |
| `WEATHER_UPSTREAM_ERROR` | 200 (ok:false) | 上游返回非 2xx |
| `INVALID_COORDINATES` | 400 | lat/lon 越界或非数字 |
| `RATE_LIMIT_EXCEEDED` | 429 | 单用户超频 |

---

## 测试

```bash
# 香港
curl 'https://api.diveplan.cn/api/weather/ambient?lat=22.27&lon=114.16' \
  -H 'Authorization: Bearer <jwt>'

# 北京
curl 'https://api.diveplan.cn/api/weather/ambient?lat=39.90&lon=116.40'

# 缺位置（应回 400）
curl 'https://api.diveplan.cn/api/weather/ambient'

# 越界（应回 400）
curl 'https://api.diveplan.cn/api/weather/ambient?lat=200&lon=0'
```

---

## 前端切换 Mock → 真实

后端上线后，Flutter 端在 `main.dart` 加：

```dart
import 'package:mixer/services/weather_service.dart';

void main() async {
  ...
  WeatherService.setProvider(EcsWeatherProvider(
    baseUrl: 'https://api.diveplan.cn',
    authToken: '<JWT>',  // 后期账号系统接入后从 auth.dart 拿
  ));
  ...
}
```

一行切换。Mock 数据继续作为开发期 fallback 使用（无网络时）。
