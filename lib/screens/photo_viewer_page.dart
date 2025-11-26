import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import '../services/session_service.dart';
import '../models/photo_item.dart';

class PhotoViewerPage extends StatefulWidget {
  const PhotoViewerPage({
    super.key,
    required this.photos,
    required this.initialIndex,
  });

  final List<AssetEntity> photos;
  final int initialIndex;

  @override
  State<PhotoViewerPage> createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends State<PhotoViewerPage> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    
    // Share initial photo if host
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _shareCurrentPhoto();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _shareCurrentPhoto() {
    final sessionService = context.read<SessionService>();
    if (sessionService.session.isHost) {
      final asset = widget.photos[_currentIndex];
      final photoItem = PhotoItem(
        id: asset.id,
        localId: asset.id,
        width: asset.width,
        height: asset.height,
        createDateTime: asset.createDateTime,
        isLivePhoto: asset.isLivePhoto,
      );
      sessionService.selectPhoto(photoItem);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionService = context.watch<SessionService>();
    final isHost = sessionService.session.isHost;
    final isBufferActive = sessionService.isBufferActive;
    final showSharedConfirmation = sessionService.showSharedConfirmation;
    final remainingSeconds = sessionService.bufferSecondsRemaining;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('Photo ${_currentIndex + 1} / ${widget.photos.length}'),
        actions: [
          if (isHost)
             Padding(
               padding: const EdgeInsets.only(right: 16.0),
               child: Center(
                 child: Text(
                   'Peers: ${sessionService.session.peerIds.length}',
                   style: const TextStyle(color: Colors.white),
                 ),
               ),
             ),
        ],
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (i) {
              setState(() => _currentIndex = i);
              _shareCurrentPhoto();
            },
            itemCount: widget.photos.length,
            itemBuilder: (context, index) {
              return PhotoPageItem(asset: widget.photos[index]);
            },
          ),
          if (isHost && (isBufferActive || showSharedConfirmation))
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade900.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isBufferActive) ...[
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.orange.shade200,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'Sharing in ${remainingSeconds}s...',
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(width: 16),
                        TextButton(
                          onPressed: () => sessionService.cancelShare(),
                          child: const Text('Cancel'),
                        ),
                      ] else if (showSharedConfirmation) ...[
                        Icon(Icons.check_circle_rounded, color: Colors.green.shade300, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Shared',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class PhotoPageItem extends StatefulWidget {
  final AssetEntity asset;

  const PhotoPageItem({super.key, required this.asset});

  @override
  State<PhotoPageItem> createState() => _PhotoPageItemState();
}

class _PhotoPageItemState extends State<PhotoPageItem> {
  late Future<Uint8List?> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.asset.thumbnailDataWithSize(
      const ThumbnailSize.square(2000),
    );
  }

  @override
  void didUpdateWidget(covariant PhotoPageItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.id != widget.asset.id) {
      _future = widget.asset.thumbnailDataWithSize(
        const ThumbnailSize.square(2000),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }
        final bytes = snapshot.data;
        if (bytes == null || bytes.isEmpty) {
          return const Center(
            child: Text(
              '이미지를 불러올 수 없습니다',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }
        return InteractiveViewer(
          child: Center(child: Image.memory(bytes, fit: BoxFit.contain)),
        );
      },
    );
  }
}
