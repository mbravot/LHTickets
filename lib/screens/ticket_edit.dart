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

  // Agregar variables faltantes
  int? _prioridad;
  int? _departamento;
  int? _estado;
  List<dynamic> prioridades = [];
  List<dynamic> departamentos = [];

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

  // Agregar variable para almacenar las categorías disponibles
  List<dynamic> _categorias = [];
  String? _selectedCategoriaId;

  @override
  void initState() {
    super.initState();
    // DEBUG ticket recibido
    _tituloController = TextEditingController(text: widget.ticket['titulo']);
    _descripcionController =
        TextEditingController(text: widget.ticket['descripcion']);
    
    // Forzar tipo int para todos los campos por id
    _prioridad = widget.ticket['id_prioridad'] is int
        ? widget.ticket['id_prioridad']
        : int.tryParse(widget.ticket['id_prioridad']?.toString() ?? '');
    _departamento = widget.ticket['id_departamento'] is int
        ? widget.ticket['id_departamento']
        : int.tryParse(widget.ticket['id_departamento']?.toString() ?? '');
    _estado = widget.ticket['id_estado'] is int
        ? widget.ticket['id_estado']
        : int.tryParse(widget.ticket['id_estado']?.toString() ?? '');
    _selectedCategoriaId = widget.ticket['id_categoria']?.toString();
    // Prints para depuración
    print('INIT _prioridad: [32m'+_prioridad.toString()+'\x1b[0m');
    print('INIT _departamento: [32m'+_departamento.toString()+'\x1b[0m');
    print('INIT _estado: [32m'+_estado.toString()+'\x1b[0m');

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

    _fetchDropdownData();
    // Cargar categorías iniciales si hay departamento
    if (_departamento != null) {
      _loadCategorias(_departamento.toString());
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _tituloController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  Future<void> _fetchDropdownData() async {
    try {
      final prioridadesData = await apiService.getPrioridades();
      final departamentosData = await apiService.getDepartamentos();
      final estadosData = await apiService.getEstadosUsuarios();

      // Prints para depuración
      print("Departamentos recibidos: $departamentosData");
      print("ID departamento del ticket: "+ _departamento.toString());

      setState(() {
        prioridades = prioridadesData;
        departamentos = departamentosData;
        // Si _prioridad sigue en null, buscar el id por el nombre
        if (_prioridad == null && widget.ticket['prioridad'] != null) {
          final prioridadEncontrada = prioridades.firstWhere(
            (p) => p['nombre'] == widget.ticket['prioridad'],
            orElse: () => null,
          );
          if (prioridadEncontrada != null) {
            _prioridad = prioridadEncontrada['id'] is int
              ? prioridadEncontrada['id']
              : int.tryParse(prioridadEncontrada['id'].toString());
            print('PRIORIDAD corregida por nombre: '+_prioridad.toString());
          }
        }
        // Eliminar búsqueda por nombre para estado, solo usar id_estado
      });
    } catch (e) {
      print("Error al cargar datos: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar los datos: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Método para cargar categorías según el departamento seleccionado
  Future<void> _loadCategorias(String? departamentoId) async {
    if (departamentoId == null) {
      setState(() {
        _categorias = [];
        _selectedCategoriaId = null;
      });
      return;
    }
    try {
      final categorias = await apiService.getCategorias(departamentoId);
      setState(() {
        _categorias = categorias;
        // Si la categoría seleccionada sigue existiendo, mantenla
        if (_selectedCategoriaId != null &&
            _categorias.any((c) => c['id'].toString() == _selectedCategoriaId)) {
          // no cambiar
        } else if (_categorias.isNotEmpty) {
          _selectedCategoriaId = _categorias.first['id'].toString();
        } else {
          _selectedCategoriaId = null;
        }
      });
    } catch (e) {
      print("Error al cargar categorías: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar categorías: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // Modificar el método _onDepartamentoChanged para usar int
  void _onDepartamentoChanged(int? value) {
    setState(() {
      _departamento = value;
      // Cargar categorías al cambiar el departamento
      if (value != null) {
        _loadCategorias(value.toString());
      }
    });
  }

  // Modificar el método _submitForm para incluir id_categoria
  Future<void> _submitForm() async {
    // Prints para depuración antes de guardar
    print('SUBMIT _prioridad: [34m'+_prioridad.toString()+'\x1b[0m');
    print('SUBMIT _departamento: [34m'+_departamento.toString()+'\x1b[0m');
    print('SUBMIT _estado: [34m'+_estado.toString()+'\x1b[0m');
    if (_tituloController.text.trim().isEmpty || _descripcionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⚠️ El título y la descripción no pueden estar vacíos'), backgroundColor: Colors.red),
      );
      return;
    }
    if (_prioridad == null || _departamento == null || _estado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⚠️ Prioridad, departamento y estado son obligatorios'), backgroundColor: Colors.red),
      );
      return;
    }
    // La categoría puede ser opcional, si tu lógica lo permite

    setState(() {
      _isLoading = true;
    });

    Map<String, dynamic> ticketData = {
      'id_usuario': 1, // 🔹 Reemplazar con el usuario autenticado
      'id_estado': _estado,
      'id_prioridad': _prioridad,
      'id_departamento': _departamento,
      'titulo': _tituloController.text,
      'descripcion': _descripcionController.text,
      'id_categoria': _selectedCategoriaId,
    };

    try {
      await apiService.updateTicket(widget.ticket['id'].toString(), ticketData);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ticket actualizado exitosamente'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      print("Error al actualizar ticket: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar ticket: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mostrar loader si los datos aún no están cargados
    if (departamentos.isEmpty) {
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
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
          ),
        ),
      );
    }

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
                          "#${widget.ticket['id'].toString()}"),
                      _buildInfoRow(
                          Icons.person, "Creado por", widget.ticket['usuario']),
                      _buildInfoRow(Icons.support_agent, "Agente",
                          widget.ticket['agente'] ?? 'Sin asignar'),
                      _buildInfoRow(
                          Icons.flag, "Prioridad", widget.ticket['prioridad']),
                      _buildInfoRow(Icons.business, "Departamento", 
                        departamentos.firstWhere(
                          (d) => d['id'] == _departamento,
                          orElse: () => {'nombre': 'Sin departamento'},
                        )['nombre']
                      ),
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
                        const SizedBox(height: 16),
                        DropdownButtonFormField<int>(
                          value: _prioridad,
                          decoration: InputDecoration(
                            labelText: 'Prioridad',
                            prefixIcon: Icon(Icons.flag, color: primaryColor),
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
                            fillColor: Colors.white,
                          ),
                          items: prioridades.map<DropdownMenuItem<int>>((prioridad) {
                            return DropdownMenuItem<int>(
                              value: prioridad['id'] is int ? prioridad['id'] : int.tryParse(prioridad['id'].toString()),
                              child: Text(prioridad['nombre']),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _prioridad = value;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Por favor selecciona una prioridad';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<int>(
                          value: _departamento,
                          decoration: InputDecoration(
                            labelText: 'Departamento',
                            prefixIcon: Icon(Icons.business, color: primaryColor),
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
                            fillColor: Colors.white,
                          ),
                          items: departamentos.map<DropdownMenuItem<int>>((departamento) {
                            return DropdownMenuItem<int>(
                              value: departamento['id'] is int ? departamento['id'] : int.tryParse(departamento['id'].toString()),
                              child: Text(departamento['nombre']),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _departamento = value;
                              _loadCategorias(value?.toString());
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Por favor selecciona un departamento';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _selectedCategoriaId != null ? _selectedCategoriaId.toString() : null,
                          decoration: InputDecoration(
                            labelText: 'Categoría',
                            prefixIcon: Icon(Icons.label, color: primaryColor),
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
                            fillColor: Colors.white,
                          ),
                          items: _categorias.map<DropdownMenuItem<String>>((categoria) {
                            return DropdownMenuItem<String>(
                              value: categoria['id'].toString(),
                              child: Text(categoria['nombre']),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedCategoriaId = value;
                            });
                          },
                          validator: (value) {
                            // Solo validar si hay categorías cargadas
                            if (_categorias.isNotEmpty && (value == null || value.isEmpty)) {
                              return 'Por favor selecciona una categoría';
                            }
                            return null;
                          },
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
                                onPressed: _submitForm,
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
