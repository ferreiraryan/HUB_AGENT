import 'package:cms_app/features/editor/remote_search_controller.dart';
import 'package:cms_app/features/editor/remote_search_spotlight.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRemoteSearchController extends RemoteSearchController {
  @override
  RemoteSearchState build() {
    return const RemoteSearchState(isOpen: true, query: 'spotify', wasHidden: false);
  }

  @override
  void updateQuery(String query) {
    state = state.copyWith(query: query);
  }

  @override
  Future<void> close() async {
    state = const RemoteSearchState(isOpen: false, query: '', wasHidden: false);
  }
}

void main() {
  testWidgets('RemoteSearchCompactView renderiza TextField com Material sem erros',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          remoteSearchControllerProvider
              .overrideWith(() => _FakeRemoteSearchController()),
        ],
        child: const MaterialApp(
          home: RemoteSearchCompactView(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('spotify'), findsOneWidget);
    expect(find.text('ESC'), findsOneWidget);
    expect(find.text('ENTER'), findsOneWidget);
  });

  testWidgets('RemoteSearchOverlayView renderiza TextField sobre Stack com Material sem erros',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          remoteSearchControllerProvider
              .overrideWith(() => _FakeRemoteSearchController()),
        ],
        child: const MaterialApp(
          home: Stack(
            children: [
              SizedBox(width: 800, height: 600),
              RemoteSearchOverlayView(),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('spotify'), findsOneWidget);
  });
}
