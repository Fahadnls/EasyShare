import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/home_controller.dart';
import '../../../routes/app_pages.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(color: Color(0xFFF7F9FC)),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
                children: [
                  _TopBar(
                    onHistory: () => Get.toNamed(Routes.TRANSFER_HISTORY),
                    onSettings: () => Get.toNamed(Routes.SETTINGS),
                  ),
                  const SizedBox(height: 28),
                  _ActionRow(
                    onSend: _startSendFlow,
                    onReceive: _startReceiveFlow,
                  ),
                  const SizedBox(height: 24),
                  _ShortcutSection(
                    controller: controller,
                    onPhotosTap: () => _pickFilesByCategory('photos'),
                    onVideosTap: () => _pickFilesByCategory('videos'),
                    onDocsTap: () => _pickFilesByCategory('docs'),
                  ),
                  const SizedBox(height: 18),
                  const _TransferBanner(),
                  const SizedBox(height: 18),
                  _DiscoverSection(controller: controller),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _startSendFlow() async {
    Get.toNamed(Routes.TRANSFER_SEND);
  }

  Future<void> _startReceiveFlow() async {
    Get.toNamed(Routes.TRANSFER_RECEIVE);
  }

  Future<void> _pickFilesByCategory(String category) async {
    controller.selectCategory(category);
    Get.toNamed(
      Routes.TRANSFER_SEND,
      arguments: {'initialAction': category == 'docs' ? 'documents' : category},
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onHistory, required this.onSettings});

  final VoidCallback onHistory;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Image.asset('assets/logo_launcher.png', width: 32, height: 32),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Next Share', style: textTheme.titleLarge),
                  const SizedBox(height: 2),
                  Text('Connect. Share. Done.', style: textTheme.bodySmall),
                ],
              ),
            ],
          ),
        ),
        _TopBadge(
          icon: Icons.history_rounded,
          tooltip: 'Transfer history',
          onTap: onHistory,
        ),
        const SizedBox(width: 10),
        _TopBadge(
          icon: Icons.settings_rounded,
          tooltip: 'Settings',
          onTap: onSettings,
        ),
      ],
    );
  }
}

class _TopBadge extends StatelessWidget {
  const _TopBadge({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE3E9F3)),
          ),
          child: Icon(icon, size: 21, color: const Color(0xFF1B2430)),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.onSend, required this.onReceive});

  final VoidCallback onSend;
  final VoidCallback onReceive;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.send_rounded,
            label: 'Send',
            onTap: onSend,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _ActionButton(
            icon: Icons.move_to_inbox_rounded,
            label: 'Receive',
            onTap: onReceive,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Column(
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF3E8DFF), Color(0xFF2572F5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1F2572F5),
                  blurRadius: 18,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 12),
          Text(label, style: textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _TransferBanner extends StatelessWidget {
  const _TransferBanner();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF13223B), Color(0xFF2053C8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2216356E),
            blurRadius: 24,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Fast local transfer for every file type.',
                  style: textTheme.headlineSmall?.copyWith(color: Colors.white),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'HOT',
                  style: textTheme.labelLarge?.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Send photos, videos, documents and folders over the same Wi-Fi without cloud upload.',
            style: textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.84),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            height: 145,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: Column(
                children: [
                  const Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _BannerMiniCard(icon: Icons.image_rounded),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _BannerMiniCard(
                            icon: Icons.description_rounded,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _BannerMiniCard(
                            icon: Icons.folder_zip_rounded,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // const SizedBox(height: 14),
                  // Row(
                  //   children: [
                  //     Expanded(
                  //       child: Text(
                  //         'One tap to start sending',
                  //         style: textTheme.bodySmall?.copyWith(
                  //           color: Colors.white.withValues(alpha: 0.78),
                  //         ),
                  //       ),
                  //     ),
                  //     FilledButton(
                  //       onPressed: () => Get.toNamed(Routes.TRANSFER_SEND),
                  //       style: FilledButton.styleFrom(
                  //         backgroundColor: const Color(0xFF3E8DFF),
                  //         minimumSize: const Size(88, 44),
                  //         shape: RoundedRectangleBorder(
                  //           borderRadius: BorderRadius.circular(16),
                  //         ),
                  //       ),
                  //       child: const Text('Start'),
                  //     ),
                  //   ],
                  // ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerMiniCard extends StatelessWidget {
  const _BannerMiniCard({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Center(child: Icon(icon, color: Colors.white, size: 34)),
    );
  }
}

class _ShortcutSection extends StatelessWidget {
  const _ShortcutSection({
    required this.controller,
    required this.onPhotosTap,
    required this.onVideosTap,
    required this.onDocsTap,
  });

  final HomeController controller;
  final VoidCallback onPhotosTap;
  final VoidCallback onVideosTap;
  final VoidCallback onDocsTap;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'FAST ACCESS',
      actionLabel: 'More',
      child: Row(
        children: [
          Expanded(
            child: Obx(
              () => _ShortcutItem(
                colors: const [Color(0xFF33D17A), Color(0xFF00A86B)],
                icon: Icons.photo_library_rounded,
                label: 'Photos',
                isActive: controller.selectedCategory.value == 'photos',
                onTap: onPhotosTap,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Obx(
              () => _ShortcutItem(
                colors: const [Color(0xFFFF7A59), Color(0xFFFF4D6D)],
                icon: Icons.video_library_rounded,
                label: 'Videos',
                isActive: controller.selectedCategory.value == 'videos',
                onTap: onVideosTap,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Obx(
              () => _ShortcutItem(
                colors: const [Color(0xFF5B7CFF), Color(0xFF2572F5)],
                icon: Icons.insert_drive_file_rounded,
                label: 'Docs',
                isActive: controller.selectedCategory.value == 'docs',
                onTap: onDocsTap,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ShortcutMoreButton(
              onTap: () {
                controller.resetCategory();
                Get.toNamed(Routes.TRANSFER_SEND);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortcutItem extends StatelessWidget {
  const _ShortcutItem({
    required this.colors,
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  final List<Color> colors;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFF2F6FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: colors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: isActive
                    ? const [
                        BoxShadow(
                          color: Color(0x222572F5),
                          blurRadius: 14,
                          offset: Offset(0, 8),
                        ),
                      ]
                    : null,
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: textTheme.bodySmall?.copyWith(
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShortcutMoreButton extends StatelessWidget {
  const _ShortcutMoreButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF1FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'MORE',
              style: textTheme.labelLarge?.copyWith(
                color: const Color(0xFF2A63D3),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('Explore', style: textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _DiscoverSection extends StatelessWidget {
  const _DiscoverSection({required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => _SectionCard(
        title: 'DISCOVER',
        actionLabel: controller.selectedCategory.value == 'all'
            ? 'More'
            : controller.selectedCategory.value.capitalizeFirst ?? 'More',
        tint: const Color(0xFFFFF2DE),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < controller.visibleItems.length; i++) ...[
                _DiscoverCard(item: controller.visibleItems[i]),
                if (i != controller.visibleItems.length - 1)
                  const SizedBox(width: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.actionLabel,
    required this.child,
    this.tint = Colors.white,
  });

  final String title;
  final String actionLabel;
  final Widget child;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6EBF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              Text(
                actionLabel,
                style: textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF7F8B9D),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _DiscoverCard extends StatelessWidget {
  const _DiscoverCard({required this.item});

  final HomeDiscoverItem item;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: 168,
      height: 248,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(item.accentStart), Color(item.accentEnd)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                item.meta,
                style: textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const Spacer(),
          Text(
            item.title,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.subtitle,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            item.category.capitalizeFirst ?? item.category,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
