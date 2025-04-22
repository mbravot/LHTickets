import 'package:flutter/material.dart';
//import 'package:shared_preferences/shared_preferences.dart';
import 'ticket_create.dart';
import 'ticket_edit.dart';
import 'login_screen.dart';
//import 'register_screen.dart';
import 'ticket_detail_screen.dart';
import 'user_management_screen.dart';
import 'agent_management_screen.dart';
import 'change_password_screen.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import 'package:file_picker/file_picker.dart';
//import 'dart:typed_data';
import 'department_management_screen.dart';
import 'package:flutter/foundation.dart';
//import 'package:flutter/rendering.dart' as ui;
// Importar dart:html solo para web
//import 'dart:html' if (dart.library.html) 'dart:html' as html;

class TicketListScreen extends StatefulWidget {
  final ApiService apiService;
  final SessionService sessionService;

  const TicketListScreen({
    Key? key,
    required this.apiService,
    required this.sessionService,
  }) : super(key: key);

  @override
  _TicketListScreenState createState() => _TicketListScreenState();
}

class _TicketListScreenState extends State<TicketListScreen>
    with SingleTickerProviderStateMixin {
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

  int _currentPage = 0;
  int _ticketsPerPage = 10;

  TextEditingController searchController = TextEditingController();

  // Colores y estilos
  final Color primaryColor = Colors.green;
  final Color secondaryColor = Colors.white;
  final Color backgroundColor = Colors.grey[200]!;
  final TextStyle cardTitleStyle = TextStyle(
    fontSize: 16,
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
    _initializeData();

    // Establecer el contexto en el servicio de sesión para permitir la redirección
    widget.sessionService.setContext(context);
  }

  Future<void> _initializeData() async {
    try {
      final sessionData = await widget.sessionService.getSessionData();

      userRole = sessionData['user_role'];
      userName = sessionData['nombre_usuario'] ?? "Usuario";
      userId = int.tryParse(sessionData['user_id'] ?? '0');

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

      await _loadTickets();

      // Asegurar que se muestre la lista correcta según el rol
      if (userRole == "1" || userRole == "2") {
        setState(() {
          filteredTickets = ticketsAsignados;
        });
      } else {
        setState(() {
          filteredTickets = misTicketsAbiertos;
        });
      }
    } catch (e) {
      print("❌ Error al inicializar datos: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error al cargar los datos: $e'),
          backgroundColor: Colors.red,
        ),
      );
      _logout();
    }
  }

  Future<void> _loadTickets() async {
    setState(() => isLoading = true);
    try {
      final allTickets = await widget.apiService.getTickets();
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

        // Actualizar la lista filtrada según la pestaña actual
        if (_tabController != null) {
          _filterTickets(searchController.text);
        }
      });
    } catch (e) {
      print("❌ Error al cargar tickets: $e");

      if (e.toString().contains('token') ||
          e.toString().contains('autenticación')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '🔒 Tu sesión ha expirado. Serás redirigido al inicio de sesión.'),
            backgroundColor: Colors.orange,
          ),
        );
        _logout();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al cargar los tickets: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
    setState(() {
      _currentPage = 0; // Reiniciar la paginación a la primera página
    });

    List<dynamic> selectedList;

    // Determinar qué lista mostrar según el rol y la pestaña actual
    if (userRole == "1") {
      // Administrador
      switch (_tabController.index) {
        case 0: // Asignados
          selectedList = ticketsAsignados;
          break;
        case 1: // Mis Tickets Abiertos
          selectedList = misTicketsAbiertos;
          break;
        case 2: // Mis Tickets Cerrados
          selectedList = misTicketsCerrados;
          break;
        case 3: // Sin Agente
          selectedList = ticketsSinAgente;
          break;
        case 4: // Todos
          selectedList = todosLosTickets;
          break;
        default:
          selectedList = ticketsAsignados;
      }
    } else if (userRole == "2") {
      // Agente
      switch (_tabController.index) {
        case 0: // Asignados
          selectedList = ticketsAsignados;
          break;
        case 1: // Mis Tickets Abiertos
          selectedList = misTicketsAbiertos;
          break;
        case 2: // Mis Tickets Cerrados
          selectedList = misTicketsCerrados;
          break;
        default:
          selectedList = ticketsAsignados;
      }
    } else {
      // Usuario normal
      switch (_tabController.index) {
        case 0: // Mis Tickets Abiertos
          selectedList = misTicketsAbiertos;
          break;
        case 1: // Mis Tickets Cerrados
          selectedList = misTicketsCerrados;
          break;
        default:
          selectedList = misTicketsAbiertos;
      }
    }

    setState(() {
      if (query.isEmpty) {
        filteredTickets = selectedList;
      } else {
        filteredTickets = selectedList.where((ticket) {
          final titulo = ticket['titulo'].toString().toLowerCase();
          final agente = ticket['agente']?.toString().toLowerCase() ?? '';
          final usuario = ticket['usuario']?.toString().toLowerCase() ?? '';
          final estado = ticket['estado']?.toString().toLowerCase() ?? '';
          final departamento =
              ticket['departamento']?.toString().toLowerCase() ?? '';

          return titulo.contains(query.toLowerCase()) ||
              agente.contains(query.toLowerCase()) ||
              usuario.contains(query.toLowerCase()) ||
              estado.contains(query.toLowerCase()) ||
              departamento.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  Future<void> _logout() async {
    bool confirmar = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.logout, color: Colors.red),
                SizedBox(width: 8),
                Text('Cerrar Sesión'),
              ],
            ),
            content: Text('¿Estás seguro de que deseas cerrar sesión?'),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancelar'),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(true),
                icon: Icon(Icons.logout),
                label: Text('Cerrar Sesión'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmar) {
      try {
        setState(() => isLoading = true);

        // Usar el servicio de sesión para limpiar los datos
        await widget.sessionService.clearSession();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('👋 Sesión cerrada correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        }

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => LoginScreen(
                apiService: widget.apiService,
                sessionService: widget.sessionService,
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Error al cerrar sesión: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => isLoading = false);
        }
      }
    }
  }

  void _deleteTicket(int ticketId) async {
    bool confirmDelete = await _showDeleteConfirmation();
    if (confirmDelete) {
      try {
        await widget.apiService.deleteTicket(ticketId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Ticket eliminado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
        _refreshTickets();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al eliminar el ticket: $e'),
            backgroundColor: Colors.red,
          ),
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
      setState(() => isLoading = true);
      List agentes = await widget.apiService.getAgentes();

      if (agentes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ No hay agentes disponibles'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      int? agenteSeleccionado;

      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.person_add, color: primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Asignar Agente',
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      value: agenteSeleccionado,
                      decoration: InputDecoration(
                        labelText: 'Selecciona un agente',
                        prefixIcon:
                            Icon(Icons.support_agent, color: primaryColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: primaryColor, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
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
                    ),
                  ],
                );
              },
            ),
            actions: [
              TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close, color: Colors.grey[600]),
                label: Text(
                  'Cancelar',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  if (agenteSeleccionado == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('❌ Debes seleccionar un agente'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  try {
                    setState(() => isLoading = true);
                    await widget.apiService
                        .asignarTicket(ticketId, agenteSeleccionado!);
                    Navigator.pop(context);
                    _refreshTickets();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('✅ Agente asignado con éxito'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    print("❌ Error al asignar agente: $e");
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('❌ Error al asignar el agente'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  } finally {
                    setState(() => isLoading = false);
                  }
                },
                icon: Icon(Icons.check),
                label: Text('Asignar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: secondaryColor,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 4,
                ),
              ),
            ],
          );
        },
      );
    } catch (e) {
      print("❌ Error al obtener agentes: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error al obtener la lista de agentes'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _mostrarDialogoReasignar(int ticketId, int departamentoId) async {
    try {
      setState(() => isLoading = true);
      List agentes =
          await widget.apiService.getAgentesPorDepartamento(departamentoId);

      if (agentes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ No hay agentes en este departamento'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      int? agenteSeleccionado;

      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.swap_horiz, color: primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Reasignar Ticket',
                  style: TextStyle(
                    color: Colors.grey[800],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      value: agenteSeleccionado,
                      decoration: InputDecoration(
                        labelText: 'Selecciona un agente',
                        prefixIcon:
                            Icon(Icons.support_agent, color: primaryColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: primaryColor, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                      ),
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
                    ),
                  ],
                );
              },
            ),
            actions: [
              TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close, color: Colors.grey[600]),
                label: Text(
                  'Cancelar',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  if (agenteSeleccionado == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('❌ Debes seleccionar un agente'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  try {
                    setState(() => isLoading = true);
                    await widget.apiService
                        .reasignarTicket(ticketId, agenteSeleccionado!);
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
                      SnackBar(
                        content: Text('❌ Error al reasignar el ticket'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  } finally {
                    setState(() => isLoading = false);
                  }
                },
                icon: Icon(Icons.check),
                label: Text('Reasignar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: secondaryColor,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 4,
                ),
              ),
            ],
          );
        },
      );
    } catch (e) {
      print("❌ Error en _mostrarDialogoReasignar: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error al obtener la lista de agentes'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _seleccionarArchivo(int ticketId) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      Uint8List archivoBytes = result.files.single.bytes!;
      String fileName = result.files.single.name;

      try {
        await widget.apiService.subirArchivo(archivoBytes, fileName, ticketId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📂 Archivo adjuntado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
        _refreshTickets();
      } catch (e) {
        print("❌ Error al subir archivo: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al subir el archivo'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se seleccionó ningún archivo'),
          backgroundColor: Colors.red,
        ),
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              "No hay tickets disponibles",
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    int startIndex = _currentPage * _ticketsPerPage;
    int endIndex = startIndex + _ticketsPerPage;
    List<dynamic> paginatedTickets = ticketList.sublist(
      startIndex,
      endIndex > ticketList.length ? ticketList.length : endIndex,
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'Buscar tickets...',
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
            onChanged: _filterTickets,
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 16),
            itemCount: paginatedTickets.length,
            itemBuilder: (context, index) {
              final ticket = paginatedTickets[index];
              return AnimatedContainer(
                duration: Duration(milliseconds: 300),
                margin: EdgeInsets.only(bottom: 12),
                child: Card(
                  elevation: 4,
                  shadowColor: Colors.black26,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              TicketDetailScreen(ticket: ticket),
                        ),
                      );
                      if (result == true) {
                        _refreshTickets();
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _getStatusColor(ticket['estado'] ?? ''),
                            _getStatusColor(ticket['estado'] ?? '')
                                .withOpacity(0.7),
                          ],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    ticket['titulo'] ?? 'Sin título',
                                    style: cardTitleStyle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                _buildStatusChip(ticket['estado'] ?? ''),
                                _buildPopupMenu(ticket),
                              ],
                            ),
                            SizedBox(height: 12),
                            _buildInfoRow(Icons.person,
                                "Creado por: ${ticket['usuario'] ?? 'Desconocido'}"),
                            _buildInfoRow(Icons.business,
                                "Departamento: ${ticket['departamento'] ?? 'Sin asignar'}"),
                            _buildInfoRow(Icons.support_agent,
                                "Agente: ${ticket['agente'] ?? 'Sin asignar'}"),
                            _buildInfoRow(Icons.calendar_today,
                                "Fecha: ${ticket['creado'] ?? 'N/A'}"),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        _buildPaginationControls(ticketList.length),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: cardSubtitleStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String estado) {
    Color chipColor;
    IconData statusIcon;

    switch (estado) {
      case 'Abierto':
        chipColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'En Proceso':
        chipColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
      case 'Cerrado':
        chipColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        chipColor = Colors.grey;
        statusIcon = Icons.help;
    }

    return Chip(
      avatar: Icon(statusIcon, size: 16, color: Colors.white),
      label: Text(
        estado,
        style: TextStyle(color: Colors.white, fontSize: 12),
      ),
      backgroundColor: chipColor,
      padding: EdgeInsets.symmetric(horizontal: 8),
    );
  }

  Color _getStatusColor(String estado) {
    switch (estado) {
      case 'Abierto':
        return Colors.green.shade50;
      case 'En Proceso':
        return Colors.orange.shade50;
      case 'Cerrado':
        return Colors.red.shade50;
      default:
        return Colors.grey.shade50;
    }
  }

  Widget _buildPaginationControls(int totalTickets) {
    int totalPages = (totalTickets / _ticketsPerPage).ceil();

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
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white.withOpacity(0.2),
              child: Icon(Icons.confirmation_number, color: Colors.white),
            ),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Bienvenido, ${userName ?? 'Usuario'} 👋",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  userRole == "1"
                      ? "Administrador"
                      : userRole == "2"
                          ? "Agente"
                          : "Usuario",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primaryColor,
                primaryColor.withOpacity(0.8),
                Colors.green.shade700,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshTickets,
            tooltip: 'Actualizar tickets',
          ),
          IconButton(
            icon: Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {
              // Función para mostrar notificaciones (a implementar)
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Sistema de notificaciones en desarrollo'),
                  backgroundColor: Colors.blue,
                ),
              );
            },
            tooltip: 'Notificaciones',
          ),
          SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: primaryColor,
              labelColor: primaryColor,
              unselectedLabelColor: Colors.grey[500],
              indicatorWeight: 3,
              tabs: [
                if (userRole == "1" || userRole == "2")
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment),
                        SizedBox(width: 8),
                        Text("Asignados (${ticketsAsignados.length})"),
                      ],
                    ),
                  ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox),
                      SizedBox(width: 8),
                      Text("Mis Tickets (${misTicketsAbiertos.length})"),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle),
                      SizedBox(width: 8),
                      Text("Cerrados (${misTicketsCerrados.length})"),
                    ],
                  ),
                ),
                if (userRole == "1")
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_off),
                        SizedBox(width: 8),
                        Text("Sin Agente (${ticketsSinAgente.length})"),
                      ],
                    ),
                  ),
                if (userRole == "1")
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.list),
                        SizedBox(width: 8),
                        Text("Todos (${todosLosTickets.length})"),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [primaryColor, primaryColor.withOpacity(0.8)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 35, color: primaryColor),
                  ),
                  SizedBox(height: 12),
                  Text(
                    userName ?? 'Usuario',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    userRole == "1"
                        ? "Administrador"
                        : userRole == "2"
                            ? "Agente"
                            : "Usuario",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            if (userRole == "1") ...[
              _buildDrawerItem(
                icon: Icons.group,
                title: 'Gestionar Usuarios',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UserManagementScreen(),
                    ),
                  );
                },
              ),
              _buildDrawerItem(
                icon: Icons.supervisor_account,
                title: 'Gestionar Agentes',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AgentManagementScreen(),
                    ),
                  );
                },
              ),
              _buildDrawerItem(
                icon: Icons.business,
                title: 'Gestionar Departamentos',
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
            _buildDrawerItem(
              icon: Icons.lock,
              title: 'Cambiar Clave',
              iconColor: Colors.amber,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChangePasswordScreen(),
                  ),
                );
              },
            ),
            _buildDrawerItem(
              icon: Icons.logout,
              title: 'Cerrar Sesión',
              iconColor: Colors.red,
              onTap: _logout,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => TicketCreateScreen()),
          ).then((result) {
            if (result == true) _refreshTickets();
          });
        },
        backgroundColor: primaryColor,
        icon: Icon(Icons.add, color: Colors.white),
        label: Text(
          'Nuevo Ticket',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 4,
        tooltip: 'Crear nuevo ticket',
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            )
          : _buildTicketList(filteredTickets),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? primaryColor),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
}
