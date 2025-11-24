import 'package:equatable/equatable.dart';

class PhotoItem extends Equatable {
  final String id;
  final String? localId; // For PhotoManager
  final String? uri; // For display if available directly
  final int width;
  final int height;
  final bool isLivePhoto;
  final DateTime? createDateTime;

  const PhotoItem({
    required this.id,
    this.localId,
    this.uri,
    required this.width,
    required this.height,
    this.isLivePhoto = false,
    this.createDateTime,
  });

  @override
  List<Object?> get props => [id, localId, uri, width, height, isLivePhoto, createDateTime];
}
