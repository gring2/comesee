import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Offline Photo Share',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const PhotoAccessPage(),
    );
  }
}

enum PhotosPermissionStatus { loading, granted, limited, denied }

class PhotoAccessPage extends StatefulWidget {
  const PhotoAccessPage({super.key});

  @override
  State<PhotoAccessPage> createState() => _PhotoAccessPageState();
}

class _PhotoAccessPageState extends State<PhotoAccessPage> {
  PhotosPermissionStatus _status = PhotosPermissionStatus.loading;
  List<AssetEntity> _photos = const [];
  bool _isFetching = false;

  @override
  void initState() {
    super.initState();
    _checkAndLoad();
  }

  Future<void> _checkAndLoad() async {
    setState(() => _status = PhotosPermissionStatus.loading);

    final PermissionState permission =
        await PhotoManager.requestPermissionExtend();

    if (!mounted) return;

    final isDenied =
        permission == PermissionState.denied ||
        permission == PermissionState.restricted;
    final isLimited = permission == PermissionState.limited;
    final isGranted = permission == PermissionState.authorized;

    if (isDenied) {
      setState(() {
        _status = PhotosPermissionStatus.denied;
        _photos = const [];
      });
      return;
    }

    if (isGranted || isLimited) {
      _status = isLimited
          ? PhotosPermissionStatus.limited
          : PhotosPermissionStatus.granted;
      await _fetchPhotos();
    }
  }

  Future<void> _fetchPhotos() async {
    setState(() {
      _isFetching = true;
      _photos = const [];
    });

    final filteredPaths = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
      filterOption: FilterOptionGroup(
        orders: [
          const OrderOption(type: OrderOptionType.createDate, asc: false),
        ],
      ),
    );

    if (!mounted) return;
    if (filteredPaths.isEmpty) {
      setState(() {
        _isFetching = false;
        _photos = const [];
      });
      return;
    }

    final AssetPathEntity allPhotosPath = filteredPaths.first;
    final assetList = await allPhotosPath.getAssetListPaged(page: 0, size: 200);

    final imagesOnly = assetList.where((asset) {
      if (asset.type != AssetType.image) return false;
      final mime = asset.mimeType ?? '';
      if (mime.startsWith('video/')) return false;
      // Treat Live Photos as stills by accepting only image/* mimetype; allow unknowns that are tagged as image.
      if (mime.isEmpty) return true;
      return mime.startsWith('image/');
    }).toList();

    if (!mounted) return;
    setState(() {
      _photos = imagesOnly;
      _isFetching = false;
    });
  }

  Widget _buildPermissionCard({
    required String title,
    required String message,
    required List<Widget> actions,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: actions,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGrid() {
    if (_isFetching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_photos.isEmpty) {
      return _buildPermissionCard(
        title: '사진을 찾을 수 없습니다',
        message: '사진만 표시합니다. 비디오/Live Photo는 제외됩니다.',
        actions: [
          FilledButton.icon(
            onPressed: _fetchPhotos,
            icon: const Icon(Icons.refresh),
            label: const Text('다시 불러오기'),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchPhotos,
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
        ),
        itemCount: _photos.length,
        itemBuilder: (context, index) {
          final asset = _photos[index];
          return GestureDetector(
            onTap: () => _openViewer(index),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  FutureBuilder<Uint8List?>(
                    future: asset.thumbnailDataWithSize(
                      const ThumbnailSize(360, 360),
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const ColoredBox(
                          color: Color(0x11000000),
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 1.5),
                          ),
                        );
                      }
                      final bytes = snapshot.data;
                      if (bytes == null || bytes.isEmpty) {
                        return const ColoredBox(color: Colors.black12);
                      }
                      return Image.memory(bytes, fit: BoxFit.cover);
                    },
                  ),
                  if (asset.isFavorite)
                    const Positioned(
                      right: 4,
                      top: 4,
                      child: Icon(
                        Icons.favorite,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openViewer(int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PhotoViewerPage(photos: _photos, initialIndex: index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showLimitedNotice = _status == PhotosPermissionStatus.limited;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Photo Share'),
        actions: [
          IconButton(
            onPressed: _checkAndLoad,
            icon: const Icon(Icons.refresh),
            tooltip: '권한/목록 새로고침',
          ),
        ],
      ),
      body: SafeArea(
        child: switch (_status) {
          PhotosPermissionStatus.loading => const Center(
            child: CircularProgressIndicator(),
          ),
          PhotosPermissionStatus.denied => _buildPermissionCard(
            title: '사진 접근 권한이 필요합니다',
            message: '사진만 읽기 전용으로 사용합니다. 비디오는 접근/사용하지 않습니다.',
            actions: [
              FilledButton(
                onPressed: _checkAndLoad,
                child: const Text('권한 요청'),
              ),
              OutlinedButton(
                onPressed: () => PhotoManager.openSetting(),
                child: const Text('설정 열기'),
              ),
            ],
          ),
          PhotosPermissionStatus.granted ||
          PhotosPermissionStatus.limited => Column(
            children: [
              if (showLimitedNotice)
                MaterialBanner(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  content: const Text(
                    '선택한 사진만 접근 중입니다. 더 많은 사진을 공유하려면 “사진 선택 관리”를 눌러 주세요.',
                  ),
                  leading: const Icon(Icons.info_outline),
                  actions: [
                    TextButton(
                      onPressed: () => PhotoManager.presentLimited(),
                      child: const Text('사진 선택 관리'),
                    ),
                  ],
                ),
              Expanded(child: _buildGrid()),
            ],
          ),
        },
      ),
    );
  }
}

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
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('Photo ${_currentIndex + 1} / ${widget.photos.length}'),
      ),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        itemCount: widget.photos.length,
        itemBuilder: (context, index) {
          final asset = widget.photos[index];
          return FutureBuilder<Uint8List?>(
            future: asset.thumbnailDataWithSize(
              const ThumbnailSize.square(2000),
            ),
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
        },
      ),
    );
  }
}
