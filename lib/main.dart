import 'package:flutter/material.dart';
import 'screens/ticket_list.dart';
import 'screens/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _clearSessionOnStartup();
  runApp(MyApp());
}

Future<void> _clearSessionOnStartup() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('token'); // Elimina el token al iniciar
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sistema de Tickets La Hornilla',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: AuthChecker(), // Comprobador de autenticación 2.0
    );
  }
}

class AuthChecker extends StatelessWidget {
  const AuthChecker({super.key});

  Future<bool> _isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('token'); // Verifica si el token existee
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isLoggedIn(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasData && snapshot.data == true) {
          return TicketListScreen(); // Usuario autenticado
        } else {
          return LoginScreen(); // Usuario no autenticado
        }
      },
    );
  }
}
