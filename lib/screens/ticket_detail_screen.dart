import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';

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
            icon: Icon(Icons.print),
            tooltip: 'Imprimir ticket', color: Colors.white,
            onPressed: () {
              if (kIsWeb) {
                _imprimirTicketWeb(ticket);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('La impresión solo está disponible en la versión web.'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
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
                      _buildInfoRow(
                          Icons.person, "Creado por", ticket['usuario']),
                      _buildInfoRow(Icons.support_agent, "Agente",
                          ticket['agente'] ?? 'Sin asignar'),
                      _buildInfoRow(
                          Icons.flag, "Prioridad", ticket['prioridad']),
                      _buildInfoRow(Icons.business, "Departamento",
                          ticket['departamento']),
                      _buildInfoRow(
                          Icons.calendar_today, "Fecha", ticket['creado']),
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
                  child: InkWell(
                    onTap: () => _abrirAdjunto(ticket['adjunto']),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.attach_file, color: primaryColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Archivos Adjuntos (${ticket['adjunto'].split(',').length})',
                                  style: cardTitleStyle,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Toca para ver los archivos',
                                  style: TextStyle(
                                    color: Colors.blue,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.open_in_new, color: Colors.blue),
                        ],
                      ),
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

  void _imprimirTicketWeb(Map<String, dynamic> ticket) async {
    List<dynamic> comentariosList = [];
    try {
      comentariosList = await widget.apiService.obtenerComentarios(ticket['id']);
    } catch (e) {
      comentariosList = [];
    }

    final htmlContent = '''
    <html>
      <head>
        <title>Detalle del Ticket</title>
        <style>
          body { font-family: Arial, sans-serif; margin: 40px; }
          h1 { color: #388e3c; }
          .section { margin-bottom: 24px; }
          .label { font-weight: bold; }
          .estado { background: #81C784; color: #fff; padding: 8px 16px; border-radius: 8px; }
          .comentario { border-bottom: 1px solid #e0e0e0; margin-bottom: 12px; padding-bottom: 8px; }
          .comentario-usuario { font-weight: bold; color: #388e3c; }
          .comentario-fecha { color: #888; font-size: 12px; margin-left: 8px; }
          .comentario-texto { margin-top: 4px; }
        </style>
        <script>
          window.onload = function() { window.print(); }
        </script>
      </head>
      <body>
        <h1>Detalle del Ticket</h1>
        <div class="section estado">Estado: ${ticket['estado']} | ID: #${ticket['id']}</div>
        <div class="section">
          <div><span class="label">Creado por:</span> ${ticket['usuario']}</div>
          <div><span class="label">Agente:</span> ${ticket['agente'] ?? 'Sin asignar'}</div>
          <div><span class="label">Prioridad:</span> ${ticket['prioridad']}</div>
          <div><span class="label">Departamento:</span> ${ticket['departamento']}</div>
          <div><span class="label">Fecha:</span> ${ticket['creado']}</div>
        </div>
        <div class="section">
          <div class="label">Descripción:</div>
          <div>${ticket['descripcion']}</div>
        </div>
        ${ticket['adjunto'] != null && ticket['adjunto'].isNotEmpty ? '''
        <div class="section">
          <div class="label">Archivos Adjuntos:</div>
          <ul>
            ${ticket['adjunto'].split(',').map((file) => '<li>$file</li>').join()}
          </ul>
        </div>
        ''' : ''}
        ${comentariosList.isNotEmpty ? '''
        <div class="section">
          <div class="label">Comentarios:</div>
          ${comentariosList.map((comentario) => '''
            <div class="comentario">
              <span class="comentario-usuario">${comentario['usuario']}</span>
              <span class="comentario-fecha">${comentario['creado']}</span>
              <div class="comentario-texto">${comentario['comentario']}</div>
            </div>
          ''').join('')}
        </div>
        ''' : ''}
      </body>
    </html>
    ''';

    final bytes = utf8.encode(htmlContent);
    final blob = html.Blob([bytes], 'text/html');
    final url = html.Url.createObjectUrlFromBlob(blob);

    final fileName = 'ticket${ticket['id']}.html';
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();

    html.Url.revokeObjectUrl(url);
  }
}
