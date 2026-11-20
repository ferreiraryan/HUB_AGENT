import 'dart:io';
import 'package:agent_core/agent_core.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late File todoFile;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('todo_service_test_');
    todoFile = File('${tempDir.path}/todos.json');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('TodoRepository & TodoService', () {
    test('carrega arquivo inexistente inicializando vazio', () async {
      final repo = TodoRepository(file: todoFile);
      final service = TodoService(repository: repo);

      await service.init();
      expect(service.current.items, isEmpty);
      expect(service.current.pending, equals(0));
      expect(service.current.total, equals(0));
      expect(await todoFile.exists(), isTrue);

      await service.dispose();
    });

    test('adiciona, alterna status, remove e limpa concluidas com persistencia', () async {
      final repo = TodoRepository(file: todoFile);
      final service = TodoService(repository: repo);
      await service.init();

      await service.addItem('Estudar Rust');
      await service.addItem('Estudar Flutter');
      expect(service.current.total, equals(2));
      expect(service.current.pending, equals(2));
      expect(service.current.items.first.text, equals('Estudar Flutter'));

      // Alterna 'Estudar Flutter' como done
      final flutterId = service.current.items.first.id;
      await service.toggleItem(flutterId);
      expect(service.current.pending, equals(1));
      expect(service.current.items.first.done, isTrue);

      // Recarrega em nova instancia do servico para atestar persistencia atomica em disco
      final service2 = TodoService(repository: TodoRepository(file: todoFile));
      await service2.init();
      expect(service2.current.total, equals(2));
      expect(service2.current.pending, equals(1));

      // Limpa concluidas
      await service2.clearDone();
      expect(service2.current.total, equals(1));
      expect(service2.current.pending, equals(1));
      expect(service2.current.items.first.text, equals('Estudar Rust'));

      // Remove unico item
      final rustId = service2.current.items.first.id;
      await service2.removeItem(rustId);
      expect(service2.current.items, isEmpty);
      expect(service2.current.total, equals(0));

      await service.dispose();
      await service2.dispose();
    });

    test('recupera de JSON corrompido criando .bak sem crashar', () async {
      await todoFile.writeAsString('{ json invalido ...');
      final repo = TodoRepository(file: todoFile);
      final service = TodoService(repository: repo);

      await service.init();
      expect(service.current.items, isEmpty);
      expect(File('${todoFile.path}.bak').existsSync(), isTrue);

      await service.dispose();
    });
  });
}

