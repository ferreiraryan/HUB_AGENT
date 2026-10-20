import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'remote_search_controller.dart';

class RemoteSearchInput extends ConsumerStatefulWidget {
  const RemoteSearchInput({super.key});

  @override
  ConsumerState<RemoteSearchInput> createState() => _RemoteSearchInputState();
}

class _RemoteSearchInputState extends ConsumerState<RemoteSearchInput> {
  late final TextEditingController _textController;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final initialQuery = ref.read(remoteSearchControllerProvider).query;
    _textController = TextEditingController(text: initialQuery);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onClose() {
    ref.read(remoteSearchControllerProvider.notifier).close();
  }

  @override
  Widget build(BuildContext context) {
    // Sincroniza se o estado mudar externamente
    ref.listen<RemoteSearchState>(remoteSearchControllerProvider, (prev, next) {
      if (next.query != _textController.text) {
        _textController.text = next.query;
      }
    });

    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape) {
          _onClose();
        }
      },
      child: Material(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(14),
        elevation: 6,
        shadowColor: const Color(0x66000000),
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF89B4FA),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.keyboard_alt_outlined,
                color: Color(0xFF89B4FA),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  autofocus: true,
                  style: const TextStyle(
                    color: Color(0xFFCDD6F4),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Pesquisar widgets no tablet...',
                    hintStyle: TextStyle(
                      color: Color(0xFFA6ADC8),
                      fontSize: 15,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                  onChanged: (val) {
                    ref
                        .read(remoteSearchControllerProvider.notifier)
                        .updateQuery(val);
                  },
                  onSubmitted: (_) => _onClose(),
                ),
              ),
              if (_textController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  color: const Color(0xFFA6ADC8),
                  splashRadius: 16,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  tooltip: 'Limpar',
                  onPressed: () {
                    _textController.clear();
                    ref
                        .read(remoteSearchControllerProvider.notifier)
                        .updateQuery('');
                  },
                ),
              const SizedBox(width: 4),
              _buildBadge('ESC', 'fechar'),
              const SizedBox(width: 6),
              _buildBadge('ENTER', 'ok'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String label, String hint) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF313244),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF45475A)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFBAC2DE),
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Visualização compacta (janela redimensionada para 620x110 quando o CMS estava em background).
class RemoteSearchCompactView extends StatelessWidget {
  const RemoteSearchCompactView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF181825),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580),
              child: const RemoteSearchInput(),
            ),
          ),
        ),
      ),
    );
  }
}

/// Visualização overlay flutuante (quando o CMS já estava visível na tela).
class RemoteSearchOverlayView extends ConsumerWidget {
  const RemoteSearchOverlayView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          ref.read(remoteSearchControllerProvider.notifier).close();
        },
        child: Container(
          color: Colors.black.withValues(alpha: 0.6),
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 100),
          child: GestureDetector(
            onTap: () {}, // Bloqueia cliques dentro do input de fecharem o overlay
            child: const SizedBox(
              width: 600,
              child: RemoteSearchInput(),
            ),
          ),
        ),
      ),
    );
  }
}
