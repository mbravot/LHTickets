import 'package:flutter/material.dart';
import '../services/api_service.dart';

class TicketCommentsScreen extends StatefulWidget {
  final int ticketId;
  final String ticketTitulo;

  const TicketCommentsScreen(
      {super.key, required this.ticketId, required this.ticketTitulo});

  @override
  _TicketCommentsScreenState createState() => _TicketCommentsScreenState();
}

class _TicketCommentsScreenState extends State<TicketCommentsScreen> {
  final ApiService apiService = ApiService();
  late Future<List<dynamic>> comentarios;
  final TextEditingController _comentarioController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    comentarios = apiService.getComentarios(widget.ticketId);
  }

  void _addComentario() async {
    if (_comentarioController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    Map<String, dynamic> comentarioData = {
      'id_usuario': 1, // Cambia según el usuario autenticado
      'comentario': _comentarioController.text
    };

    try {
      await apiService.addComentario(widget.ticketId, comentarioData);
      _comentarioController.clear();
      setState(() {
        comentarios =
            apiService.getComentarios(widget.ticketId); // Recargar comentarios
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al agregar comentario: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Comentarios - ${widget.ticketTitulo}')),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: comentarios,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error al cargar comentarios'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text('No hay comentarios aún.'));
                } else {
                  return ListView.builder(
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      final comentario = snapshot.data![index];
                      return ListTile(
                        title: Text(comentario['usuario'],
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(comentario['comentario']),
                        trailing: Text(comentario['creado']),
                      );
                    },
                  );
                }
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _comentarioController,
                    decoration:
                        InputDecoration(labelText: 'Agregar comentario'),
                  ),
                ),
                _isLoading
                    ? CircularProgressIndicator()
                    : IconButton(
                        icon: Icon(Icons.send, color: Colors.blue),
                        onPressed: _addComentario,
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
