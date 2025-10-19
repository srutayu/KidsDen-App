import 'package:flutter/material.dart';
import 'package:frontend/provider/auth_provider.dart';
import 'package:frontend/provider/themeProvider.dart';
import 'package:frontend/provider/user_data_provider.dart';
import 'package:frontend/screens/splash/splash_screen.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:month_year_picker/month_year_picker.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context); 

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kids Den',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 82, 172, 163),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color.fromARGB(255, 195, 244, 205),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 82, 172, 163),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color.fromARGB(255, 46, 87, 72),
        useMaterial3: true,
      ),
      themeMode:
          themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light, // ✅ reactive
      home: const SplashScreen(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        MonthYearPickerLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
      ],
    );
  }
}
