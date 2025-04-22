import 'package:flutter/material.dart';
import '../services/api_service.dart';

class TicketEditScreen extends StatefulWidget {
  final Map<String, dynamic> ticket;

  const TicketEditScreen({super.key, required this.ticket});

  @override
  _TicketEditScreenState createState() => _TicketEditScreenState();
}

class _TicketEditScreenState extends State<TicketEditScreen>
    with SingleTickerProviderStateMixin {
  final ApiService apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _tituloController;
  late TextEditingController _descripcionController;
  bool _isLoading = false;

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
    _tituloController = TextEditingController(text: widget.ticket['titulo']);
    _descripcionController =
        TextEditingController(text: widget.ticket['descripcion']);

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
    _tituloController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  void _updateTicket() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final Map<String, dynamic> updatedTicket = {
        'titulo': _tituloController.text.trim(),
        'descripcion': _descripcionController.text.trim(),
      };

      try {
        await apiService.updateTicket(widget.ticket['id'], updatedTicket);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Ticket actualizado con éxito'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Refresca la lista al volver
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al actualizar el ticket: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Editar Ticket',
          style: TextStyle(
            color: secondaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 4,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: secondaryColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                      _buildInfoRow(Icons.confirmation_number, "ID",
                          "#${widget.ticket['id']}"),
                      _buildInfoRow(
                          Icons.person, "Creado por", widget.ticket['usuario']),
                      _buildInfoRow(Icons.support_agent, "Agente",
                          widget.ticket['agente'] ?? 'Sin asignar'),
                      _buildInfoRow(
                          Icons.flag, "Prioridad", widget.ticket['prioridad']),
                      _buildInfoRow(Icons.business, "Departamento",
                          widget.ticket['departamento']),
                      _buildInfoRow(Icons.calendar_today, "Fecha",
                          widget.ticket['creado']),
                      _buildInfoRow(
                          Icons.info, "Estado", widget.ticket['estado']),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Formulario de edición
              Card(
                elevation: 4,
                shadowColor: Colors.black26,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.edit, color: primaryColor),
                            const SizedBox(width: 8),
                            Text(
                              'Editar Información',
                              style: cardTitleStyle,
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        TextFormField(
                          controller: _tituloController,
                          decoration: InputDecoration(
                            labelText: 'Título',
                            prefixIcon: Icon(Icons.title, color: primaryColor),
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
                            filled: true,
                            fillColor: Colors.grey[100],
                          ),
                          validator: (value) =>
                              value!.isEmpty ? 'Ingresa un título' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descripcionController,
                          decoration: InputDecoration(
                            labelText: 'Descripción',
                            prefixIcon:
                                Icon(Icons.description, color: primaryColor),
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
                            filled: true,
                            fillColor: Colors.grey[100],
                          ),
                          maxLines: 5,
                          validator: (value) =>
                              value!.isEmpty ? 'Ingresa una descripción' : null,
                        ),
                        const SizedBox(height: 24),
                        _isLoading
                            ? Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      primaryColor),
                                ),
                              )
                            : ElevatedButton.icon(
                                onPressed: _updateTicket,
                                icon: Icon(Icons.save),
                                label: Text(
                                  'Guardar Cambios',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: secondaryColor,
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 4,
                                ),
                              ),
                      ],
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
}
