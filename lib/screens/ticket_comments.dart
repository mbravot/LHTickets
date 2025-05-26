import 'package:flutter/material.dart';
import '../services/api_service.dart';

class TicketCommentsScreen extends StatefulWidget {
  final String ticketId;
  final String ticketTitulo;
  final ApiService apiService = ApiService();

  TicketCommentsScreen({
    super.key,
    required this.ticketId,
    required this.ticketTitulo,
  });

  @override
  _TicketCommentsScreenState createState() => _TicketCommentsScreenState();
}

class _TicketCommentsScreenState extends State<TicketCommentsScreen>
    with SingleTickerProviderStateMixin {
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
    comentarios = widget.apiService.getComentarios(widget.ticketId);

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

  void _addComentario() async {
    if (_comentarioController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ El comentario no puede estar vacío'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Agregar el comentario
      await widget.apiService.agregarComentario(
        widget.ticketId.toString(),
        _comentarioController.text,
      );

      // Cambiar el estado del ticket a "En Proceso"
      await widget.apiService
          .cambiarEstadoTicket(widget.ticketId.toString(), "En Proceso");

      _comentarioController.clear();
      setState(() {
        comentarios = widget.apiService.getComentarios(widget.ticketId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('✅ Comentario agregado y ticket actualizado a "En Proceso"'),
          backgroundColor: Colors.green,
        ),
      );

      // Notificar a la pantalla anterior que el ticket fue actualizado
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error al agregar comentario: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Comentarios del Ticket',
          style: TextStyle(
            color: secondaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 4,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: secondaryColor),
            onPressed: () {
              setState(() {
                comentarios = widget.apiService.getComentarios(widget.ticketId);
              });
            },
            tooltip: 'Actualizar comentarios',
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
              // Título del ticket
              Card(
                elevation: 4,
                shadowColor: Colors.black26,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.confirmation_number, color: primaryColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ticket #${widget.ticketId}',
                              style: cardTitleStyle,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.ticketTitulo,
                              style: cardSubtitleStyle,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Lista de comentarios
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
                            onPressed: _addComentario,
                            tooltip: 'Enviar comentario',
                          ),
                        ),
                        onSubmitted: (value) {
                          _addComentario();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
