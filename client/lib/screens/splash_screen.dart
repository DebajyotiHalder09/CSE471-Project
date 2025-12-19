import 'package:flutter/material.dart';
import 'dart:async';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Wait for the first frame to be rendered before navigating
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigateToLogin();
    });
  }

  void _navigateToLogin() async {
    // Wait for splash screen to be visible (minimum 1.5 seconds)
    await Future.delayed(const Duration(milliseconds: 1500));
    
    if (mounted) {
      // Use Navigator.of(context) instead of Navigator.pushReplacement
      // This ensures we're using the correct Navigator context
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.white,
        child: Center(
          child: Image.asset(
            'assets/main.png',
            width: 200,
            height: 200,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              // Fallback if image fails to load
              return const Icon(
                Icons.directions_bus,
                size: 100,
                color: Colors.blue,
              );
            },
          ),
        ),
      ),
    );
  }
}

