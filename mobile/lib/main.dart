import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'services/api_service.dart';
import 'theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeController.instance.load();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<bool> _checkLoginStatus() async {
    final token = await ApiService.getToken();
    return token != null;
  }

  @override
  Widget build(BuildContext context) {
    // Warna seed: biru utama aplikasi agar palet light/dark konsisten.
    const seed = Color(0xFF1E66D0);
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'Form4x',
          debugShowCheckedModeBanner: false,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            FlutterQuillLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'),
            Locale('id'),
          ],
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF1E66D0),
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: seed,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          themeMode: ThemeController.instance.mode,
          home: FutureBuilder<bool>(
            future: _checkLoginStatus(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              final bool isLoggedIn = snapshot.data ?? false;
              return isLoggedIn ? const HomePage() : const LoginPage();
            },
          ),
        );
      },
    );
  }
}