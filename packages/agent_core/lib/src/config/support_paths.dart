import 'dart:io';

/// Resolução centralizada de diretórios de dados e binários irmãos em Dart puro,
/// compatível com os caminhos do `path_provider` no Linux, Windows e macOS.
class SupportPaths {
  /// Diretório de suporte do Hub Agent (onde ficam `layout.json`, `agent_config.json`,
  /// `screensaver.json`, `todos.json`, `page_rules.json`, `sounds/` e `images/`).
  ///
  /// Mantém exatamente os mesmos diretórios já usados pelo `cms_app`:
  /// - Linux: `$XDG_DATA_HOME/com.example.cms_app` (ou `~/.local/share/com.example.cms_app`)
  /// - Windows: `%APPDATA%\com.example\cms_app`
  /// - macOS: `~/Library/Application Support/com.example.cms_app`
  static Directory resolveSupportDir({String? overridePath}) {
    final explicit = (overridePath ?? Platform.environment['HUB_AGENT_DATA_DIR'] ?? '').trim();
    if (explicit.isNotEmpty) {
      return Directory(explicit);
    }

    if (Platform.isLinux) {
      final xdg = (Platform.environment['XDG_DATA_HOME'] ?? '').trim();
      final base = xdg.isNotEmpty
          ? xdg
          : '${Platform.environment['HOME'] ?? '.'}/.local/share';
      return Directory('$base/com.example.cms_app');
    }

    if (Platform.isWindows) {
      final appData = (Platform.environment['APPDATA'] ?? '').trim();
      if (appData.isNotEmpty) {
        return Directory('$appData\\com.example\\cms_app');
      }
      final userProfile = (Platform.environment['USERPROFILE'] ?? '.').trim();
      return Directory('$userProfile\\AppData\\Roaming\\com.example\\cms_app');
    }

    if (Platform.isMacOS) {
      final home = Platform.environment['HOME'] ?? '.';
      return Directory('$home/Library/Application Support/com.example.cms_app');
    }

    return Directory.current;
  }

  /// Localiza um executável irmão no mesmo diretório do binário atual
  /// (ex: `hub_agent_daemon`, `cms_app`, `hub_tray_linux`).
  static String? resolveSiblingBinary(String baseName) {
    final exeName = Platform.isWindows && !baseName.endsWith('.exe')
        ? '$baseName.exe'
        : baseName;
    final sep = Platform.pathSeparator;
    final candidates = <String>[];

    try {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      candidates.add('$exeDir$sep$exeName');
      candidates.add('$exeDir${sep}resources$sep$exeName');
    } catch (_) {}

    try {
      final scriptDir = File(Platform.script.toFilePath()).parent.path;
      candidates.add('$scriptDir$sep$exeName');
    } catch (_) {}

    final cwd = Directory.current.path;
    candidates.addAll([
      '$cwd$sep$exeName',
      '$cwd${sep}build${sep}linux${sep}x64${sep}release${sep}bundle$sep$exeName',
      '$cwd${sep}apps${sep}cms_app${sep}build${sep}linux${sep}x64${sep}release${sep}bundle$sep$exeName',
      '$cwd${sep}apps${sep}cms_app${sep}build${sep}windows${sep}x64${sep}runner${sep}Release$sep$exeName',
    ]);

    for (final c in candidates) {
      if (File(c).existsSync()) return c;
    }
    return null;
  }

  /// Localiza o arquivo de ícone da bandeja (`app_icon.ico` no Windows, `app_icon.png` no Linux).
  static String? resolveTrayIconPath() {
    final sep = Platform.pathSeparator;
    final fileName = Platform.isWindows ? 'app_icon.ico' : 'app_icon.png';
    final candidates = <String>[];

    try {
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      candidates.addAll([
        '$exeDir${sep}data${sep}flutter_assets${sep}assets${sep}icons$sep$fileName',
        '$exeDir${sep}resources$sep$fileName',
        '$exeDir$sep$fileName',
      ]);
    } catch (_) {}

    final cwd = Directory.current.path;
    candidates.addAll([
      '$cwd${sep}assets${sep}icons$sep$fileName',
      '$cwd${sep}apps${sep}cms_app${sep}assets${sep}icons$sep$fileName',
      '$cwd${sep}apps${sep}cms_app${sep}windows${sep}runner${sep}resources$sep$fileName',
    ]);

    for (final c in candidates) {
      if (File(c).existsSync()) return c;
    }
    return null;
  }
}
