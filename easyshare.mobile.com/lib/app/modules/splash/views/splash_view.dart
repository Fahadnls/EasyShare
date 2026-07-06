import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/splash_controller.dart';

class SplashView extends GetView<SplashController> {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F9FF),
      body: SafeArea(
        child: Center(
          child: ClipRect(
            child: SizedBox(
              width: 360,
              height: 460,
              child: FittedBox(
                fit: BoxFit.fitWidth,
                child: ColorFiltered(
                  colorFilter: const ColorFilter.mode(
                    Color(0xFFF4F9FF),
                    BlendMode.modulate,
                  ),
                  child: Image.asset('assets/logo_with_text.png', width: 720),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
