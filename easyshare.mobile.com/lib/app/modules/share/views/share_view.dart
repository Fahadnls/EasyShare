import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/share_controller.dart';

class ChatView extends GetView<ShareController> {
  const ChatView({super.key});

  @override
  Widget build(BuildContext context) {
    final input = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        title: Text(controller.device.name ?? controller.device.address),
        // subtitle: Obx(() => Text(controller.connectionState.value)),
        actions: [
          IconButton(
            onPressed: controller.pickAndSendFile,
            icon: const Icon(Icons.attach_file),
            tooltip: 'Send file',
          ),
          IconButton(
            onPressed: controller.disconnect,
            icon: const Icon(Icons.link_off),
            tooltip: 'Disconnect',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Obx(() {
              final list = controller.messages;
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final m = list[i];
                  final align = m.me
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start;
                  final bubbleAlign = m.me
                      ? Alignment.centerRight
                      : Alignment.centerLeft;
                  return Column(
                    crossAxisAlignment: align,
                    children: [
                      Align(
                        alignment: bubbleAlign,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: m.me
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                          ),
                          child: Text(m.text),
                        ),
                      ),
                    ],
                  );
                },
              );
            }),
          ),

          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: input,
                      decoration: const InputDecoration(
                        hintText: 'Type message...',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (v) {
                        controller.sendText(v);
                        input.clear();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: () {
                      controller.sendText(input.text);
                      input.clear();
                    },
                    child: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
