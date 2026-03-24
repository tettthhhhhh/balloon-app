import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../theme/app_theme.dart';

class VideoScreen extends StatefulWidget {
  const VideoScreen({super.key, required this.videoId, required this.title});

  final String videoId;
  final String title;

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  late final YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      autoPlay: false,
      params: const YoutubePlayerParams(showFullscreenButton: true),
    );
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppPalette.cyan.withValues(alpha: 0.12),
                ),
                color: Colors.white.withValues(alpha: 0.04),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: YoutubePlayer(controller: _controller),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Видео открыто внутри приложения, чтобы обучение и онбординг не выпадали из сценария заказа.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.64),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
