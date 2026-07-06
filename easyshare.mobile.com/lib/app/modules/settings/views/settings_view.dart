import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/ui_constants.dart';
import '../controllers/settings_controller.dart';

class SettingsView extends GetView<SettingsController> {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: const BackButton(),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Text(
                'Appearance',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 14),
              const _ThemeModeCard(),
              const SizedBox(height: 24),
              Text(
                'Receiving',
                style: Theme.of(context).textTheme.headlineSmall,
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
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFFFB020,
                              ).withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(
                                kBorderRadius,
                              ),
                            ),
                            child: const Icon(
                              Icons.folder_open_rounded,
                              color: Color(0xFFFF9A00),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Default Save Location',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        Platform.isIOS
                            ? 'Received files use the app Documents folder unless an available Files location is selected.'
                            : 'All received files are saved here unless you choose another folder.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      Obx(
                        () => Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(kBorderRadius),
                          ),
                          child: Text(
                            controller.storage.defaultSaveLocation.value.isEmpty
                                ? _systemDefaultLabel()
                                : controller.storage.defaultSaveLocation.value,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Obx(
                        () => Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            FilledButton.icon(
                              onPressed: controller.isPicking.value
                                  ? null
                                  : controller.chooseSaveLocation,
                              icon: controller.isPicking.value
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.create_new_folder_rounded),
                              label: const Text('Choose folder'),
                            ),
                            OutlinedButton(
                              onPressed: controller.useSystemDefault,
                              child: const Text('Use system default'),
                            ),
                          ],
                        ),
                      ),
                      Obx(
                        () => controller.statusText.value.isEmpty
                            ? const SizedBox.shrink()
                            : Padding(
                                padding: const EdgeInsets.only(top: 14),
                                child: Text(controller.statusText.value),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.all(18),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF22B573).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(kBorderRadius),
                    ),
                    child: const Icon(
                      Icons.security_rounded,
                      color: Color(0xFF22B573),
                    ),
                  ),
                  title: const Text('Local transfers'),
                  subtitle: Text(
                    'Files move directly over the local network. Keep both devices on the same Wi-Fi.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _systemDefaultLabel() {
    if (Platform.isIOS) return 'App Documents';
    return 'Downloads';
  }
}

class _ThemeModeCard extends GetView<SettingsController> {
  const _ThemeModeCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C5CFC).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(kBorderRadius),
                  ),
                  child: const Icon(
                    Icons.palette_rounded,
                    color: Color(0xFF7C5CFC),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'App theme',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Choose a theme or follow your device setting.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Obx(
              () => Row(
                children: [
                  Expanded(
                    child: _ThemeOption(
                      label: 'System',
                      icon: Icons.brightness_auto_rounded,
                      color: const Color(0xFF3478F6),
                      selected:
                          controller.storage.themeModeName.value == 'system',
                      onTap: () => controller.changeThemeMode('system'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ThemeOption(
                      label: 'Light',
                      icon: Icons.light_mode_rounded,
                      color: const Color(0xFFFF9A00),
                      selected:
                          controller.storage.themeModeName.value == 'light',
                      onTap: () => controller.changeThemeMode('light'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ThemeOption(
                      label: 'Dark',
                      icon: Icons.dark_mode_rounded,
                      color: const Color(0xFF7C5CFC),
                      selected:
                          controller.storage.themeModeName.value == 'dark',
                      onTap: () => controller.changeThemeMode('dark'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? color.withValues(alpha: 0.14)
          : scheme.surfaceContainerHighest.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(kBorderRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kBorderRadius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kBorderRadius),
            border: Border.all(
              color: selected ? color : scheme.outlineVariant,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 7),
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: 17,
                color: selected ? color : scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
