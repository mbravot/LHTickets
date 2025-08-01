import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
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
    // Obtener comentarios
    List<dynamic> comentariosList = [];
    try {
      comentariosList = await widget.apiService.obtenerComentarios(ticket['id'].toString());
    } catch (e) {
      comentariosList = [];
    }

    final pdf = pw.Document();
    final baseColor = PdfColor.fromInt(0xFF388e3c);
    final lightGrey = PdfColor.fromInt(0xFFF5F5F5);

    // Función para crear el header de cada página
    pw.Widget _buildHeader() {
      return pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: baseColor,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Row(
          children: [
            pw.Text('Estado: ${ticket['estado']}', 
              style: pw.TextStyle(
                color: PdfColor.fromInt(0xFFFFFFFF), 
                fontWeight: pw.FontWeight.bold, 
                fontSize: 16,
                font: pw.Font.helvetica(),
              )
            ),
            pw.SizedBox(width: 16),
            pw.Text('ID: #${ticket['id'].toString()}', 
              style: pw.TextStyle(
                color: PdfColor.fromInt(0xFFFFFFFF), 
                fontSize: 14,
                font: pw.Font.helvetica(),
              )
            ),
          ],
        ),
      );
    }

    // Función para crear la información del ticket
    pw.Widget _buildTicketInfo() {
      return pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: lightGrey,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Información del Ticket', 
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, 
                fontSize: 16,
                font: pw.Font.helvetica(),
              )
            ),
            pw.Divider(),
            pw.Text('Fecha: ${formatearComoChile(ticket['creado'])}', 
              style: pw.TextStyle(font: pw.Font.helvetica())
            ),
            pw.Text('Título: ${ticket['titulo'] ?? 'Sin título'}', 
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                font: pw.Font.helvetica(),
              )
            ),
            pw.Text('Creado por: ${ticket['usuario']}', 
              style: pw.TextStyle(font: pw.Font.helvetica())
            ),
            pw.Text('Sucursal: ${(ticket['sucursal'] is Map && ticket['sucursal'] != null) ? (ticket['sucursal']['nombre'] ?? 'No asignada') : ticket['sucursal']?.toString() ?? 'No asignada'}', 
              style: pw.TextStyle(font: pw.Font.helvetica())
            ),
            pw.Text('Departamento: ${(ticket['departamento'] is Map && ticket['departamento'] != null) ? ticket['departamento']['nombre'] : ticket['departamento']?.toString() ?? 'Sin asignar'}', 
              style: pw.TextStyle(font: pw.Font.helvetica())
            ),
            pw.Text('Categoría: ${(ticket['categoria'] is Map && ticket['categoria'] != null) ? ticket['categoria']['nombre'] : ticket['categoria']?.toString() ?? 'Sin asignar'}', 
              style: pw.TextStyle(font: pw.Font.helvetica())
            ),
            pw.Text('Agente: ${ticket['agente'] ?? "Sin asignar"}', 
              style: pw.TextStyle(font: pw.Font.helvetica())
            ),
            pw.Text('Prioridad: ${ticket['prioridad']}', 
              style: pw.TextStyle(font: pw.Font.helvetica())
            ),
          ],
        ),
      );
    }

    // Función para crear la descripción
    pw.Widget _buildDescription() {
      return pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: lightGrey,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Descripción', 
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, 
                fontSize: 16,
                font: pw.Font.helvetica(),
              )
            ),
            pw.Divider(),
            pw.Text(ticket['descripcion'] ?? '', 
              style: pw.TextStyle(font: pw.Font.helvetica())
            ),
          ],
        ),
      );
    }

    // Función para crear los archivos adjuntos
    pw.Widget? _buildAttachments() {
      if (ticket['adjunto'] == null || ticket['adjunto'].isEmpty) return null;
      
      return pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: lightGrey,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Archivos Adjuntos', 
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, 
                fontSize: 16,
                font: pw.Font.helvetica(),
              )
            ),
            pw.Divider(),
            pw.Text(ticket['adjunto'].split(',').join(', '), 
              style: pw.TextStyle(font: pw.Font.helvetica())
            ),
          ],
        ),
      );
    }

    // Función para crear un comentario individual
    pw.Widget _buildComment(Map<String, dynamic> comentario) {
      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 8),
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromInt(0xFFFFFFFF),
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: PdfColor.fromInt(0xFFDDDDDD)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              children: [
                pw.Text(comentario['usuario'], 
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    font: pw.Font.helvetica(),
                  )
                ),
                pw.SizedBox(width: 12),
                pw.Text(comentario['creado'], 
                  style: pw.TextStyle(
                    fontSize: 10, 
                    color: PdfColor.fromInt(0xFF888888),
                    font: pw.Font.helvetica(),
                  )
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Text(comentario['comentario'], 
              style: pw.TextStyle(font: pw.Font.helvetica())
            ),
          ],
        ),
      );
    }

    // Primera página con información básica y comentarios
    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            pw.SizedBox(height: 16),
            _buildTicketInfo(),
            pw.SizedBox(height: 16),
            _buildDescription(),
            if (_buildAttachments() != null) ...[
              pw.SizedBox(height: 16),
              _buildAttachments()!,
            ],
            if (comentariosList.isNotEmpty) ...[
              pw.SizedBox(height: 16),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: lightGrey,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Comentarios', 
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, 
                        fontSize: 16,
                        font: pw.Font.helvetica(),
                      )
                    ),
                    pw.Divider(),
                    ...comentariosList.take(6).map((comentario) => _buildComment(comentario)), // Mostrar solo los primeros 6 en la primera página
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );

    // Páginas adicionales para comentarios restantes si hay más de 6
    if (comentariosList.length > 6) {
      final comentariosRestantes = comentariosList.skip(6).toList();
      final comentariosPorPagina = 8; // Número de comentarios por página adicional
      final paginasComentarios = (comentariosRestantes.length / comentariosPorPagina).ceil();
      
      for (int i = 0; i < paginasComentarios; i++) {
        final inicio = i * comentariosPorPagina;
        final fin = (i + 1) * comentariosPorPagina;
        final comentariosPagina = comentariosRestantes.sublist(inicio, fin > comentariosRestantes.length ? comentariosRestantes.length : fin);
        
        pdf.addPage(
          pw.Page(
            margin: const pw.EdgeInsets.all(24),
            build: (pw.Context context) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                pw.SizedBox(height: 16),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: lightGrey,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Comentarios (Continuación)', 
                        style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, 
                          fontSize: 16,
                          font: pw.Font.helvetica(),
                        )
                      ),
                      pw.Divider(),
                      ...comentariosPagina.map((comentario) => _buildComment(comentario)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } else if (comentariosList.isEmpty) {
      // Si no hay comentarios, agregar una página con mensaje
      pdf.addPage(
        pw.Page(
          margin: const pw.EdgeInsets.all(24),
          build: (pw.Context context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              pw.SizedBox(height: 16),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: lightGrey,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Comentarios', 
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, 
                        fontSize: 16,
                        font: pw.Font.helvetica(),
                      )
                    ),
                    pw.Divider(),
                    pw.Text('No hay comentarios aún.', 
                      style: pw.TextStyle(
                        color: PdfColor.fromInt(0xFF888888),
                        font: pw.Font.helvetica(),
                      )
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final pdfBytes = await pdf.save();
    final blob = html.Blob([pdfBytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final fileName = 'ticket${ticket['id']}.pdf';
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  String formatearComoChile(String fechaStr) {
    if (fechaStr.isEmpty) return '';
    
    DateTime dt;
    try {
      // Si la fecha ya tiene zona horaria, la parseamos directamente
      if (fechaStr.contains('+') || fechaStr.contains('-') || fechaStr.contains('Z')) {
        dt = DateTime.parse(fechaStr.replaceFirst(' ', 'T'));
      } else {
        // Si no tiene zona horaria, asumimos que está en zona local de Chile
        // Agregamos la zona horaria de Chile (-04:00)
        dt = DateTime.parse(fechaStr.replaceFirst(' ', 'T') + '-04:00');
      }
      
      return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
             '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    } catch (e) {
      // Si hay error en el parsing, devolvemos la fecha original
      return fechaStr;
    }
  }
}
