import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/constants/ui_constants.dart';
import '../data/service/platform_file_service.dart';

class AppFileTile extends StatelessWidget {
  const AppFileTile({
    required this.name,
    this.path,
    this.subtitle,
    this.status,
    this.progress,
    this.trailing,
    this.onTap,
    this.previewSize = 52,
    this.showDivider = false,
    super.key,
  });

  final String name;
  final String? path;
  final String? subtitle;
  final String? status;
  final double? progress;
  final Widget? trailing;
  final VoidCallback? onTap;
  final double previewSize;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final effectiveTap =
        onTap ??
        (path?.isNotEmpty == true
            ? () => PlatformFileService.openPath(path!)
            : null);

    final tile = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppFilePreview(name: name, path: path, size: previewSize),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                if (subtitle?.isNotEmpty == true) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (status?.isNotEmpty == true) ...[
                  const SizedBox(height: 2),
                  Text(
                    status!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _previewStyleFor(name).color,
                    ),
                  ),
                ],
                if (progress != null) ...[
                  const SizedBox(height: 10),
                  LinearProgressIndicator(
                    value: progress!.clamp(0, 1),
                    minHeight: 7,
                    borderRadius: BorderRadius.circular(999),
                    color: _previewStyleFor(name).color,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(
                  color: colors.outlineVariant.withValues(alpha: 0.6),
                ),
              )
            : null,
      ),
      child: effectiveTap == null
          ? tile
          : InkWell(
              onTap: effectiveTap,
              borderRadius: BorderRadius.circular(kBorderRadius),
              child: tile,
            ),
    );
  }
}

class AppFilePreview extends StatefulWidget {
  const AppFilePreview({
    required this.name,
    this.path,
    this.size = 52,
    super.key,
  });

  final String name;
  final String? path;
  final double size;

  @override
  State<AppFilePreview> createState() => _AppFilePreviewState();
}

class _AppFilePreviewState extends State<AppFilePreview> {
  Future<Uint8List?>? _thumbnailFuture;

  @override
  void initState() {
    super.initState();
    _thumbnailFuture = _loadThumbnail();
  }

  @override
  void didUpdateWidget(covariant AppFilePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path || oldWidget.name != widget.name) {
      _thumbnailFuture = _loadThumbnail();
    }
  }

  Future<Uint8List?> _loadThumbnail() async {
    if ((widget.path ?? '').isEmpty) return null;
    if (_isImage(widget.name)) return null;
    if (!_isVideo(widget.name)) return null;
    return PlatformFileService.fileThumbnail(widget.path!, maxSize: 180);
  }

  @override
  Widget build(BuildContext context) {
    final preview = _previewStyleFor(widget.name);
    final path = widget.path;
    final radius = BorderRadius.circular(kBorderRadius);

    Widget fallback() => Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: preview.color.withValues(alpha: 0.14),
        borderRadius: radius,
      ),
      alignment: Alignment.center,
      child: Icon(preview.icon, color: preview.color, size: widget.size * 0.42),
    );

    if (path?.isNotEmpty == true &&
        _isImage(widget.name) &&
        File(path!).existsSync()) {
      return ClipRRect(
        borderRadius: radius,
        child: Image.file(
          File(path),
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback(),
        ),
      );
    }

    if (_isVideo(widget.name) && path?.isNotEmpty == true) {
      return FutureBuilder<Uint8List?>(
        future: _thumbnailFuture,
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (bytes == null || bytes.isEmpty) return fallback();
          return ClipRRect(
            borderRadius: radius,
            child: Image.memory(
              bytes,
              width: widget.size,
              height: widget.size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback(),
            ),
          );
        },
      );
    }

    return fallback();
  }
}

class _PreviewStyle {
  const _PreviewStyle(this.icon, this.color);

  final IconData icon;
  final Color color;
}

_PreviewStyle _previewStyleFor(String name) {
  final extension = name.contains('.')
      ? name.split('.').last.toLowerCase()
      : '';
  if (_isImage(name)) {
    return const _PreviewStyle(Icons.image_rounded, Color(0xFF00A7A0));
  }
  if (_isVideo(name)) {
    return const _PreviewStyle(Icons.video_file_rounded, Color(0xFFFF8A3D));
  }
  if (const {
    'pdf',
    'doc',
    'docx',
    'txt',
    'rtf',
    'xls',
    'xlsx',
    'ppt',
    'pptx',
  }.contains(extension)) {
    return const _PreviewStyle(Icons.description_rounded, Color(0xFF5B6FF9));
  }
  if (extension == 'apk') {
    return const _PreviewStyle(Icons.android_rounded, Color(0xFF22B573));
  }
  if (const {'zip', 'rar', '7z'}.contains(extension)) {
    return const _PreviewStyle(Icons.folder_zip_rounded, Color(0xFFFFB020));
  }
  return const _PreviewStyle(
    Icons.insert_drive_file_rounded,
    Color(0xFF3478F6),
  );
}

bool _isImage(String name) {
  final extension = name.contains('.')
      ? name.split('.').last.toLowerCase()
      : '';
  return const {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
    'heic',
    'heif',
    'bmp',
  }.contains(extension);
}

bool _isVideo(String name) {
  final extension = name.contains('.')
      ? name.split('.').last.toLowerCase()
      : '';
  return const {
    'mp4',
    'mov',
    'mkv',
    'avi',
    'webm',
    '3gp',
    'm4v',
  }.contains(extension);
}
