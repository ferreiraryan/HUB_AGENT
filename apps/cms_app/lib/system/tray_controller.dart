import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:tray_manager/tray_manager.dart';

class TrayController with TrayListener {
  static final instance = TrayController._();

  TrayController._();

  VoidCallback? _onShowWindow;
  VoidCallback? _onHideWindow;
  VoidCallback? _onPublish;
  VoidCallback? _onQuit;

  Future<void> init({
    required VoidCallback onShowWindow,
    required VoidCallback onHideWindow,
    required VoidCallback onPublish,
    required VoidCallback onQuit,
  }) async {
    _onShowWindow = onShowWindow;
    _onHideWindow = onHideWindow;
    _onPublish = onPublish;
    _onQuit = onQuit;

    trayManager.addListener(this);

    try {
      if (Platform.isLinux) {
        await trayManager.setIcon('application-x-executable');
      } else {
        // TODO: Adicionar asset real e chamar setIcon() passando o caminho no Windows/macOS.
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

    try {
      final menu = Menu(
        items: [
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
            label: 'Publicar agora',
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
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show') {
      _onShowWindow?.call();
    } else if (menuItem.key == 'hide') {
      _onHideWindow?.call();
    } else if (menuItem.key == 'publish') {
      _onPublish?.call();
    } else if (menuItem.key == 'quit') {
      _onQuit?.call();
    }
  }

  void dispose() {
    trayManager.removeListener(this);
  }
}
