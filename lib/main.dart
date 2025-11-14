import 'package:flutter/material.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/screens/splash_screen.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // We don't want to initialize notifications here anymore
  // as it requires settings to be loaded first.
  // await NotificationService.initialize(); 
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppProvider(),
      child: Consumer<AppProvider>(
        builder: (context, appProvider, child) {
          return MaterialApp(
            title: 'Headscale Manager',
            theme: ThemeData.light(), // Using a default theme
            darkTheme: ThemeData.dark(), // Using a default dark theme
            themeMode: ThemeMode.system, // Let the system decide
            locale: appProvider.locale,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en', ''),
              Locale('fr', ''),
            ],
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
