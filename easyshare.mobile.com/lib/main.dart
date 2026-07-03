import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app/data/service/app_storage_service.dart';
import 'app/routes/app_pages.dart';
import 'app/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Get.putAsync(() => AppStorageService().init(), permanent: true);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Next Share',
      initialRoute: AppPages.INITIAL,

      getPages: AppPages.routes,
      theme: AppTheme.light,
    );
  }
}
