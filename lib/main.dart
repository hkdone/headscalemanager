import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/screens/splash_screen.dart';
import 'package:provider/provider.dart';

/// Point d'entrée principal de l'application Flutter.
///
/// Cette fonction initialise et lance l'application en exécutant le widget [MyApp].
void main() {
  runApp(const MyApp());
}

/// Widget racine de l'application.
///
/// [MyApp] est un [StatelessWidget] qui configure la structure de base de l'application,
/// y compris la gestion de l'état avec [ChangeNotifierProvider] et les thèmes visuels.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    /// Fournit une instance de [AppProvider] à l'ensemble de l'arborescence des widgets.
    ///
    /// [AppProvider] est instancié ici. Il est important de noter que [AppProvider]
    /// instancie directement ses dépendances ([HeadscaleApiService] et [StorageService]).
    /// Pour des applications plus complexes ou pour faciliter les tests unitaires,
    /// une injection de dépendances plus explicite pourrait être envisagée pour ces services.
    return ChangeNotifierProvider(
      create: (context) => AppProvider(),
      child: Consumer<AppProvider>(
        builder: (context, appProvider, child) {
          return MaterialApp(
            /// Titre de l'application, affiché dans la barre des tâches ou le sélecteur d'applications.
            title: 'Gestionnaire Headscale',

            /// Configuration de la localisation
            locale: appProvider.locale,
            supportedLocales: const [
              Locale('en', ''),
              Locale('fr', ''),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],

            /// Désactive la bannière "DEBUG" en mode développement.
        debugShowCheckedModeBanner: false,

        /// Thème visuel de l'application pour le mode clair.
        ///
        /// Note : `primarySwatch` est déprécié. Pour un theming plus moderne,
        /// il est recommandé d'utiliser `ColorScheme.fromSeed` ou de définir
        /// un `ColorScheme` personnalisé.
        theme: ThemeData(
          brightness: Brightness.light,
          primarySwatch: Colors.blue,
          scaffoldBackgroundColor:
              Colors.grey[100], // Fond d'écran légèrement gris
          visualDensity: VisualDensity.adaptivePlatformDensity,
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            backgroundColor: Colors.white, // Barre de nav blanche
            selectedItemColor: Colors.blue,
            unselectedItemColor: Colors.black54,
            type: BottomNavigationBarType.fixed,
          ),
        ),

        /// Thème visuel de l'application pour le mode sombre.
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          primarySwatch: Colors.blue,
          scaffoldBackgroundColor:
              const Color(0xFF121212), // Fond d'écran sombre
          visualDensity: VisualDensity.adaptivePlatformDensity,
          bottomNavigationBarTheme: BottomNavigationBarThemeData(
            backgroundColor:
                const Color(0xFF212121), // Barre de nav plus claire
            selectedItemColor: Colors.blue[300],
            unselectedItemColor: Colors.grey,
            type: BottomNavigationBarType.fixed,
          ),
        ),

        /// Définit le mode de thème à utiliser (système, clair ou sombre).
        /// `ThemeMode.system` respecte les préférences de thème du système d'exploitation.
        themeMode: ThemeMode.system,

        /// Le premier écran affiché au lancement de l'application.
        home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
