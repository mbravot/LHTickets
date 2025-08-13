import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:flutter/foundation.dart'; // Added for kDebugMode

class CategoriaManagementScreen extends StatefulWidget {
  const CategoriaManagementScreen({super.key});

  @override
  _CategoriaManagementScreenState createState() => _CategoriaManagementScreenState();
}

class _CategoriaManagementScreenState extends State<CategoriaManagementScreen>
    with SingleTickerProviderStateMixin {
  final ApiService apiService = ApiService();
  List<dynamic> categorias = [];
  List<dynamic> departamentos = [];
  List<dynamic> agentes = [];
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

  @override
  void initState() {
    super.initState();
    _loadData();

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

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);
      categorias = await apiService.getAdminCategorias();
      departamentos = await apiService.getDepartamentos();
      agentes = await apiService.getAgentes(); // Usar endpoint básico
      
      // Ordenar departamentos alfabéticamente como respaldo
      departamentos.sort((a, b) => a['nombre'].compareTo(b['nombre']));
      
      setState(() => _isLoading = false);
    } catch (e) {
      if (kDebugMode) {
  
      }
      setState(() => _isLoading = false);
    }
  }

  List<dynamic> _filtrarCategorias(List<dynamic> categorias) {
    if (_searchQuery.isEmpty) {
      return categorias;
    }
    return categorias
        .where((categoria) =>
            categoria['nombre'].toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  List<dynamic> _obtenerCategoriasPaginadas(List<dynamic> categorias) {
    int startIndex = _currentPage * _itemsPerPage;
    int endIndex = startIndex + _itemsPerPage;
    if (endIndex > categorias.length) {
      endIndex = categorias.length;
    }
    return categorias.sublist(startIndex, endIndex);
  }

  Map<String, List<dynamic>> _agruparCategoriasPorDepartamento() {
    Map<String, List<dynamic>> categoriasPorDepartamento = {};
    for (var categoria in categorias) {
      String departamentoNombre = _getDepartamentoNombre(categoria['id_departamento']);
      if (!categoriasPorDepartamento.containsKey(departamentoNombre)) {
        categoriasPorDepartamento[departamentoNombre] = [];
      }
      categoriasPorDepartamento[departamentoNombre]!.add(categoria);
    }
    // Ordenar los departamentos alfabéticamente
    categoriasPorDepartamento = Map.fromEntries(
      categoriasPorDepartamento.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    // Ordenar las categorías alfabéticamente dentro de cada departamento
    categoriasPorDepartamento.forEach((key, value) {
      value.sort((a, b) => a['nombre'].toString().compareTo(b['nombre'].toString()));
    });
    return categoriasPorDepartamento;
  }

  String _getDepartamentoNombre(dynamic departamentoId) {
    if (departamentoId == null) return 'Sin departamento';
    final departamento = departamentos.firstWhere(
      (d) => d['id'].toString() == departamentoId.toString(),
      orElse: () => null,
    );
    return departamento?['nombre'] ?? 'Departamento no encontrado';
  }

  String _getAgenteNombre(dynamic agenteId) {
    if (agenteId == null) return 'Sin agente asignado';
    final agente = agentes.firstWhere(
      (a) => a['id'].toString() == agenteId.toString(),
      orElse: () => null,
    );
    return agente?['nombre'] ?? 'Agente no encontrado';
  }

  Widget _buildCategoriaCard(dynamic categoria) {
    final departamentoNombre = _getDepartamentoNombre(categoria['id_departamento']);
    final agenteNombre = _getAgenteNombre(categoria['id_usuario']);
    
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
                    Icons.category,
                    color: primaryColor,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        categoria['nombre'] ?? '',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      Text(
                        'ID: ${categoria['id']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: primaryColor),
                  onSelected: (value) {
                    if (value == 'edit') {
                      _editarCategoria(categoria);
                    } else if (value == 'delete') {
                      _eliminarCategoria(categoria);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, color: primaryColor),
                          SizedBox(width: 8),
                          Text('Editar'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Eliminar'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                _buildInfoChip(
                  Icons.business,
                  departamentoNombre,
                  Colors.blue,
                ),
                SizedBox(width: 8),
                _buildInfoChip(
                  Icons.supervisor_account,
                  agenteNombre,
                  categoria['id_usuario'] != null ? Colors.green : Colors.grey,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: color,
          ),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _editarCategoria(dynamic categoria) async {
    await _mostrarFormularioCategoria(categoria);
  }

  void _crearCategoria() async {
    await _mostrarFormularioCategoria(null);
  }

  Future<void> _mostrarFormularioCategoria(dynamic categoria) async {
    final _formKey = GlobalKey<FormState>();
    final _nombreController = TextEditingController(text: categoria?['nombre'] ?? '');
    String? _selectedDepartamento = categoria?['id_departamento']?.toString();
    String? _selectedUsuario = categoria?['id_usuario']?.toString();
    List<dynamic> _agentesDisponibles = [];
    bool _isLoading = false;

    if (kDebugMode) {
      
    }

    // Cargar agentes disponibles si hay departamento seleccionado
    if (_selectedDepartamento != null) {
      try {
        // Obtener agentes del departamento específico usando el endpoint
        _agentesDisponibles = await apiService.getAgentesPorDepartamento(int.parse(_selectedDepartamento));
        
        // Si no hay agentes disponibles, mostrar mensaje
        if (_agentesDisponibles.isEmpty) {
          if (kDebugMode) {
  
          }
        }
      } catch (e) {
        if (kDebugMode) {

        }
        _agentesDisponibles = [];
      }
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(
                categoria == null ? Icons.add : Icons.edit,
                color: primaryColor,
              ),
              SizedBox(width: 8),
              Text(
                categoria == null ? 'Nueva Categoría' : 'Editar Categoría',
                style: TextStyle(color: primaryColor),
              ),
            ],
          ),
          content: Container(
            width: 400,
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _nombreController,
                    decoration: InputDecoration(
                      labelText: 'Nombre de la categoría',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: Icon(Icons.category, color: primaryColor),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'El nombre es requerido';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedDepartamento,
                    decoration: InputDecoration(
                      labelText: 'Departamento',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: Icon(Icons.business, color: primaryColor),
                    ),
                    items: departamentos.map((departamento) {
                      return DropdownMenuItem<String>(
                        value: departamento['id'].toString(),
                        child: Text(departamento['nombre']),
                      );
                    }).toList(),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'El departamento es requerido';
                      }
                      return null;
                    },
                    onChanged: (value) async {
                      setState(() {
                        _selectedDepartamento = value;
                        _selectedUsuario = null;
                        _isLoading = true;
                      });
                      
                      if (value != null) {
                        try {
                          // Obtener agentes del departamento específico usando el endpoint
                          _agentesDisponibles = await apiService.getAgentesPorDepartamento(int.parse(value));
                          
                          // Si no hay agentes disponibles, mostrar mensaje
                          if (_agentesDisponibles.isEmpty) {
                            if (kDebugMode) {
                  
                            }
                          }
                        } catch (e) {
                          if (kDebugMode) {
                
                          }
                          _agentesDisponibles = [];
                        }
                      } else {
                        _agentesDisponibles = [];
                      }
                      
                      setState(() {
                        _isLoading = false;
                      });
                    },
                  ),
                  SizedBox(height: 16),
                  if (_isLoading)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text('Cargando agentes disponibles...'),
                        ],
                      ),
                    ),
                  if (!_isLoading && _agentesDisponibles.isNotEmpty)
                    DropdownButtonFormField<String>(
                      value: _selectedUsuario,
                      decoration: InputDecoration(
                        labelText: 'Agente asignado (opcional)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        prefixIcon: Icon(Icons.person, color: primaryColor),
                      ),
                      items: [
                        DropdownMenuItem<String>(
                          value: null,
                          child: Text('Sin agente asignado'),
                        ),
                        ..._agentesDisponibles.map((agente) {
                          return DropdownMenuItem<String>(
                            value: agente['id'].toString(),
                            child: Text('${agente['nombre']} (${agente['usuario']})'),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedUsuario = value;
                        });
                      },
                    ),
                  if (!_isLoading && _agentesDisponibles.isEmpty && _selectedDepartamento != null)
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info, color: Colors.orange, size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'No hay agentes disponibles en este departamento',
                              style: TextStyle(
                                color: Colors.orange[700],
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  try {
                    setState(() => _isLoading = true);
                    
                    final categoriaData = {
                      'nombre': _nombreController.text.trim(),
                      'id_departamento': int.parse(_selectedDepartamento!),
                      if (_selectedUsuario != null) 'id_usuario': _selectedUsuario,
                    };

                    if (categoria == null) {
                      // Crear nueva categoría
                      await apiService.createCategoria(categoriaData);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('✅ Categoría creada correctamente'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else {
                      // Editar categoría existente
                      await apiService.updateCategoria(categoria['id'], categoriaData);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('✅ Categoría actualizada correctamente'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                    
                    Navigator.of(context).pop();
                    _loadData();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('❌ Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  } finally {
                    setState(() => _isLoading = false);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
              child: Text(categoria == null ? 'Crear' : 'Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _eliminarCategoria(dynamic categoria) async {
    final confirmacion = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmar eliminación'),
        content: Text('¿Estás seguro de que quieres eliminar la categoría "${categoria['nombre']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmacion == true) {
      try {
        setState(() => _isLoading = true);
        await apiService.deleteCategoria(categoria['id']);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Categoría eliminada correctamente'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al eliminar la categoría: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
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
    final categoriasPorDepartamento = _agruparCategoriasPorDepartamento();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.category, color: secondaryColor),
            SizedBox(width: 8),
            Text(
              'Gestión de Categorías',
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
            onPressed: _loadData,
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
                        hintText: 'Buscar categoría...',
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
                    child: ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      itemCount: categoriasPorDepartamento.length,
                      itemBuilder: (context, index) {
                        final entry = categoriasPorDepartamento.entries.elementAt(index);
                        final departamento = entry.key;
                        final categoriasFiltradas = _filtrarCategorias(entry.value);
                        final categoriasPaginadas = _obtenerCategoriasPaginadas(categoriasFiltradas);
                        if (categoriasPaginadas.isEmpty) return SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                departamento,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                            ...categoriasPaginadas.map((categoria) => Padding(
                                  padding: EdgeInsets.only(bottom: 8),
                                  child: _buildCategoriaCard(categoria),
                                )),
                          ],
                        );
                      },
                    ),
                  ),
                  _buildPaginationControls(categorias.length),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _crearCategoria();
        },
        backgroundColor: primaryColor,
        icon: Icon(Icons.add, color: Colors.white),
        label: Text(
          'Nueva Categoría',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 4,
        tooltip: 'Crear nueva categoría',
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
} 