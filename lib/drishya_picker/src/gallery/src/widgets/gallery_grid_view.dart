import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../../drishya_picker/drishya_picker.dart';
import '../../../../../drishya_picker/src/gallery/src/repo/gallery_repository.dart';
import '../../../../../drishya_picker/src/gallery/src/widgets/album_builder.dart';
import '../../../../../drishya_picker/src/gallery/src/widgets/gallery_builder.dart';
import '../../../../../drishya_picker/src/gallery/src/widgets/gallery_permission_view.dart';
import '../../../../../drishya_picker/src/gallery/src/widgets/lazy_load_scroll_view.dart';

///
class GalleryGridView extends StatelessWidget {
  ///
  const GalleryGridView({
    Key? key,
    required this.controller,
    required this.albums,
    required this.onClosePressed,
    required this.onpress,
  }) : super(key: key);

  ///
  final GalleryController controller;

  final void Function(File?) onpress;

  ///
  final Albums albums;

  ///
  final VoidCallback? onClosePressed;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      // color: controller.panelSetting.foregroundColor,
      color: Colors.transparent,
      child: CurrentAlbumBuilder(
        albums: albums,
        builder: (BuildContext context, Album album, Widget? child) {
          return ValueListenableBuilder<AlbumValue>(
            valueListenable: album,
            builder: (BuildContext context, AlbumValue value, Widget? child) {
              // Error
              if (value.state == BaseState.unauthorised &&
                  value.entities.isEmpty) {
                return GalleryPermissionView(
                  onRefresh: () {
                    if (value.assetPathEntity == null) {
                      albums.fetchAlbums(controller.setting.requestType);
                    } else {
                      album.fetchAssets();
                    }
                  },
                );
              }

              // No data
              if (value.state == BaseState.completed &&
                  value.entities.isEmpty) {
                return const Center(
                  child: Text(
                    'No media available',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }

              if (value.state == BaseState.error) {
                return const Center(
                  child: Text(
                    'Something went wrong. Please try again!',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }

              final List<AssetEntity> entities = value.entities;
              // final enableCamera = controller.setting.enableCamera;

              final int itemCount = albums.value.state == BaseState.fetching
                  ? 20
                  : entities.length;

              return LazyLoadScrollView(
                onEndOfPage: album.fetchAssets,
                scrollOffset: MediaQuery.of(context).size.height * 0.4,
                child: GridView.builder(
                  controller: controller.panelController.scrollController,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: controller.setting.crossAxisCount ?? 3,
                    crossAxisSpacing: 3,
                    mainAxisSpacing: 3,
                  ),
                  itemCount: itemCount,
                  padding: EdgeInsets.zero,
                  itemBuilder: (BuildContext context, int index) {
                    // if (enableCamera && index == 0) {
                    //   return InkWell(
                    //     onTap: () {
                    //       // controller.openCamera(context).then((value) {
                    //       //   if (value != null) {
                    //       //     album.insert(value);
                    //       //   }
                    //       // },);
                    //     },
                    //     child: Icon(
                    //       CupertinoIcons.camera,
                    //       color: Colors.lightBlue.shade300,
                    //       size: 26,
                    //     ),
                    //   );
                    // }

                    final int ind = index;

                    final AssetEntity? entity =
                        albums.value.state == BaseState.fetching
                            ? null
                            : entities[ind];

                    if (entity == null) return const SizedBox();

                    return _MediaTile(
                      controller: controller,
                      entity: entity,
                      onpress: onpress,
                    );
                  },
                ),
              );
            },
          );

          //
        },
      ),
    );
  }
}

///
class _MediaTile extends StatelessWidget {
  ///
  const _MediaTile({
    Key? key,
    required this.entity,
    required this.controller,
    required this.onpress,
  }) : super(key: key);

  ///
  final GalleryController controller;

  final void Function(File?) onpress;

  ///
  final AssetEntity entity;

  @override
  Widget build(BuildContext context) {
    Uint8List? bytes;

    final PanelController panelController = PanelController();

    final DrishyaEntity drishya = entity.toDrishya;

    return ColoredBox(
      color: Colors.grey.shade800,
      child: InkWell(
        onTap: () async {
          final DrishyaEntity entity = drishya.copyWith(pickedThumbData: bytes);
          VideoplayerValue.videoPlayerPath = await entity.file;
          if (controller.setting.requestType == RequestType.video) {
            try {
              if (VideoplayerValue.videoPlayerController != null) {
                VideoplayerValue.videoPlayerController = null;
              }
              VideoplayerValue.videoPlayerController =
                  VideoPlayerController.file(VideoplayerValue.videoPlayerPath!);
              await VideoplayerValue.videoPlayerController!
                  .initialize()
                  .then((_) {
                VideoplayerValue.videoPlayerController!.play();
                VideoplayerValue.videosink.add('');
              });
            } on Exception {
              VideoplayerValue.errorMessage = "Can't play Video";
              VideoplayerValue.videosink.add('');
            }
          } else if (controller.setting.requestType == RequestType.image) {
            onpress(VideoplayerValue.videoPlayerPath);
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            EntityThumbnail(
              entity: drishya,
              onBytesGenerated: (Uint8List? b) {
                bytes = b;
              },
            ),
            _SelectionCount(controller: controller, entity: entity),
          ],
        ),
      ),
    );
  }
}

class _SelectionCount extends StatelessWidget {
  const _SelectionCount({
    Key? key,
    required this.controller,
    required this.entity,
  }) : super(key: key);

  final GalleryController controller;
  final AssetEntity entity;

  @override
  Widget build(BuildContext context) {
    return GalleryBuilder(
      controller: controller,
      builder: (GalleryValue value, Widget? child) {
        final bool actionBased =
            controller.setting.selectionMode == SelectionMode.actionBased;

        final bool singleSelection = actionBased
            ? !value.enableMultiSelection
            : controller.singleSelection;

        final bool isSelected = value.selectedEntities.contains(entity);
        final int index = value.selectedEntities.indexOf(entity.toDrishya);

        Widget counter = const SizedBox();

        if (isSelected) {
          counter = CircleAvatar(
            backgroundColor: Theme.of(context).primaryColor,
            radius: 14,
            child: Text(
              '${index + 1}',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
            ),
          );
        }

        if (actionBased && !singleSelection) {
          counter = Container(
            height: 30,
            width: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: isSelected ? counter : const SizedBox(),
          );
        }

        return Container(
          color: isSelected ? Colors.white38 : Colors.transparent,
          padding: const EdgeInsets.all(6),
          child: Align(
            alignment: actionBased ? Alignment.topRight : Alignment.center,
            child: counter,
          ),
        );
      },
    );
  }
}

// ignore: avoid_classes_with_only_static_members
class VideoplayerValue {
  static StreamController videostream = StreamController<dynamic>.broadcast();
  static StreamSink get videosink => videostream.sink;
  static Stream get videoControllerStream => videostream.stream;
  static VideoPlayerController? videoPlayerController;
  static String? errorMessage;
  static File? videoPlayerPath;

  static void dispose() {
    videostream.close();
    // videoPlayerController?.dispose();
    errorMessage = '';
    videoPlayerPath = null;
  }
}
