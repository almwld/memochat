import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MediaViewer extends StatefulWidget {
  final String mediaUrl;
  final String mediaType;
  final List<String>? mediaList;

  const MediaViewer({
    super.key,
    required this.mediaUrl,
    required this.mediaType,
    this.mediaList,
  });

  @override
  State<MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<MediaViewer> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    if (widget.mediaList != null && widget.mediaList!.isNotEmpty) {
      _currentIndex = widget.mediaList!.indexOf(widget.mediaUrl);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: widget.mediaType == 'image'
            ? const Text('صورة', style: TextStyle(color: Colors.white))
            : const Text('وسائط', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            onPressed: () {
              // تنزيل الصورة
            },
          ),
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () {
              // مشاركة الصورة
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          if (widget.mediaList != null && widget.mediaList!.length > 1)
            PhotoViewGallery.builder(
              pageController: _pageController,
              itemCount: widget.mediaList!.length,
              builder: (context, index) {
                return PhotoViewGalleryPageOptions(
                  imageProvider: CachedNetworkImageProvider(
                    widget.mediaList![index],
                  ),
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 2,
                );
              },
              scrollPhysics: const BouncingScrollPhysics(),
              backgroundDecoration: const BoxDecoration(
                color: Colors.black,
              ),
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
              },
            )
          else
            Center(
              child: PhotoView(
                imageProvider: CachedNetworkImageProvider(widget.mediaUrl),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 2,
                backgroundDecoration: const BoxDecoration(
                  color: Colors.black,
                ),
              ),
            ),
          if (widget.mediaList != null && widget.mediaList!.length > 1)
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${widget.mediaList!.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
