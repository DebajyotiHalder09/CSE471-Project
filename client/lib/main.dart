import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/nav.dart';
import 'screens/navDriver.dart';
import 'screens/profile.dart';
import 'screens/pinfo.dart';
import 'screens/map.dart';
import 'screens/tripHistory.dart';
import 'screens/top.dart';
import 'screens/friends.dart';
import 'screens/offers.dart';

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
        NavDriverScreen.routeName: (context) => NavDriverScreen(),
        ProfileScreen.routeName: (context) => ProfileScreen(),
        PersonalInfoScreen.routeName: (context) => PersonalInfoScreen(),
        '/map': (context) => MapScreen(),
        TripHistoryScreen.routeName: (context) => TripHistoryScreen(),
        TopScreen.routeName: (context) => TopScreen(),
        FriendsScreen.routeName: (context) => FriendsScreen(),
        OffersScreen.routeName: (context) => OffersScreen(),
      },
      onUnknownRoute: (settings) {
        print('Unknown route: ${settings.name}');
        return MaterialPageRoute(
          builder: (context) => Scaffold(
            body: Center(
              child: Text('Route not found: ${settings.name}'),
            ),
          ),
        );
      },
    );
  }
}
