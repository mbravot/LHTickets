import 'package:flutter/material.dart';
//import 'screens/ticket_list.dart';
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
      home: LoginScreen(), // Siempre inicia en Login
    );
  }
}
