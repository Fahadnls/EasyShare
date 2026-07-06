import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

class TransferProgressItem {
  const TransferProgressItem({
    required this.name,
    required this.size,
    required this.transferred,
    required this.progress,
    required this.status,
  });

  final String name;
  final int size;
  final int transferred;
  final double progress;
  final String status;
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
  String _filter = 'All';

  List<TransferProgressItem> get _visibleFiles {
    return switch (_filter) {
      'Active' =>
        widget.files
            .where((item) => item.status != 'Complete')
            .toList(growable: false),
      'Completed' =>
        widget.files
            .where((item) => item.status == 'Complete')
            .toList(growable: false),
      _ => widget.files,
    };
  }

  @override
  Widget build(BuildContext context) {
    final peerColor = widget.peerLabel == 'Receiver'
        ? const Color(0xFF22B573)
        : const Color(0xFF5B6FF9);
    final visibleFiles = _visibleFiles;
    final completedCount = widget.files
        .where((item) => item.status == 'Complete')
        .length;
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
            children: [
              TransferHeader(
                title: widget.isComplete ? 'Transfer complete' : widget.title,
                subtitle: widget.isComplete
                    ? 'All files were transferred successfully.'
                    : widget.status,
              ),
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 27,
                        backgroundColor: peerColor.withValues(alpha: 0.12),
                        foregroundColor: peerColor,
                        child: Icon(
                          widget.isComplete
                              ? Icons.check_rounded
                              : Icons.devices_rounded,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.peerLabel,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.peerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              widget.isComplete
                                  ? 'Transfer completed'
                                  : '${widget.fileCount} file(s) • Connected',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: peerColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${(widget.overallProgress * 100).toStringAsFixed(0)}%',
                          style: Theme.of(
                            context,
                          ).textTheme.labelLarge?.copyWith(color: peerColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.fileName.isEmpty
                                  ? (widget.isComplete
                                        ? '${widget.fileCount} file(s)'
                                        : 'Preparing files…')
                                  : widget.fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          Text(
                            widget.fileCount == 0
                                ? ''
                                : '${widget.fileIndex.clamp(0, widget.fileCount)} of ${widget.fileCount}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _ProgressLine(
                        label: 'Overall',
                        progress: widget.overallProgress,
                      ),
                      const SizedBox(height: 14),
                      _ProgressLine(
                        label: 'Current file',
                        progress: widget.fileProgress,
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        spacing: 24,
                        runSpacing: 14,
                        children: [
                          _Metric(
                            label: 'Progress',
                            value:
                                '${(widget.overallProgress * 100).toStringAsFixed(0)}%',
                          ),
                          _Metric(
                            label: 'Speed',
                            value:
                                '${(widget.speedBytes / (1024 * 1024)).toStringAsFixed(2)} MB/s',
                          ),
                          _Metric(
                            label: 'Transferred',
                            value:
                                '${formatBytes(widget.transferredBytes)} / ${formatBytes(widget.totalBytes)}',
                          ),
                          _Metric(
                            label: 'Time remaining',
                            value: formatDuration(widget.estimatedTime),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (widget.isComplete)
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (widget.onOpenFile != null)
                      FilledButton.tonalIcon(
                        onPressed: widget.onOpenFile,
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: const Text('Open file'),
                      ),
                    if (widget.onOpenFolder != null)
                      FilledButton.tonalIcon(
                        onPressed: widget.onOpenFolder,
                        icon: const Icon(Icons.folder_open_rounded),
                        label: const Text('Open folder'),
                      ),
                    FilledButton(
                      onPressed: Get.back,
                      child: const Text('Done'),
                    ),
                  ],
                )
              else
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: widget.onRetry != null ? 380 : 190,
                    ),
                    child: Row(
                      children: [
                        if (widget.onRetry != null) ...[
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: widget.onRetry,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Retry'),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: widget.onCancel,
                            icon: const Icon(Icons.close_rounded),
                            label: const Text('Cancel'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'All files',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Text(
                    '$completedCount/${widget.files.length} complete',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final filter in ['All', 'Active', 'Completed']) ...[
                      ChoiceChip(
                        label: Text(filter),
                        selected: _filter == filter,
                        onSelected: (_) => setState(() => _filter = filter),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (visibleFiles.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Text(
                        'No $_filter files',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                ),
              for (var index = 0; index < visibleFiles.length; index++)
                _FileProgressItem(
                  item: visibleFiles[index],
                  index: widget.files.indexOf(visibleFiles[index]) + 1,
                  total: widget.files.length,
                ),
            ],
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
  });

  final TransferProgressItem item;
  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isError = item.status == 'Failed' || item.status == 'Cancelled';
    final isComplete = item.status == 'Complete';
    final isActive = const {
      'Sending',
      'Receiving',
      'Retrying',
    }.contains(item.status);
    final statusColor = isError
        ? colors.error
        : isComplete
        ? const Color(0xFF22B573)
        : isActive
        ? const Color(0xFF3478F6)
        : const Color(0xFFFF9A00);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: statusColor.withValues(alpha: isActive ? 0.08 : 0.025),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: statusColor.withValues(alpha: 0.14),
                  foregroundColor: statusColor,
                  child: isComplete
                      ? const Icon(Icons.check_rounded, size: 20)
                      : isError
                      ? const Icon(Icons.error_outline_rounded, size: 20)
                      : Text('$index'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'File $index of $total • ${formatBytes(item.transferred)} / ${formatBytes(item.size)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${(item.progress * 100).toStringAsFixed(0)}%',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    Text(
                      item.status,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: statusColor),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: item.progress.clamp(0, 1),
              minHeight: 7,
              borderRadius: BorderRadius.circular(999),
              color: statusColor,
            ),
          ],
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
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 132,
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
