import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'user_edit_screen.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  _UserManagementScreenState createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final ApiService apiService = ApiService();
  List<dynamic> usuarios = [];
  bool _isLoading = false;
  TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _currentPage = 0;
  final int _itemsPerPage = 10; // Número de usuarios por página

  @override
  void initState() {
    super.initState();
    _loadUsuarios();
  }

  void _loadUsuarios() async {
    try {
      setState(() => _isLoading = true);
      final users = await apiService.getUsuariosActivos();
      setState(() {
        usuarios = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print("❌ Error al cargar usuarios: $e");
    }
  }

  List<dynamic> _filtrarUsuarios(List<dynamic> usuarios) {
    if (_searchQuery.isEmpty) {
      return usuarios;
    }
    return usuarios
        .where((user) =>
            user['nombre'].toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  List<dynamic> _obtenerUsuariosPaginados(List<dynamic> usuarios) {
    int startIndex = _currentPage * _itemsPerPage;
    int endIndex = startIndex + _itemsPerPage;
    if (endIndex > usuarios.length) {
      endIndex = usuarios.length;
    }
    return usuarios.sublist(startIndex, endIndex);
  }

  bool _hayMasPaginas(List<dynamic> usuariosFiltrados) {
    int startIndex = (_currentPage + 1) * _itemsPerPage;
    return startIndex < usuariosFiltrados.length;
  }

  @override
  Widget build(BuildContext context) {
    final usuariosFiltrados = _filtrarUsuarios(usuarios);
    final usuariosPaginados = _obtenerUsuariosPaginados(usuariosFiltrados);

    return Scaffold(
      appBar: AppBar(
        title: Text('Gestión de Usuarios'),
        backgroundColor: Colors.green, // Fondo verde
        foregroundColor: Colors.white, // Texto blanco
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadUsuarios, // Botón para recargar la lista
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 🔹 Buscador
                Padding(
                  padding: EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar usuario...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                        _currentPage = 0; // Reiniciar la paginación al buscar
                      });
                    },
                  ),
                ),

                // 🔹 Lista de usuarios
                Expanded(
                  child: ListView.builder(
                    itemCount: usuariosPaginados.length,
                    itemBuilder: (context, index) {
                      final user = usuariosPaginados[index];
                      return Card(
                        margin:
                            EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          title: Text(
                            user['nombre'],
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Correo: ${user['correo']}'),
                              Text('Rol: ${user['rol'] ?? 'Sin asignar'}'),
                              Text(
                                  'Estado: ${user['estado'] ?? 'Desconocido'}'),
                            ],
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.edit, color: Colors.green),
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      UserEditScreen(user: user),
                                ),
                              );

                              if (result == true) {
                                _loadUsuarios(); // Recargar lista tras edición
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // 🔹 Controles de paginación
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back),
                        onPressed: _currentPage > 0
                            ? () {
                                setState(() {
                                  _currentPage--;
                                });
                              }
                            : null,
                      ),
                      Text('Página ${_currentPage + 1}'),
                      IconButton(
                        icon: Icon(Icons.arrow_forward),
                        onPressed: () {
                          if (_hayMasPaginas(usuariosFiltrados)) {
                            setState(() {
                              _currentPage++;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
