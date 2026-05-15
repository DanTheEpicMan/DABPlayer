import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import '../main.dart';
import '../audio/audio_handler.dart';
import '../theme.dart';
import '../utils/time_utils.dart';

/// Playback slider + time display + play/pause/skip buttons.
class PlaybackControls extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onSeekEnd;
  final Future<void> Function(Duration offset) onSeekRelative;
  final VoidCallback onPlayPause;

  const PlaybackControls({
    super.key,
    required this.isLoading,
    required this.onSeekRelative,
    required this.onPlayPause,
    this.onSeekEnd,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, miSnap) {
        final total = miSnap.data?.duration ?? Duration.zero;
        return StreamBuilder<PlaybackState>(
          stream: audioHandler.playbackState,
          builder: (context, psSnap) {
            final ps = psSnap.data;
            final pos = ps?.updatePosition ?? Duration.zero;
            final playing = ps?.playing ?? false;
            final buffering = ps?.processingState ==
                    AudioProcessingState.buffering ||
                ps?.processingState == AudioProcessingState.loading;

            return StreamBuilder<Duration>(
              stream: AudioService.position,
              builder: (context, posSnap) {
                final pos = posSnap.data ?? ps?.updatePosition ?? Duration.zero;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Time labels
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            formatDuration(pos, forceHours: total.inHours > 0),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            formatDuration(total, forceHours: total.inHours > 0),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    // Slider
                    Slider(
                      value: (total == Duration.zero ? 0.0 : pos.inMilliseconds.toDouble())
                          .clamp(0.0, total.inMilliseconds.toDouble().clamp(1, double.infinity)),
                      min: 0.0,
                      max: total == Duration.zero ? 1.0 : total.inMilliseconds.toDouble(),
                      onChanged: isLoading || total == Duration.zero
                          ? null
                          : (v) => audioHandler.seek(Duration(milliseconds: v.round())),
                      onChangeEnd: (_) => onSeekEnd?.call(),
                    ),
                    // Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.replay_30),
                          iconSize: 44,
                          onPressed: isLoading ? null : () => onSeekRelative(const Duration(seconds: -30)),
                          tooltip: 'Rewind 30s',
                        ),
                        if (buffering || isLoading)
                          const SizedBox(
                            width: 64,
                            height: 64,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else
                          IconButton(
                            icon: Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_filled),
                            iconSize: 64,
                            color: kPrimaryColor,
                            onPressed: onPlayPause,
                            tooltip: playing ? 'Pause' : 'Play',
                          ),
                        IconButton(
                          icon: const Icon(Icons.forward_30),
                          iconSize: 44,
                          onPressed: isLoading ? null : () => onSeekRelative(const Duration(seconds: 30)),
                          tooltip: 'Forward 30s',
                        ),
                      ],
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}
