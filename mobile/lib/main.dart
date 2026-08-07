import 'package:flutter/material.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'services/api_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
    return MaterialApp(
      title: 'Form4x',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(235, 255, 255, 255)),
        useMaterial3: true,
      ),
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
  }
}
