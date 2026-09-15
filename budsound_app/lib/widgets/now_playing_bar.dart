import 'package:flutter/material.dart';

import '../services/preview_player.dart';
import '../theme/app_colors.dart';

/// Mini reproductor anclado sobre la navegación inferior.
class NowPlayingBar extends StatelessWidget {
  const NowPlayingBar({super.key});

  @override
  Widget build(BuildContext context) {
    final player = PreviewPlayer.instance;

    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final pista = player.actual;
        if (pista == null) return const SizedBox.shrink();

        return Material(
          color: AppColors.surface,
          child: InkWell(
            onTap: () => player.toggle(pista),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      pista.artworkGrande,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(
                        width: 44,
                        height: 44,
                        child: Icon(Icons.album_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          pista.trackName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          pista.artistName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: player.reproduciendo ? 'Pausar' : 'Reproducir',
                    onPressed: () => player.toggle(pista),
                    icon: Icon(
                      player.reproduciendo
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: AppColors.neonBlue,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Detener',
                    onPressed: player.detener,
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
