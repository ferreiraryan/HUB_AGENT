import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../models/weather_state.dart';

typedef HttpJsonFetcher = Future<Map<String, dynamic>?> Function(Uri uri);

/// Serviço de clima em Dart puro usando a API gratuita Open-Meteo (sem API key).
///
/// Busca geocoding da cidade + clima atual + previsão de 3 dias diretamente no PC
/// e emite [WeatherState] para publicação via MQTT (`nodes/{id}/weather`).
class WeatherService {
  final Duration pollInterval;
  final HttpJsonFetcher? customFetcher;

  final _ctl = StreamController<WeatherState>.broadcast();
  WeatherState? _current;
  String _city = '';
  String _unit = 'C';
  double? _cachedLat;
  double? _cachedLon;
  String? _resolvedCityName;
  Timer? _timer;
  bool _disposed = false;

  WeatherService({
    this.pollInterval = const Duration(minutes: 15),
    this.customFetcher,
  });

  Stream<WeatherState> get updates => _ctl.stream;
  WeatherState? get current => _current;
  String get city => _city;
  String get unit => _unit;

  void start({required String city, String unit = 'C'}) {
    _city = city.trim();
    _unit = unit == 'F' ? 'F' : 'C';
    _timer?.cancel();
    if (_city.isNotEmpty) {
      unawaited(refreshNow());
    }
    _timer = Timer.periodic(pollInterval, (_) {
      if (_city.isNotEmpty) unawaited(refreshNow());
    });
  }

  Future<WeatherState?> configure({
    required String city,
    String? unit,
  }) async {
    final trimmed = city.trim();
    final nextUnit = (unit ?? _unit) == 'F' ? 'F' : 'C';
    final cityChanged = trimmed.toLowerCase() != _city.toLowerCase();
    final unitChanged = nextUnit != _unit;

    _city = trimmed;
    _unit = nextUnit;

    if (cityChanged) {
      _cachedLat = null;
      _cachedLon = null;
      _resolvedCityName = null;
    }

    if (_city.isEmpty) return null;
    if (cityChanged || unitChanged || _current == null) {
      return await refreshNow();
    }
    return _current;
  }

  Future<WeatherState?> refreshNow() async {
    if (_disposed || _city.isEmpty) return null;

    try {
      if (_cachedLat == null || _cachedLon == null) {
        final geoUri = Uri.https(
          'geocoding-api.open-meteo.com',
          '/v1/search',
          {
            'name': _city,
            'count': '1',
            'language': 'pt',
            'format': 'json',
          },
        );
        final geo = await _fetchJson(geoUri);
        final results = geo?['results'];
        if (results is! List || results.isEmpty) return null;
        final first = results.first as Map<String, dynamic>;
        _cachedLat = (first['latitude'] as num?)?.toDouble();
        _cachedLon = (first['longitude'] as num?)?.toDouble();
        final name = first['name'] as String? ?? _city;
        final admin = first['admin1'] as String?;
        _resolvedCityName =
            (admin != null && admin.isNotEmpty && admin != name)
                ? '$name, $admin'
                : name;
      }

      if (_cachedLat == null || _cachedLon == null) return null;

      final forecastUri = Uri.https(
        'api.open-meteo.com',
        '/v1/forecast',
        {
          'latitude': _cachedLat!.toStringAsFixed(4),
          'longitude': _cachedLon!.toStringAsFixed(4),
          'current':
              'temperature_2m,relative_humidity_2m,apparent_temperature,is_day,weather_code,wind_speed_10m',
          'daily': 'weather_code,temperature_2m_max,temperature_2m_min',
          'forecast_days': '4',
          'timezone': 'auto',
          if (_unit == 'F') 'temperature_unit': 'fahrenheit',
        },
      );

      final data = await _fetchJson(forecastUri);
      if (data == null) return null;

      final parsed = parseOpenMeteoResponse(
        data,
        cityName: _resolvedCityName ?? _city,
        unit: _unit,
      );
      if (parsed != null && !_disposed) {
        _current = parsed;
        if (!_ctl.isClosed) _ctl.add(parsed);
      }
      return parsed;
    } catch (e) {
      stderr.writeln('WeatherService erro ao buscar clima para "$_city": $e');
      return null;
    }
  }

  static WeatherState? parseOpenMeteoResponse(
    Map<String, dynamic> data, {
    required String cityName,
    String unit = 'C',
  }) {
    final cur = data['current'];
    if (cur is! Map) return null;
    final currentMap = cur.cast<String, dynamic>();

    final temp = (currentMap['temperature_2m'] as num?)?.toDouble();
    if (temp == null) return null;

    final feels =
        (currentMap['apparent_temperature'] as num?)?.toDouble() ?? temp;
    final humidity =
        (currentMap['relative_humidity_2m'] as num?)?.toInt() ?? 0;
    final wind = (currentMap['wind_speed_10m'] as num?)?.toDouble() ?? 0;
    final isDay = ((currentMap['is_day'] as num?)?.toInt() ?? 1) == 1;
    final code = (currentMap['weather_code'] as num?)?.toInt() ?? 0;
    final (condition, icon) = mapWmoCode(code, isDay: isDay);

    double minToday = temp;
    double maxToday = temp;
    final forecastDays = <WeatherForecastDay>[];

    final daily = data['daily'];
    if (daily is Map) {
      final times = (daily['time'] as List?) ?? const [];
      final mins = (daily['temperature_2m_min'] as List?) ?? const [];
      final maxs = (daily['temperature_2m_max'] as List?) ?? const [];
      final codes = (daily['weather_code'] as List?) ?? const [];

      if (mins.isNotEmpty && mins[0] is num) {
        minToday = (mins[0] as num).toDouble();
      }
      if (maxs.isNotEmpty && maxs[0] is num) {
        maxToday = (maxs[0] as num).toDouble();
      }

      // Próximos 3 dias (índices 1..3)
      for (var i = 1; i < times.length && i <= 3; i++) {
        final dateStr = times[i].toString();
        final dayLabel = _weekdayShortPt(dateStr);
        final dMin =
            (i < mins.length && mins[i] is num) ? (mins[i] as num).toDouble() : minToday;
        final dMax =
            (i < maxs.length && maxs[i] is num) ? (maxs[i] as num).toDouble() : maxToday;
        final dCode = (i < codes.length && codes[i] is num)
            ? (codes[i] as num).toInt()
            : 0;
        final (_, dIcon) = mapWmoCode(dCode, isDay: true);
        forecastDays.add(WeatherForecastDay(
          day: dayLabel,
          minTemp: dMin,
          maxTemp: dMax,
          icon: dIcon,
        ));
      }
    }

    return WeatherState(
      city: cityName,
      unit: unit,
      temp: temp,
      feelsLike: feels,
      minTemp: minToday,
      maxTemp: maxToday,
      humidity: humidity,
      windKmh: wind,
      condition: condition,
      icon: icon,
      isDay: isDay,
      forecast: forecastDays,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  static String _weekdayShortPt(String isoDate) {
    final dt = DateTime.tryParse(isoDate);
    if (dt == null) return isoDate;
    const names = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
    return names[(dt.weekday - 1).clamp(0, 6)];
  }

  /// Mapeia códigos meteorológicos WMO para descrição em português e ícone animado.
  static (String, String) mapWmoCode(int code, {bool isDay = true}) {
    if (code == 0) {
      return (isDay ? 'Céu limpo' : 'Noite limpa', isDay ? 'clear_day' : 'clear_night');
    }
    if (code == 1 || code == 2) {
      return ('Parcialmente nublado', isDay ? 'partly_cloudy' : 'cloudy');
    }
    if (code == 3) {
      return ('Nublado', 'cloudy');
    }
    if (code == 45 || code == 48) {
      return ('Neblina', 'fog');
    }
    if (code >= 51 && code <= 57) {
      return ('Garoa', 'drizzle');
    }
    if ((code >= 61 && code <= 67) || (code >= 80 && code <= 82)) {
      return ('Chuva', 'rain');
    }
    if ((code >= 71 && code <= 77) || code == 85 || code == 86) {
      return ('Neve', 'snow');
    }
    if (code >= 95 && code <= 99) {
      return ('Tempestade', 'storm');
    }
    return ('Variável', 'cloudy');
  }

  Future<Map<String, dynamic>?> _fetchJson(Uri uri) async {
    if (customFetcher != null) {
      return customFetcher!(uri);
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    try {
      final req = await client.getUrl(uri);
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final res = await req.close().timeout(const Duration(seconds: 8));
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final body = await utf8.decoder.bind(res).join();
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _timer?.cancel();
    await _ctl.close();
  }
}
