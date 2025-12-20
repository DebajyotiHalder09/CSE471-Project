import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'utils/app_theme.dart';
import 'providers/theme_provider.dart';
import 'screens/splash_screen.dart';
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
import 'screens/qr.dart';
import 'screens/gpayreglog.dart';
import 'screens/recharge.dart';
import 'screens/admin.dart';
import 'screens/verify.dart';
import 'screens/settings.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Set system UI overlay style for modern look (will be updated based on theme)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          // Update system UI based on theme
          final isDark = themeProvider.isDarkMode;
          SystemChrome.setSystemUIOverlayStyle(
            SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
              systemNavigationBarColor: isDark ? AppTheme.darkSurface : Colors.white,
              systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            ),
          );
          
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'SmartCommute Dhaka',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const SplashScreen(),
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
              QRScreen.routeName: (context) => QRScreen(),
              GpayRegLogScreen.routeName: (context) => GpayRegLogScreen(),
              RechargeScreen.routeName: (context) => RechargeScreen(),
              AdminScreen.routeName: (context) => AdminScreen(),
              VerifyScreen.routeName: (context) => VerifyScreen(),
              SettingsScreen.routeName: (context) => const SettingsScreen(),
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
        },
      ),
    );
  }
}
