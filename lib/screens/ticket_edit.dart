import 'package:flutter/material.dart';
import '../services/api_service.dart';

class TicketEditScreen extends StatefulWidget {
  final Map<String, dynamic> ticket;

  const TicketEditScreen({super.key, required this.ticket});

  @override
  _TicketEditScreenState createState() => _TicketEditScreenState();
}

class _TicketEditScreenState extends State<TicketEditScreen> {
  final ApiService apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _tituloController;
  late TextEditingController _descripcionController;

  @override
  void initState() {
    super.initState();
    _tituloController = TextEditingController(text: widget.ticket['titulo']);
    _descripcionController =
        TextEditingController(text: widget.ticket['descripcion']);
  }

  void _updateTicket() async {
    if (_formKey.currentState!.validate()) {
      final Map<String, dynamic> updatedTicket = {
        'titulo': _tituloController.text.trim(),
        'descripcion': _descripcionController.text.trim(),
      };

      try {
        await apiService.updateTicket(widget.ticket['id'], updatedTicket);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ticket actualizado con éxito'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Refresca la lista al volver
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar el ticket: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Editar Ticket')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _tituloController,
                decoration: InputDecoration(labelText: 'Título'),
                validator: (value) =>
                    value!.isEmpty ? 'Ingresa un título' : null,
              ),
              TextFormField(
                controller: _descripcionController,
                decoration: InputDecoration(labelText: 'Descripción'),
                maxLines: 3,
                validator: (value) =>
                    value!.isEmpty ? 'Ingresa una descripción' : null,
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _updateTicket,
                child: Text('Actualizar Ticket'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
