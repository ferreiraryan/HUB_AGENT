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

  Widget _buildTileIcon(String? iconValue, {double size = 32}) {
    if (iconValue == null || iconValue.isEmpty) {
      return Icon(Icons.widgets, size: size, color: Colors.white);
    }

    // Verifica se a string é um nome válido de Material Symbol
    if (iconMap.containsKey(iconValue)) {
      return Icon(iconMap[iconValue], size: size, color: Colors.white);
    }

    // Se não estiver no mapa, é um emoji antigo. Renderiza como texto.
    return Text(
      iconValue,
      style: TextStyle(fontSize: size),
    );
  }

  Widget _buildContent(Color accentColor) {
    final tile = widget.tile;
    final is2x2 = tile.is2x2;
    final is2x1 = tile.is2x1;
    final is1x2 = tile.is1x2;

    if (tile is SliderTile) {
      if (is1x2) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildTileIcon(tile.icon, size: 24),
              const SizedBox(height: 2),
              Text(
                '50%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Container(
                  width: 14,
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.bottomCenter,
                    heightFactor: 0.5,
                    child: Container(
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                tile.label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      }

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _buildTileIcon(tile.icon, size: is2x2 ? 36 : 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tile.label,
                    style: TextStyle(
                      fontSize: is2x2 ? 14 : 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '50%',
                  style: TextStyle(
                    fontSize: is2x2 ? 14 : 12,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: is2x2 ? 12 : 6),
            Container(
              height: is2x2 ? 14 : 8,
              decoration: BoxDecoration(
                color: Colors.black45,
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
        ),
      );
    }

    if (tile is StatTile) {
      if (is1x2) {
        // Medidor vertical
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildTileIcon(tile.icon, size: 22),
              const SizedBox(height: 2),
              Text(
                tile.label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Container(
                  width: 14,
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.bottomCenter,
                    heightFactor: 0.42,
                    child: Container(
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '42${tile.source.unit}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
            ],
          ),
        );
      }

      if (is2x2) {
        // Card Pro 2x2
        final badgeLabel = tile.source.kind.toUpperCase();
        String detailText;
        switch (tile.source.kind) {
          case 'cpu':
            detailText = '52°C • 3.8 GHz';
            break;
          case 'ram':
            detailText = '6.8 GB / 16.0 GB';
            break;
          case 'disk':
            detailText = '210 GB / 512 GB';
            break;
          default:
            detailText = 'Estatística do Sistema';
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _buildTileIcon(tile.icon, size: 28),
                      const SizedBox(width: 8),
                      Text(
                        tile.label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(
                      badgeLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                '42${tile.source.unit}',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: accentColor,
                  height: 1.1,
                ),
              ),
              Text(
                detailText,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white60,
                  fontWeight: FontWeight.w500,
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: 0.42,
                  backgroundColor: Colors.black45,
                  valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                  minHeight: 8,
                ),
              ),
            ],
          ),
        );
      }

      if (is2x1) {
        // Horizontal 2x1
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _buildTileIcon(tile.icon, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        tile.label,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '42${tile.source.unit}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                    ),
                  ),
                ],
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: 0.42,
                  backgroundColor: Colors.black45,
                  valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        );
      }

      // Compacto 1x1
      return Padding(
        padding: const EdgeInsets.all(6),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTileIcon(tile.icon, size: 20),
                const SizedBox(height: 2),
                Text(
                  tile.label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white70,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '42${tile.source.unit}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 48,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: 0.42,
                      backgroundColor: Colors.black45,
                      valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                      minHeight: 4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Atalhos, sons, pastas e voltar
    final iconSize = is2x2 ? 48.0 : (is1x2 ? 38.0 : 32.0);
    final fontSize = is2x2 ? 15.0 : 12.0;

    return Padding(
      padding: const EdgeInsets.all(6.0),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTileIcon(tile.icon, size: iconSize),
              const SizedBox(height: 6),
              Text(
                tile.label,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: is2x2 ? FontWeight.w600 : FontWeight.normal,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
                maxLines: is2x2 ? 3 : 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
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
      child: Stack(
        children: [
          Center(child: content),
          if (widget.tile is SoundTile)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.deepPurpleAccent.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(Icons.music_note, size: 12, color: Colors.deepPurpleAccent),
              ),
            ),
        ],
      ),
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

    final feedbackW = widget.tile.width * 120.0 + (widget.tile.width - 1) * 16.0;
    final feedbackH = widget.tile.height * 120.0 + (widget.tile.height - 1) * 16.0;

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
            width: feedbackW,
            height: feedbackH,
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
