import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

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
                          const Icon(Icons.folder_open_rounded),
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
                            borderRadius: BorderRadius.circular(14),
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
                  leading: const Icon(Icons.security_rounded),
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
