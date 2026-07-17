import 'package:flutter/material.dart';
import 'screens/splash_decider.dart';

void main() {
  runApp(const DilanScissorsApp());
}

class DilanScissorsApp extends StatelessWidget {
  const DilanScissorsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DilanScissors',
      debugShowCheckedModeBanner: false,
      home: const SplashDecider(),
    );
  }
}