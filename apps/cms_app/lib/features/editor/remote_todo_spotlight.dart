import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'remote_todo_controller.dart';

class RemoteTodoInput extends ConsumerStatefulWidget {
  const RemoteTodoInput({super.key});

  @override
  ConsumerState<RemoteTodoInput> createState() => _RemoteTodoInputState();
}

class _RemoteTodoInputState extends ConsumerState<RemoteTodoInput> {
  late final TextEditingController _textController;
  final FocusNode _focusNode = FocusNode();
  final FocusNode _keyboardFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  void _onClose() {
    ref.read(remoteTodoControllerProvider.notifier).close();
  }

  void _onSubmit() {
    ref.read(remoteTodoControllerProvider.notifier).submit(_textController.text);
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _keyboardFocusNode,
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
              color: const Color(0xFFA6E3A1), // Verde Catppuccin para Todo
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle_outline,
                color: Color(0xFFA6E3A1),
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
                    hintText: 'Digite a nova tarefa no teclado do PC...',
                    hintStyle: TextStyle(
                      color: Color(0xFFA6ADC8),
                      fontSize: 15,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                  onSubmitted: (_) => _onSubmit(),
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
                    setState(() {});
                  },
                ),
              const SizedBox(width: 4),
              _buildBadge('ESC', 'cancelar'),
              const SizedBox(width: 6),
              _buildBadge('ENTER', 'adicionar'),
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

/// Visualização compacta de adicionar tarefa (quando o CMS estava em background).
class RemoteTodoCompactView extends StatelessWidget {
  const RemoteTodoCompactView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF11111B),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(6),
          child: RemoteTodoInput(),
        ),
      ),
    );
  }
}

/// Visualização overlay flutuante (quando o CMS já estava visível).
class RemoteTodoOverlayView extends ConsumerWidget {
  const RemoteTodoOverlayView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          ref.read(remoteTodoControllerProvider.notifier).close();
        },
        child: Container(
          color: Colors.black.withValues(alpha: 0.6),
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 100),
          child: GestureDetector(
            onTap: () {}, // Evita fechar ao clicar dentro do card
            child: const SizedBox(
              width: 600,
              child: RemoteTodoInput(),
            ),
          ),
        ),
      ),
    );
  }
}

