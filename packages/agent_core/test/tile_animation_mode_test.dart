import 'package:agent_core/agent_core.dart';
import 'package:test/test.dart';

void main() {
  group('Tile animationMode & staticIcon round-trip', () {
    test('ShortcutTile com animationMode e staticIcon serializa e desserializa', () {
      const tile = ShortcutTile(
        id: 'btn_fire',
        icon: 'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7',
        staticIcon: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
        animationMode: 'on_tap',
        label: 'Fire',
      );

      final json = tile.toJson();
      expect(json['animation_mode'], equals('on_tap'));
      expect(json['static_icon'], contains('data:image/png'));

      final fromJson = Tile.fromJson(json) as ShortcutTile;
      expect(fromJson.animationMode, equals('on_tap'));
      expect(fromJson.staticIcon, equals(tile.staticIcon));
      expect(fromJson.icon, equals(tile.icon));
    });

    test('SoundTile com animationMode while_playing serializa e desserializa', () {
      const sound = SoundTile(
        id: 'sound_airhorn',
        soundId: 'airhorn',
        icon: 'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7',
        staticIcon: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
        animationMode: 'while_playing',
        label: 'Buzina',
      );

      final json = sound.toJson();
      expect(json['animation_mode'], equals('while_playing'));
      expect(json['static_icon'], contains('data:image/png'));

      final fromJson = Tile.fromJson(json) as SoundTile;
      expect(fromJson.animationMode, equals('while_playing'));
      expect(fromJson.staticIcon, equals(sound.staticIcon));
    });

    test('Tile sem animationMode omite chaves no JSON para economizar espaco', () {
      const tile = ShortcutTile(
        id: 'btn_normal',
        icon: '⚡',
        label: 'Normal',
      );

      final json = tile.toJson();
      expect(json.containsKey('animation_mode'), isFalse);
      expect(json.containsKey('static_icon'), isFalse);
    });
  });
}

