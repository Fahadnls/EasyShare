import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../routes/app_pages.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          _AmbientBackground(colorScheme: cs),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
              children: [
                _reveal(delay: 0, child: _Header(cs: cs)),
                const SizedBox(height: 18),
                _reveal(delay: 220, child: _HeroCard(cs: cs)),
                const SizedBox(height: 18),
                _reveal(
                  delay: 220,
                  child: _ActionGrid(
                    cs: cs,
                    onSend: _startSendFlow,
                    onReceive: _startReceiveFlow,
                  ),
                ),
                const SizedBox(height: 18),
                _reveal(delay: 320, child: _HowItWorks(cs: cs)),
                const SizedBox(height: 18),
                _reveal(delay: 420, child: _NetworkHint(cs: cs)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startSendFlow() async {
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: false,
    );
    if (res == null || res.files.isEmpty) return;

    Get.toNamed(Routes.TRANSFER_SEND, arguments: {'files': res.files});
  }

  Future<void> _startReceiveFlow() async {
    Get.toNamed(Routes.TRANSFER_RECEIVE);
  }

  Widget _reveal({required Widget child, int delay = 0}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 700 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 18),
            child: child,
          ),
        );
      },
    );
  }
}

class _AmbientBackground extends StatelessWidget {
  const _AmbientBackground({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer.withOpacity(0.65),
            colorScheme.surface,
            colorScheme.tertiaryContainer.withOpacity(0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: const [
          Positioned(
            top: -80,
            right: -60,
            child: _GlowBlob(color: Color(0x3381C784), size: 220),
          ),
          Positioned(
            bottom: -90,
            left: -50,
            child: _GlowBlob(color: Color(0x3366D2A5), size: 240),
          ),
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.cs});

  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.primary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.auto_awesome, color: cs.onPrimary),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'EasyShare',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              'QR Wi-Fi Transfer',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.cs});

  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [cs.primary.withOpacity(0.9), cs.tertiary.withOpacity(0.9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fast, private, offline-ready',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: cs.onPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Send multiple files in one tap. Receiver scans a QR code and the files drop straight into Downloads.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: cs.onPrimary.withOpacity(0.9),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({
    required this.cs,
    required this.onSend,
    required this.onReceive,
  });

  final ColorScheme cs;
  final VoidCallback onSend;
  final VoidCallback onReceive;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth > 520;
        final children = [
          _ActionCard(
            cs: cs,
            title: 'Send Files',
            subtitle: 'Pick one or many files to share.',
            icon: Icons.north_east_rounded,
            accent: cs.primary,
            onPressed: onSend,
          ),
          _ActionCard(
            cs: cs,
            title: 'Receive Files',
            subtitle: 'Scan the QR and watch the progress.',
            icon: Icons.south_west_rounded,
            accent: cs.tertiary,
            onPressed: onReceive,
          ),
        ];
        return Row(
          children: [
            Expanded(child: children[0]),
            const SizedBox(width: 16),
            Expanded(child: children[1]),
          ],
        );
      },
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.cs,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onPressed,
  });

  final ColorScheme cs;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: cs.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks({required this.cs});

  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How it works',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          _StepRow(
            cs: cs,
            index: '01',
            text: 'Pick files on the sender device.',
          ),
          _StepRow(cs: cs, index: '02', text: 'Receiver scans the QR code.'),
          _StepRow(
            cs: cs,
            index: '03',
            text: 'Files land in Downloads automatically.',
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.cs, required this.index, required this.text});

  final ColorScheme cs;
  final String index;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              index,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: cs.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _NetworkHint extends StatelessWidget {
  const _NetworkHint({required this.cs});

  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer.withOpacity(0.35),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_rounded, color: cs.tertiary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Both devices must be on the same Wi-Fi network.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
