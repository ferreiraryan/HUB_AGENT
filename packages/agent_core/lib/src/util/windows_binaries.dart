import 'dart:io';

/// Utilitário centralizado para localização com cache dos binários nativos no Windows
/// (`hub_audio_helper.exe` e `nircmd.exe`).
class WindowsBinaries {
  static String? _cachedHelperPath;
  static String? _cachedNircmdPath;

  /// Permite sobrescrever os caminhos para uso em testes unitários.
  static String? overrideHelperPath;
  static String? overrideNircmdPath;

  /// Localiza o caminho absoluto de `hub_audio_helper.exe`.
  ///
  /// Procura sucessivamente:
  /// 1. Override configurado para testes
  /// 2. Cache em memória
  /// 3. Diretório do executável (`Platform.resolvedExecutable`)
  /// 4. Subdiretório `data/flutter_assets/`
  /// 5. Diretório do script atual (`Platform.script`)
  /// 6. Caminhos relativos de desenvolvimento (`windows/runner/resources/` etc.)
  static String? resolveHelperPath() {
    if (overrideHelperPath != null && File(overrideHelperPath!).existsSync()) {
      return overrideHelperPath;
    }
    if (_cachedHelperPath != null && File(_cachedHelperPath!).existsSync()) {
      return _cachedHelperPath;
    }

    final found = _searchBinary('hub_audio_helper.exe');
    if (found != null) {
      _cachedHelperPath = found;
    }
    return found;
  }

  /// Localiza o caminho absoluto de `nircmd.exe`.
  static String? resolveNircmdPath() {
    if (overrideNircmdPath != null && File(overrideNircmdPath!).existsSync()) {
      return overrideNircmdPath;
    }
    if (_cachedNircmdPath != null && File(_cachedNircmdPath!).existsSync()) {
      return _cachedNircmdPath;
    }

    final found = _searchBinary('nircmd.exe');
    if (found != null) {
      _cachedNircmdPath = found;
    }
    return found;
  }

  /// Invalida o cache em memória (útil se novos binários forem copiados em runtime).
  static void invalidateCache() {
    _cachedHelperPath = null;
    _cachedNircmdPath = null;
  }

  static String? _searchBinary(String binaryName) {
    final candidates = <String>[];

    // 1. Ao lado do executável da aplicação
    try {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      candidates.add('$exeDir\\$binaryName');
      candidates.add('$exeDir\\data\\flutter_assets\\$binaryName');
      candidates.add('$exeDir\\resources\\$binaryName');
    } catch (_) {}

    // 2. Ao lado do script Dart em execução
    try {
      final scriptDir = File(Platform.script.toFilePath()).parent.path;
      candidates.add('$scriptDir\\$binaryName');
      candidates.add('$scriptDir\\windows\\runner\\resources\\$binaryName');
    } catch (_) {}

    // 3. Diretório de trabalho atual e caminhos relativos conhecidos de desenvolvimento
    final cwd = Directory.current.path;
    candidates.addAll([
      '$cwd\\$binaryName',
      '$cwd\\apps\\cms_app\\windows\\runner\\resources\\$binaryName',
      '$cwd\\windows\\runner\\resources\\$binaryName',
      '$cwd\\..\\cms_app\\windows\\runner\\resources\\$binaryName',
      '$cwd\\..\\..\\apps\\cms_app\\windows\\runner\\resources\\$binaryName',
    ]);

    for (final candidate in candidates) {
      if (File(candidate).existsSync()) {
        return candidate;
      }
    }

    return null;
  }
}

