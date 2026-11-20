import 'dart:io';

import 'package:agent_core/agent_core.dart';
import 'package:test/test.dart';

void main() {
  group('ScreensaverConfig & Presets', () {
    test('round-trip JSON preserva todos os campos e widgets', () {
      final original = ScreensaverPresets.auroraDesk(city: 'Curitiba');
      final json = original.toJson();
      final decoded = ScreensaverConfig.fromJson(json);

      expect(decoded.backgroundStyle, equals('aurora'));
      expect(decoded.weatherCity, equals('Curitiba'));
      expect(decoded.widgets.length, equals(original.widgets.length));
      expect(decoded.widgets.first.id, equals(original.widgets.first.id));
      expect(decoded.widgets.first.x, equals(original.widgets.first.x));
    });

    test('clamp de coordenadas evita widgets fora da tela', () {
      final w = ScreensaverWidget.fromJson({
        'id': 'w1',
        'type': 'clock',
        'x': 95,
        'y': 95,
        'w': 30,
        'h': 25,
      });
      expect(w.w, equals(30));
      expect(w.h, equals(25));
      expect(w.x, equals(70));
      expect(w.y, equals(75));
    });

    test('todos os 4 presets são válidos e serializáveis', () {
      final all = ScreensaverPresets.all(city: 'Recife');
      expect(all.length, equals(4));
      for (final cfg in all.values) {
        final rt = ScreensaverConfig.fromJson(cfg.toJson());
        expect(rt.weatherCity, equals('Recife'));
        expect(rt.widgets, isNotEmpty);
      }
    });
  });

  group('ScreensaverRepository', () {
    test('persiste atomicamente em disco e recarrega', () async {
      final dir = await Directory.systemTemp.createTemp('ss_repo_test_');
      addTearDown(() => dir.delete(recursive: true));

      final file = File('${dir.path}/screensaver.json');
      final repo = ScreensaverRepository(file: file);
      await repo.load();
      expect(repo.current.backgroundStyle, equals('aurora'));

      final updated = ScreensaverPresets.cyberTelemetry(city: 'Florianópolis');
      repo.update(updated);
      await repo.flush();

      final repo2 = ScreensaverRepository(file: file);
      await repo2.load();
      expect(repo2.current.backgroundStyle, equals('particles'));
      expect(repo2.current.weatherCity, equals('Florianópolis'));
      expect(repo2.current.widgets.length, equals(updated.widgets.length));

      await repo.dispose();
      await repo2.dispose();
    });
  });

  group('WeatherService', () {
    test('faz geocoding e parse de resposta Open-Meteo com previsão de 3 dias', () async {
      final svc = WeatherService(
        customFetcher: (uri) async {
          if (uri.host.contains('geocoding')) {
            return {
              'results': [
                {
                  'name': 'São Paulo',
                  'admin1': 'São Paulo',
                  'latitude': -23.55,
                  'longitude': -46.63,
                }
              ],
            };
          }
          return {
            'current': {
              'temperature_2m': 24.6,
              'apparent_temperature': 26.1,
              'relative_humidity_2m': 68,
              'wind_speed_10m': 14.2,
              'is_day': 1,
              'weather_code': 2,
            },
            'daily': {
              'time': ['2026-11-19', '2026-11-20', '2026-11-21', '2026-11-22'],
              'temperature_2m_min': [18.0, 17.4, 19.0, 20.1],
              'temperature_2m_max': [27.2, 26.0, 28.5, 29.0],
              'weather_code': [2, 61, 0, 95],
            },
          };
        },
      );

      final state = await svc.configure(city: 'São Paulo', unit: 'C');
      expect(state, isNotNull);
      expect(state!.city, equals('São Paulo'));
      expect(state.temp.round(), equals(25));
      expect(state.humidity, equals(68));
      expect(state.icon, equals('partly_cloudy'));
      expect(state.condition, equals('Parcialmente nublado'));
      expect(state.forecast.length, equals(3));
      expect(state.forecast[0].icon, equals('rain'));
      expect(state.forecast[1].icon, equals('clear_day'));
      expect(state.forecast[2].icon, equals('storm'));

      await svc.dispose();
    });
  });
}
