import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart'; // Added for kDebugMode

class ApiService {
  final String baseUrl = 'https://apilhtickets-927498545444.us-central1.run.app/api'; //Ruta API
  //final String baseUrl = 'http://192.168.1.37:8080/api'; //Ruta API


  // 🔹 Obtener token guardado en SharedPreferences
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  // 🔹 Iniciar sesión y guardar token
  Future<Map<String, dynamic>> login(String correo, String clave) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'correo': correo, 'clave': clave}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // Asegurarse de que la respuesta incluya la sucursal activa
      if (data['usuario'] != null) {
        // Obtener la sucursal de la estructura anidada
        final sucursalActiva = data['usuario']['sucursal_activa'];
        if (sucursalActiva != null && sucursalActiva['nombre'] != null) {
          data['usuario']['sucursal'] = sucursalActiva['nombre'];
        } else {
          data['usuario']['sucursal'] = 'No asignada';
        }
      }
      return data;
    } else {
      throw Exception('Error en el login: ${response.body}');
    }
  }

  // 🔹 Renovar token JWT usando refresh_token
  Future<String> refreshToken(String refreshToken) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $refreshToken',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', data['access_token']);
        return data['access_token'];
      } else {
        throw Exception('Error al renovar el token: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error al renovar el token: $e');
    }
  }

  // Método genérico para peticiones protegidas con refresco automático
  Future<http.Response> protectedRequest(Future<http.Response> Function(String token) requestFn) async {
    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('jwt_token');
    String? refreshTokenStr = prefs.getString('refresh_token');
    http.Response response = await requestFn(token ?? '');
    if (response.statusCode == 401 && refreshTokenStr != null) {
      // Intentar refrescar el token
      final newToken = await refreshToken(refreshTokenStr);
      response = await requestFn(newToken);
    }
    return response;
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
    final response = await protectedRequest(
      (token) => http.get(
        Uri.parse("$baseUrl/usuarios"),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception("Error al obtener usuarios activos");
      }
  }

  // 🔹 Obtener todos los usuarios (activos e inactivos)
  Future<List<dynamic>> getUsuarios() async {
    final response = await protectedRequest(
      (token) => http.get(
        Uri.parse("$baseUrl/usuarios"),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception("Error al obtener todos los usuarios");
    }
  }

  // 🔹 Cerrar sesión y eliminar token
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
  }

  // 🔹 Obtener lista de tickets
  Future<List<dynamic>> getTickets() async {
    final response = await protectedRequest(
      (token) => http.get(
        Uri.parse('$baseUrl/tickets'),
      headers: {
        'Authorization': 'Bearer $token',
          'Accept': 'application/json'
      },
      ),
    );
    if (response.statusCode == 200) {
      List<dynamic> tickets = json.decode(response.body);
      return tickets.map((ticket) {
        return {
          'id': ticket['id'],
          'id_formatted': ticket['id']?.toString().padLeft(6, '0') ?? '',
          'titulo': ticket['titulo']?.toString() ?? 'Sin título',
          'descripcion': ticket['descripcion']?.toString() ?? 'Sin descripción',
          'estado': ticket['estado']?.toString() ?? 'ABIERTO',
          'prioridad': ticket['prioridad']?.toString() ?? 'Normal',
          'departamento': ticket['departamento'],
          'categoria': ticket['categoria'],
          'agente': ticket['agente']?.toString() ?? 'Sin asignar',
          'usuario': ticket['usuario']?.toString() ?? 'Usuario desconocido',
          'creado': ticket['fecha_creacion']?.toString() ?? '',
          'id_usuario': ticket['id_usuario']?.toString() ?? '',
          'id_agente': ticket['id_agente']?.toString(),
          'id_departamento': ticket['id_departamento']?.toString(),
          'id_categoria': ticket['id_categoria']?.toString(),
          'id_estado': ticket['id_estado'],
          'adjunto': ticket['adjunto']?.toString() ?? '',
          'sucursal': ticket['sucursal'],
        };
      }).toList();
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
  Future<void> updateTicket(String id, Map<String, dynamic> ticketData) async {
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
  Future<void> deleteTicket(String id) async {
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
    final response = await protectedRequest(
      (token) => http.get(
      Uri.parse('$baseUrl/prioridades'),
      headers: {'Authorization': 'Bearer $token'},
      ),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Error al obtener prioridades: ${response.body}');
    }
  }

  // 🔹 Obtener departamentos
  Future<List<dynamic>> getDepartamentos() async {
    final response = await protectedRequest(
      (token) => http.get(
      Uri.parse('$baseUrl/departamentos'),
      headers: {'Authorization': 'Bearer $token'},
      ),
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
        return;
      } else {
        throw Exception('Error al crear el departamento: ${response.body}');
      }
    } catch (e) {
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
    final response = await protectedRequest(
      (token) => http.get(
        Uri.parse('$baseUrl/usuarios/estados'),
      headers: {'Authorization': 'Bearer $token'},
      ),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception(
          'Error al obtener los estados de usuario: ${response.body}');
    }
  }

  // 🔹 Obtener comentarios de un ticket
  Future<List<dynamic>> getComentarios(String ticketId) async {
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
      String ticketId, Map<String, dynamic> comentarioData) async {
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
  Future<void> asignarTicket(String ticketId, String agenteId) async {
    String? token = await _getToken();
    if (token == null) throw Exception('Token no encontrado');

    final response = await http.put(
      Uri.parse('$baseUrl/tickets/$ticketId/assign'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({'agente_id': agenteId}),
    );

    if (response.statusCode != 200) {
      throw Exception('Error al asignar el ticket: ${response.body}');
    }
  }

  // 🔹 Obtener lista de agentes
  Future<List<dynamic>> getAgentes() async {
    final response = await protectedRequest(
      (token) => http.get(
        Uri.parse('$baseUrl/agentes'),
      headers: {'Authorization': 'Bearer $token'},
      ),
    );
    if (response.statusCode == 200) {
      List<dynamic> agentes = json.decode(response.body);
      // Validación silenciosa de agentes sin nombre
      for (var agente in agentes) {
        if (agente['nombre'] == null) {
          // Log silencioso para evitar sobrecarga en producción
        }
      }
      return agentes;
    } else {
      throw Exception('Error al obtener la lista de agentes: ${response.body}');
    }
  }

  // 🔹 Obtener lista de agentes con sus departamentos asignados
  Future<List<dynamic>> getAgentesConDepartamentos() async {
    final response = await protectedRequest(
      (token) => http.get(
        Uri.parse('$baseUrl/agentes/departamentos'),
      headers: {'Authorization': 'Bearer $token'},
      ),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Error al obtener agentes: ${response.body}');
    }
  }

  // 🔹 Obtener sucursales
  Future<List<dynamic>> getSucursales() async {
    final response = await protectedRequest(
      (token) => http.get(
        Uri.parse("$baseUrl/sucursales"),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception("Error al obtener sucursales");
    }
  }

  // 🔹 Obtener roles
  Future<List<dynamic>> getRoles() async {
    final response = await protectedRequest(
      (token) => http.get(
        Uri.parse("$baseUrl/roles"),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception("Error al obtener roles");
    }
  }

  // Método para actualizar usuarios
  Future<void> updateUser(String userId, Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    // Debug temporal
    print('🔍 DEBUG - updateUser:');
    print('  URL: $baseUrl/usuarios/$userId');
    print('  UserData: $userData');

    final response = await http.put(
      Uri.parse('$baseUrl/usuarios/$userId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(userData),
    );

    print('🔍 DEBUG - Response Status: ${response.statusCode}');
    print('🔍 DEBUG - Response Body: ${response.body}');

    if (response.statusCode != 200) {
      throw Exception('Error al actualizar usuario: ${response.body}');
    }
  }

  // 🔹 Subir archivo adjunto
  Future<void> subirArchivo(Uint8List archivoBytes, String fileName, String ticketId) async {
    String? token = await _getToken();
    if (token == null) throw Exception('Token no encontrado');

    try {
      // Crear la solicitud multipart
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/tickets/$ticketId/upload'),
      );

      // Agregar el token de autorización
      request.headers['Authorization'] = 'Bearer $token';

      // Agregar el archivo como multipart
      request.files.add(
        http.MultipartFile.fromBytes(
        'file',
        archivoBytes,
        filename: fileName,
        ),
      );

      // Enviar la solicitud
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        throw Exception('Error al subir el archivo: ${response.body}');
      }

      // Obtener el ticket actual para ver los archivos existentes
      final ticketResponse = await http.get(
        Uri.parse('$baseUrl/tickets/$ticketId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (ticketResponse.statusCode != 200) {
        throw Exception('Error al obtener el ticket: ${ticketResponse.body}');
      }

      // Obtener los archivos adjuntos actuales
      Map<String, dynamic> ticketData = jsonDecode(ticketResponse.body);
      String archivosActuales = ticketData['adjunto'] ?? '';
      List<String> listaArchivos = archivosActuales.isEmpty ? [] : archivosActuales.split(',').where((a) => a.isNotEmpty).toList();

      // Obtener el nombre único del archivo de la respuesta
      Map<String, dynamic> uploadResponse = jsonDecode(response.body);
      String uniqueFilename = uploadResponse['adjunto'].split(',').last;

      // Verificar si el archivo ya existe en la lista usando el nombre único
      if (!listaArchivos.contains(uniqueFilename)) {
        // Agregar el nuevo archivo a la lista
        listaArchivos.add(uniqueFilename);

        // Actualizar el ticket con la nueva lista de archivos
        final updateResponse = await http.put(
          Uri.parse('$baseUrl/tickets/$ticketId'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'adjunto': listaArchivos.join(','),
          }),
        );

        if (updateResponse.statusCode != 200) {
          throw Exception('Error al actualizar el ticket: ${updateResponse.body}');
        }
      }
    } catch (e) {
      throw Exception('Error al subir el archivo: $e');
    }
  }

// Metodo para agregar comentario al ticket
  Future<void> agregarComentario(String ticketId, String comentario) async {
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
  Future<void> cambiarEstadoTicket(String ticketId, String nuevoEstado) async {
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

// Metodo para obtener comentario al ticket
  Future<List<dynamic>> obtenerComentarios(String ticketId) async {
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
      String userId, String oldPassword, String newPassword) async {
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
  Future<void> deleteUser(String userId) async {
    final String url = '$baseUrl/usuarios/$userId';

    final response = await http.delete(
      Uri.parse(url),
      headers: await getHeaders(), // ✅ Ahora funcionará correctamente
    );

    // Logs removidos para evitar sobrecarga en producción

    if (response.statusCode != 200) {
      throw Exception('Error al eliminar el usuario: \\${response.body}');
    }
  }

  // 🔹 Obtener agentes por departamento
  Future<List<dynamic>> getAgentesPorDepartamento(int departamentoId) async {
    final response = await protectedRequest(
      (token) => http.get(
        Uri.parse('$baseUrl/departamentos/$departamentoId/agentes'),
      headers: {'Authorization': 'Bearer $token'},
      ),
    );
    if (response.statusCode == 200) {
      List agentes = json.decode(response.body);
      return agentes;
    } else {
      throw Exception('Error al obtener los agentes');
    }
  }



  // Método para crear un nuevo usuario
  Future<dynamic> createUser(Map<String, dynamic> userData) async {
    String? token = await _getToken();
    if (token == null) throw Exception('Token no encontrado');

    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode(userData),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body); // Devuelve la respuesta del backend
    } else {
      throw Exception('Error al crear el usuario: ${response.body}');
    }
  }

  // 🔹 Eliminar un adjunto de un ticket
  Future<void> eliminarAdjunto(String ticketId, String nombreAdjunto) async {
    String? token = await _getToken();
    if (token == null) throw Exception('Token no encontrado');

    final response = await http.delete(
      Uri.parse('$baseUrl/tickets/$ticketId/adjunto/$nombreAdjunto'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Error al eliminar adjunto: ${response.body}');
    }
  }

  // Método para cerrar el ticket
  Future<Map<String, dynamic>> cerrarTicket(String ticketId, String comentario) async {
    try {
      String? token = await _getToken();
      if (token == null) throw Exception('Token no encontrado');
      
      final response = await http.put(
        Uri.parse('$baseUrl/tickets/$ticketId/cerrar'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'comentario': comentario,
          'fecha_cierre': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Error al cerrar el ticket: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error al cerrar el ticket: $e');
    }
  }

  Future<Map<String, dynamic>> actualizarTicket(String id, Map<String, dynamic> datos) async {
    try {
      String? token = await _getToken();
      if (token == null) throw Exception('Token no encontrado');

      // Asegurarnos de que la fecha de actualización esté en el formato correcto y en UTC
      if (datos['fecha_actualizacion'] != null) {
        final fecha = DateTime.now().toUtc();
        datos['fecha_actualizacion'] = fecha.toIso8601String();
      }

      final response = await http.put(
        Uri.parse('$baseUrl/tickets/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(datos),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Error al actualizar el ticket: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error al actualizar el ticket: $e');
    }
  }

  // 🔹 Obtener colaboradores
  Future<List<dynamic>> getColaboradores() async {
    final response = await protectedRequest(
      (token) => http.get(
        Uri.parse('$baseUrl/colaboradores'),
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Error al obtener la lista de colaboradores');
    }
  }

  Future<void> editarDepartamento(int id, String nombre) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) throw Exception('No se encontró el token de autenticación');

    final response = await http.put(
      Uri.parse('$baseUrl/departamentos/$id'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'nombre': nombre}),
    );

    if (response.statusCode != 200) {
      throw Exception('Error al editar el departamento: ${response.body}');
    }
  }

  Future<void> asignarDepartamentos(String agenteId, List<int> idDepartamentos) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) throw Exception('No se encontró el token de autenticación');

    final response = await http.put(
      Uri.parse('$baseUrl/agentes/$agenteId/departamentos'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'id_departamentos': idDepartamentos}),
    );

    if (response.statusCode != 200) {
      throw Exception('Error al asignar departamentos: ${response.body}');
    }
  }

  Future<Map<String, List<dynamic>>> getAgentesAgrupadosPorSucursal() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) throw Exception('Token no encontrado');

    final response = await http.get(
      Uri.parse('$baseUrl/agentes/agrupados-por-sucursal'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      // Se espera que el backend devuelva un mapa {sucursal: [agentes]}
      return Map<String, List<dynamic>>.from(
        data.map((k, v) => MapEntry(k, List<dynamic>.from(v)))
      );
    } else {
      throw Exception('Error al obtener agentes agrupados: ${response.body}');
    }
  }

  // Método para hacer peticiones autenticadas
  Future<dynamic> _makeAuthenticatedRequest(String method, String endpoint) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) throw Exception('Token no encontrado');

    final response = await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Error en la petición: ${response.body}');
    }
  }

  // 🔹 Asignar un departamento a un agente
  Future<void> asignarDepartamento(String agenteId, int departamentoId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
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

  Future<List<dynamic>> getCategorias(String departamentoId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      if (token == null) throw Exception('Token no encontrado');

      final response = await http.get(
        Uri.parse('$baseUrl/categorias?departamento_id=$departamentoId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Error al obtener categorías: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // 🔹 Obtener todas las categorías (para administradores)
  Future<List<dynamic>> getAdminCategorias() async {
    final response = await protectedRequest(
      (token) => http.get(
        Uri.parse('$baseUrl/admin/categorias'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Error al obtener las categorías: ${response.body}');
    }
  }

  // 🔹 Crear nueva categoría (para administradores)
  Future<Map<String, dynamic>> createCategoria(Map<String, dynamic> categoriaData) async {
    final response = await protectedRequest(
      (token) => http.post(
        Uri.parse('$baseUrl/admin/categorias'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(categoriaData),
      ),
    );
    if (response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception('Error al crear la categoría: ${response.body}');
    }
  }

  // 🔹 Editar categoría existente (para administradores)
  Future<void> updateCategoria(String categoriaId, Map<String, dynamic> categoriaData) async {
    if (kDebugMode) {
      print('🔍 DEBUG - updateCategoria llamado con:');
      print('  ID de categoría: $categoriaId');
      print('  Datos: $categoriaData');
    }
    
    final response = await protectedRequest(
      (token) => http.put(
        Uri.parse('$baseUrl/admin/categorias/$categoriaId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(categoriaData),
      ),
    );
    
    if (kDebugMode) {
      print('🔍 DEBUG - Respuesta del backend:');
      print('  Status: ${response.statusCode}');
      print('  Body: ${response.body}');
    }
    
    if (response.statusCode == 200) {
      return;
    } else {
      throw Exception('Error al actualizar la categoría: ${response.body}');
    }
  }

  // 🔹 Eliminar categoría (para administradores)
  Future<void> deleteCategoria(String categoriaId) async {
    final response = await protectedRequest(
      (token) => http.delete(
        Uri.parse('$baseUrl/admin/categorias/$categoriaId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Error al eliminar la categoría: ${response.body}');
    }
  }

  // 🔹 Obtener usuarios disponibles para una categoría (para administradores)
  Future<List<dynamic>> getUsuariosDisponiblesCategoria(String categoriaId) async {
    final response = await protectedRequest(
      (token) => http.get(
        Uri.parse('$baseUrl/admin/categorias/$categoriaId/usuarios-disponibles'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Error al obtener usuarios disponibles: ${response.body}');
    }
  }

  // 🔹 Obtener agentes disponibles para una categoría (para administradores)
  Future<List<dynamic>> getAgentesDisponiblesCategoria(String categoriaId) async {
    if (kDebugMode) {
      print('🔍 DEBUG - getAgentesDisponiblesCategoria llamado con:');
      print('  ID de categoría: $categoriaId');
    }
    
    final response = await protectedRequest(
      (token) => http.get(
        Uri.parse('$baseUrl/admin/categorias/$categoriaId/agentes-disponibles?categoria_id=$categoriaId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ),
    );
    
    if (kDebugMode) {
      print('🔍 DEBUG - Respuesta de agentes disponibles:');
      print('  Status: ${response.statusCode}');
      print('  Body: ${response.body}');
    }
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Error al obtener agentes disponibles: ${response.body}');
    }
  }

  // 🔹 Obtener todas las apps disponibles (para administradores)
  Future<List<dynamic>> getAdminApps() async {
    final response = await protectedRequest(
      (token) => http.get(
        Uri.parse('$baseUrl/admin/apps'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Error al obtener las apps: ${response.body}');
    }
  }

  // 🔹 Crear nueva app (para administradores)
  Future<Map<String, dynamic>> createApp(Map<String, dynamic> appData) async {
    final response = await protectedRequest(
      (token) => http.post(
        Uri.parse('$baseUrl/admin/apps'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(appData),
      ),
    );
    if (response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      throw Exception('Error al crear la app: ${response.body}');
    }
  }

  // 🔹 Editar app existente (para administradores)
  Future<Map<String, dynamic>> updateApp(String appId, Map<String, dynamic> appData) async {
    final response = await protectedRequest(
      (token) => http.put(
        Uri.parse('$baseUrl/admin/apps/$appId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(appData),
      ),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Error al actualizar la app: ${response.body}');
    }
  }

  // 🔹 Eliminar app (para administradores)
  Future<void> deleteApp(String appId) async {
    final response = await protectedRequest(
      (token) => http.delete(
        Uri.parse('$baseUrl/admin/apps/$appId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Error al eliminar la app: ${response.body}');
    }
  }

  // 🔹 Obtener apps de un usuario específico (para administradores)
  Future<Map<String, dynamic>> getUsuarioAppsById(String userId) async {
    final response = await protectedRequest(
      (token) => http.get(
        Uri.parse('$baseUrl/admin/usuarios/$userId/apps'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Error al obtener apps del usuario: ${response.body}');
    }
  }

  // 🔹 Obtener todos los usuarios con sus apps (optimizado para administradores)
  Future<List<dynamic>> getUsuariosConApps() async {
    final response = await protectedRequest(
      (token) => http.get(
        Uri.parse('$baseUrl/admin/usuarios/apps'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Error al obtener usuarios con apps: ${response.body}');
    }
  }

  // 🔹 Asignar apps a un usuario (para administradores)
  Future<Map<String, dynamic>> asignarAppsUsuario(String userId, List<String> appIds) async {
    final response = await protectedRequest(
      (token) => http.put(
        Uri.parse('$baseUrl/admin/usuarios/$userId/apps'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'app_ids': appIds}),
      ),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Error al asignar apps al usuario: ${response.body}');
    }
  }

  // 🔹 Obtener las apps a las que tiene acceso el usuario actual
  Future<List<dynamic>> getUsuarioApps() async {
    final response = await protectedRequest(
      (token) => http.get(
        Uri.parse('$baseUrl/usuario/apps'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Error al obtener las apps del usuario: ${response.body}');
    }
  }

  // 🔹 Obtener agentes disponibles para reasignar un ticket
  Future<List<dynamic>> getAgentesDisponiblesTicket(String ticketId) async {
    final response = await protectedRequest(
      (token) => http.get(
        Uri.parse('$baseUrl/tickets/$ticketId/agentes-disponibles'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Error al obtener agentes disponibles: ${response.body}');
    }
  }

  // 🔹 Reasignar ticket a un nuevo agente
  Future<Map<String, dynamic>> reasignarTicket(String ticketId, String nuevoAgenteId) async {
    final response = await protectedRequest(
      (token) => http.put(
        Uri.parse('$baseUrl/tickets/$ticketId/assign'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'agente_id': nuevoAgenteId}),
      ),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Error al reasignar el ticket: ${response.body}');
    }
  }
}
