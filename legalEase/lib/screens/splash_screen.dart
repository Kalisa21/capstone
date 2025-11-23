import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 2000), () {
      Navigator.pushReplacementNamed(context, '/chatbot');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(radius: 56, backgroundColor: Colors.white, child: Text('L', style: TextStyle(fontSize: 48, color: AppTheme.primary, fontWeight: FontWeight.bold))),
          const SizedBox(height: 20),
          const Text('LEGAL EASE', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('The law at your fingertips', style: TextStyle(color: Colors.white70)),
        ]),
      ),
    );
  }
}
