import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:html' if (dart.library.html) 'dart:html' as html;
import 'dart:async';
import 'api_service.dart';
import 'package:flutter/material.dart';
import '../screens/login_screen.dart';

class SessionService {
  static final SessionService _instance = SessionService._internal();
  factory SessionService() => _instance;
  SessionService._internal();

  bool _isInitialized = false;
  Timer? _tokenRefreshTimer;
  final ApiService _apiService = ApiService();

  // Tiempo de expiración del token (20 minutos en milisegundos)
  static const int TOKEN_EXPIRATION_TIME = 20 * 60 * 1000;

  // Tiempo de renovación (5 minutos antes de expirar)
  static const int TOKEN_REFRESH_TIME = 15 * 60 * 1000;

  // Contexto global para navegación
  BuildContext? _context;

  // Establecer el contexto para navegación
  void setContext(BuildContext context) {
    _context = context;
  }

  // Inicializar el servicio
  Future<void> initialize() async {
    if (_isInitialized) return;

    if (kIsWeb) {
      // Configurar listener para el cierre del navegador
      html.window.onBeforeUnload.listen((event) async {
        await clearSession();
      });
    }

    // Iniciar el temporizador de renovación de token
    _startTokenRefreshTimer();

    _isInitialized = true;
  }

  // Iniciar el temporizador de renovación de token
  void _startTokenRefreshTimer() {
    // Cancelar el temporizador existente si hay uno
    _tokenRefreshTimer?.cancel();

    // Crear un nuevo temporizador que se ejecuta cada minuto para verificar
    _tokenRefreshTimer = Timer.periodic(Duration(minutes: 1), (timer) async {
      await _checkAndRefreshToken();
    });
  }

  // Verificar y renovar el token si es necesario
  Future<void> _checkAndRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionStartTime = prefs.getInt('session_start_time') ?? 0;
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    final elapsedTime = currentTime - sessionStartTime;

    // Si ha pasado más tiempo que TOKEN_REFRESH_TIME, renovar el token
    if (elapsedTime > TOKEN_REFRESH_TIME) {
      try {
        final refreshToken = prefs.getString('refresh_token');
        if (refreshToken != null && refreshToken.isNotEmpty) {
          final refreshedToken = await _apiService.refreshToken(refreshToken);
          await prefs.setString('jwt_token', refreshedToken);
          await prefs.setInt('session_start_time', currentTime);
          print('✅ Token renovado automáticamente');
        }
      } catch (e) {
        print('❌ Error al renovar el token: $e');
        // Si hay un error al renovar, limpiar la sesión y redirigir al login
        await _handleTokenExpiration();
      }
    }
  }

  // Manejar la expiración del token
  Future<void> _handleTokenExpiration() async {
    await clearSession();

    // Redirigir al usuario a la pantalla de login si tenemos contexto
    if (_context != null && _context!.mounted) {
      Navigator.pushAndRemoveUntil(
        _context!,
        MaterialPageRoute(
          builder: (context) => LoginScreen(
            apiService: _apiService,
            sessionService: this,
          ),
        ),
        (route) => false,
      );

      // Mostrar mensaje de sesión expirada
      ScaffoldMessenger.of(_context!).showSnackBar(
        SnackBar(
          content: Text(
              '🔒 Tu sesión ha expirado. Por favor, inicia sesión nuevamente.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  // Guardar token de sesión
  Future<void> saveSession(String accessToken, String refreshToken, Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', accessToken);
    await prefs.setString('refresh_token', refreshToken);
    await prefs.setString('user_role', userData['id_rol'].toString());
    await prefs.setString('nombre_usuario', userData['nombre']);
    await prefs.setString('user_id', userData['id'].toString());
    await prefs.setString('sucursal', userData['sucursal'] ?? 'No asignada');
    await prefs.setInt('session_start_time', DateTime.now().millisecondsSinceEpoch);
    _startTokenRefreshTimer();
  }

  // Verificar si hay una sesión activa
  Future<bool> hasActiveSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    final sessionStartTime = prefs.getInt('session_start_time') ?? 0;
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    final elapsedTime = currentTime - sessionStartTime;

    // Verificar si el token existe y no ha expirado
    if (token == null ||
        token.isEmpty ||
        elapsedTime >= TOKEN_EXPIRATION_TIME) {
      return false;
    }

    // Si el token está próximo a expirar, intentar renovarlo
    if (elapsedTime > TOKEN_REFRESH_TIME) {
      try {
        final refreshedToken = await _apiService.refreshToken(token);
        await prefs.setString('jwt_token', refreshedToken);
        await prefs.setInt('session_start_time', currentTime);
        return true;
      } catch (e) {
        print('❌ Error al verificar la sesión: $e');
        return false;
      }
    }

    return true;
  }

  // Obtener datos de la sesión
  Future<Map<String, dynamic>> getSessionData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'token': prefs.getString('jwt_token'),
      'user_role': prefs.getString('user_role'),
      'nombre_usuario': prefs.getString('nombre_usuario'),
      'user_id': prefs.getString('user_id'),
      'sucursal': prefs.getString('sucursal'),
    };
  }

  // Limpiar la sesión
  Future<void> clearSession() async {
    // Cancelar el temporizador de renovación
    _tokenRefreshTimer?.cancel();

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('refresh_token');
  }
}
