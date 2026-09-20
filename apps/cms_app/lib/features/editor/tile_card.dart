import 'package:agent_core/agent_core.dart';
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
    _scale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    Future.delayed(Duration(milliseconds: widget.index * 25), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void didUpdateWidget(covariant TileCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tile.id != widget.tile.id) {
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = Color(widget.theme.cardColor);
    final accentColor = Color(widget.theme.accentColor);

    Widget content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          widget.tile.icon,
          style: TextStyle(
            fontSize: 32,
            color: accentColor,
          ),
        ),
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

    Widget interactiveContent = content;

    if (widget.onTap != null || widget.onDoubleTap != null) {
      interactiveContent = GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: widget.onTap,
            child: content,
          ),
        ),
      );
    }

    Widget cardUi = Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border:
            widget.selected ? Border.all(color: accentColor, width: 2) : null,
      ),
      child: interactiveContent,
    );

    if (widget.fromPage == null || widget.tile.id == '__auto_back__') {
      return FadeTransition(
        opacity: _opacity,
        child: ScaleTransition(
          scale: _scale,
          child: cardUi,
        ),
      );
    }

    return FadeTransition(
      opacity: _opacity,
      child: ScaleTransition(
        scale: _scale,
        child: LongPressDraggable<TileDragPayload>(
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
        ),
      ),
    );
  }
}
