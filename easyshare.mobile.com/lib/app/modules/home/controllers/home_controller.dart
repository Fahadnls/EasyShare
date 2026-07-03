import 'package:get/get.dart';

class HomeController extends GetxController {
  final selectedCategory = 'all'.obs;

  final items = const <HomeDiscoverItem>[
    HomeDiscoverItem(
      title: 'Share photos instantly',
      subtitle:
          'Gallery images and camera shots ready for quick local sending.',
      meta: 'JPG / PNG',
      category: 'photos',
      accentStart: 0xFF9343F5,
      accentEnd: 0xFFFF7AA2,
    ),
    HomeDiscoverItem(
      title: 'Quick office transfers',
      subtitle: 'PDF files, contracts, slides, and notes for work sharing.',
      meta: 'PDF / DOCX',
      category: 'docs',
      accentStart: 0xFF20293A,
      accentEnd: 0xFF455B8F,
    ),
    HomeDiscoverItem(
      title: 'Cross-device workflow',
      subtitle:
          'Move edited clips and recordings across devices on the same Wi-Fi.',
      meta: 'MP4 / MOV',
      category: 'videos',
      accentStart: 0xFF3797FF,
      accentEnd: 0xFF7AD7F0,
    ),
    HomeDiscoverItem(
      title: 'Large file support',
      subtitle:
          'Transfer compressed folders and mixed project files with less friction.',
      meta: 'ZIP / MIXED',
      category: 'docs',
      accentStart: 0xFFFF8B2C,
      accentEnd: 0xFFFFD166,
    ),
  ];

  List<HomeDiscoverItem> get visibleItems {
    if (selectedCategory.value == 'all') return items;
    return items
        .where((item) => item.category == selectedCategory.value)
        .toList(growable: false);
  }

  void selectCategory(String category) {
    selectedCategory.value = category;
  }

  void resetCategory() {
    selectedCategory.value = 'all';
  }
}

class HomeDiscoverItem {
  const HomeDiscoverItem({
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.category,
    required this.accentStart,
    required this.accentEnd,
  });

  final String title;
  final String subtitle;
  final String meta;
  final String category;
  final int accentStart;
  final int accentEnd;
}
