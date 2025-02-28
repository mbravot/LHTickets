import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'department_create_screen.dart';

class DepartmentManagementScreen extends StatefulWidget {
  const DepartmentManagementScreen({super.key});

  @override
  _DepartmentManagementScreenState createState() =>
      _DepartmentManagementScreenState();
}

class _DepartmentManagementScreenState
    extends State<DepartmentManagementScreen> {
  final ApiService apiService = ApiService();
  List<dynamic> departamentos = [];
  bool _isLoading = false;
  TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _currentPage = 0;
  final int _itemsPerPage = 10; // Número de departamentos por página

  @override
  void initState() {
    super.initState();
    _loadDepartamentos();
  }

  void _loadDepartamentos() async {
    try {
      setState(() => _isLoading = true);
      final deptos = await apiService.getDepartamentos();
      setState(() {
        departamentos = deptos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print("❌ Error al cargar departamentos: $e");
    }
  }

  List<dynamic> _filtrarDepartamentos(List<dynamic> departamentos) {
    if (_searchQuery.isEmpty) {
      return departamentos;
    }
    return departamentos
        .where((depto) =>
            depto['nombre'].toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  List<dynamic> _obtenerDepartamentosPaginados(List<dynamic> departamentos) {
    int startIndex = _currentPage * _itemsPerPage;
    int endIndex = startIndex + _itemsPerPage;
    if (endIndex > departamentos.length) {
      endIndex = departamentos.length;
    }
    return departamentos.sublist(startIndex, endIndex);
  }

  bool _hayMasPaginas(List<dynamic> departamentosFiltrados) {
    int startIndex = (_currentPage + 1) * _itemsPerPage;
    return startIndex < departamentosFiltrados.length;
  }

  void _eliminarDepartamento(int id) async {
    bool confirmar = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Confirmar eliminación'),
            content:
                Text('¿Estás seguro de que deseas eliminar este departamento?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('Eliminar', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmar) {
      try {
        await apiService.eliminarDepartamento(id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Departamento eliminado correctamente')),
        );
        _loadDepartamentos(); // Recargar la lista
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error al eliminar el departamento: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final departamentosFiltrados = _filtrarDepartamentos(departamentos);
    final departamentosPaginados =
        _obtenerDepartamentosPaginados(departamentosFiltrados);

    return Scaffold(
      appBar: AppBar(
        title: Text('Gestión de Departamentos'),
        backgroundColor: Colors.green, // Fondo verde
        foregroundColor: Colors.white, // Texto blanco
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
                      hintText: 'Buscar departamento...',
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

                // 🔹 Lista de departamentos
                Expanded(
                  child: ListView.builder(
                    itemCount: departamentosPaginados.length,
                    itemBuilder: (context, index) {
                      final depto = departamentosPaginados[index];
                      return Card(
                        margin:
                            EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListTile(
                          title: Text(depto['nombre']),
                          subtitle: Text('ID: ${depto['id']}'),
                          trailing: IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _eliminarDepartamento(depto['id']),
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
                          if (_hayMasPaginas(departamentosFiltrados)) {
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DepartmentCreateScreen(),
            ),
          ).then((result) {
            if (result == true) {
              _loadDepartamentos(); // Recargar la lista después de crear un departamento
            }
          });
        },
        child: Icon(Icons.add),
        backgroundColor: Colors.green, // Fondo verde
      ),
    );
  }
}
