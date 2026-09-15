import 'package:flutter/material.dart';

import '../models/itunes_track.dart';
import '../services/preview_player.dart';
import '../theme/app_colors.dart';

/// Fila de catálogo con preview de iTunes.
class TrackTile extends StatelessWidget {
  const TrackTile({super.key, required this.pista});

  final ItunesTrack pista;

  @override
  Widget build(BuildContext context) {
    final player = PreviewPlayer.instance;

    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final activa = player.esActual(pista);
        final playing = activa && player.reproduciendo;
        final tienePreview = pista.previewUrl != null;

        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: activa ? AppColors.neonBlue : AppColors.border,
            ),
          ),
          child: ListTile(
            onTap: tienePreview ? () => player.toggle(pista) : null,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                pista.artworkGrande,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(
                  width: 56,
                  height: 56,
                  child: Icon(Icons.album_rounded),
                ),
              ),
            ),
            title: Text(
              pista.trackName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              '${pista.artistName} · ${pista.genre}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.muted),
            ),
            trailing: Icon(
              !tienePreview
                  ? Icons.music_off_rounded
                  : playing
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_outline_rounded,
              color: tienePreview ? AppColors.neonBlue : AppColors.muted,
              size: 32,
            ),
          ),
        );
      },
    );
  }
}
