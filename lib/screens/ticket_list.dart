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
import 'admin_app_management_screen.dart';
import 'categoria_management_screen.dart';
import 'info_page.dart';
import 'package:flutter/foundation.dart';
//import 'package:flutter/rendering.dart' as ui;
// Importar dart:html solo para web
//import 'dart:html' if (dart.library.html) 'dart:html' as html;
import 'dart:convert';
import 'dart:io';

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
  TabController? _tabController;
  late Future<List<dynamic>> tickets;
  List<dynamic> misTickets = [];
  List<dynamic> ticketsAsignados = [];
  List<dynamic> todosLosTickets = [];
  List<dynamic> ticketsSinAgente = [];
  List<dynamic> filteredTickets = [];
  List<dynamic> misTicketsAbiertos = [];
  List<dynamic> misTicketsCerrados = [];
  List<dynamic> sucursalesAutorizadas = [];
  List<dynamic> ticketsDepartamento = [];

  String? userRole;
  String? userName;
  String? userId;
  String? userSucursal;
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

  // Nuevo: Estado de filtro para 'Mis Tickets'
  String misTicketsEstadoFiltro = 'TODOS';
  final List<String> estadosFiltro = ['TODOS', 'ABIERTO', 'EN PROCESO', 'CERRADO'];

  @override
  void initState() {
    super.initState();
    _initializeData();

    // Establecer el contexto en el servicio de sesión para permitir la redirección
    widget.sessionService.setContext(context);

    // Asegurar que el filtro esté en 'TODOS' al iniciar
    setState(() {
      misTicketsEstadoFiltro = 'TODOS';
    });
  }

  Future<void> _initializeData() async {
    try {
      final sessionData = await widget.sessionService.getSessionData();

      userRole = sessionData['user_role'];
      userName = sessionData['nombre_usuario'] ?? "Usuario";
      userId = sessionData['user_id'];
      userSucursal = sessionData['sucursal'] ?? 'No asignada';

      // Obtener sucursales autorizadas del usuario
      final usuario = await widget.apiService.getUsuarios();
      final usuarioActual = usuario.firstWhere((u) => u['id'].toString() == userId, orElse: () => null);
      sucursalesAutorizadas = usuarioActual != null ? (usuarioActual['sucursales_autorizadas'] ?? []) : [];

      if (userRole == null) {
        _logout();
        return;
      }

      int tabLength = userRole == "1"
          ? 5  // Mis Tickets, Asignados, Cerrados, Sin Agente, Todos
          : userRole == "2"
              ? 4  // Mis Tickets, Asignados, Cerrados, Mi Departamento
              : 1; // Solo Mis Tickets

      _tabController = TabController(length: tabLength, vsync: this);
      _tabController?.addListener(() {
        _filterTickets(searchController.text);
      });

      setState(() {
        isLoading = false;
      });

      await _loadTickets();

      // Asegurar que se muestre la lista correcta según el rol
      setState(() {
        filteredTickets = misTickets;
      });
    } catch (e) {
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
      List<dynamic> allTickets;
      
      // Para administradores, usar endpoint específico que devuelve todos los tickets
      if (userRole == "1") {
        // Administrador: usar endpoint con parámetro para obtener todos los tickets
        allTickets = await widget.apiService.getTickets(allTickets: true);

      } else {
        allTickets = await widget.apiService.getTickets();
      }
      
      // Asegurarse de que userId sea un string para la comparación
      final String userIdStr = userId?.toString() ?? '';
      
      // Obtener el departamento del agente (asumiendo que solo tiene uno principal)
      final usuario = await widget.apiService.getUsuarios();
      final usuarioActual = usuario.firstWhere((u) => u['id'].toString() == userId, orElse: () => null);
      int? departamentoAgente;
      if (usuarioActual != null && usuarioActual['id_departamento'] != null) {
        if (usuarioActual['id_departamento'] is List && usuarioActual['id_departamento'].isNotEmpty) {
          departamentoAgente = usuarioActual['id_departamento'][0] is int
            ? usuarioActual['id_departamento'][0]
            : int.tryParse(usuarioActual['id_departamento'][0].toString());
        } else if (usuarioActual['id_departamento'] is int) {
          departamentoAgente = usuarioActual['id_departamento'];
        } else {
          departamentoAgente = int.tryParse(usuarioActual['id_departamento'].toString());
        }
      }
      // Logs de debug removidos para producción
      
      // Para agentes, usar endpoints específicos del backend
      List<dynamic> nuevosMisTickets;
      List<dynamic> nuevosTicketsDepartamento;
      
      if (userRole == "2") {
        // Agente: usar endpoints específicos
        try {
          nuevosMisTickets = await widget.apiService.getMisTickets();
          nuevosTicketsDepartamento = await widget.apiService.getTicketsMiDepartamento();
        } catch (e) {
          // Fallback al método anterior si fallan los endpoints específicos
          nuevosMisTickets = allTickets
              .where((ticket) => ticket['id_usuario']?.toString() == userIdStr)
              .toList();
          nuevosTicketsDepartamento = departamentoAgente != null
            ? allTickets.where((ticket) =>
                ticket['id_departamento'] != null &&
                int.tryParse(ticket['id_departamento'].toString()) == departamentoAgente
              ).toList()
            : [];
        }
      } else {
        // Usuario normal: usar método anterior
        nuevosMisTickets = allTickets
            .where((ticket) => ticket['id_usuario']?.toString() == userIdStr)
            .toList();
        nuevosTicketsDepartamento = departamentoAgente != null
          ? allTickets.where((ticket) =>
              ticket['id_departamento'] != null &&
              int.tryParse(ticket['id_departamento'].toString()) == departamentoAgente
            ).toList()
          : [];
      }
          
      List<dynamic> nuevosTicketsAsignados = allTickets
          .where((ticket) =>
              ticket['id_agente']?.toString() == userIdStr &&
              (ticket['estado']?.toString() == 'ABIERTO' || 
               ticket['estado']?.toString() == 'EN PROCESO'))
          .toList();
          
      List<dynamic> nuevosMisTicketsCerrados = allTickets
          .where((ticket) =>
              ticket['id_agente']?.toString() == userIdStr &&
              ticket['estado']?.toString() == 'CERRADO')
          .toList();
          
      List<dynamic> nuevosTodosLosTickets = allTickets;
      List<dynamic> nuevosTicketsSinAgente =
          allTickets.where((ticket) => 
              ticket['id_agente'] == null || 
              ticket['id_agente'].toString().isEmpty).toList();

      // Debug: Verificar que todosLosTickets tenga todos los tickets
      if (userRole == "1") {

      }

      setState(() {
        misTickets = nuevosMisTickets;
        ticketsAsignados = nuevosTicketsAsignados;
        misTicketsCerrados = nuevosMisTicketsCerrados;
        todosLosTickets = nuevosTodosLosTickets;
        ticketsSinAgente = nuevosTicketsSinAgente;
        ticketsDepartamento = nuevosTicketsDepartamento;
      });

      // Aseguramos el filtrado después del primer frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _filterTickets(searchController.text);
      });
    } catch (e) {

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
      switch (_tabController?.index) {
        case 0: // Abiertos
          selectedList = ticketsAsignados;
          break;
        case 1: // Cerrados
          selectedList = misTicketsCerrados;
          break;
        case 2: // Mis Tickets
          selectedList = misTickets;
          if (misTicketsEstadoFiltro != 'TODOS') {
            selectedList = selectedList.where((ticket) => ticket['estado'] == misTicketsEstadoFiltro).toList();
          }
          break;
        case 3: // Sin Agente
          selectedList = ticketsSinAgente;
          break;
        case 4: // Todos
          selectedList = todosLosTickets;
          // Debug: Verificar qué se está mostrando en la pestaña "Todos"
          if (userRole == "1") {
    
          }
          break;
        default:
          selectedList = ticketsAsignados;
      }
    } else if (userRole == "2") {
      switch (_tabController?.index) {
        case 0: // Abiertos
          selectedList = ticketsAsignados;
          break;
        case 1: // Cerrados
          selectedList = misTicketsCerrados;
          break;
        case 2: // Mi Departamento
          selectedList = ticketsDepartamento;
          if (misTicketsEstadoFiltro != 'TODOS') {
            selectedList = selectedList.where((ticket) => ticket['estado'] == misTicketsEstadoFiltro).toList();
          }
          break;
        case 3: // Mis Tickets
          selectedList = misTickets;
          if (misTicketsEstadoFiltro != 'TODOS') {
            selectedList = selectedList.where((ticket) => ticket['estado'] == misTicketsEstadoFiltro).toList();
          }
          break;
        default:
          selectedList = ticketsAsignados;
      }
    } else {
      selectedList = misTickets;
      if (misTicketsEstadoFiltro != 'TODOS') {
        selectedList = selectedList.where((ticket) => ticket['estado'] == misTicketsEstadoFiltro).toList();
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
          final categoria =
              ticket['categoria']?.toString().toLowerCase() ?? '';
          final id = ticket['id']?.toString().toLowerCase() ?? '';

          return titulo.contains(query.toLowerCase()) ||
              agente.contains(query.toLowerCase()) ||
              usuario.contains(query.toLowerCase()) ||
              estado.contains(query.toLowerCase()) ||
              departamento.contains(query.toLowerCase()) ||
              categoria.contains(query.toLowerCase()) ||
              id.contains(query.toLowerCase());
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
                style: TextButton.styleFrom(
                  foregroundColor: Colors.green,
                ),
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

  void _deleteTicket(String ticketId) async {
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
          int departamentoId = ticket['id_departamento'] is int
              ? ticket['id_departamento']
              : int.tryParse(ticket['id_departamento']?.toString() ?? '-1') ?? -1;

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
            child: Text('Adjuntar Archivos'),
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

  void _mostrarDialogoAsignar(String ticketId) async {
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

      String? agenteSeleccionado;

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
                // Procesar agentes para IDs string únicos
                List<Map<String, dynamic>> agentesProcesados = [];
                Set<String> idsUnicos = {};
                for (var agente in agentes) {
                  final id = agente['id']?.toString();
                  final nombre = agente['nombre'] ?? 'Sin nombre';
                  if (id != null && id.isNotEmpty && !idsUnicos.contains(id)) {
                    agentesProcesados.add({'id': id, 'nombre': nombre});
                    idsUnicos.add(id);
                  }
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
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
                      items: [
                        DropdownMenuItem<String>(
                          value: null,
                          child: Text('Selecciona un agente'),
                        ),
                        ...agentesProcesados.map<DropdownMenuItem<String>>((agente) {
                          return DropdownMenuItem<String>(
                          value: agente['id'],
                          child: Text(agente['nombre']),
                        );
                      }).toList(),
                      ],
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

  void _mostrarDialogoReasignar(String ticketId, int departamentoId) async {
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

      // Convertir los agentes a una lista de IDs válidos (aceptando String o int)
      List<Map<String, dynamic>> agentesProcesados = [];
      Set<String> idsUnicos = {};
      for (var agente in agentes) {
        final id = agente['id']?.toString();
        final nombre = agente['nombre'] ?? 'Sin nombre';
        if (id != null && id.isNotEmpty && !idsUnicos.contains(id)) {
          agentesProcesados.add({'id': id, 'nombre': nombre});
          idsUnicos.add(id);
        }
      }

      String? agenteSeleccionado = null;

      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
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
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      constraints: BoxConstraints(maxHeight: 300),
                      child: DropdownButtonFormField<String>(
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
                        items: [
                          DropdownMenuItem<String>(
                            value: null,
                            child: Text('Selecciona un agente'),
                          ),
                          ...agentesProcesados.map<DropdownMenuItem<String>>((agente) {
                            return DropdownMenuItem<String>(
                          value: agente['id'],
                          child: Text(agente['nombre']),
                        );
                      }).toList(),
                        ],
                      onChanged: (value) {
                          setDialogState(() {
                          agenteSeleccionado = value;
                        });
                      },
                      ),
                    ),
                  ],
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
        },
      );
    } catch (e) {
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

  Future<void> _seleccionarArchivo(String ticketId) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
      );

      if (result != null) {
        // Archivos seleccionados para subir
        List<String> archivosSubidos = [];
        List<String> archivosFallidos = [];
        Set<String> archivosProcesados = {}; // Para evitar duplicados

        for (var file in result.files) {
          // Verificar si el archivo ya fue procesado
          if (archivosProcesados.contains(file.name)) {
            // Archivo duplicado, saltar
            continue;
          }
          
          try {
            // Procesando archivo
            final bytes = file.bytes ?? (file.path != null ? await File(file.path!).readAsBytes() : null);
            
            if (bytes != null) {
              // Generar nombre único para el archivo con un pequeño retraso
              await Future.delayed(Duration(milliseconds: 100)); // Pequeño retraso para asegurar timestamp único
              final timestamp = DateTime.now().millisecondsSinceEpoch;
              final extension = file.name.split('.').last;
              final nombreBase = file.name.substring(0, file.name.lastIndexOf('.'));
              final nombreUnico = '${nombreBase}_${timestamp}.$extension';

              // Subiendo archivo con nombre único
              await widget.apiService.subirArchivo(
                bytes,
                nombreUnico,
                ticketId,
              );
              archivosSubidos.add(file.name);
              archivosProcesados.add(file.name);
      
            }
          } catch (e) {
            // Error al subir archivo
            archivosFallidos.add(file.name);
          }
        }

        if (archivosSubidos.isNotEmpty) {
          String mensaje = '✅ Archivos adjuntados: ${archivosSubidos.join(", ")}';
          if (archivosFallidos.isNotEmpty) {
            mensaje += '\n❌ No se pudieron adjuntar: ${archivosFallidos.join(", ")}';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(mensaje),
              backgroundColor: archivosFallidos.isEmpty ? Colors.green : Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
          _refreshTickets();
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error al adjuntar archivos: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleMenuSelection(String value, dynamic ticket) {
    switch (value) {
      case 'assign':
        _mostrarDialogoAsignar(ticket['id'].toString());
        break;
      case 'reasign':
        if (ticket['id_departamento'] != null) {
          _mostrarDialogoReasignar(
            ticket['id'].toString(),
            ticket['id_departamento'] is int
                ? ticket['id_departamento']
                : int.tryParse(ticket['id_departamento'].toString()) ?? -1
          );
        }
        break;
      case 'upload':
        _seleccionarArchivo(ticket['id'].toString());
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
        _deleteTicket(ticket['id'].toString());
        break;
    }
  }

  Widget _buildTicketList(List<dynamic> ticketList) {
    final bool mostrarFiltroMisTickets =
        (userRole == "1" && _tabController?.index == 2) ||
        (userRole == "2" && (_tabController?.index == 2 || _tabController?.index == 3)) ||
        (userRole != "1" && userRole != "2");

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
              hintText: 'Buscar por ID, título, agente, usuario...',
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
        if (mostrarFiltroMisTickets)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 8,
              children: estadosFiltro.map((estado) {
                final bool seleccionado = misTicketsEstadoFiltro == estado;
                return ChoiceChip(
                  label: Text(estado),
                  selected: seleccionado,
                  selectedColor: _chipColorEstado(estado),
                  labelStyle: TextStyle(
                    color: seleccionado ? Colors.white : _chipColorEstado(estado),
                    fontWeight: FontWeight.bold,
                  ),
                  backgroundColor: Colors.white,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        misTicketsEstadoFiltro = estado;
                      });
                      _filterTickets(searchController.text);
                    }
                  },
                );
              }).toList(),
            ),
          ),
        if (ticketList.isEmpty)
          Expanded(
            child: Center(
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
            ),
          )
        else ...[
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // ID del ticket a la izquierda
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      "#${ticket['id_formatted']}",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green[900],
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                  // Estado del ticket y menú de opciones a la derecha
                                  Row(
                                    children: [
                                      _buildStatusChip(ticket['estado'] ?? ''),
                                      SizedBox(width: 8),
                                      _buildPopupMenu(ticket),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Título
                              Text(
                                      ticket['titulo'] ?? 'Sin título',
                                style: cardTitleStyle.copyWith(fontSize: 18),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                              const SizedBox(height: 8),
                              // Creado por y Fecha en la misma línea
                              Row(
                                children: [
                                  Icon(Icons.person, size: 16, color: Colors.blue),
                                  SizedBox(width: 4),
                                  Text(
                                    "Creado por: "+(ticket['usuario'] ?? 'Desconocido'),
                                    style: cardSubtitleStyle,
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.location_on, size: 16, color: Colors.blue),
                                  SizedBox(width: 4),
                                  Text(
                                    "Sucursal: " +
                                      ((ticket['sucursal'] is Map && ticket['sucursal'] != null)
                                        ? (ticket['sucursal']['nombre'] ?? 'No asignada')
                                        : ticket['sucursal']?.toString() ?? 'No asignada'),
                                    style: cardSubtitleStyle,
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.calendar_today, size: 16, color: Colors.blue),
                                  SizedBox(width: 4),
                                  Text(
                                    formatearComoChile(ticket['creado']),
                                    style: cardSubtitleStyle,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Agente, Departamento y Categoría en la misma línea
                              Row(
                                children: [
                                  Icon(Icons.support_agent, size: 16, color: Colors.blue),
                                  SizedBox(width: 4),
                                  Text(
                                    "Agente: "+(ticket['agente'] ?? 'Sin asignar'),
                                    style: cardSubtitleStyle,
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.business, size: 16, color: Colors.blue),
                                  SizedBox(width: 4),
                                  Text(
                                    "Departamento: "+(
                                      (ticket['departamento'] is Map && ticket['departamento'] != null)
                                        ? ticket['departamento']['nombre']
                                        : ticket['departamento']?.toString() ?? 'Sin asignar'
                                    ),
                                    style: cardSubtitleStyle,
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.category, size: 16, color: Colors.blue),
                                  SizedBox(width: 4),
                                  Text(
                                    "Categoría: "+(
                                      (ticket['categoria'] is Map && ticket['categoria'] != null)
                                        ? ticket['categoria']['nombre']
                                        : ticket['categoria']?.toString() ?? 'Sin asignar'
                                    ),
                                    style: cardSubtitleStyle,
                                  ),
                                ],
                              ),
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
      case 'ABIERTO':
        chipColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'EN PROCESO':
        chipColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
      case 'CERRADO':
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
      case 'ABIERTO':
        return Colors.green.shade50;
      case 'EN PROCESO':
        return Colors.orange.shade50;
      case 'CERRADO':
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
    if (isLoading || _tabController == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Cargando...'),
          backgroundColor: primaryColor,
        ),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundColor: Colors.white.withOpacity(0.2),
              child: Icon(Icons.confirmation_number, color: Colors.white),
            ),
            SizedBox(width: 10),
                Text(
                  "Bienvenido, ${userName ?? 'Usuario'} 👋",
                  style: TextStyle(
                    color: Colors.white,
                fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            SizedBox(width: 10),
            GestureDetector(
              onTap: _cambiarSucursalActiva,
              child: Container(
                constraints: BoxConstraints(maxWidth: 300),
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_on, color: Colors.white, size: 15),
                    SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        "Sucursal: ${userSucursal ?? 'No asignada'}",
                  style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          overflow: TextOverflow.ellipsis,
                        ),
                  ),
                ),
                    SizedBox(width: 2),
                    Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
              ],
            ),
              ),
            ),
            SizedBox(width: 10),
            _buildPerfilChip(userRole),
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
              controller: _tabController!,
              labelColor: primaryColor,
              unselectedLabelColor: Colors.grey[500],
              indicatorColor: primaryColor,
              indicatorWeight: 3,
              tabs: [
                if (userRole == "1") ...[
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment, color: primaryColor),
                        SizedBox(width: 8),
                        Text(
                          'Abiertos',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${ticketsAsignados.length}',
                            style: TextStyle(
                              fontSize: 12,
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: Colors.red),
                        SizedBox(width: 8),
                        Text(
                          'Cerrados',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${misTicketsCerrados.length}',
                            style: TextStyle(
                              fontSize: 12,
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, color: primaryColor),
                        SizedBox(width: 8),
                        Text(
                          'Mis Tickets',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${misTickets.length}',
                            style: TextStyle(
                              fontSize: 12,
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_off, color: primaryColor),
                        SizedBox(width: 8),
                        Text(
                          'Sin Agente',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${ticketsSinAgente.length}',
                            style: TextStyle(
                              fontSize: 12,
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.list, color: primaryColor),
                        SizedBox(width: 8),
                        Text(
                          'Todos',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${todosLosTickets.length}',
                            style: TextStyle(
                              fontSize: 12,
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (userRole == "2") ...[
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment, color: primaryColor),
                        SizedBox(width: 8),
                        Text(
                          'Abiertos',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${ticketsAsignados.length}',
                            style: TextStyle(
                              fontSize: 12,
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: Colors.red),
                        SizedBox(width: 8),
                        Text(
                          'Cerrados',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${misTicketsCerrados.length}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.apartment, color: Colors.amber),
                        SizedBox(width: 8),
                        Text(
                          'Mi Departamento',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${ticketsDepartamento.length}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.amber,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Mis Tickets',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${misTickets.length}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, color: primaryColor),
                        SizedBox(width: 8),
                        Text(
                          'Mis Tickets',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${misTickets.length}',
                            style: TextStyle(
                              fontSize: 12,
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
              _buildDrawerItem(
                icon: Icons.category,
                title: 'Gestionar Categorías',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CategoriaManagementScreen(),
                    ),
                  );
                },
              ),
              _buildDrawerItem(
                icon: Icons.apps,
                title: 'Gestionar Aplicaciones',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AdminAppManagementScreen(
                        apiService: widget.apiService,
                        sessionService: widget.sessionService,
                      ),
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
              icon: Icons.info,
              title: "Acerca de",
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => InfoPage()),
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
      body: _buildTicketList(filteredTickets),
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

  // Nuevo: función para obtener color según estado para los chips
  Color _chipColorEstado(String estado) {
    switch (estado) {
      case 'ABIERTO':
        return Colors.green;
      case 'EN PROCESO':
        return Colors.orange;
      case 'CERRADO':
        return Colors.red;
      default:
        return primaryColor;
    }
  }

  String formatearComoChile(String fechaStr) {
    if (fechaStr.isEmpty) return '';
    
    try {
      // Las fechas vienen del backend en UTC, necesitamos sumar 4 horas para zona local de Chile
      DateTime dt = DateTime.parse(fechaStr.replaceFirst(' ', 'T') + 'Z');
      DateTime dtChile = dt.add(Duration(hours: 4)); // Sumamos 4 horas para zona local de Chile
      
      return '${dtChile.year.toString().padLeft(4, '0')}-${dtChile.month.toString().padLeft(2, '0')}-${dtChile.day.toString().padLeft(2, '0')} '
             '${dtChile.hour.toString().padLeft(2, '0')}:${dtChile.minute.toString().padLeft(2, '0')}:${dtChile.second.toString().padLeft(2, '0')}';
    } catch (e) {
      // Si hay error en el parsing, devolvemos la fecha original
      return fechaStr;
    }
  }

  Future<void> _cambiarSucursalActiva() async {
    if (sucursalesAutorizadas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ No tienes otras sucursales autorizadas, por favor contacta a tu administrador'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final seleccion = await showDialog<String>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: Text('Selecciona tu sucursal activa'),
          children: sucursalesAutorizadas.map((sucursal) {
            return SimpleDialogOption(
              onPressed: () => Navigator.pop(context, sucursal['id'].toString()),
              child: Row(
                children: [
                  Icon(Icons.location_on, color: primaryColor),
                  SizedBox(width: 8),
                  Text(
                    sucursal['nombre'],
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );

    if (seleccion != null && seleccion != userSucursal) {
      try {
        setState(() => isLoading = true);
        await widget.apiService.updateUser(userId!, {'id_sucursalactiva': seleccion});
        setState(() {
          userSucursal = sucursalesAutorizadas.firstWhere((s) => s['id'].toString() == seleccion)['nombre'];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Sucursal activa actualizada'), backgroundColor: Colors.green),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error al actualizar sucursal: $e'), backgroundColor: Colors.red),
        );
      } finally {
        setState(() => isLoading = false);
      }
    }
  }

  Widget _buildPerfilChip(String? userRole) {
    String label = 'Usuario';
    IconData icon = Icons.person_outline;
    Color color = Colors.green.shade700;
    if (userRole == "1") {
      label = 'Administrador';
      icon = Icons.admin_panel_settings;
      color = Colors.green.shade700;
    } else if (userRole == "2") {
      label = 'Agente';
      icon = Icons.person;
      color = Colors.green.shade700;
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
