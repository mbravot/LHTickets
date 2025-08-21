import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';

class TicketDetailScreen extends StatefulWidget {
  final Map<String, dynamic> ticket;
  final ApiService apiService = ApiService();

  TicketDetailScreen({super.key, required this.ticket});

  @override
  _TicketDetailScreenState createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen>
    with SingleTickerProviderStateMixin {
  late Map<String, dynamic> ticket;
  late Future<List<dynamic>> comentarios;
  final TextEditingController _comentarioController = TextEditingController();

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
    ticket = widget.ticket;
    comentarios = _cargarComentarios();

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
    super.dispose();
  }

  Future<List<dynamic>> _cargarComentarios() async {
    return await widget.apiService.obtenerComentarios(ticket['id'].toString());
  }

  void _agregarComentario() async {
    if (_comentarioController.text.isEmpty) return;

    try {
      // Agregar el comentario
      await widget.apiService
          .agregarComentario(ticket['id'].toString(), _comentarioController.text);

      // Cambiar el estado del ticket a "En Proceso"
      await widget.apiService.cambiarEstadoTicket(ticket['id'].toString(), "EN PROCESO");

      // Actualizar el estado localmente
      setState(() {
        ticket['estado'] = "EN PROCESO";
      });

      _comentarioController.clear();
      setState(() {
        comentarios = _cargarComentarios(); // Recargar comentarios
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('✅ Comentario agregado y ticket actualizado a "EN PROCESO"'),
          backgroundColor: Colors.green,
        ),
      );

      // No cerrar la pantalla, solo actualizar el estado local
      // Cuando el usuario regrese a la lista de tickets, se actualizará automáticamente
      // porque el ticket ha sido modificado
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error al agregar comentario: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _cambiarEstadoTicket(String ticketId, String nuevoEstado) async {
    try {
      await widget.apiService.cambiarEstadoTicket(ticketId.toString(), nuevoEstado);
      setState(() {
        ticket['estado'] = nuevoEstado; // Actualizar estado localmente
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Estado actualizado a $nuevoEstado'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true); // <- Esto le avisa a la lista que refresque
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error al actualizar estado'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _cerrarTicket() async {
    bool confirmar = await _mostrarConfirmacion();
    if (!confirmar) return;

    // Controlador para el campo de comentario
    final comentarioController = TextEditingController();

    // Mostrar diálogo para ingresar comentario
    String? comentario = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Comentario de cierre'),
        content: TextField(
          controller: comentarioController,
          decoration: InputDecoration(
            hintText: 'Ingrese un comentario para el cierre del ticket',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancelar'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.green,
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(comentarioController.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text('Cerrar Ticket'),
          ),
        ],
      ),
    );

    if (comentario == null || comentario.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Debe ingresar un comentario para cerrar el ticket'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await widget.apiService.cerrarTicket(ticket['id'].toString(), comentario);
      setState(() {
        ticket['estado'] = "CERRADO"; // Actualiza el estado localmente
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Ticket cerrado correctamente'),
          backgroundColor: Colors.green,
        ),
      );

      // 🔹 Notificar a la pantalla anterior que el ticket fue cerrado
      Navigator.pop(context, true); // Devuelve `true` para indicar que se cerró el ticket
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error al cerrar el ticket: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<bool> _mostrarConfirmacion() async {
    return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirmar Cierre'),
            content:
                const Text('¿Estás seguro de que deseas cerrar este ticket?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.green,
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Cerrar Ticket'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _abrirAdjunto(String adjunto) async {
    if (adjunto.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ No hay archivos adjuntos'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Dividir la cadena de adjuntos por comas para obtener una lista de archivos
    List<String> adjuntos = adjunto.split(',');

    // Mostrar un diálogo con la lista de archivos adjuntos
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Archivos Adjuntos'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: adjuntos.map((file) {
              return ListTile(
                leading: Icon(Icons.attach_file),
                title: Text(file),
                onTap: () async {
                  final String url = "https://apilhtickets-927498545444.us-central1.run.app/api/uploads/$file";
                  if (await canLaunch(url)) {
                    await launch(url);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('❌ No se pudo abrir el archivo: $file'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String estado) {
    switch (estado) {
      case 'ABIERTO':
        return Colors.green;
      case 'EN PROCESO':
        return Colors.orange;
      case 'CERRADO':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Detalle del Ticket',
          style: TextStyle(
            color: secondaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 4,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: secondaryColor),
          onPressed: () {
            Navigator.pop(context, true);
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: secondaryColor),
            onPressed: () {
              setState(() {
                comentarios = _cargarComentarios();
              });
            },
            tooltip: 'Actualizar comentarios',
          ),
          IconButton(
            icon: Icon(Icons.picture_as_pdf, color: secondaryColor),
            tooltip: 'Descargar PDF',
            onPressed: () {
              _descargarTicketPDF(ticket);
            },
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tarjeta de estado
              Card(
                elevation: 4,
                shadowColor: Colors.black26,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _getStatusColor(ticket['estado']),
                        _getStatusColor(ticket['estado']).withOpacity(0.7),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        ticket['estado'] == 'ABIERTO'
                            ? Icons.check_circle
                            : ticket['estado'] == 'EN PROCESO'
                                ? Icons.pending
                                : Icons.cancel,
                        color: Colors.white,
                        size: 32,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Estado: ${ticket['estado']}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ID: #${ticket['id'].toString()}',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Información del ticket
              Card(
                elevation: 4,
                shadowColor: Colors.black26,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            'Información del Ticket',
                            style: cardTitleStyle,
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      _buildInfoRow(Icons.confirmation_number, "ID", "#${ticket['id'].toString()}"),
                      _buildInfoRow(
                          Icons.calendar_today, "Fecha", formatearComoChile(ticket['creado'])),
                      _buildInfoRow(Icons.title, "Título", ticket['titulo'] ?? 'Sin título'),
                      _buildInfoRow(Icons.person, "Creado por", ticket['usuario']),
                      _buildInfoRow(Icons.location_on, "Sucursal",
                        (ticket['sucursal'] is Map && ticket['sucursal'] != null)
                          ? (ticket['sucursal']['nombre'] ?? 'No asignada')
                          : ticket['sucursal']?.toString() ?? 'No asignada'),     
                      _buildInfoRow(Icons.business, "Departamento",
                          (ticket['departamento'] is Map && ticket['departamento'] != null)
                            ? ticket['departamento']['nombre']
                            : ticket['departamento']?.toString() ?? 'Sin asignar'),
                      _buildInfoRow(Icons.category, "Categoría",
                          (ticket['categoria'] is Map && ticket['categoria'] != null)
                            ? ticket['categoria']['nombre']
                            : ticket['categoria']?.toString() ?? 'Sin asignar'),
                      _buildAgenteRow(),
                      _buildInfoRow(Icons.flag, "Prioridad", ticket['prioridad']),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Descripción
              Card(
                elevation: 4,
                shadowColor: Colors.black26,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.description, color: primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            'Descripción',
                            style: cardTitleStyle,
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Text(
                        ticket['descripcion'],
                        style: cardSubtitleStyle,
                      ),
                    ],
                  ),
                ),
              ),

              // Adjuntos
              if (ticket['adjunto'] != null && ticket['adjunto'].isNotEmpty)
                Card(
                  elevation: 4,
                  shadowColor: Colors.black26,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.attach_file, color: primaryColor),
                            const SizedBox(width: 8),
                            Text(
                              'Archivos Adjuntos',
                              style: cardTitleStyle,
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        ...((ticket['adjunto'] is String && ticket['adjunto'].isNotEmpty)
                            ? List<String>.from((ticket['adjunto'] as String).split(',')).where((String a) => a.isNotEmpty).toList()
                            : <String>[])
                            .map<Widget>((file) => Row(
                              children: [
                                Icon(Icons.insert_drive_file, color: primaryColor),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: InkWell(
                                    onTap: () async {
                                      final String url = "https://apilhtickets-927498545444.us-central1.run.app/api/uploads/$file";
                                      if (await canLaunch(url)) {
                                        await launch(url);
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('❌ No se pudo abrir el archivo: $file'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    },
                                    child: Text(file, overflow: TextOverflow.ellipsis, style: TextStyle(decoration: TextDecoration.underline, color: Colors.blue)),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  tooltip: 'Eliminar adjunto',
                                  onPressed: () async {
                                    bool confirmar = await showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: Text('Eliminar adjunto'),
                                        content: Text('¿Seguro que deseas eliminar este archivo?'),
                                        actions: [
                                          TextButton(
                                            child: Text('Cancelar'),
                                            onPressed: () => Navigator.of(context).pop(false),
                                          ),
                                          TextButton(
                                            child: Text('Eliminar', style: TextStyle(color: Colors.red)),
                                            onPressed: () => Navigator.of(context).pop(true),
                                          ),
                                        ],
                                      ),
                                    ) ?? false;
                                    if (confirmar) {
                                      try {
                                        await widget.apiService.eliminarAdjunto(ticket['id'].toString(), file);
                                        setState(() {
                                          final adjuntos = (ticket['adjunto'] is String && ticket['adjunto'].isNotEmpty)
                                              ? List<String>.from((ticket['adjunto'] as String).split(',')).where((String a) => a.isNotEmpty).toList()
                                              : <String>[];
                                          adjuntos.remove(file);
                                          ticket['adjunto'] = adjuntos.join(',');
                                        });
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Adjunto eliminado correctamente'), backgroundColor: Colors.green),
                                        );
                                      } catch (e) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Error al eliminar adjunto: $e'), backgroundColor: Colors.red),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ],
                            ))
                            .toList(),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // Comentarios
              Card(
                elevation: 4,
                shadowColor: Colors.black26,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.comment, color: primaryColor),
                          const SizedBox(width: 8),
                          Text(
                            'Comentarios',
                            style: cardTitleStyle,
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      FutureBuilder<List<dynamic>>(
                        future: comentarios,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      primaryColor),
                                ),
                              ),
                            );
                          }
                          if (snapshot.hasError) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  "❌ Error al cargar comentarios",
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            );
                          }
                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  "No hay comentarios aún.",
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ),
                            );
                          }

                          return Column(
                            children: snapshot.data!.map((comentario) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: primaryColor,
                                          radius: 16,
                                          child: Text(
                                            comentario['usuario'][0]
                                                .toUpperCase(),
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                comentario['usuario'],
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.grey[800],
                                                ),
                                              ),
                                              Text(
                                                comentario['creado'],
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      comentario['comentario'],
                                      style: TextStyle(
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      // Campo para agregar comentarios
                      TextField(
                        controller: _comentarioController,
                        minLines: 1,
                        maxLines: 5,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: "Escribe un comentario...",
                          filled: true,
                          fillColor: Colors.grey[100],
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
                            borderSide:
                                BorderSide(color: primaryColor, width: 2),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(Icons.send, color: primaryColor),
                            onPressed: _agregarComentario,
                            tooltip: 'Enviar comentario',
                          ),
                        ),
                        keyboardType: TextInputType.multiline,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Botones de acción
                if (ticket['estado'] == "ABIERTO")
                Center(
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.7,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _cambiarEstadoTicket(ticket['id'].toString(), "EN PROCESO"),
                      icon: Icon(Icons.pending),
                      label: Text("Cambiar a En Proceso"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 4,
                      ),
                    ),
                  ),
                ),

              if (ticket['estado'] == "EN PROCESO")
                Center(
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.7,
                    child: ElevatedButton.icon(
                      onPressed: _cerrarTicket,
                      icon: Icon(Icons.check_circle),
                      label: Text("Cerrar Ticket"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 4,
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blue),
          const SizedBox(width: 8),
          Text(
            "$label: ",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.grey[800],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgenteRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(Icons.support_agent, size: 20, color: Colors.blue),
          const SizedBox(width: 8),
          Text(
            "Agente: ",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          Expanded(
            child: Text(
              ticket['agente'] ?? 'Sin asignar',
              style: TextStyle(
                color: Colors.grey[800],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _mostrarDialogoReasignacion() async {
    try {
      // Obtener agentes disponibles
      List<dynamic> agentesDisponibles = await widget.apiService.getAgentesDisponiblesTicket(ticket['id'].toString());
      
      if (agentesDisponibles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ No hay agentes disponibles para reasignar'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      String? agenteSeleccionado;
      
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.swap_horiz, color: primaryColor),
              SizedBox(width: 8),
              Text('Reasignar Ticket', style: TextStyle(color: primaryColor)),
            ],
          ),
          content: Container(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Selecciona el nuevo agente para el ticket:',
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: agenteSeleccionado,
                  decoration: InputDecoration(
                    labelText: 'Nuevo Agente',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: Icon(Icons.person, color: primaryColor),
                  ),
                  items: agentesDisponibles.map((agente) {
                    return DropdownMenuItem<String>(
                      value: agente['id'].toString(),
                      child: Text('${agente['nombre']} (${agente['usuario']})'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    agenteSeleccionado = value;
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Debes seleccionar un agente';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (agenteSeleccionado != null) {
                  try {
                    // Reasignar el ticket
                    await widget.apiService.asignarTicket(ticket['id'].toString(), agenteSeleccionado!);
                    
                    // Actualizar el estado local
                    setState(() {
                      ticket['agente'] = agentesDisponibles.firstWhere(
                        (a) => a['id'].toString() == agenteSeleccionado,
                      )['nombre'];
                    });
                    
                    Navigator.of(context).pop();
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('✅ Ticket reasignado correctamente'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('❌ Error al reasignar: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
              child: Text('Reasignar'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error al cargar agentes: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _descargarTicketPDF(Map<String, dynamic> ticket) async {
    try {
      // Mostrar indicador de carga
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🔄 Generando archivo...'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 2),
        ),
      );

    // Obtener comentarios
    List<dynamic> comentariosList = [];
    try {
      comentariosList = await widget.apiService.obtenerComentarios(ticket['id'].toString());
    } catch (e) {
      comentariosList = [];
    }

      // Crear contenido HTML simple
      String htmlContent = '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Ticket #${ticket['id']}</title>
    <style>
        @media print {
            body { margin: 0; background-color: white; }
            .container { max-width: none; box-shadow: none; }
            .header { background-color: #388e3c !important; -webkit-print-color-adjust: exact; }
            .section { background-color: #f8f9fa !important; -webkit-print-color-adjust: exact; }
            .comment { background-color: white !important; -webkit-print-color-adjust: exact; }
            .print-button { display: none !important; }
        }
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; background-color: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .header { background-color: #388e3c; color: white; padding: 16px; border-radius: 8px; margin-bottom: 20px; }
        .section { background-color: #f8f9fa; border: 1px solid #dee2e6; border-radius: 8px; padding: 16px; margin-bottom: 20px; }
        .section h3 { margin-top: 0; color: #495057; border-bottom: 1px solid #dee2e6; padding-bottom: 8px; }
        .comment { background-color: white; border: 1px solid #e9ecef; border-radius: 6px; padding: 12px; margin-bottom: 12px; }
        .comment-header { font-weight: bold; color: #495057; margin-bottom: 4px; }
        .comment-content { color: #212529; }
        .info-row { margin-bottom: 8px; }
        .label { font-weight: bold; color: #495057; }
        .print-button { 
            background-color: #388e3c; 
            color: white; 
            border: none; 
            padding: 12px 24px; 
            border-radius: 6px; 
            font-size: 16px; 
            cursor: pointer; 
            margin: 20px 0; 
            display: block; 
            width: 100%;
            font-weight: bold;
        }
        .print-button:hover { 
            background-color: #2e7d32; 
        }
        .instructions { 
            background-color: #e3f2fd; 
            border: 1px solid #2196f3; 
            border-radius: 6px; 
            padding: 12px; 
            margin: 20px 0; 
            color: #1976d2; 
            font-size: 14px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h2>Ticket #${ticket['id']} - ${ticket['estado']}</h2>
        </div>
        
        <div class="section">
            <h3>Información del Ticket</h3>
            <div class="info-row"><span class="label">Fecha:</span> ${formatearComoChile(ticket['creado'])}</div>
            <div class="info-row"><span class="label">Título:</span> ${ticket['titulo'] ?? 'Sin título'}</div>
            <div class="info-row"><span class="label">Usuario:</span> ${ticket['usuario']}</div>
            <div class="info-row"><span class="label">Sucursal:</span> ${(ticket['sucursal'] is Map && ticket['sucursal'] != null) ? (ticket['sucursal']['nombre'] ?? 'No asignada') : ticket['sucursal']?.toString() ?? 'No asignada'}</div>
            <div class="info-row"><span class="label">Departamento:</span> ${(ticket['departamento'] is Map && ticket['departamento'] != null) ? ticket['departamento']['nombre'] : ticket['departamento']?.toString() ?? 'Sin asignar'}</div>
            <div class="info-row"><span class="label">Categoría:</span> ${(ticket['categoria'] is Map && ticket['categoria'] != null) ? ticket['categoria']['nombre'] : ticket['categoria']?.toString() ?? 'Sin asignar'}</div>
            <div class="info-row"><span class="label">Agente:</span> ${ticket['agente'] ?? "Sin asignar"}</div>
            <div class="info-row"><span class="label">Prioridad:</span> ${ticket['prioridad']}</div>
        </div>
        
        <div class="section">
            <h3>Descripción</h3>
            <div style="white-space: pre-line;">${ticket['descripcion'] ?? ''}</div>
        </div>
        
        <div class="section">
            <h3>Comentarios</h3>
            ${comentariosList.isEmpty ? '<p style="color: #6c757d;">No hay comentarios aún.</p>' : comentariosList.map((comentario) => '''
                <div class="comment">
                    <div class="comment-header">${comentario['usuario']} - ${comentario['creado']}</div>
                    <div class="comment-content" style="white-space: pre-line;">${comentario['comentario']}</div>
                </div>
            ''').join('')}
        </div>
        
        <button class="print-button" onclick="window.print()">
            🖨️ Imprimir como PDF
        </button>
    </div>
</body>
</html>
      ''';

      // Crear blob con contenido HTML
      final blob = html.Blob([htmlContent], 'text/html');
      final url = html.Url.createObjectUrlFromBlob(blob);
      
      // Abrir en nueva ventana
      html.window.open(url, '_blank');
      
      html.Url.revokeObjectUrl(url);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Archivo abierto. Presiona Ctrl+P para imprimir como PDF'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error al generar archivo: $e'),
          backgroundColor: Colors.red,
          ),
        );
      }
  }

  Widget _buildInfoRowPDF(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
            children: [
          Icon(icon, size: 16, color: Colors.blue),
          SizedBox(width: 8),
          Text(
            "$label: ",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
              fontSize: 14,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.grey[800],
                fontSize: 14,
              ),
                ),
              ),
            ],
      ),
    );
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
}
