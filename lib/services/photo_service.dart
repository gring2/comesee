import 'dart:typed_data';
import 'package:photo_manager/photo_manager.dart';
import '../models/photo_item.dart';

class PhotoService {
  Future<bool> requestPermission() async {
    final PermissionState permission = await PhotoManager.requestPermissionExtend();
    return permission == PermissionState.authorized || permission == PermissionState.limited;
  }

  Future<List<PhotoItem>> fetchPhotos({int page = 0, int size = 200}) async {
    final filteredPaths = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
      filterOption: FilterOptionGroup(
        orders: [
          const OrderOption(type: OrderOptionType.createDate, asc: false),
        ],
      ),
    );

    if (filteredPaths.isEmpty) return [];

    final AssetPathEntity allPhotosPath = filteredPaths.first;
    final assetList = await allPhotosPath.getAssetListPaged(page: page, size: size);

    final imagesOnly = assetList.where((asset) {
      if (asset.type != AssetType.image) return false;
      final mime = asset.mimeType ?? '';
      if (mime.startsWith('video/')) return false;
      if (mime.isEmpty) return true;
      return mime.startsWith('image/');
    }).map((asset) => PhotoItem(
      id: asset.id,
      localId: asset.id,
      width: asset.width,
      height: asset.height,
      createDateTime: asset.createDateTime,
      isLivePhoto: asset.isLivePhoto,
    )).toList();

    return imagesOnly;
  }

  Future<Uint8List?> getThumbnail(String id, {int width = 360, int height = 360}) async {
    final asset = await AssetEntity.fromId(id);
    return asset?.thumbnailDataWithSize(ThumbnailSize(width, height));
  }

  Future<Uint8List?> getFullImage(String id) async {
    final asset = await AssetEntity.fromId(id);
    // Use originBytes for full quality, or thumbnailDataWithSize with large size
    return asset?.originBytes;
  }
}
