import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AgentManagementScreen extends StatefulWidget {
  @override
  _AgentManagementScreenState createState() => _AgentManagementScreenState();
}

class _AgentManagementScreenState extends State<AgentManagementScreen> {
  final ApiService apiService = ApiService();
  List<dynamic> agentes = [];
  List<dynamic> departamentos = [];
  bool _isLoading = false;
  TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _currentPage = 0;
  final int _itemsPerPage = 10; // Número de agentes por página

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);
      agentes = await apiService.getAgentesConDepartamentos();
      departamentos = await apiService.getDepartamentos();
      setState(() => _isLoading = false);
    } catch (e) {
      print("❌ Error al cargar datos: $e");
      setState(() => _isLoading = false);
    }
  }

  void _asignarDepartamento(int agenteId, int departamentoId) async {
    try {
      await apiService.asignarDepartamento(agenteId, departamentoId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Departamento asignado correctamente')),
      );
      _loadData(); // Recargar la lista de agentes
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Map<String, List<dynamic>> _agruparAgentesPorDepartamento() {
    Map<String, List<dynamic>> agentesPorDepartamento = {};

    for (var agente in agentes) {
      String departamento = agente['departamentos'].isNotEmpty
          ? agente['departamentos'].join(', ')
          : 'Sin asignar';

      if (!agentesPorDepartamento.containsKey(departamento)) {
        agentesPorDepartamento[departamento] = [];
      }
      agentesPorDepartamento[departamento]!.add(agente);
    }

    // Ordenar los departamentos alfabéticamente
    agentesPorDepartamento = Map.fromEntries(
      agentesPorDepartamento.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key)),
    );

    // Ordenar los agentes alfabéticamente dentro de cada departamento
    agentesPorDepartamento.forEach((key, value) {
      value.sort((a, b) => a['nombre'].compareTo(b['nombre']));
    });

    return agentesPorDepartamento;
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

  // Método para verificar si hay más páginas
  bool _hayMasPaginas(List<dynamic> agentesFiltrados) {
    int startIndex = (_currentPage + 1) * _itemsPerPage;
    return startIndex < agentesFiltrados.length;
  }

  @override
  Widget build(BuildContext context) {
    final agentesPorDepartamento = _agruparAgentesPorDepartamento();

    return Scaffold(
      appBar: AppBar(
        title: Text('Gestión de Agentes'),
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
                      hintText: 'Buscar agente...',
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

                // 🔹 Lista de agentes
                Expanded(
                  child: ListView(
                    children: agentesPorDepartamento.entries.map((entry) {
                      final departamento = entry.key;
                      final agentesFiltrados = _filtrarAgentes(entry.value);
                      final agentesPaginados =
                          _obtenerAgentesPaginados(agentesFiltrados);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Text(
                              departamento,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green, // Texto verde
                              ),
                            ),
                          ),
                          ...agentesPaginados.map((agente) {
                            return Card(
                              margin: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ListTile(
                                title: Text(
                                  agente['nombre'],
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text("Departamento: $departamento"),
                                trailing: DropdownButton<int>(
                                  hint: Text("Asignar"),
                                  items: departamentos
                                      .map<DropdownMenuItem<int>>((dept) {
                                    return DropdownMenuItem<int>(
                                      value: dept['id'],
                                      child: Text(dept['nombre']),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      _asignarDepartamento(agente['id'], value);
                                    }
                                  },
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                      );
                    }).toList(),
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
                          final agentesFiltrados = _filtrarAgentes(agentes);
                          if (_hayMasPaginas(agentesFiltrados)) {
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
