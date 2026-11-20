import 'dart:io';

import 'package:agent_core/agent_core.dart';
import 'package:flutter/widgets.dart';
import 'package:tray_manager/tray_manager.dart';

class TrayController with TrayListener {
  static final instance = TrayController._();

  TrayController._();

  VoidCallback? _onShowWindow;
  VoidCallback? _onHideWindow;
  VoidCallback? _onPublish;
  VoidCallback? _onReconnect;
  VoidCallback? _onTogglePomodoro;
  VoidCallback? _onQuit;
  AgentConnectionState _connState = AgentConnectionState.disconnected;

  Future<void> init({
    required VoidCallback onShowWindow,
    required VoidCallback onHideWindow,
    required VoidCallback onPublish,
    VoidCallback? onReconnect,
    VoidCallback? onTogglePomodoro,
    required VoidCallback onQuit,
  }) async {
    _onShowWindow = onShowWindow;
    _onHideWindow = onHideWindow;
    _onPublish = onPublish;
    _onReconnect = onReconnect;
    _onTogglePomodoro = onTogglePomodoro;
    _onQuit = onQuit;

    trayManager.addListener(this);

    try {
      if (Platform.isWindows) {
        await trayManager.setIcon('assets/icons/app_icon.ico');
      } else {
        await trayManager.setIcon('assets/icons/app_icon.png');
      }
    } catch (e) {
      stderr.writeln('Falha ao configurar ícone da bandeja: $e');
    }

    if (!Platform.isLinux) {
      try {
        await trayManager.setToolTip('Hub Agent CMS');
      } catch (e) {
        stderr.writeln('Falha ao configurar tooltip da bandeja: $e');
      }
    }

    await _rebuildMenu();
  }

  Future<void> updateConnectionState(AgentConnectionState state) async {
    if (_connState == state) return;
    _connState = state;
    await _rebuildMenu();
  }

  Future<void> _rebuildMenu() async {
    final statusLabel = switch (_connState) {
      AgentConnectionState.connected => '● Broker: Conectado',
      AgentConnectionState.connecting => '◐ Broker: Conectando...',
      AgentConnectionState.disconnected => '○ Broker: Desconectado',
    };

    try {
      final menu = Menu(
        items: [
          MenuItem(
            key: 'status',
            label: statusLabel,
            disabled: true,
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'show',
            label: 'Mostrar janela',
          ),
          MenuItem(
            key: 'hide',
            label: 'Esconder janela',
          ),
          MenuItem(
            key: 'publish',
            label: 'Publicar layout agora',
          ),
          if (_onReconnect != null)
            MenuItem(
              key: 'reconnect',
              label: 'Reconectar broker',
            ),
          if (_onTogglePomodoro != null)
            MenuItem(
              key: 'pomodoro',
              label: 'Pomodoro: Iniciar / Pausar',
            ),
          MenuItem.separator(),
          MenuItem(
            key: 'quit',
            label: 'Encerrar agente',
          ),
        ],
      );

      await trayManager.setContextMenu(menu);
    } catch (e) {
      stderr.writeln('Falha ao configurar menu da bandeja: $e');
    }
  }

  @override
  void onTrayIconMouseDown() {
    _onShowWindow?.call();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show') {
      _onShowWindow?.call();
    } else if (menuItem.key == 'hide') {
      _onHideWindow?.call();
    } else if (menuItem.key == 'publish') {
      _onPublish?.call();
    } else if (menuItem.key == 'reconnect') {
      _onReconnect?.call();
    } else if (menuItem.key == 'pomodoro') {
      _onTogglePomodoro?.call();
    } else if (menuItem.key == 'quit') {
      _onQuit?.call();
    }
  }

  void dispose() {
    trayManager.removeListener(this);
  }
}
