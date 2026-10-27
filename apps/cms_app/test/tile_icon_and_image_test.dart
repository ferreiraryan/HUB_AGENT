import 'dart:convert';
import 'dart:typed_data';
import 'package:cms_app/features/editor/helpers/image_icon_helper.dart';
import 'package:cms_app/features/editor/widgets/tile_icon_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ImageIconHelper', () {
    test('isImageDataUri identifica corretamente strings Data URI', () {
      expect(ImageIconHelper.isImageDataUri('data:image/png;base64,abc'), isTrue);
      expect(ImageIconHelper.isImageDataUri('data:image/jpeg;base64,123'), isTrue);
      expect(ImageIconHelper.isImageDataUri('data:image/webp;base64,xyz'), isTrue);
      expect(ImageIconHelper.isImageDataUri('play_arrow'), isFalse);
      expect(ImageIconHelper.isImageDataUri('🎮'), isFalse);
      expect(ImageIconHelper.isImageDataUri(''), isFalse);
      expect(ImageIconHelper.isImageDataUri(null), isFalse);
    });

    test('extractBytes decodifica Base64 com sucesso', () {
      final sampleBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      final base64Str = base64Encode(sampleBytes);
      final dataUri = 'data:image/png;base64,$base64Str';

      final decoded = ImageIconHelper.extractBytes(dataUri);
      expect(decoded, isNotNull);
      expect(decoded, equals(sampleBytes));
    });

    test('extractBytes retorna null para string invalida', () {
      expect(ImageIconHelper.extractBytes('not_an_image'), isNull);
      expect(ImageIconHelper.extractBytes('data:image/png;base64,invalid!@#%'), isNull);
      expect(ImageIconHelper.extractBytes(null), isNull);
    });
  });

  group('TileIconView Widget', () {
    testWidgets('renderiza fallback Icon quando icon for nulo ou vazio', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TileIconView(icon: null),
          ),
        ),
      );

      expect(find.byIcon(Icons.widgets), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TileIconView(icon: ''),
          ),
        ),
      );

      expect(find.byIcon(Icons.widgets), findsOneWidget);
    });

    testWidgets('renderiza Material Symbol mapeado', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TileIconView(icon: 'play_arrow'),
          ),
        ),
      );

      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('renderiza emoji como Text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TileIconView(icon: '🎮'),
          ),
        ),
      );

      expect(find.text('🎮'), findsOneWidget);
    });

    testWidgets('renderiza Image quando for Base64 Data URI', (tester) async {
      // 1x1 transparente PNG válido
      final transparentPng = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
      );
      final dataUri = 'data:image/png;base64,${base64Encode(transparentPng)}';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TileIconView(icon: dataUri),
          ),
        ),
      );

      expect(find.byType(Image), findsOneWidget);
    });
  });
}

