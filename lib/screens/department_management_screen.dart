import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'department_create_screen.dart';

class DepartmentManagementScreen extends StatefulWidget {
  const DepartmentManagementScreen({super.key});

  @override
  _DepartmentManagementScreenState createState() =>
      _DepartmentManagementScreenState();
}

class _DepartmentManagementScreenState extends State<DepartmentManagementScreen>
    with SingleTickerProviderStateMixin {
  final ApiService apiService = ApiService();
  List<dynamic> departamentos = [];
  bool _isLoading = false;
  TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _currentPage = 0;
  final int _itemsPerPage = 10;

  // Animación
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Colores y estilos
  final Color primaryColor = Colors.green;
  final Color secondaryColor = Colors.white;
  final Color backgroundColor = Colors.grey[100]!;
  final TextStyle cardTitleStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: Colors.grey[800],
  );
  final TextStyle cardSubtitleStyle = TextStyle(
    fontSize: 14,
    color: Colors.grey[600],
  );

  @override
  void initState() {
    super.initState();
    _loadDepartamentos();

    // Inicializar animación
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _loadDepartamentos() async {
    try {
      setState(() => _isLoading = true);
      final deptos = await apiService.getDepartamentos();

      // Obtener agentes para cada departamento
      for (var depto in deptos) {
        try {
          final agentes =
              await apiService.getAgentesPorDepartamento(depto['id']);
          depto['agentes'] = agentes;
        } catch (e) {
          // Error al cargar agentes del departamento
          depto['agentes'] = [];
        }
      }

      setState(() {
        departamentos = deptos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      // Error al cargar departamentos
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error al cargar los departamentos'),
          backgroundColor: Colors.red,
        ),
      );
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

  Widget _buildDepartmentCard(dynamic departamento) {
    return Card(
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: primaryColor.withOpacity(0.1),
                  child: Icon(
                    Icons.business,
                    color: primaryColor,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        departamento['nombre'],
                        style: cardTitleStyle,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit, color: primaryColor),
                  onPressed: () async {
                    final TextEditingController _editController = TextEditingController(text: departamento['nombre']);
                    final result = await showDialog<String>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('Editar Departamento'),
                        content: TextField(
                          controller: _editController,
                          decoration: InputDecoration(labelText: 'Nombre'),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text('Cancelar', style: TextStyle(color: Colors.red)),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(_editController.text),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            child: Text('Editar', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                    if (result != null && result.trim().isNotEmpty && result != departamento['nombre']) {
                      try {
                        await apiService.editarDepartamento(departamento['id'], result.trim());
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('✅ Departamento actualizado'), backgroundColor: Colors.green),
                        );
                        _loadDepartamentos();
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('❌ Error al editar: $e'), backgroundColor: Colors.red),
                    );
                      }
                    }
                  },
                  tooltip: 'Editar departamento',
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('Eliminar Departamento'),
                        content: Text('¿Estás seguro de eliminar este departamento?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: Text('Cancelar', style: TextStyle(color: Colors.green)),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            child: Text('Eliminar', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      try {
                        await apiService.eliminarDepartamento(departamento['id']);
                    ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('✅ Departamento eliminado'), backgroundColor: Colors.green),
                        );
                        _loadDepartamentos();
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('❌ Error al eliminar: $e'), backgroundColor: Colors.red),
                    );
                      }
                    }
                  },
                  tooltip: 'Eliminar departamento',
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.people, size: 16, color: Colors.grey[600]),
                SizedBox(width: 8),
                Text(
                  "Agentes: ${departamento['agentes']?.length ?? 0}",
                  style: cardSubtitleStyle,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaginationControls(int totalItems) {
    int totalPages = (totalItems / _itemsPerPage).ceil();

    return Container(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton.icon(
            icon: Icon(Icons.arrow_back),
            label: Text('Anterior'),
            onPressed: _currentPage > 0
                ? () {
                    setState(() {
                      _currentPage--;
                    });
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "Página ${_currentPage + 1} de $totalPages",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton.icon(
            icon: Icon(Icons.arrow_forward),
            label: Text('Siguiente'),
            onPressed: _currentPage < totalPages - 1
                ? () {
                    setState(() {
                      _currentPage++;
                    });
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final departamentosFiltrados = _filtrarDepartamentos(departamentos);
    final departamentosPaginados =
        _obtenerDepartamentosPaginados(departamentosFiltrados);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.business, color: secondaryColor),
            SizedBox(width: 8),
            Text(
              'Gestión de Departamentos',
              style: TextStyle(
                color: secondaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        backgroundColor: primaryColor,
        elevation: 4,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: secondaryColor),
            onPressed: _loadDepartamentos,
            tooltip: 'Recargar lista',
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                ),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Buscar departamento...',
                        prefixIcon: Icon(Icons.search, color: primaryColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: primaryColor, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                          _currentPage = 0;
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: departamentosPaginados.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.business,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No hay departamentos',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Agrega un nuevo departamento',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            itemCount: departamentosPaginados.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: EdgeInsets.only(bottom: 8),
                                child: _buildDepartmentCard(
                                    departamentosPaginados[index]),
                              );
                            },
                          ),
                  ),
                  _buildPaginationControls(departamentosFiltrados.length),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DepartmentCreateScreen(),
            ),
          ).then((result) {
            if (result == true) {
              _loadDepartamentos();
            }
          });
        },
        backgroundColor: primaryColor,
        icon: Icon(Icons.add, color: Colors.white),
        label: Text(
          'Nuevo Departamento',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 4,
        tooltip: 'Crear nuevo departamento',
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
