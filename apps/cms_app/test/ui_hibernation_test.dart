import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:agent_core/agent_core.dart';
import 'package:cms_app/features/editor/editor_page.dart';
import 'package:cms_app/features/editor/helpers/image_icon_helper.dart';
import 'package:cms_app/main.dart';
import 'package:cms_app/providers.dart';
import 'package:cms_app/system/agent_config.dart';
import 'package:cms_app/system/window_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Hibernação de UI na bandeja e cache de imagens', () {
    late Directory tempDir;
    late AgentRuntime runtime;
    late SoundLibraryRepository soundLib;
    late ImageLibraryRepository imgLib;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('cms_hibernate_test_');
      final repo = LayoutRepository(file: File('${tempDir.path}/layout.json'));
      await repo.load(fallbackDeviceName: 'TestPC');
      final mqtt = MqttService(host: '127.0.0.1', deviceId: 'test-pc');
      runtime = AgentRuntime(
        repository: repo,
        mqtt: mqtt,
        audio: UnsupportedAudioController(),
        brightness: UnsupportedBrightnessController(),
        osd: NoopOsdService(),
      );
      soundLib =
          SoundLibraryRepository(soundsDir: Directory('${tempDir.path}/sounds'));
      imgLib =
          ImageLibraryRepository(imagesDir: Directory('${tempDir.path}/images'));
    });

    tearDown(() async {
      WindowController.instance.isWindowVisible.value = true;
      WindowController.instance.onHidden = null;
      await runtime.dispose();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    testWidgets(
      'CmsApp desmonta EditorPage quando oculto e remonta ao exibir',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        WindowController.instance.isWindowVisible.value = false;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              agentConfigProvider.overrideWithValue(
                const AgentConfig(
                  host: '127.0.0.1',
                  port: 1883,
                  deviceId: 'test-pc',
                ),
              ),
              agentRuntimeProvider.overrideWithValue(runtime),
              connectionStateProvider.overrideWith(
                (ref) => Stream.value(AgentConnectionState.disconnected),
              ),
              soundLibraryRepositoryProvider.overrideWithValue(soundLib),
              imageLibraryRepositoryProvider.overrideWithValue(imgLib),
            ],
            child: const CmsApp(),
          ),
        );
        await tester.pump();

        // Oculto na bandeja -> EditorPage NÃO deve estar montado
        expect(find.byType(EditorPage), findsNothing);
        expect(find.byType(SizedBox), findsOneWidget);

        // Ao exibir a janela -> EditorPage é remontado imediatamente
        WindowController.instance.isWindowVisible.value = true;
        await tester.pump();
        expect(find.byType(EditorPage), findsOneWidget);

        // Avança timers pendentes de entrada dos TileCards
        await tester.pump(const Duration(milliseconds: 400));

        // Ao ocultar novamente -> EditorPage volta a ser desmontado
        WindowController.instance.isWindowVisible.value = false;
        await tester.pump();
        expect(find.byType(EditorPage), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
      timeout: const Timeout(Duration(seconds: 15)),
    );

    test('ImageIconHelper respeita cache LRU e clearCache()', () {
      ImageIconHelper.clearCache();
      final bytes = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
      final uri = 'data:image/png;base64,${base64Encode(bytes)}';

      final first = ImageIconHelper.extractBytes(uri);
      final second = ImageIconHelper.extractBytes(uri);
      expect(first, isNotNull);
      expect(identical(first, second), isTrue);

      ImageIconHelper.clearCache();
      final third = ImageIconHelper.extractBytes(uri);
      expect(third, isNotNull);
      expect(identical(first, third), isFalse);
    });
  });
}
