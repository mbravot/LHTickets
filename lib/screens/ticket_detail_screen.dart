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
    return await widget.apiService.obtenerComentarios(ticket['id']);
  }

  void _agregarComentario() async {
    if (_comentarioController.text.isEmpty) return;

    try {
      // Agregar el comentario
      await widget.apiService
          .agregarComentario(ticket['id'], _comentarioController.text);

      // Cambiar el estado del ticket a "En Proceso"
      await widget.apiService.cambiarEstadoTicket(ticket['id'], "En Proceso");

      // Actualizar el estado localmente
      setState(() {
        ticket['estado'] = "En Proceso";
      });

      _comentarioController.clear();
      setState(() {
        comentarios = _cargarComentarios(); // Recargar comentarios
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('✅ Comentario agregado y ticket actualizado a "En Proceso"'),
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

  void _cambiarEstadoTicket(int ticketId, String nuevoEstado) async {
    try {
      await widget.apiService.cambiarEstadoTicket(ticketId, nuevoEstado);
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

    try {
      await widget.apiService.cerrarTicket(ticket['id']);
      setState(() {
        ticket['estado'] = "Cerrado"; // Actualiza el estado localmente
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Ticket cerrado correctamente'),
          backgroundColor: Colors.green,
        ),
      );

      // 🔹 Notificar a la pantalla anterior que el ticket fue cerrado
      Navigator.pop(
          context, true); // Devuelve `true` para indicar que se cerró el ticket
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
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Cerrar Ticket'),
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
                  final String url = "https://api.lahornilla.cl/api/uploads/$file";
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
      case 'Abierto':
        return Colors.green;
      case 'En Proceso':
        return Colors.orange;
      case 'Cerrado':
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
                        ticket['estado'] == 'Abierto'
                            ? Icons.check_circle
                            : ticket['estado'] == 'En Proceso'
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
                              'ID: #${ticket['id']}',
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
                      _buildInfoRow(Icons.confirmation_number, "ID", "#${ticket['id']}"),
                      _buildInfoRow(Icons.title, "Título", ticket['titulo'] ?? 'Sin título'),
                      _buildInfoRow(Icons.person, "Creado por", ticket['usuario']),
                      _buildInfoRow(Icons.support_agent, "Agente",
                          ticket['agente'] ?? 'Sin asignar'),
                      _buildInfoRow(
                          Icons.flag, "Prioridad", ticket['prioridad']),
                      _buildInfoRow(Icons.business, "Departamento",
                          ticket['departamento']),
                      _buildInfoRow(
                          Icons.calendar_today, "Fecha", formatearComoChile(ticket['creado'])),
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
                            ? ticket['adjunto'].split(',').where((a) => a is String && a.isNotEmpty).toList()
                            : <String>[])
                            .map<Widget>((file) => Row(
                              children: [
                                Icon(Icons.insert_drive_file, color: primaryColor),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: InkWell(
                                    onTap: () async {
                                      final String url = "https://api.lahornilla.cl/api/uploads/$file";
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
                                        await widget.apiService.eliminarAdjunto(ticket['id'], file);
                                        setState(() {
                                          final adjuntos = (ticket['adjunto'] is String && ticket['adjunto'].isNotEmpty)
                                              ? ticket['adjunto'].split(',').where((a) => a is String && a.isNotEmpty).toList()
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
                        onSubmitted: (value) {
                          _agregarComentario();
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Botones de acción
              if (ticket['estado'] == "Abierto")
                Center(
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.7,
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _cambiarEstadoTicket(ticket['id'], "En Proceso"),
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

              if (ticket['estado'] == "En Proceso")
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
          Icon(icon, size: 20, color: Colors.grey[600]),
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

  Future<void> _descargarTicketPDF(Map<String, dynamic> ticket) async {
    // Obtener comentarios
    List<dynamic> comentariosList = [];
    try {
      comentariosList = await widget.apiService.obtenerComentarios(ticket['id']);
    } catch (e) {
      comentariosList = [];
    }

    final pdf = pw.Document();
    final baseColor = PdfColor.fromInt(0xFF388e3c);
    final lightGrey = PdfColor.fromInt(0xFFF5F5F5);

    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: baseColor,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                children: [
                  pw.Text('Estado: ${ticket['estado']}', style: pw.TextStyle(color: PdfColor.fromInt(0xFFFFFFFF), fontWeight: pw.FontWeight.bold, fontSize: 16)),
                  pw.SizedBox(width: 16),
                  pw.Text('ID: #${ticket['id']}', style: pw.TextStyle(color: PdfColor.fromInt(0xFFFFFFFF), fontSize: 14)),
                ],
              ),
            ),
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
                  pw.Row(
                    children: [
                      pw.Icon(pw.IconData(0xe88e), color: baseColor), // info_outline
                      pw.SizedBox(width: 8),
                      pw.Text('Información del Ticket', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  pw.Divider(),
                  pw.Text('Título: ${ticket['titulo'] ?? 'Sin título'}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('Creado por: ${ticket['usuario']}'),
                  pw.Text('Agente: ${ticket['agente'] ?? "Sin asignar"}'),
                  pw.Text('Prioridad: ${ticket['prioridad']}'),
                  pw.Text('Departamento: ${ticket['departamento']}'),
                  pw.Text('Fecha: ${formatearComoChile(ticket['creado'])}'),
                ],
              ),
            ),
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
                  pw.Row(
                    children: [
                      pw.Icon(pw.IconData(0xe873), color: baseColor), // description
                      pw.SizedBox(width: 8),
                      pw.Text('Descripción', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  pw.Divider(),
                  pw.Text(ticket['descripcion'] ?? ''),
                ],
              ),
            ),
            if (ticket['adjunto'] != null && ticket['adjunto'].isNotEmpty) ...[
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
                    pw.Row(
                      children: [
                        pw.Icon(pw.IconData(0xe226), color: baseColor), // attach_file
                        pw.SizedBox(width: 8),
                        pw.Text('Archivos Adjuntos', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    pw.Divider(),
                    pw.Bullet(text: ticket['adjunto'].split(',').join(', ')),
                  ],
                ),
              ),
            ],
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
                  pw.Row(
                    children: [
                      pw.Icon(pw.IconData(0xe0b7), color: baseColor), // comment
                      pw.SizedBox(width: 8),
                      pw.Text('Comentarios', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  pw.Divider(),
                  if (comentariosList.isEmpty)
                    pw.Text('No hay comentarios aún.', style: pw.TextStyle(color: PdfColor.fromInt(0xFF888888))),
                  ...comentariosList.map((comentario) => pw.Container(
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
                            pw.Text(comentario['usuario'], style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                            pw.SizedBox(width: 12),
                            pw.Text(comentario['creado'], style: pw.TextStyle(fontSize: 10, color: PdfColor.fromInt(0xFF888888))),
                          ],
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(comentario['comentario']),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );

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
    final fechaConOffset = fechaStr.replaceFirst(' ', 'T') + '-04:00';
    final dt = DateTime.parse(fechaConOffset);
    return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
           '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }
}
