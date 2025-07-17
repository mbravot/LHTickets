import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AgentManagementScreen extends StatefulWidget {
  const AgentManagementScreen({super.key});

  @override
  _AgentManagementScreenState createState() => _AgentManagementScreenState();
}

class _AgentManagementScreenState extends State<AgentManagementScreen>
    with SingleTickerProviderStateMixin {
  final ApiService apiService = ApiService();
  List<dynamic> agentes = [];
  List<dynamic> departamentos = [];
  List<dynamic> usuarios = [];
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
      agentes = await apiService.getAgentesConDepartamentos();
      departamentos = await apiService.getDepartamentos();
      usuarios = await apiService.getUsuarios();
      setState(() => _isLoading = false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error al cargar los datos'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  void _asignarDepartamento(int agenteId, int departamentoId) async {
    try {
      setState(() => _isLoading = true);
      await apiService.asignarDepartamento(agenteId.toString(), departamentoId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Departamento asignado correctamente'),
          backgroundColor: Colors.green,
        ),
      );
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

  Map<String, List<dynamic>> _agruparAgentesPorSucursal() {
    Map<String, List<dynamic>> agentesPorSucursal = {};
    for (var agente in agentes) {
      String sucursal = (agente['sucursal'] ?? agente['sucursal_activa'] ?? 'Sin sucursal').toString();
      if (!agentesPorSucursal.containsKey(sucursal)) {
        agentesPorSucursal[sucursal] = [];
      }
      agentesPorSucursal[sucursal]!.add(agente);
    }
    // Ordenar las sucursales alfabéticamente
    agentesPorSucursal = Map.fromEntries(
      agentesPorSucursal.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    // Ordenar los agentes alfabéticamente dentro de cada sucursal
    agentesPorSucursal.forEach((key, value) {
      value.sort((a, b) => a['nombre'].toString().compareTo(b['nombre'].toString()));
    });
    return agentesPorSucursal;
  }

  List<dynamic> _filtrarAgentes(List<dynamic> agentes) {
    if (_searchQuery.isEmpty) {
      return agentes;
    }
    return agentes
        .where((agente) =>
            agente['nombre'].toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  List<dynamic> _obtenerAgentesPaginados(List<dynamic> agentes) {
    int startIndex = _currentPage * _itemsPerPage;
    int endIndex = startIndex + _itemsPerPage;
    if (endIndex > agentes.length) {
      endIndex = agentes.length;
    }
    return agentes.sublist(startIndex, endIndex);
  }

  bool _hayMasPaginas(List<dynamic> agentesFiltrados) {
    int startIndex = (_currentPage + 1) * _itemsPerPage;
    return startIndex < agentesFiltrados.length;
  }

  Widget _buildAgentCard(dynamic agente, String sucursal) {
    // Obtener departamentos del agente
    List<String> nombresDepartamentos = [];
    if (agente['departamentos'] != null && agente['departamentos'] is List) {
      nombresDepartamentos = (agente['departamentos'] as List)
        .map((d) => d is Map && d['nombre'] != null ? d['nombre'].toString() : d.toString())
        .toList();
    }
    // Buscar usuario por id_usuario
    final usuario = usuarios.firstWhere(
      (u) => u['id'].toString() == (agente['id_usuario']?.toString() ?? agente['id']?.toString()),
      orElse: () => null,
    );
    final correo = usuario != null ? usuario['correo'] ?? '' : '';
    final sucursalActiva = usuario != null ? (usuario['sucursal'] ?? usuario['sucursal_activa'] ?? '') : '';
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
                    Icons.person,
                    color: primaryColor,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        agente['nombre'] ?? agente['usuario'] ?? '',
                        style: cardTitleStyle,
                      ),
                      Text(
                        correo,
                        style: cardSubtitleStyle,
                      ),
                      Text(
                        'Sucursal: $sucursalActiva',
                        style: cardSubtitleStyle,
                      ),
                      if (nombresDepartamentos.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Wrap(
                            spacing: 6.0,
                            runSpacing: 2.0,
                            children: nombresDepartamentos.map((dep) => Chip(
                              label: Text(dep, style: TextStyle(fontSize: 12)),
                              backgroundColor: primaryColor.withOpacity(0.1),
                              labelStyle: TextStyle(color: primaryColor),
                            )).toList(),
                          ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit, color: primaryColor),
                  tooltip: 'Asignar departamentos',
                  onPressed: () async {
                    List<int> selectedIds = [];
                    var rawList = (agente['departamentos_id'] ?? agente['departamentos'] ?? []) as List;
                    for (var d in rawList) {
                      int? id = d is int ? d : int.tryParse(d.toString());
                      if (id != null) selectedIds.add(id);
                    }
                    final result = await showDialog<List>(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: Text('Asignar Departamentos'),
                          content: StatefulBuilder(
                            builder: (context, setStateDialog) {
                              return SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: departamentos.map<Widget>((dep) {
                                    int depId = 0;
                                    if (dep['id'] is int) {
                                      depId = dep['id'];
                                    } else if (dep['id'] is String) {
                                      depId = int.tryParse(dep['id']) ?? 0;
                                    }
                                    return CheckboxListTile(
                                      value: selectedIds.contains(depId),
                                      title: Text(dep['nombre']),
                                      onChanged: (checked) {
                                        setStateDialog(() {
                                          if (checked == true) {
                                            if (!selectedIds.contains(depId)) selectedIds.add(depId);
                                          } else {
                                            selectedIds.remove(depId);
                                          }
                                        });
                                      },
                    );
                  }).toList(),
                                ),
                              );
                            },
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text('Cancelar', style: TextStyle(color: Colors.red)),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.of(context).pop(selectedIds),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                              child: Text('Guardar', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        );
                      },
                    );
                    if (result != null) {
                      try {
                        final idsInt = (result as List)
                          .map((e) => int.tryParse(e.toString()) ?? 0)
                          .where((e) => e != 0)
                          .toList();
                        await apiService.asignarDepartamentos(agente['id'], idsInt);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('✅ Departamentos asignados correctamente'), backgroundColor: Colors.green),
                        );
                        _loadData();
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
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
    final agentesPorSucursal = _agruparAgentesPorSucursal();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.supervisor_account, color: secondaryColor),
            SizedBox(width: 8),
            Text(
              'Gestión de Agentes',
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
                        hintText: 'Buscar agente...',
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
                      itemCount: agentesPorSucursal.length,
                      itemBuilder: (context, index) {
                        final entry = agentesPorSucursal.entries.elementAt(index);
                        final sucursal = entry.key;
                        final agentesFiltrados = _filtrarAgentes(entry.value);
                        final agentesPaginados = _obtenerAgentesPaginados(agentesFiltrados);
                        if (agentesPaginados.isEmpty) return SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                sucursal,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                            ),
                            ...agentesPaginados.map((agente) => Padding(
                                  padding: EdgeInsets.only(bottom: 8),
                                  child: _buildAgentCard(agente, sucursal),
                                )),
                          ],
                        );
                      },
                    ),
                  ),
                  _buildPaginationControls(agentes.length),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Implementar creación de agente
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🚧 Función en desarrollo'),
              backgroundColor: Colors.orange,
            ),
          );
        },
        backgroundColor: primaryColor,
        icon: Icon(Icons.person_add, color: Colors.white),
        label: Text(
          'Nuevo Agente',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 4,
        tooltip: 'Crear nuevo agente',
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
