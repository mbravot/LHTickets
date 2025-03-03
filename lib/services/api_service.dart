import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  final String baseUrl =
      'http://api-tickets-c2g2bpcgauebg4fb.brazilsouth-01.azurewebsites.net/api'; //Ruta API

  // 🔹 Obtener token guardado en SharedPreferences
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  // 🔹 Iniciar sesión y guardar tokens
  Future<Map<String, dynamic>> login(String correo, String clave) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'correo': correo, 'clave': clave}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body); // ✅ Retornar los datos correctamente
    } else {
      throw Exception('Error en el login: ${response.body}');
    }
  }

  // 🔹 Registrar usuario
  Future<void> register(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    final token =
        prefs.getString('jwt_token'); // 🔹 Obtener el token almacenado

    if (token == null) {
      throw Exception("No hay token de autenticación.");
    }

    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {
        'Authorization': 'Bearer $token', // 🔹 Enviar token en la cabecera
        'Content-Type': 'application/json',
      },
      body: json.encode(userData),
    );

    if (response.statusCode != 201) {
      throw Exception('Error en el registro: ${response.body}');
    }
  }

// 🔹 Obtener usuarios activos
  Future<List<dynamic>> getUsuariosActivos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.get(
        Uri.parse("$baseUrl/usuarios"),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception("Error al obtener usuarios activos");
      }
    } catch (e) {
      throw Exception("Error en la API: $e");
    }
  }

  // 🔹 Cerrar sesión y eliminar token
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    print("🔹 Token eliminado al cerrar sesión"); // 🛠️ Debug
  }

  // 🔹 Obtener lista de tickets
  Future<List<dynamic>> getTickets() async {
    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('jwt_token');

    print("🔹 Token obtenido en getTickets(): $token");

    if (token == null) {
      throw Exception('Token no encontrado');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/tickets'), // Cambia esta línea
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json' // Agrega esta línea
      },
    );

    print("🔹 Respuesta del servidor: ${response.statusCode}");
    print("🔹 Respuesta body: ${response.body}"); // Agrega este log

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Error al obtener los tickets: ${response.body}');
    }
  }

  // 🔹 Crear un nuevo ticket y devolver el ticket_id
  Future<Map<String, dynamic>> createTicket(
      Map<String, dynamic> ticketData) async {
    String? token = await _getToken();
    if (token == null) throw Exception('Token no encontrado');

    final response = await http.post(
      Uri.parse('$baseUrl/tickets'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(ticketData),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body); // ✅ Devuelve el JSON con el ticket_id
    } else {
      throw Exception('Error al crear el ticket: ${response.body}');
    }
  }

  // 🔹 Actualizar un ticket
  Future<void> updateTicket(int id, Map<String, dynamic> ticketData) async {
    String? token = await _getToken();
    if (token == null) throw Exception('Token no encontrado');

    final response = await http.put(
      Uri.parse('$baseUrl/tickets/$id'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token'
      },
      body: json.encode(ticketData),
    );

    if (response.statusCode != 200) {
      throw Exception('Error al actualizar el ticket: ${response.body}');
    }
  }

  // 🔹 Eliminar un ticket
  Future<void> deleteTicket(int id) async {
    String? token = await _getToken();
    if (token == null) throw Exception('Token no encontrado');

    final response = await http.delete(
      Uri.parse('$baseUrl/tickets/$id'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception('Error al eliminar el ticket: ${response.body}');
    }
  }

  // 🔹 Obtener prioridades
  Future<List<dynamic>> getPrioridades() async {
    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('jwt_token');

    if (token == null) throw Exception('Token no encontrado');

    final response = await http.get(
      Uri.parse('$baseUrl/prioridades'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Error al obtener prioridades: ${response.body}');
    }
  }

  // 🔹 Obtener departamentos
  Future<List<dynamic>> getDepartamentos() async {
    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('jwt_token');
    if (token == null) throw Exception('Token no encontrado');

    final response = await http.get(
      Uri.parse('$baseUrl/departamentos'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Error al obtener los departamentos: ${response.body}');
    }
  }

  // Crear un departamento (opcional)
  Future<void> crearDepartamento(String nombre) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token =
          prefs.getString('jwt_token'); // 🔹 Cambiar 'token' por 'jwt_token'

      if (token == null) {
        throw Exception('No se encontró el token de autenticación');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/departamentos'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'nombre': nombre,
        }),
      );

      if (response.statusCode == 201) {
        print('Departamento creado exitosamente');
      } else {
        // 🔹 Mejorar manejo de errores
        print('Error del servidor: ${response.statusCode} - ${response.body}');
        throw Exception('Error al crear el departamento: ${response.body}');
      }
    } catch (e) {
      print('Error en crearDepartamento: $e');
      throw e;
    }
  }

  // Eliminar un departamento
  Future<void> eliminarDepartamento(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token'); // Obtener el token JWT

    if (token == null) {
      throw Exception('No se encontró el token de autenticación');
    }

    final response = await http.delete(
      Uri.parse('$baseUrl/departamentos/$id'),
      headers: {
        'Authorization': 'Bearer $token', // Enviar el token en el header
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Error al eliminar el departamento: ${response.body}');
    }
  }

  // 🔹 Obtener estados
  Future<List<dynamic>> getEstadosUsuarios() async {
    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('jwt_token');
    if (token == null) throw Exception('Token no encontrado');

    final response = await http.get(
      Uri.parse('$baseUrl/usuarios/estados'), // 🔹 Debe ser la API correcta
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception(
          'Error al obtener los estados de usuario: ${response.body}');
    }
  }

  // 🔹 Obtener comentarios de un ticket
  Future<List<dynamic>> getComentarios(int ticketId) async {
    String? token = await _getToken();
    if (token == null) throw Exception('Token no encontrado');

    final response = await http.get(
      Uri.parse('$baseUrl/tickets/$ticketId/comentarios'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Error al obtener los comentarios: ${response.body}');
    }
  }

  // 🔹 Agregar un comentario a un ticket
  Future<void> addComentario(
      int ticketId, Map<String, dynamic> comentarioData) async {
    String? token = await _getToken();
    if (token == null) throw Exception('Token no encontrado');

    final response = await http.post(
      Uri.parse('$baseUrl/tickets/$ticketId/comentarios'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token'
      },
      body: json.encode(comentarioData),
    );

    if (response.statusCode != 201) {
      throw Exception('Error al agregar el comentario: ${response.body}');
    }
  }

  // Método para asignar un ticket a un agente
  Future<void> asignarTicket(int ticketId, int agenteId) async {
    String? token = await _getToken();
    if (token == null) throw Exception('Token no encontrado');

    final response = await http.put(
      Uri.parse('$baseUrl/tickets/$ticketId/asignar'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({'id_agente': agenteId}),
    );

    if (response.statusCode != 200) {
      throw Exception('Error al asignar el ticket: ${response.body}');
    }
  }

// 🔹 Obtener lista de agentes con sus departamentos asignados
  Future<List<dynamic>> getAgentesConDepartamentos() async {
    String? token = await _getToken();
    if (token == null) throw Exception('Token no encontrado');

    final response = await http.get(
      Uri.parse('$baseUrl/agentes/departamentos'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Error al obtener agentes: ${response.body}');
    }
  }

// 🔹 Asignar un departamento a un agente
  Future<void> asignarDepartamento(int agenteId, int departamentoId) async {
    String? token = await _getToken();
    if (token == null) throw Exception('Token no encontrado');

    final response = await http.put(
      Uri.parse('$baseUrl/agentes/$agenteId/departamentos'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({'id_departamento': departamentoId}),
    );

    if (response.statusCode != 200) {
      throw Exception('Error al asignar departamento: ${response.body}');
    }
  }

// Método para obtener un agente
  Future<List<dynamic>> getAgentes() async {
    String? token = await _getToken();
    if (token == null) throw Exception('Token no encontrado');

    final response = await http.get(
      Uri.parse('$baseUrl/agentes'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Error al obtener la lista de agentes');
    }
  }

// Método para obtener sucursales
  Future<List<dynamic>> getSucursales() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.get(
        Uri.parse("$baseUrl/sucursales"),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception("Error al obtener sucursales");
      }
    } catch (e) {
      throw Exception("Error en la API: $e");
    }
  }

// Método para obtener roles
  Future<List<dynamic>> getRoles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final response = await http.get(
        Uri.parse("$baseUrl/roles"),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception("Error al obtener roles");
      }
    } catch (e) {
      throw Exception("Error en la API: $e");
    }
  }

//Método para actualizar usuarios
  Future<void> updateUser(int userId, Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    final response = await http.put(
      Uri.parse('$baseUrl/usuarios/$userId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(userData),
    );

    if (response.statusCode != 200) {
      throw Exception('Error al actualizar usuario: ${response.body}');
    }
  }

// Método para adjuntar archivos al ticket
  Future<void> subirArchivo(
      Uint8List archivoBytes, String fileName, int ticketId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      if (token == null) {
        print("❌ No hay token disponible. El usuario no está autenticado.");
        return;
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse(
            '$baseUrl/tickets/$ticketId/upload'), // Verificar que la ruta es correcta
      );

      request.headers['Authorization'] =
          'Bearer $token'; // Agregar token correctamente

      // Adjuntar el archivo como 'file'
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        archivoBytes,
        filename: fileName,
      ));

      var response = await request.send();
      var responseBody =
          await response.stream.bytesToString(); // Obtener respuesta como texto

      if (response.statusCode == 200) {
        print("✅ Archivo subido correctamente");
      } else {
        print(
            "❌ Error al subir el archivo: ${response.statusCode} - $responseBody");
      }
    } catch (e) {
      print("❌ Error en subirArchivo: $e");
    }
  }

// Metodo para agregar comentario al ticket
  Future<void> agregarComentario(int ticketId, String comentario) async {
    String? token = await _getToken();
    if (token == null) throw Exception('Token no encontrado');

    final response = await http.post(
      Uri.parse('$baseUrl/tickets/$ticketId/comentarios'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({'comentario': comentario}),
    );

    if (response.statusCode != 201) {
      throw Exception('Error al agregar comentario: ${response.body}');
    }
  }

// Metodo para cambiar estado al ticket
  Future<void> cambiarEstadoTicket(int ticketId, String nuevoEstado) async {
    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('jwt_token');

    final response = await http.put(
      Uri.parse('$baseUrl/tickets/$ticketId/estado'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'estado': nuevoEstado}),
    );

    if (response.statusCode != 200) {
      throw Exception('Error al cambiar estado del ticket');
    }
  }

// Metodo para cerrar el ticket
  Future<void> cerrarTicket(int ticketId) async {
    String? token = await _getToken();
    if (token == null) throw Exception('Token no encontrado');

    final response = await http.put(
      Uri.parse('$baseUrl/tickets/$ticketId/cerrar'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token'
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Error al cerrar el ticket: ${response.body}');
    }
  }

// Metodo para obtener comentario al ticket
  Future<List<dynamic>> obtenerComentarios(int ticketId) async {
    String? token = await _getToken();
    if (token == null) throw Exception('Token no encontrado');

    final response = await http.get(
      Uri.parse('$baseUrl/tickets/$ticketId/comentarios'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Error al obtener comentarios: ${response.body}');
    }
  }

// Metodo para cambiar la clave
  Future<void> cambiarClave(
      int userId, String oldPassword, String newPassword) async {
    String? token = await _getToken();
    if (token == null) throw Exception('Token no encontrado');

    final response = await http.put(
      Uri.parse('$baseUrl/usuarios/$userId/cambiar-clave'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'old_password': oldPassword,
        'new_password': newPassword,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Error al cambiar la clave: ${response.body}');
    }
  }

  Future<Map<String, String>> getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token') ?? '';

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

// Metodo para eliminar usuarios
  Future<void> deleteUser(int userId) async {
    final String url = '$baseUrl/usuarios/$userId';

    final response = await http.delete(
      Uri.parse(url),
      headers: await getHeaders(), // ✅ Ahora funcionará correctamente
    );

    if (response.statusCode != 200) {
      throw Exception('Error al eliminar el usuario: ${response.body}');
    }
  }

  Future<List<dynamic>> getAgentesPorDepartamento(int departamentoId) async {
    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('jwt_token');

    if (token == null) throw Exception('Token no encontrado');

    final response = await http.get(
      Uri.parse(
          '$baseUrl/departamentos/$departamentoId/agentes'), // ✅ URL corregida
      headers: {'Authorization': 'Bearer $token'},
    );

    print(
        "🔹 Respuesta de la API: ${response.body}"); // ✅ Agrega este print para depuración

    if (response.statusCode == 200) {
      List agentes = json.decode(response.body);
      print(
          "✅ Agentes obtenidos: $agentes"); // ✅ Verifica que los datos son correctos
      return agentes;
    } else {
      print(
          "❌ Error en API: ${response.body}"); // ✅ Muestra la respuesta en caso de error
      throw Exception('Error al obtener los agentes');
    }
  }

// ✅ Función para reasignar ticket
  Future<void> reasignarTicket(int ticketId, int nuevoAgenteId) async {
    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('jwt_token');

    final response = await http.put(
      Uri.parse('$baseUrl/tickets/$ticketId/asignar'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      },
      body: jsonEncode({'id_agente': nuevoAgenteId}),
    );

    if (response.statusCode != 200) {
      throw Exception('Error al reasignar el ticket');
    }
  }
}
