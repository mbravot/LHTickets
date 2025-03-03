import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';

class TicketDetailScreen extends StatefulWidget {
  final Map<String, dynamic> ticket;
  final ApiService apiService = ApiService();

  TicketDetailScreen({super.key, required this.ticket});

  @override
  _TicketDetailScreenState createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  late Map<String, dynamic> ticket;
  late Future<List<dynamic>> comentarios;
  final TextEditingController _comentarioController = TextEditingController();

  @override
  void initState() {
    super.initState();
    ticket = widget.ticket;
    comentarios = _cargarComentarios();
  }

  Future<List<dynamic>> _cargarComentarios() async {
    return await widget.apiService.obtenerComentarios(ticket['id']);
  }

  void _agregarComentario() async {
    if (_comentarioController.text.isEmpty) return;

    try {
      await widget.apiService
          .agregarComentario(ticket['id'], _comentarioController.text);
      _comentarioController.clear();
      setState(() {
        comentarios = _cargarComentarios(); // Recargar comentarios
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error al agregar comentario: $e')),
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
        SnackBar(content: Text('❌ Error al cerrar el ticket: $e')),
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
        const SnackBar(content: Text('❌ No hay archivo adjunto')),
      );
      return;
    }

    final String url =
        "http://api-tickets-c2g2bpcgauebg4fb.brazilsouth-01.azurewebsites.net/api/uploads/$adjunto"; //Ruta API

    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ No se pudo abrir el archivo adjunto')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del Ticket'),
        backgroundColor: Colors.green, // Fondo verde
        foregroundColor: Colors.white, // Texto blanco
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildInfoTable([
                    ["Creado", ticket['usuario']],
                    ["Agente Asignado", ticket['agente'] ?? 'Sin asignar'],
                    ["Prioridad", ticket['prioridad']],
                    ["Título", ticket['titulo']],
                  ]),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildInfoTable([
                    ["Fecha Creación", ticket['creado']],
                    ["Departamento", ticket['departamento']],
                    ["Estado", ticket['estado']],
                  ]),
                ),
              ],
            ),
            const SizedBox(height: 16.0),

            // Descripción
            const Text("Descripción:",
                style: TextStyle(fontWeight: FontWeight.bold)),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(ticket['descripcion']),
            ),

            const SizedBox(height: 16.0),

            // Adjuntos
            if (ticket['adjunto'] != null && ticket['adjunto'].isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: InkWell(
                  onTap: () => _abrirAdjunto(ticket['adjunto']),
                  child: const Text(
                    "📎 Ver adjunto",
                    style: TextStyle(
                        color: Colors.blue,
                        decoration: TextDecoration.underline),
                  ),
                ),
              ),

            const SizedBox(height: 16.0),

            // 🔹 Sección de comentarios
            const Text("Comentarios:",
                style: TextStyle(fontWeight: FontWeight.bold)),
            FutureBuilder<List<dynamic>>(
              future: comentarios,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Text("❌ Error al cargar comentarios");
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Text("No hay comentarios.");
                }

                return Column(
                  children: snapshot.data!.map((comentario) {
                    return ListTile(
                      title: Text(
                          "${comentario['usuario']} (${comentario['creado']})"),
                      subtitle: Text(comentario['comentario']),
                    );
                  }).toList(),
                );
              },
            ),

            // Campo para agregar comentarios
            const SizedBox(height: 10),
            TextField(
              controller: _comentarioController,
              decoration: InputDecoration(
                hintText: "Escribe un comentario...",
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send, color: Colors.green),
                  onPressed: _agregarComentario, // Enviar al presionar el ícono
                ),
              ),
              onSubmitted: (value) {
                _agregarComentario(); // Enviar al presionar Enter
              },
            ),

            // 🔹 Espacio entre el campo de comentarios y los botones
            const SizedBox(height: 20),

            // 🔹 Botón para cambiar estado (solo si el ticket está en "Abierto")

            if (ticket['estado'] == "Abierto")
              Center(
                child: SizedBox(
                  width: double.infinity, // Ocupa todo el ancho disponible
                  child: ElevatedButton(
                    onPressed: () =>
                        _cambiarEstadoTicket(ticket['id'], "En Proceso"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.lightBlue,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                          vertical: 16), // Aumentar el padding vertical
                    ),
                    child: const Text("En Proceso"),
                  ),
                ),
              ),

            // 🔹 Botón para cerrar ticket (solo si el estado es "En Proceso")
            if (ticket['estado'] == "En Proceso")
              Center(
                child: SizedBox(
                  width: double.infinity, // Ocupa todo el ancho disponible
                  child: ElevatedButton(
                    onPressed: _cerrarTicket, // 🔹 Cambia esto
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                          vertical: 16), // Aumentar el padding vertical
                    ),
                    child: const Text("Cerrar Ticket"),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTable(List<List<String>> data) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, // Fondo blanco
        borderRadius: BorderRadius.circular(8), // Bordes redondeados
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Table(
        border: TableBorder.symmetric(
          inside: BorderSide(color: Colors.grey[300]!),
          outside: BorderSide.none,
        ),
        columnWidths: const {0: FlexColumnWidth(1), 1: FlexColumnWidth(2)},
        children: data.map((row) {
          return TableRow(
            decoration: BoxDecoration(
              color: row == data.first
                  ? Colors.white.withOpacity(0.1)
                  : null, // Fondo verde claro para la primera fila
            ),
            children: row.map((cell) {
              return Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  cell,
                  style: TextStyle(
                    fontWeight:
                        row.first == cell ? FontWeight.bold : FontWeight.normal,
                    color: row.first == cell
                        ? Colors.green
                        : Colors.black, // Texto verde para las cabeceras
                  ),
                ),
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }
}
