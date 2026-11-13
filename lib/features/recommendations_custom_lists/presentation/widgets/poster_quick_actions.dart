import 'package:flutter/material.dart';

import '../../../../core/favorites/favorite_ids_store.dart';
import 'add_to_list_sheet.dart';

/// Overlay for any poster: a heart when the movie is a favorite (top right)
/// and a "+" button to add it to a list (bottom right).
/// Place it as the last child of the poster's [Stack].
class PosterQuickActions extends StatelessWidget {
  const PosterQuickActions({
    required this.movieId,
    super.key,
    this.compact = false,
    this.heartOnLeft = false,
  });

  final int movieId;

  /// Smaller icons for small thumbnails.
  final bool compact;

  /// Puts the heart top left when the top right corner is already used.
  final bool heartOnLeft;

  @override
  Widget build(BuildContext context) {
    final store = FavoriteIdsStore.instance;
    return Positioned.fill(
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) => Stack(
          children: [
            if (store.contains(movieId))
              Positioned(
                top: 6,
                right: heartOnLeft ? null : 6,
                left: heartOnLeft ? 6 : null,
                child: FavoriteHeartBadge(size: compact ? 14 : 18),
              ),
            Positioned(
              right: 6,
              bottom: 6,
              child: AddToListCircleButton(
                movieId: movieId,
                size: compact ? 26 : 32,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FavoriteHeartBadge extends StatelessWidget {
  const FavoriteHeartBadge({super.key, this.size = 18});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'In your favorites',
      child: Container(
        padding: EdgeInsets.all(size * 0.28),
        decoration: const BoxDecoration(
          color: Color(0xCC101014),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.favorite_rounded,
          size: size,
          color: const Color(0xFFFF4D6D),
        ),
      ),
    );
  }
}

/// Round "+" button opening the add-to-list sheet for [movieId].
class AddToListCircleButton extends StatefulWidget {
  const AddToListCircleButton({
    required this.movieId,
    super.key,
    this.size = 32,
  });

  final int movieId;
  final double size;

  @override
  State<AddToListCircleButton> createState() => _AddToListCircleButtonState();
}

class _AddToListCircleButtonState extends State<AddToListCircleButton> {
  bool _loading = false;

  Future<void> _open() async {
    setState(() => _loading = true);
    await showAddToListSheetForId(context, widget.movieId);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return Tooltip(
      message: 'Add to a list',
      child: Material(
        color: Colors.black.withValues(alpha: 0.72),
        shape: CircleBorder(
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.85),
            width: 1.5,
          ),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _loading ? null : _open,
          child: SizedBox.square(
            dimension: size,
            child: _loading
                ? Padding(
                    padding: EdgeInsets.all(size * 0.25),
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    Icons.add_rounded,
                    size: size * 0.66,
                    color: Colors.white,
                  ),
          ),
        ),
      ),
    );
  }
}
