import 'dart:convert';
import 'package:agent_core/agent_core.dart';
import 'package:test/test.dart';

void main() {
  group('Contrato PomodoroTile & TodoTile', () {
    test('PomodoroTile serializa e desserializa com valores padrao', () {
      const tile = PomodoroTile(id: 'pomo_1');
      expect(tile.type, equals('pomodoro'));
      expect(tile.width, equals(2));
      expect(tile.height, equals(1));
      expect(tile.focusDurationMinutes, equals(25));
      expect(tile.shortBreakDurationMinutes, equals(5));
      expect(tile.longBreakDurationMinutes, equals(15));
      expect(tile.cyclesBeforeLongBreak, equals(4));
      expect(tile.startPhaseSoundId, isNull);
      expect(tile.endPhaseSoundId, isNull);

      final json = tile.toJson();
      expect(json, equals({
        'type': 'pomodoro',
        'id': 'pomo_1',
        'icon': 'timer',
        'label': 'Pomodoro',
      }));

      final parsed = Tile.fromJson(json) as PomodoroTile;
      expect(parsed, equals(tile));
    });

    test('PomodoroTile serializa valores customizados', () {
      const custom = PomodoroTile(
        id: 'pomo_custom',
        icon: 'alarm',
        label: 'Estudo Intenso',
        focusDurationMinutes: 50,
        shortBreakDurationMinutes: 10,
        longBreakDurationMinutes: 30,
        cyclesBeforeLongBreak: 3,
        startPhaseSoundId: 'sound_start',
        endPhaseSoundId: 'sound_end',
        width: 2,
        height: 2,
      );

      final json = custom.toJson();
      expect(json['focus_duration_minutes'], equals(50));
      expect(json['short_break_duration_minutes'], equals(10));
      expect(json['long_break_duration_minutes'], equals(30));
      expect(json['cycles_before_long_break'], equals(3));
      expect(json['start_phase_sound_id'], equals('sound_start'));
      expect(json['end_phase_sound_id'], equals('sound_end'));
      expect(json['height'], equals(2));

      final parsed = Tile.fromJson(json) as PomodoroTile;
      expect(parsed, equals(custom));
      expect(parsed.hashCode, equals(custom.hashCode));
    });

    test('TodoTile serializa e desserializa corretamente', () {
      const tile = TodoTile(id: 'todo_1');
      expect(tile.type, equals('todo'));
      expect(tile.width, equals(1));
      expect(tile.height, equals(1));
      expect(tile.icon, equals('content_paste'));
      expect(tile.label, equals('Tarefas'));

      final json = tile.toJson();
      expect(json, equals({
        'type': 'todo',
        'id': 'todo_1',
        'icon': 'content_paste',
        'label': 'Tarefas',
      }));

      final parsed = Tile.fromJson(json) as TodoTile;
      expect(parsed, equals(tile));
    });

    test('Layout com PomodoroTile e TodoTile nunca expoe bindings e respeita toPublishJson', () {
      final initialLayout = Layout(
        deviceName: 'PC de Teste',
        theme: HubTheme.fallback,
        pages: {
          'home': [
            const PomodoroTile(id: 'pomodoro_tile'),
            const TodoTile(id: 'todo_tile'),
          ],
        },
      ).setBindingLegacy('pomodoro_tile', ['echo', 'pomo']);

      final published = initialLayout.toPublishJson();
      expect(published.keys.toList(), equals(['deviceName', 'theme', 'pages']));
      final publishedStr = jsonEncode(published);
      expect(publishedStr.contains('"bindings"'), isFalse);
      expect(publishedStr.contains('echo'), isFalse);

      final homeTiles = published['pages']['home'] as List;
      expect(homeTiles.length, equals(2));
      expect(homeTiles[0]['type'], equals('pomodoro'));
      expect(homeTiles[1]['type'], equals('todo'));
    });

    test('Layout.validate valida PomodoroTile com duracoes invalidas', () {
      final badLayout = Layout(
        deviceName: 'PC',
        theme: HubTheme.fallback,
        pages: {
          'home': [
            const PomodoroTile(
              id: 'pomo_bad',
              focusDurationMinutes: 0,
              shortBreakDurationMinutes: -5,
              longBreakDurationMinutes: 0,
              cyclesBeforeLongBreak: 0,
            ),
          ],
        },
      );

      final issues = badLayout.validate();
      expect(issues.any((i) => i.message.contains('tempo de foco')), isTrue);
      expect(issues.any((i) => i.message.contains('tempo de pausa curta')), isTrue);
      expect(issues.any((i) => i.message.contains('tempo de pausa longa')), isTrue);
      expect(issues.any((i) => i.message.contains('ciclos do Pomodoro')), isTrue);
    });

    test('PomodoroState e PomodoroPhase parsing e serializacao', () {
      expect(PomodoroPhase.parse('focus'), equals(PomodoroPhase.focus));
      expect(PomodoroPhase.parse('short_break'), equals(PomodoroPhase.shortBreak));
      expect(PomodoroPhase.parse('long_break'), equals(PomodoroPhase.longBreak));
      expect(PomodoroPhase.parse('idle'), equals(PomodoroPhase.idle));
      expect(PomodoroPhase.parse('invalid'), equals(PomodoroPhase.idle));

      const state = PomodoroState(
        phase: PomodoroPhase.focus,
        remainingMs: 1500000,
        cycle: 2,
        totalCycles: 4,
        isRunning: true,
      );

      final json = state.toJson();
      expect(json, equals({
        'phase': 'focus',
        'remaining_ms': 1500000,
        'cycle': 2,
        'total_cycles': 4,
        'is_running': true,
      }));

      final parsed = PomodoroState.fromJson(json);
      expect(parsed, equals(state));
    });

    test('TodoState e TodoItem serializacao e contagem de pendentes', () {
      final item1 = TodoItem(id: 't1', text: 'Tarefa 1', done: false, createdAt: 100);
      final item2 = TodoItem(id: 't2', text: 'Tarefa 2', done: true, createdAt: 200);

      final state = TodoState.fromItems([item1, item2]);
      expect(state.total, equals(2));
      expect(state.pending, equals(1));

      final json = state.toJson();
      expect(json['total'], equals(2));
      expect(json['pending'], equals(1));
      expect(json['items'].length, equals(2));

      final parsed = TodoState.fromJson(json);
      expect(parsed, equals(state));
    });

    test('AgentTopics contem pomodoro e todos', () {
      const topics = AgentTopics('meu_pc');
      expect(topics.pomodoro, equals('nodes/meu_pc/state/pomodoro'));
      expect(topics.todos, equals('nodes/meu_pc/state/todos'));
    });

    test('builtinActions contem remote_todo_prompt', () {
      expect(Layout.builtinActions.contains('remote_todo_prompt'), isTrue);
    });

    test('CommandDispatcher despacha remote_todo_prompt', () async {
      bool called = false;
      final dispatcher = CommandDispatcher(
        audio: _DummyAudio(),
        brightness: UnsupportedBrightnessController(),
        media: MediaService(),
        keySender: _DummyKeySender(),
        layoutProvider: () => Layout.initial('test'),
        onRemoteTodoPrompt: () => called = true,
      );

      final cmd = AgentCommand.tryParse('{"action": "remote_todo_prompt"}')!;
      await dispatcher.dispatch(cmd);
      expect(called, isTrue);

      called = false;
      final handled = await dispatcher.runShortcut('remote_todo_prompt');
      expect(handled, isTrue);
      expect(called, isTrue);
    });
  });
}

class _DummyAudio implements AudioController {
  @override
  List<AppVolume> get apps => const [];
  @override
  Stream<List<AppVolume>> get appsChanges => const Stream.empty();
  @override
  Future<void> dispose() async {}
  @override
  bool get isAvailable => false;
  @override
  MasterVolume get master => const MasterVolume(value: 50);
  @override
  Stream<MasterVolume> get masterChanges => const Stream.empty();
  @override
  Future<void> refresh() async {}
  @override
  Future<void> setAppVolume(String id, int volume) async {}
  @override
  Future<void> setAppVolumeByName(String name, int volume) async {}
  @override
  Future<void> setMasterVolume(int volume) async {}
  @override
  Future<void> setMute(bool muted) async {}
  @override
  Future<void> start() async {}
}

class _DummyKeySender implements KeySender {
  @override
  Future<bool> send(String combo) async => true;
  @override
  Future<void> dispose() async {}
}

