import 'package:flutter/material.dart';
import 'camera.dart';

void main() {
  runApp(const pen_to_pixel());
}

class pen_to_pixel extends StatelessWidget {
  const pen_to_pixel({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pen to Pixel',
      theme: ThemeData.dark(),
      home: const CameraPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}