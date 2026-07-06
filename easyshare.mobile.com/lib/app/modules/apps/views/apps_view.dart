import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/ui_constants.dart';
import '../../../data/service/platform_file_service.dart';
import '../controllers/apps_controller.dart';

class AppsView extends GetView<AppsController> {
  const AppsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Apps'),
        leading: const BackButton(),
        actions: [
          if (controller.isSupported)
            IconButton(
              onPressed: controller.loadApps,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Reload apps',
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: controller.isSupported
              ? _AndroidAppList(controller: controller)
              : const _UnsupportedApps(),
        ),
      ),
      bottomNavigationBar: controller.isSupported
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                child: Obx(
                  () => FilledButton.icon(
                    onPressed:
                        controller.selectedPackages.isEmpty ||
                            controller.isPreparing.value
                        ? null
                        : controller.sendSelected,
                    icon: controller.isPreparing.value
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(
                      controller.isPreparing.value
                          ? 'Preparing apps…'
                          : controller.selectedPackages.isEmpty
                          ? 'Select apps to send'
                          : 'Send ${controller.selectedPackages.length} app(s)',
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class _AndroidAppList extends StatelessWidget {
  const _AndroidAppList({required this.controller});

  final AppsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      if (controller.apps.isEmpty) {
        return _MessageState(
          icon: Icons.apps_rounded,
          title: 'No apps available',
          message: controller.errorText.value,
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        itemCount: controller.apps.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final app = controller.apps[index];
          return Obx(
            () => _AppCard(
              app: app,
              selected: controller.selectedPackages.contains(app.packageName),
              onTap: () => controller.toggle(app),
            ),
          );
        },
      );
    });
  }
}

class _AppCard extends StatelessWidget {
  const _AppCard({
    required this.app,
    required this.selected,
    required this.onTap,
  });

  final SharedAppInfo app;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kBorderRadius),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(kBorderRadius),
                child: app.icon == null
                    ? Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF22B573,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(kBorderRadius),
                        ),
                        child: const Icon(
                          Icons.android_rounded,
                          color: Color(0xFF22B573),
                        ),
                      )
                    : Image.memory(
                        app.icon!,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      app.packageName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatBytes(app.size),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Checkbox(value: selected, onChanged: (_) => onTap()),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnsupportedApps extends StatelessWidget {
  const _UnsupportedApps();

  @override
  Widget build(BuildContext context) {
    return const _MessageState(
      icon: Icons.app_blocking_rounded,
      title: 'Direct app sharing is unavailable',
      message:
          'iOS and macOS do not allow apps to export installed application packages. You can still send ordinary files and folders.',
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF5B6FF9).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(kBorderRadius + 6),
              ),
              child: Icon(icon, size: 36, color: const Color(0xFF5B6FF9)),
            ),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

String _formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(unit == 0 ? 0 : 1)} ${units[unit]}';
}
