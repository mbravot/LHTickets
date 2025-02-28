import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ticket_create.dart';
import 'ticket_edit.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'ticket_detail_screen.dart';
import 'user_management_screen.dart';
import 'agent_management_screen.dart';
import 'change_password_screen.dart';
import '../services/api_service.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'department_management_screen.dart';

class TicketListScreen extends StatefulWidget {
  const TicketListScreen({super.key});

  @override
  _TicketListScreenState createState() => _TicketListScreenState();
}

class _TicketListScreenState extends State<TicketListScreen>
    with SingleTickerProviderStateMixin {
  final ApiService apiService = ApiService();
  late TabController _tabController;
  late Future<List<dynamic>> tickets;
  List<dynamic> misTickets = [];
  List<dynamic> ticketsAsignados = [];
  List<dynamic> todosLosTickets = [];
  List<dynamic> ticketsSinAgente = [];
  List<dynamic> filteredTickets = [];
  List<dynamic> misTicketsAbiertos = [];
  List<dynamic> misTicketsCerrados = [];

  String? userRole;
  String? userName;
  int? userId;
  bool isLoading = true;

  int _currentPage = 0; // Página actual
  int _ticketsPerPage = 10; // Cantidad de tickets por página

  TextEditingController searchController = TextEditingController();

  // Colores y estilos
  final Color primaryColor = Colors.green;
  final Color secondaryColor = Colors.white;
  final Color backgroundColor = Colors.grey[200]!;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    final prefs = await SharedPreferences.getInstance();
    userRole = prefs.getString('user_role');
    userName = prefs.getString('nombre_usuario') ?? "Usuario";
    userId = int.tryParse(prefs.getString('user_id') ?? '0');

    if (userRole == null) {
      _logout();
      return;
    }

    int tabLength = userRole == "1"
        ? 5
        : userRole == "2"
            ? 3
            : 2;

    _tabController = TabController(length: tabLength, vsync: this);
    _tabController.addListener(() {
      _filterTickets(searchController.text);
    });

    setState(() {
      isLoading = false;
    });

    _loadTickets();
  }

  Future<void> _loadTickets() async {
    setState(() => isLoading = true);
    try {
      final allTickets = await apiService.getTickets();
      setState(() {
        // Mis Tickets: Solo tickets del usuario actual
        misTickets = allTickets
            .where((ticket) => ticket['id_usuario'] == userId)
            .toList();

        // Mis Tickets Abiertos/En Proceso
        misTicketsAbiertos = misTickets
            .where((ticket) =>
                ticket['estado'] == 'Abierto' ||
                ticket['estado'] == 'En Proceso')
            .toList();

        // Mis Tickets Cerrados
        misTicketsCerrados = misTickets
            .where((ticket) => ticket['estado'] == 'Cerrado')
            .toList();

        // Tickets Asignados: Solo tickets asignados al usuario actual (agentes y administradores)
        ticketsAsignados = allTickets
            .where((ticket) =>
                ticket['id_agente'] != null && ticket['id_agente'] == userId)
            .toList();

        // Todos los Tickets (solo para administradores)
        todosLosTickets = allTickets;

        // Tickets Sin Agente (solo para administradores)
        ticketsSinAgente =
            allTickets.where((ticket) => ticket['id_agente'] == null).toList();

        // Inicialmente mostrar Mis Tickets Abiertos/En Proceso
        filteredTickets = misTicketsAbiertos;
      });
    } catch (e) {
      print("❌ Error: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _refreshTickets() async {
    setState(() => isLoading = true);

    await Future.delayed(Duration(milliseconds: 500)); // Evita UI freeze
    await _loadTickets();

    setState(() {
      _filterTickets(searchController
          .text); // 🔹 Actualiza la lista filtrada de la pestaña actual
      isLoading = false;
    });
  }

  void _filterTickets(String query) {
    List<dynamic> selectedList;

    switch (_tabController.index) {
      case 0:
        selectedList = misTicketsAbiertos; // Mis Tickets (Abiertos/En Proceso)
        break;
      case 1:
        selectedList = misTicketsCerrados; // Tickets Cerrados
        break;
      case 2:
        selectedList = ticketsAsignados; // Asignados
        break;
      case 3:
        selectedList = todosLosTickets; // Todos (solo para administradores)
        break;
      case 4:
        selectedList =
            ticketsSinAgente; // Sin Agente (solo para administradores)
        break;
      default:
        selectedList = misTicketsAbiertos;
    }

    setState(() {
      filteredTickets = selectedList.where((ticket) {
        final titulo = ticket['titulo'].toString().toLowerCase();
        final agente = ticket['agente']?.toString().toLowerCase() ?? '';
        final usuario = ticket['usuario']?.toString().toLowerCase() ?? '';

        return titulo.contains(query.toLowerCase()) ||
            agente.contains(query.toLowerCase()) ||
            usuario.contains(query.toLowerCase());
      }).toList();
    });
  }

  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
        (route) => false,
      );
    }
  }

  void _deleteTicket(int ticketId) async {
    bool confirmDelete = await _showDeleteConfirmation();
    if (confirmDelete) {
      try {
        await apiService.deleteTicket(ticketId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Ticket eliminado correctamente')),
        );
        _refreshTickets();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error al eliminar el ticket: $e')),
        );
      }
    }
  }

  Future<bool> _showDeleteConfirmation() async {
    return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Confirmar eliminación'),
            content: Text('¿Estás seguro de que deseas eliminar este ticket?'),
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
  }

  Widget _buildPopupMenu(dynamic ticket) {
    return PopupMenuButton<String>(
      itemBuilder: (context) {
        List<PopupMenuEntry<String>> opciones = [];

        if (userRole == "1") {
          opciones.add(
            const PopupMenuItem<String>(
              value: 'assign',
              child: Text('Asignar Agente'),
            ),
          );
        }

        if (userRole == "2") {
          int departamentoId = ticket['id_departamento'] ?? -1;

          if (departamentoId != -1) {
            opciones.add(
              const PopupMenuItem<String>(
                value: 'reasign',
                child: Text('Reasignar Agente'),
              ),
            );
          }
        }

        opciones.addAll([
          const PopupMenuItem<String>(
            value: 'upload',
            child: Text('Adjuntar Archivo'),
          ),
          const PopupMenuItem<String>(
            value: 'edit',
            child: Text('Editar'),
          ),
          const PopupMenuItem<String>(
            value: 'delete',
            child: Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ]);

        return opciones;
      },
      onSelected: (String value) => _handleMenuSelection(value, ticket),
    );
  }

  void _mostrarDialogoAsignar(int ticketId) async {
    try {
      List agentes = await apiService.getAgentes();

      if (agentes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No hay agentes disponibles')),
        );
        return;
      }

      int? agenteSeleccionado;

      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Asignar Agente'),
            content: StatefulBuilder(
              builder: (context, setState) {
                return DropdownButton<int>(
                  value: agenteSeleccionado,
                  hint: Text('Selecciona un agente'),
                  isExpanded: true,
                  items: agentes.map<DropdownMenuItem<int>>((agente) {
                    return DropdownMenuItem<int>(
                      value: agente['id'],
                      child: Text(agente['nombre']),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      agenteSeleccionado = value;
                    });
                  },
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (agenteSeleccionado != null) {
                    await apiService.asignarTicket(
                        ticketId, agenteSeleccionado!);
                    Navigator.pop(context);
                    _refreshTickets();
                  }
                },
                child: Text('Asignar'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      print("❌ Error al obtener agentes: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al obtener la lista de agentes')),
      );
    }
  }

  void _mostrarDialogoReasignar(int ticketId, int departamentoId) async {
    try {
      List agentes = await apiService.getAgentesPorDepartamento(departamentoId);

      if (agentes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ No hay agentes en este departamento')),
        );
        return;
      }

      int? agenteSeleccionado;

      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Reasignar Ticket'),
            content: StatefulBuilder(
              builder: (context, setState) {
                return DropdownButton<int>(
                  value: agenteSeleccionado,
                  hint: Text('Selecciona un agente'),
                  isExpanded: true,
                  items: agentes.map<DropdownMenuItem<int>>((agente) {
                    return DropdownMenuItem<int>(
                      value: agente['id'],
                      child: Text(agente['nombre']),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      agenteSeleccionado = value;
                    });
                  },
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (agenteSeleccionado == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('❌ Debes seleccionar un agente')),
                    );
                    return;
                  }

                  try {
                    await apiService.asignarTicket(
                        ticketId, agenteSeleccionado!);
                    Navigator.pop(context);
                    _refreshTickets();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('✅ Ticket reasignado con éxito'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    print("❌ Error al reasignar ticket: $e");
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('❌ Error al reasignar el ticket')),
                    );
                  }
                },
                child: Text('Reasignar'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      print("❌ Error en _mostrarDialogoReasignar: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error al obtener la lista de agentes')),
      );
    }
  }

  void _seleccionarArchivo(int ticketId) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      Uint8List archivoBytes = result.files.single.bytes!;
      String fileName = result.files.single.name;

      try {
        await apiService.subirArchivo(archivoBytes, fileName, ticketId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('📂 Archivo adjuntado correctamente')),
        );
        _refreshTickets();
      } catch (e) {
        print("❌ Error al subir archivo: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error al subir el archivo')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se seleccionó ningún archivo')),
      );
    }
  }

  void _handleMenuSelection(String value, dynamic ticket) {
    switch (value) {
      case 'assign':
        _mostrarDialogoAsignar(ticket['id']);
        break;
      case 'reasign':
        if (ticket['id_departamento'] != null) {
          _mostrarDialogoReasignar(ticket['id'], ticket['id_departamento']);
        }
        break;
      case 'upload':
        _seleccionarArchivo(ticket['id']);
        break;
      case 'edit':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TicketEditScreen(ticket: ticket),
          ),
        ).then((result) {
          if (result == true) _refreshTickets();
        });
        break;
      case 'delete':
        _deleteTicket(ticket['id']);
        break;
    }
  }

  Widget _buildTicketList(List<dynamic> ticketList) {
    if (ticketList.isEmpty) {
      return Center(child: Text("No hay tickets disponibles"));
    }

    int startIndex = _currentPage * _ticketsPerPage;
    int endIndex = startIndex + _ticketsPerPage;
    List<dynamic> paginatedTickets = ticketList.sublist(
      startIndex,
      endIndex > ticketList.length ? ticketList.length : endIndex,
    );

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: paginatedTickets.length,
            itemBuilder: (context, index) {
              final ticket = paginatedTickets[index];
              return Card(
                margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  title: Text(ticket['titulo'] ?? 'Sin título',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          "📝 Creado por: ${ticket['usuario'] ?? 'Desconocido'}"),
                      Text(
                          "👜 Departamento: ${ticket['departamento'] ?? 'Sin asignar'}"),
                      Text(
                          "👨‍💼 Agente: ${ticket['agente'] ?? 'Sin asignar'}"),
                      Text("📌 Estado: ${ticket['estado'] ?? 'Desconocido'}"),
                      Text("📅 Fecha: ${ticket['creado'] ?? 'N/A'}"),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: _buildPopupMenu(ticket),
                  onTap: () async {
                    // 🔹 Esperar el resultado de la pantalla de detalle
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            TicketDetailScreen(ticket: ticket),
                      ),
                    );
                    // 🔹 Si el resultado es `true`, actualizar la lista de tickets
                    if (result == true) {
                      _refreshTickets();
                    }
                  },
                ),
              );
            },
          ),
        ),
        _buildPaginationControls(ticketList.length),
      ],
    );
  }

  Widget _buildPaginationControls(int totalTickets) {
    int totalPages = (totalTickets / _ticketsPerPage).ceil();

    return Row(
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
        Text("Página ${_currentPage + 1} de $totalPages"),
        IconButton(
          icon: Icon(Icons.arrow_forward),
          onPressed: _currentPage < totalPages - 1
              ? () {
                  setState(() {
                    _currentPage++;
                  });
                }
              : null,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Bienvenido, ${userName ?? 'Usuario'} 👋",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: primaryColor,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _refreshTickets,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: secondaryColor,
          labelColor: secondaryColor,
          unselectedLabelColor: Colors.grey[300],
          tabs: [
            Tab(text: "Mis Tickets (${misTicketsAbiertos.length})"),
            Tab(text: "Tickets Cerrados (${misTicketsCerrados.length})"),
            if (userRole == "1" || userRole == "2")
              Tab(text: "Asignados (${ticketsAsignados.length})"),
            if (userRole == "1") Tab(text: "Todos (${todosLosTickets.length})"),
            if (userRole == "1")
              Tab(text: "Sin Agente (${ticketsSinAgente.length})"),
          ],
        ),
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: primaryColor),
              child: Text(
                "Bienvenido, ${userName ?? 'Usuario'} 👋",
                style: TextStyle(color: secondaryColor, fontSize: 20),
              ),
            ),
            if (userRole == "1") ...[
              ListTile(
                leading: Icon(Icons.person_add, color: primaryColor),
                title: Text('Registrar Usuario'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RegisterScreen(userRole: userRole!),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.group, color: primaryColor),
                title: Text('Gestionar Usuarios'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UserManagementScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.supervisor_account, color: primaryColor),
                title: Text('Gestionar Agentes'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AgentManagementScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.business,
                    color: primaryColor), // Icono para departamentos
                title: Text('Gestionar Departamentos'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DepartmentManagementScreen(),
                    ),
                  );
                },
              ),
            ],
            ListTile(
              leading: Icon(Icons.lock, color: Colors.amber),
              title: Text('Cambiar Clave'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChangePasswordScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.logout, color: Colors.red),
              title: Text('Cerrar Sesión'),
              onTap: _logout,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(8.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                labelText: "Buscar ticket...",
                hintText: "Buscar por título, agente o usuario",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: _filterTickets,
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTicketList(
                    filteredTickets), // Mis Tickets (Abiertos/En Proceso)
                _buildTicketList(filteredTickets), // Tickets Cerrados
                if (userRole == "1" || userRole == "2")
                  _buildTicketList(filteredTickets), // Asignados
                if (userRole == "1") _buildTicketList(filteredTickets), // Todos
                if (userRole == "1")
                  _buildTicketList(filteredTickets), // Sin Agente
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => TicketCreateScreen()),
          );
          if (result == true) _refreshTickets();
        },
        backgroundColor: primaryColor,
        child: Icon(Icons.add, color: secondaryColor),
      ),
    );
  }
}
