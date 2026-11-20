/// Estado de clima/temperatura coletado no PC e publicado via MQTT (`nodes/{id}/weather`).
class WeatherForecastDay {
  final String day; // ex: "Qui", "Sex", "Sáb"
  final double minTemp;
  final double maxTemp;
  final String icon;

  const WeatherForecastDay({
    required this.day,
    required this.minTemp,
    required this.maxTemp,
    required this.icon,
  });

  factory WeatherForecastDay.fromJson(Map<String, dynamic> json) =>
      WeatherForecastDay(
        day: (json['day'] as String?) ?? '',
        minTemp: (json['min'] as num?)?.toDouble() ?? 0,
        maxTemp: (json['max'] as num?)?.toDouble() ?? 0,
        icon: (json['icon'] as String?) ?? 'cloudy',
      );

  Map<String, dynamic> toJson() => {
        'day': day,
        'min': minTemp.round(),
        'max': maxTemp.round(),
        'icon': icon,
      };
}

class WeatherState {
  final String city;
  final String unit; // C | F
  final double temp;
  final double feelsLike;
  final double minTemp;
  final double maxTemp;
  final int humidity;
  final double windKmh;
  final String condition;
  final String icon; // clear_day | clear_night | partly_cloudy | cloudy | fog | drizzle | rain | storm | snow
  final bool isDay;
  final List<WeatherForecastDay> forecast;
  final int updatedAtMs;

  const WeatherState({
    required this.city,
    this.unit = 'C',
    required this.temp,
    required this.feelsLike,
    required this.minTemp,
    required this.maxTemp,
    required this.humidity,
    required this.windKmh,
    required this.condition,
    required this.icon,
    this.isDay = true,
    this.forecast = const [],
    required this.updatedAtMs,
  });

  factory WeatherState.fromJson(Map<String, dynamic> json) {
    final rawFc = json['forecast'];
    final fc = <WeatherForecastDay>[];
    if (rawFc is List) {
      for (final item in rawFc) {
        if (item is Map) {
          fc.add(WeatherForecastDay.fromJson(item.cast<String, dynamic>()));
        }
      }
    }
    return WeatherState(
      city: (json['city'] as String?) ?? '',
      unit: (json['unit'] as String?) ?? 'C',
      temp: (json['temp'] as num?)?.toDouble() ?? 0,
      feelsLike: (json['feels_like'] as num?)?.toDouble() ?? 0,
      minTemp: (json['min'] as num?)?.toDouble() ?? 0,
      maxTemp: (json['max'] as num?)?.toDouble() ?? 0,
      humidity: (json['humidity'] as num?)?.toInt() ?? 0,
      windKmh: (json['wind_kmh'] as num?)?.toDouble() ?? 0,
      condition: (json['condition'] as String?) ?? '',
      icon: (json['icon'] as String?) ?? 'cloudy',
      isDay: json['is_day'] as bool? ?? true,
      forecast: List.unmodifiable(fc),
      updatedAtMs: (json['updated_at'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'city': city,
        'unit': unit,
        'temp': temp.round(),
        'feels_like': feelsLike.round(),
        'min': minTemp.round(),
        'max': maxTemp.round(),
        'humidity': humidity,
        'wind_kmh': windKmh.round(),
        'condition': condition,
        'icon': icon,
        'is_day': isDay,
        'forecast': forecast.map((d) => d.toJson()).toList(),
        'updated_at': updatedAtMs,
      };
}
