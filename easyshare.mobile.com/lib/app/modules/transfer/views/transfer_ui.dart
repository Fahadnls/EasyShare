import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../widgets/app_file_tile.dart';

class TransferProgressItem {
  const TransferProgressItem({
    required this.name,
    required this.size,
    required this.transferred,
    required this.progress,
    required this.status,
    this.path,
  });

  final String name;
  final int size;
  final int transferred;
  final double progress;
  final String status;
  final String? path;
}

class TransferHeader extends StatelessWidget {
  const TransferHeader({
    required this.title,
    required this.subtitle,
    this.trailing,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          onPressed: Get.back,
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class RadarView extends StatefulWidget {
  const RadarView({
    this.active = true,
    this.centerIcon,
    this.color,
    this.dimension = 220,
    super.key,
  });

  final bool active;
  final IconData? centerIcon;
  final Color? color;
  final double dimension;

  @override
  State<RadarView> createState() => _RadarViewState();
}

class _RadarViewState extends State<RadarView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant RadarView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.active != oldWidget.active) {
      widget.active ? _controller.repeat() : _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final radarColor = widget.color ?? colors.primary;

    return SizedBox.square(
      dimension: widget.dimension,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _RadarPainter(
              color: radarColor,
              angle: _controller.value * math.pi * 2,
              progress: _controller.value,
              active: widget.active,
            ),
            child: child,
          );
        },
        child: Center(
          child: Container(
            width: widget.dimension * 0.27,
            height: widget.dimension * 0.27,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  radarColor.withValues(alpha: 0.95),
                  radarColor.withValues(alpha: 0.72),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: radarColor.withValues(alpha: 0.35),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Icon(
              widget.centerIcon ?? Icons.wifi_tethering_rounded,
              color: colors.onPrimary,
              size: widget.dimension * 0.13,
            ),
          ),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  const _RadarPainter({
    required this.color,
    required this.angle,
    required this.progress,
    required this.active,
  });

  final Color color;
  final double angle;
  final double progress;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;

    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.045)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius * 0.96, bgPaint);

    final ringPaint = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final softRingPaint = Paint()
      ..color = color.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;

    for (final scale in [0.32, 0.56, 0.80, 0.96]) {
      canvas.drawCircle(center, radius * scale, softRingPaint);
      canvas.drawCircle(center, radius * scale, ringPaint);
    }

    if (!active) return;

    final pulseScale = 0.32 + (progress * 0.64);
    final pulsePaint = Paint()
      ..color = color.withValues(alpha: (1 - progress) * 0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawCircle(center, radius * pulseScale, pulsePaint);

    final sweepRect = Rect.fromCircle(center: center, radius: radius * 0.96);

    final sweepPaint = Paint()
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: math.pi * 2,
        colors: [
          color.withValues(alpha: 0.0),
          color.withValues(alpha: 0.05),
          color.withValues(alpha: 0.24),
          color.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.55, 0.85, 1.0],
        transform: GradientRotation(angle),
      ).createShader(sweepRect);

    canvas.drawCircle(center, radius * 0.94, sweepPaint);

    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final lineEnd = Offset(
      center.dx + math.cos(angle) * radius * 0.88,
      center.dy + math.sin(angle) * radius * 0.88,
    );

    canvas.drawLine(center, lineEnd, linePaint);

    final dotPaint = Paint()
      ..color = color.withValues(alpha: 0.95)
      ..style = PaintingStyle.fill;

    final dots = [
      _radarPoint(center, radius, 0.48, angle + 0.9),
      _radarPoint(center, radius, 0.70, angle + 2.1),
      _radarPoint(center, radius, 0.82, angle + 4.0),
    ];

    for (final dot in dots) {
      canvas.drawCircle(dot, 4.2, dotPaint);
      canvas.drawCircle(dot, 9, Paint()..color = color.withValues(alpha: 0.12));
    }
  }

  Offset _radarPoint(
    Offset center,
    double radius,
    double distance,
    double pointAngle,
  ) {
    return Offset(
      center.dx + math.cos(pointAngle) * radius * distance,
      center.dy + math.sin(pointAngle) * radius * distance,
    );
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) {
    return oldDelegate.angle != angle ||
        oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.active != active;
  }
}

class TransferProgressPage extends StatefulWidget {
  const TransferProgressPage({
    required this.title,
    required this.peerLabel,
    required this.peerName,
    required this.status,
    required this.fileName,
    required this.fileIndex,
    required this.fileCount,
    required this.overallProgress,
    required this.fileProgress,
    required this.speedBytes,
    required this.transferredBytes,
    required this.totalBytes,
    required this.estimatedTime,
    required this.isComplete,
    required this.files,
    required this.onCancel,
    this.onRetry,
    this.onOpenFile,
    this.onOpenFolder,
    super.key,
  });

  final String title;
  final String peerLabel;
  final String peerName;
  final String status;
  final String fileName;
  final int fileIndex;
  final int fileCount;
  final double overallProgress;
  final double fileProgress;
  final double speedBytes;
  final int transferredBytes;
  final int totalBytes;
  final Duration? estimatedTime;
  final bool isComplete;
  final List<TransferProgressItem> files;
  final VoidCallback onCancel;
  final VoidCallback? onRetry;
  final VoidCallback? onOpenFile;
  final VoidCallback? onOpenFolder;

  @override
  State<TransferProgressPage> createState() => _TransferProgressPageState();
}

class _TransferProgressPageState extends State<TransferProgressPage> {
  @override
  Widget build(BuildContext context) {
    final peerColor = widget.peerLabel == 'Receiver'
        ? const Color(0xFF22B573)
        : const Color(0xFF5B6FF9);
    final completedCount = widget.files
        .where((item) => item.status == 'Complete')
        .length;
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                  children: [
                    TransferHeader(
                      title: widget.isComplete
                          ? 'Transfer complete'
                          : widget.title,
                      subtitle: widget.isComplete
                          ? '${widget.peerName} • All files were transferred successfully.'
                          : '${widget.peerName} • ${widget.status}',
                    ),
                    const SizedBox(height: 18),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ProgressLine(
                              label: 'Overall loading',
                              progress: widget.overallProgress,
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                _Metric(
                                  label: 'Speed',
                                  value:
                                      '${(widget.speedBytes / (1024 * 1024)).toStringAsFixed(2)} MB/s',
                                ),
                                _Metric(
                                  label: 'Time remaining',
                                  value: formatDuration(widget.estimatedTime),
                                ),
                                _Metric(
                                  label: 'Total transferred',
                                  value:
                                      '${formatBytes(widget.transferredBytes)} / ${formatBytes(widget.totalBytes)}',
                                  wide: true,
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            const Divider(height: 1),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Files',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                ),
                                Text(
                                  '$completedCount/${widget.files.length} complete',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            if (widget.files.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 24,
                                ),
                                child: Center(
                                  child: Text(
                                    'No files yet',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                                ),
                              )
                            else ...[
                              for (
                                var index = 0;
                                index < widget.files.length;
                                index++
                              )
                                _FileProgressItem(
                                  item: widget.files[index],
                                  index: index + 1,
                                  total: widget.files.length,
                                  isLast: index == widget.files.length - 1,
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _TransferBottomBar(
            isComplete: widget.isComplete,
            onRetry: widget.onRetry,
            onCancel: widget.onCancel,
            onOpenFile: widget.onOpenFile,
            onOpenFolder: widget.onOpenFolder,
          ),
        ],
      ),
    );
  }
}

class _TransferBottomBar extends StatelessWidget {
  const _TransferBottomBar({
    required this.isComplete,
    required this.onCancel,
    this.onRetry,
    this.onOpenFile,
    this.onOpenFolder,
  });

  final bool isComplete;
  final VoidCallback onCancel;
  final VoidCallback? onRetry;
  final VoidCallback? onOpenFile;
  final VoidCallback? onOpenFolder;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.98),
        border: Border(
          top: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.7)),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            child: isComplete
                ? Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      // if (onOpenFile != null)
                      // FilledButton.tonalIcon(
                      //   onPressed: onOpenFile,
                      //   icon: const Icon(Icons.open_in_new_rounded),
                      //   label: const Text('Open file'),
                      // ),
                      OutlinedButton(
                        onPressed: Get.back,
                        child: const Text('Go back'),
                      ),
                      if (onOpenFolder != null)
                        FilledButton.tonalIcon(
                          onPressed: onOpenFolder,
                          icon: const Icon(Icons.folder_open_rounded),
                          label: const Text('Open folder'),
                        ),
                    ],
                  )
                : Row(
                    children: [
                      if (onRetry != null) ...[
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: onRetry,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Retry'),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onCancel,
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('Cancel'),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _FileProgressItem extends StatelessWidget {
  const _FileProgressItem({
    required this.item,
    required this.index,
    required this.total,
    this.isLast = false,
  });

  final TransferProgressItem item;
  final int index;
  final int total;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      margin: EdgeInsets.only(bottom: isLast ? 0 : 14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: colors.outlineVariant.withValues(alpha: 0.6),
                ),
              ),
      ),
      child: AppFileTile(
        name: item.name,
        path: item.path,
        subtitle:
            'File $index of $total • ${formatBytes(item.transferred)} / ${formatBytes(item.size)}',
        status: item.status,
        progress: item.progress,
        trailing: Text(
          '${(item.progress * 100).toStringAsFixed(0)}%',
          style: Theme.of(context).textTheme.labelLarge,
        ),
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.label, required this.progress});

  final String label;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text('${(progress * 100).toStringAsFixed(0)}%'),
          ],
        ),
        const SizedBox(height: 7),
        LinearProgressIndicator(
          value: progress.clamp(0, 1),
          minHeight: 9,
          borderRadius: BorderRadius.circular(999),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.wide = false});

  final String label;
  final String value;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: wide ? 220 : 132,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ],
      ),
    );
  }
}

class _PercentBadge extends StatelessWidget {
  const _PercentBadge({required this.value, required this.color});

  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        value,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color),
      ),
    );
  }
}

String formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${unit == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1)} ${units[unit]}';
}

String formatDuration(Duration? value) {
  if (value == null) return '—';
  final minutes = value.inMinutes;
  final seconds = value.inSeconds.remainder(60);
  return minutes > 0 ? '${minutes}m ${seconds}s' : '${seconds}s';
}
