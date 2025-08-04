import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/nav.dart';
import 'screens/profile.dart';
import 'screens/map.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bus App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: LoginScreen.routeName,
      routes: {
        LoginScreen.routeName: (context) => LoginScreen(),
        SignupScreen.routeName: (context) => SignupScreen(),
        DashboardScreen.routeName: (context) => DashboardScreen(),
        NavScreen.routeName: (context) => NavScreen(),
        ProfileScreen.routeName: (context) => ProfileScreen(),
        '/map': (context) => MapScreen(),
      },
    );
  }
}
