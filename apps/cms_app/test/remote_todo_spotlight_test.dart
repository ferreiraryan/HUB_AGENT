import 'package:cms_app/features/editor/remote_todo_controller.dart';
import 'package:cms_app/features/editor/remote_todo_spotlight.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRemoteTodoController extends RemoteTodoController {
  @override
  RemoteTodoState build() {
    return const RemoteTodoState(isOpen: true, wasHidden: false);
  }

  @override
  Future<void> submit(String text) async {
    state = const RemoteTodoState(isOpen: false, wasHidden: false);
  }

  @override
  Future<void> close() async {
    state = const RemoteTodoState(isOpen: false, wasHidden: false);
  }
}

void main() {
  testWidgets('RemoteTodoCompactView renderiza TextField e badges sem erros',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          remoteTodoControllerProvider
              .overrideWith(() => _FakeRemoteTodoController()),
        ],
        child: const MaterialApp(
          home: RemoteTodoCompactView(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('ESC'), findsOneWidget);
    expect(find.text('ENTER'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
  });

  testWidgets('RemoteTodoOverlayView renderiza TextField sobre Stack com Material sem erros',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          remoteTodoControllerProvider
              .overrideWith(() => _FakeRemoteTodoController()),
        ],
        child: const MaterialApp(
          home: Stack(
            children: [
              SizedBox(width: 800, height: 600),
              RemoteTodoOverlayView(),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('ESC'), findsOneWidget);
    expect(find.text('ENTER'), findsOneWidget);
  });
}

