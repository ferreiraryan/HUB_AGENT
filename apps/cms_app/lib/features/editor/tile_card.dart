import 'package:agent_core/agent_core.dart';
import 'package:cms_app/features/editor/emoji_picker.dart';
import 'package:flutter/material.dart';

class TileDragPayload {
  final String tileId;
  final String fromPage;

  const TileDragPayload({
    required this.tileId,
    required this.fromPage,
  });
}

class TileCard extends StatefulWidget {
  final Tile tile;
  final HubTheme theme;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final int index;
  final String? fromPage;

  const TileCard({
    super.key,
    required this.tile,
    required this.theme,
    this.selected = false,
    this.onTap,
    this.onDoubleTap,
    this.index = 0,
    this.fromPage,
  });

  @override
  State<TileCard> createState() => _TileCardState();
}

class _TileCardState extends State<TileCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _scale = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    _opacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeIn,
      ),
    );

    Future.delayed(
      Duration(milliseconds: widget.index * 25),
      () {
        if (mounted) {
          _controller.forward();
        }
      },
    );
  }

  @override
  void didUpdateWidget(covariant TileCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.tile.id != widget.tile.id) {
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildTileIcon(String? iconValue) {
    if (iconValue == null || iconValue.isEmpty) {
      return const Icon(Icons.widgets, size: 32, color: Colors.white);
    }

    // Verifica se a string é um nome válido de Material Symbol
    if (iconMap.containsKey(iconValue)) {
      return Icon(iconMap[iconValue], size: 32, color: Colors.white);
    }

    // Se não estiver no mapa, é um emoji antigo. Renderiza como texto.
    return Text(
      iconValue,
      style: const TextStyle(fontSize: 32),
    );
  }

  Widget _buildContent(Color accentColor) {
    if (widget.tile is SliderTile) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTileIcon(widget.tile.icon),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  widget.tile.label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 12,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(6),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: 0.5,
              child: Container(
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildTileIcon(widget.tile.icon),
        const SizedBox(height: 8),
        Text(
          widget.tile.label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white70,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildCard(Color bgColor, Color accentColor) {
    final content = _buildContent(accentColor);

    final card = Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: widget.selected
            ? Border.all(
                color: accentColor,
                width: 2,
              )
            : null,
      ),
      child: content,
    );

    // Se não existe interação, não adiciona GestureDetector/InkWell.
    if (widget.onTap == null && widget.onDoubleTap == null) {
      return card;
    }

    // Double tap precisa de GestureDetector.
    if (widget.onDoubleTap != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        child: card,
      );
    }

    // Quando existe somente onTap, usamos InkWell para manter o ripple.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: widget.onTap,
        child: card,
      ),
    );
  }

  Widget _buildDraggable(
    Widget cardUi,
  ) {
    // Auto-back não pode ser arrastado.
    if (widget.fromPage == null || widget.tile.id == '__auto_back__') {
      return cardUi;
    }

    return LongPressDraggable<TileDragPayload>(
      data: TileDragPayload(
        tileId: widget.tile.id,
        fromPage: widget.fromPage!,
      ),
      delay: const Duration(milliseconds: 600),
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.85,
          child: SizedBox(
            width: 120,
            height: 120,
            child: cardUi,
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.4,
        child: cardUi,
      ),
      child: cardUi,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = Color(widget.theme.cardColor);
    final accentColor = Color(widget.theme.accentColor);

    final cardUi = _buildCard(
      bgColor,
      accentColor,
    );

    return FadeTransition(
      opacity: _opacity,
      child: ScaleTransition(
        scale: _scale,
        child: _buildDraggable(cardUi),
      ),
    );
  }
}
