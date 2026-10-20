import 'package:cms_app/features/editor/key_combo_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('KeyComboHelper - Normalização e Formatação', () {
    test('Normaliza string case-insensitive e aliases de Win/Super', () {
      expect(KeyComboHelper.normalize('Win+D'), equals('win+d'));
      expect(KeyComboHelper.normalize('WIN + d'), equals('win+d'));
      expect(KeyComboHelper.normalize('super+d'), equals('win+d'));
      expect(KeyComboHelper.normalize('SUPER + Space'), equals('win+space'));
      expect(KeyComboHelper.normalize('windows+tab'), equals('win+tab'));
      expect(KeyComboHelper.normalize('Meta+Alt+T'), equals('alt+win+t'));
    });

    test('Limpa sinais + espúrios no início, fim ou repetidos', () {
      expect(KeyComboHelper.normalize('+ctrl+'), equals('ctrl'));
      expect(KeyComboHelper.normalize('ctrl++shift+esc'), equals('ctrl+shift+esc'));
      expect(KeyComboHelper.normalize('   +  '), equals(''));
    });

    test('Ordena modificadores na ordem canônica correta', () {
      expect(KeyComboHelper.normalize('d+ctrl'), equals('ctrl+d'));
      expect(KeyComboHelper.normalize('esc+shift+ctrl'), equals('ctrl+shift+esc'));
      expect(KeyComboHelper.normalize('win+alt+ctrl+shift+f1'), equals('ctrl+alt+shift+win+f1'));
    });

    test('Formata para exibição elegante com formatDisplay', () {
      expect(KeyComboHelper.formatDisplay('ctrl+shift+esc'), equals('Ctrl + Shift + Esc'));
      expect(KeyComboHelper.formatDisplay('win+d'), equals('Win + D'));
      expect(KeyComboHelper.formatDisplay('alt+f4'), equals('Alt + F4'));
      expect(KeyComboHelper.formatDisplay(''), equals(''));
    });

    test('Alterna modificador com toggleModifier sem gerar + soltos', () {
      // Começa vazio
      final step1 = KeyComboHelper.toggleModifier('', 'ctrl');
      expect(step1, equals('ctrl'));

      // Adiciona tecla 'd' manualmente e depois adiciona 'win'
      final step2 = KeyComboHelper.toggleModifier('d', 'win');
      expect(step2, equals('win+d'));

      // Adiciona 'ctrl'
      final step3 = KeyComboHelper.toggleModifier(step2, 'ctrl');
      expect(step3, equals('ctrl+win+d'));

      // Remove 'win'
      final step4 = KeyComboHelper.toggleModifier(step3, 'win');
      expect(step4, equals('ctrl+d'));

      // Remove 'ctrl'
      final step5 = KeyComboHelper.toggleModifier(step4, 'ctrl');
      expect(step5, equals('d'));
    });

    test('hasModifier identifica modificador presente mesmo com alias', () {
      expect(KeyComboHelper.hasModifier('ctrl+win+d', 'ctrl'), isTrue);
      expect(KeyComboHelper.hasModifier('ctrl+win+d', 'super'), isTrue);
      expect(KeyComboHelper.hasModifier('ctrl+win+d', 'alt'), isFalse);
    });
  });
}
