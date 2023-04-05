import 'dart:async';

import '../../../../drishya_picker/drishya_picker.dart';
import '../../../../drishya_picker/src/animations/animations.dart';
// import 'package:drishya_picker/src/camera/src/widgets/ui_handler.dart';
import '../../../../drishya_picker/src/gallery/src/repo/gallery_repository.dart';
import '../../../../drishya_picker/src/gallery/src/widgets/albums_page.dart';
import '../../../../drishya_picker/src/gallery/src/widgets/gallery_asset_selector.dart';
import '../../../../drishya_picker/src/gallery/src/widgets/gallery_grid_view.dart';
import '../../../../drishya_picker/src/gallery/src/widgets/send_button.dart';
import '../../../../drishya_picker/src/gallery/src/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

///
///
class GalleryView extends StatefulWidget {
  ///
  const GalleryView({
    Key? key,
    this.controller,
    this.setting,
    this.onpress,
  }) : super(key: key);

  /// Gallery controller
  final GalleryController? controller;

  /// Gallery setting
  final GallerySetting? setting;

  ///
  static const String name = 'GalleryView';
  final void Function(String?)? onpress;

  ///
  /// Pick media
  static Future<List<DrishyaEntity>?> pick(
    BuildContext context, {

    /// Gallery controller
    GalleryController? controller,

    /// Gallery setting
    GallerySetting? setting,

    /// Route setting
    CustomRouteSetting? routeSetting,
  }) {
    return Navigator.of(context).push<List<DrishyaEntity>>(
      SlideTransitionPageRoute(
        builder: GalleryView(controller: controller, setting: setting),
        setting: routeSetting ??
            const CustomRouteSetting(
              settings: RouteSettings(name: name),
            ),
      ),
    );
  }

  @override
  State<GalleryView> createState() => _GalleryViewState();
}

class _GalleryViewState extends State<GalleryView> {
  late final GalleryController _controller;

  @override
  void initState() {
    super.initState();
    if (VideoplayerValue.videoPlayerPath != null) {
      VideoplayerValue.videoPlayerController =
          VideoPlayerController.file(VideoplayerValue.videoPlayerPath!);
    }
    _controller = widget.controller ?? GalleryController();
  }

  @override
  void dispose() {
    if (widget.controller == null || _controller.autoDispose) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If [SlidableGallery] is used no need to build panel setting again
    if (!_controller.fullScreenMode) {
      return _View(
        controller: _controller,
        setting: widget.setting!,
        onpress: widget.onpress!,
      );
    }

    // Full screen mode
    return PanelSettingBuilder(
      setting: widget.setting?.panelSetting,
      builder: (panelSetting) => _View(
        controller: _controller,
        onpress: widget.onpress!,
        setting: (widget.setting ?? _controller.setting)
            .copyWith(panelSetting: panelSetting),
      ),
    );

    //
  }
}

///
class _View extends StatefulWidget {
  ///
  const _View({
    Key? key,
    required this.controller,
    required this.setting,
    required this.onpress,
  }) : super(key: key);

  final GalleryController controller;
  final GallerySetting setting;
  final void Function(String?) onpress;

  @override
  State<_View> createState() => _ViewState();
}

class _ViewState extends State<_View> with SingleTickerProviderStateMixin {
  late final GalleryController _controller;
  late final PanelController _panelController;

  late final AnimationController _animationController;
  late final Animation<double> _animation;
  late final Albums _albums;

  double albumHeight = 0;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller..init(setting: widget.setting);
    _albums = Albums()..fetchAlbums(_controller.setting.requestType);

    _panelController = _controller.panelController;
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
      reverseDuration: const Duration(milliseconds: 300),
      value: 0,
    );

    // ignore: prefer_int_literals
    _animation = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.fastLinearToSlowEaseIn,
        reverseCurve: Curves.easeOut,
      ),
    );
  }

  @override
  void dispose() {
    _albums.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _toogleAlbumList(bool isVisible) {
    if (_animationController.isAnimating) return;
    _controller.setAlbumVisibility(visible: !isVisible);
    _panelController.isGestureEnabled = _animationController.value == 1.0;
    if (_animationController.value == 1.0) {
      _animationController.reverse();
    } else {
      _animationController.forward();
    }
  }

  //
  void _showAlert() {
    final cancel = TextButton(
      onPressed: Navigator.of(context).pop,
      child: Text(
        'CANCEL',
        style: Theme.of(context).textTheme.button!.copyWith(
              color: Colors.lightBlue,
            ),
      ),
    );
    final unselectItems = TextButton(
      onPressed: _onSelectionClear,
      child: Text(
        'USELECT ITEMS',
        style: Theme.of(context).textTheme.button!.copyWith(
              color: Colors.blue,
            ),
      ),
    );

    final alertDialog = AlertDialog(
      title: Text(
        'Unselect these items?',
        style: Theme.of(context).textTheme.headline6!.copyWith(
              color: Colors.white70,
            ),
      ),
      content: Text(
        'Going back will undo the selections you made.',
        style: Theme.of(context).textTheme.bodyText2!.copyWith(
              color: Colors.grey.shade600,
            ),
      ),
      actions: [cancel, unselectItems],
      backgroundColor: Colors.grey.shade900,
      titlePadding: const EdgeInsets.all(16),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 2,
      ),
    );

    showDialog<void>(
      context: context,
      builder: (context) => alertDialog,
    );
  }

  Future<bool> _onClosePressed() async {
    if (_animationController.isAnimating) return false;

    if (_controller.albumVisibility.value) {
      _toogleAlbumList(true);
      return false;
    }

    if (_controller.value.selectedEntities.isNotEmpty) {
      _showAlert();
      return false;
    }

    if (_controller.fullScreenMode) {
      // UIHandler.of(context).pop();
      return true;
    }

    if (_panelController.isVisible) {
      if (_panelController.value.state == PanelState.max) {
        _panelController.minimizePanel();
      } else {
        _panelController.closePanel();
      }
      return false;
    }

    return true;
  }

  void _onSelectionClear() {
    _controller.clearSelection();
    Navigator.of(context).pop();
  }

  void _onAlbumChange(Album album) {
    if (_animationController.isAnimating) return;
    _albums.changeAlbum(album);
    _toogleAlbumList(true);
  }

  @override
  Widget build(BuildContext context) {
    final panelSetting = widget.setting.panelSetting!;
    final actionMode =
        _controller.setting.selectionMode == SelectionMode.actionBased;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: panelSetting.overlayStyle,
      child: SafeArea(
        child: WillPopScope(
          onWillPop: _onClosePressed,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Stack(
              fit: StackFit.expand,
              children: [
                // Header
                // Align(
                //   alignment: Alignment.topCenter,
                //   child: GalleryHeader(
                //     controller: _controller,
                //     albums: _albums,
                //     onClose: _onClosePressed,
                //     onAlbumToggle: _toogleAlbumList,
                //   ),
                // ),

                // Body
                Column(
                  children: [
                    // Header space
                    Builder(
                      builder: (context) {
                        // Header space for full screen mode
                        // if (_controller.fullScreenMode) {
                        //   return SizedBox(height: panelSetting.headerMaxHeight);
                        // }

                        // Toogling size for header hiding animation
                        return ValueListenableBuilder<PanelValue>(
                          valueListenable: _panelController,
                          builder: (context, value, child) {
                            final height = (panelSetting.headerMaxHeight *
                                    value.factor *
                                    1.2)
                                .clamp(
                              panelSetting.thumbHandlerHeight,
                              panelSetting.headerMaxHeight,
                            );
                            return SizedBox(height: height);
                          },
                        );
                        //
                      },
                    ),

                    // Divider
                    // Divider(
                    //   color: Colors.lightBlue.shade300,
                    //   thickness: 0.5,
                    //   height: 0.5,
                    //   indent: 0,
                    //   endIndent: 0,
                    // ),

                    // Gallery grid
                    Expanded(
                      flex: 65,
                      child: StreamBuilder<dynamic>(
                        stream: VideoplayerValue.videoControllerStream,
                        builder: (context, snapshot) {
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 10),
                            decoration: const BoxDecoration(),
                            child: VideoplayerValue.videoPlayerController !=
                                        null &&
                                    VideoplayerValue.videoPlayerController!
                                        .value.isInitialized
                                ? Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(15),
                                        child: AspectRatio(
                                          aspectRatio: VideoplayerValue
                                              .videoPlayerController!
                                              .value
                                              .aspectRatio,
                                          child: GestureDetector(
                                            onTap: () {
                                              // If the video is playing, pause it.
                                              if (VideoplayerValue
                                                  .videoPlayerController!
                                                  .value
                                                  .isPlaying) {
                                                VideoplayerValue
                                                    .videoPlayerController!
                                                    .pause();
                                              } else {
                                                // If the video is paused, play it.
                                                VideoplayerValue
                                                    .videoPlayerController!
                                                    .play();
                                              }
                                              VideoplayerValue.videosink
                                                  .add('');
                                            },
                                            child: VideoPlayer(
                                              VideoplayerValue
                                                  .videoPlayerController!,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 5,
                                        right: 5,
                                        child: ElevatedButton(
                                          style: ButtonStyle(
                                            backgroundColor:
                                                MaterialStateProperty.all(
                                              Colors.white.withOpacity(0.5),
                                            ),
                                          ),
                                          onPressed: () {
                                            widget.onpress(
                                              VideoplayerValue.videoPlayerPath!
                                                  .toString(),
                                            );
                                          },
                                          child: const Text(
                                            ' Next ',
                                            style: TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : ClipRRect(
                                    borderRadius: BorderRadius.circular(15),
                                    child: const Center(
                                      child: Text(
                                        'Please select a video',
                                        style: TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                          );
                        },
                      ),
                    ),
                    Expanded(
                      flex: 45,
                      child: GalleryGridView(
                        controller: _controller,
                        albums: _albums,
                        onClosePressed: _onClosePressed,
                      ),
                    ),
                  ],
                ),

                // Send and edit button
                if (!actionMode)
                  GalleryAssetSelector(
                    controller: _controller,
                    albums: _albums,
                  ),

                // Send button
                if (actionMode)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: SendButton(controller: _controller),
                  ),

                // Album list
                AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    final offsetY = panelSetting.headerMaxHeight +
                        (panelSetting.maxHeight! -
                                panelSetting.headerMaxHeight) *
                            (1 - _animation.value);
                    return Visibility(
                      visible: _animation.value > 0.0,
                      child: Transform.translate(
                        offset: Offset(0, offsetY),
                        child: child,
                      ),
                    );
                  },
                  child: AlbumsPage(
                    albums: _albums,
                    controller: _controller,
                    onAlbumChange: _onAlbumChange,
                  ),
                ),
                //
              ],
            ),
          ),
        ),
      ),
    );

    //
  }
}
