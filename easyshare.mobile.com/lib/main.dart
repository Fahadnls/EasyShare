import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app/routes/app_pages.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EasyShare',
      initialRoute: AppPages.INITIAL,
      getPages: AppPages.routes,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B7F6A),
          primary: const Color(0xFF1B7F6A),
          secondary: const Color(0xFF0E5C63),
          tertiary: const Color(0xFFE07A5F),
          surface: const Color(0xFFF7F1EB),
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F1EB),
        textTheme: GoogleFonts.spaceGroteskTextTheme(),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
        ),
      ),
    );
  }
}
