import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:headscalemanager/providers/app_provider.dart';
import 'package:headscalemanager/screens/lock_screen.dart';
import 'package:headscalemanager/screens/splash_screen.dart';
import 'package:headscalemanager/services/security_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Edge-to-edge: required for Android 15+ when targeting API 35+.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final SecurityService _securityService = SecurityService();
  DateTime? _pausedAt;
  bool _isLockScreenOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _pausedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      _maybeShowLockOnResume();
    }
  }

  Future<void> _maybeShowLockOnResume() async {
    final pausedAt = _pausedAt;
    _pausedAt = null;

    if (SecurityService.suppressNextResumeLock) {
      SecurityService.suppressNextResumeLock = false;
      return;
    }

    if (pausedAt == null || _isLockScreenOpen) return;

    final autoLockMinutes = await _securityService.getAutoLockMinutes();
    if (autoLockMinutes < 0) return;

    final isPinConfigured = await _securityService.isPinConfigured();
    if (!isPinConfigured) return;

    final elapsed = DateTime.now().difference(pausedAt);
    if (elapsed < Duration(minutes: autoLockMinutes)) return;

    final nav = _navigatorKey.currentState;
    if (nav == null || _isLockScreenOpen) return;

    _isLockScreenOpen = true;
    try {
      await nav.push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const LockScreen(popOnUnlock: true),
        ),
      );
    } finally {
      _isLockScreenOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppProvider(),
      child: Consumer<AppProvider>(
        builder: (context, appProvider, child) {
          return MaterialApp(
            navigatorKey: _navigatorKey,
            title: 'Headscale Manager',
            theme: ThemeData.light(),
            darkTheme: ThemeData.dark(),
            themeMode: ThemeMode.system,
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
