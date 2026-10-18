import 'dart:convert';
import 'dart:io';

class AppPreset {
  final String name;
  final String match;
  final String icon;

  const AppPreset({
    required this.name,
    required this.match,
    required this.icon,
  });
}

class ProcessDiscovery {
  static const List<AppPreset> _windowsPresets = [
    AppPreset(name: 'Spotify', match: 'Spotify.exe', icon: '🎵'),
    AppPreset(name: 'Chrome', match: 'chrome.exe', icon: '🌐'),
    AppPreset(name: 'Discord', match: 'Discord.exe', icon: '💬'),
    AppPreset(name: 'Firefox', match: 'firefox.exe', icon: '🦊'),
    AppPreset(name: 'Brave', match: 'brave.exe', icon: '🦁'),
    AppPreset(name: 'Edge', match: 'msedge.exe', icon: '🌀'),
    AppPreset(name: 'VLC', match: 'vlc.exe', icon: '🎬'),
    AppPreset(name: 'Steam', match: 'steam.exe', icon: '🎮'),
    AppPreset(name: 'OBS', match: 'obs64.exe', icon: '📹'),
    AppPreset(name: 'Telegram', match: 'Telegram.exe', icon: '✈️'),
  ];

  static const List<AppPreset> _linuxPresets = [
    AppPreset(name: 'Spotify', match: 'Spotify', icon: '🎵'),
    AppPreset(name: 'Chrome', match: 'Chromium', icon: '🌐'),
    AppPreset(name: 'Discord', match: 'Discord', icon: '💬'),
    AppPreset(name: 'Firefox', match: 'Firefox', icon: '🦊'),
    AppPreset(name: 'Brave', match: 'Brave', icon: '🦁'),
    AppPreset(name: 'Edge', match: 'Edge', icon: '🌀'),
    AppPreset(name: 'VLC', match: 'VLC', icon: '🎬'),
    AppPreset(name: 'Steam', match: 'Steam', icon: '🎮'),
    AppPreset(name: 'OBS', match: 'OBS', icon: '📹'),
    AppPreset(name: 'Telegram', match: 'Telegram', icon: '✈️'),
  ];

  static List<AppPreset> get commonPresets =>
      Platform.isWindows ? _windowsPresets : _linuxPresets;

  static const Set<String> _windowsIgnore = {
    'system idle process',
    'system',
    'registry',
    'smss.exe',
    'csrss.exe',
    'wininit.exe',
    'services.exe',
    'lsass.exe',
    'svchost.exe',
    'fontdrvhost.exe',
    'winlogon.exe',
    'dwmapi.exe',
    'sihost.exe',
    'taskhostw.exe',
    'explorer.exe',
    'shellexperiencehost.exe',
    'searchhost.exe',
    'startmenuexperiencehost.exe',
    'runtimebroker.exe',
    'textinputhost.exe',
    'ctfmon.exe',
    'audiodg.exe',
    'conhost.exe',
    'cmd.exe',
    'powershell.exe',
    'pwsh.exe',
    'tasklist.exe',
    'wudfhost.exe',
    'securityhealthservice.exe',
    'systemsettings.exe',
    'smartscreen.exe',
    'spoolsv.exe',
    'monotificationux.exe',
    'searchprotocolhost.exe',
    'searchfilterhost.exe',
    'useroobebroker.exe',
    'backgroundtaskhost.exe',
    'applicationframehost.exe',
  };

  /// Retorna a lista de nomes de processos ativos no SO atual.
  static Future<List<String>> getRunningProcesses() async {
    if (Platform.isWindows) {
      return _getWindowsProcesses();
    } else if (Platform.isLinux) {
      return _getLinuxProcesses();
    }
    return [];
  }

  static Future<List<String>> _getWindowsProcesses() async {
    final results = <String>{};
    try {
      final res = await Process.run('tasklist', ['/fo', 'csv', '/nh'])
          .timeout(const Duration(seconds: 3));
      if (res.exitCode == 0) {
        final lines = (res.stdout as String).split(RegExp(r'\r?\n'));
        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) continue;
          // Formato: "nome.exe","pid","session","num","mem"
          final parts = trimmed.split('","');
          if (parts.isNotEmpty) {
            var name = parts.first.replaceAll('"', '').trim();
            if (name.isNotEmpty && !_windowsIgnore.contains(name.toLowerCase())) {
              results.add(name);
            }
          }
        }
      }
    } catch (_) {}

    final sorted = results.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }

  static Future<List<String>> _getLinuxProcesses() async {
    final results = <String>{};
    try {
      // 1. Tenta pactl sink-inputs (aplicações emitindo áudio)
      final r = await Process.run('pactl', ['-f', 'json', 'list', 'sink-inputs'])
          .timeout(const Duration(seconds: 2));
      if (r.exitCode == 0) {
        final list = jsonDecode(r.stdout as String) as List;
        for (final item in list) {
          final props = (item as Map)['properties'] as Map?;
          final appName = props?['application.name'] as String?;
          if (appName != null && appName.trim().isNotEmpty) {
            results.add(appName.trim());
          }
        }
      }
    } catch (_) {}

    try {
      // 2. Se pactl não retornou nada ou como fallback, pega lista de ps
      if (results.isEmpty) {
        final r = await Process.run('ps', ['-e', '-o', 'comm='])
            .timeout(const Duration(seconds: 2));
        if (r.exitCode == 0) {
          final lines = (r.stdout as String).split('\n');
          for (final line in lines) {
            final name = line.trim();
            if (name.isNotEmpty && !name.startsWith('[')) {
              results.add(name);
            }
          }
        }
      }
    } catch (_) {}

    final sorted = results.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }
}

