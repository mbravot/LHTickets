import 'package:flutter/material.dart';
//import 'screens/ticket_list.dart';
import 'screens/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/session_service.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar el servicio de sesión
  final sessionService = SessionService();
  await sessionService.initialize();

  // Inicializar el servicio de API
  final apiService = ApiService();

  runApp(MyApp(
    sessionService: sessionService,
    apiService: apiService,
  ));
}

class MyApp extends StatelessWidget {
  final SessionService sessionService;
  final ApiService apiService;

  const MyApp({
    super.key,
    required this.sessionService,
    required this.apiService,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sistema de Tickets La Hornilla',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: LoginScreen(
        apiService: apiService,
        sessionService: sessionService,
      ),
    );
  }
}
