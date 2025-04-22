import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';

class TicketCreateScreen extends StatefulWidget {
  const TicketCreateScreen({super.key});

  @override
  _TicketCreateScreenState createState() => _TicketCreateScreenState();
}

class _TicketCreateScreenState extends State<TicketCreateScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _tituloController = TextEditingController();
  final TextEditingController _descripcionController = TextEditingController();
  int? _prioridad;
  int? _departamento;
  int? _estado;
  bool _isLoading = false;
  bool _isFetchingData = true;
  List<dynamic> prioridades = [];
  List<dynamic> departamentos = [];
  Uint8List? _archivoBytes;
  String? _nombreArchivo;
  final ApiService apiService = ApiService();

  // Animación
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Colores y estilos
  final Color primaryColor = Colors.green;
  final Color secondaryColor = Colors.white;
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
    _fetchDropdownData();

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

  Future<void> _fetchDropdownData() async {
    try {
      final prioridadesData = await apiService.getPrioridades();
      final departamentosData = await apiService.getDepartamentos();
      final estadosData = await apiService.getEstadosUsuarios();

      setState(() {
        prioridades = prioridadesData;
        departamentos = departamentosData;
        _isFetchingData = false;

        // Estado "Abierto" por defecto (sin mostrarlo en el formulario)
        _estado = estadosData.firstWhere(
          (e) => e['nombre'] == 'Abierto',
          orElse: () => estadosData.isNotEmpty ? estadosData.first : null,
        )?['id'];

        // Prioridad "Baja" por defecto
        _prioridad = prioridadesData.firstWhere(
          (p) => p['nombre'] == 'Baja',
          orElse: () =>
              prioridadesData.isNotEmpty ? prioridadesData.first : null,
        )?['id'];
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar los datos: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isFetchingData = false;
      });
    }
  }

  void _seleccionarArchivo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      setState(() {
        _archivoBytes = result.files.single.bytes;
        _nombreArchivo = result.files.single.name;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📂 Archivo seleccionado: $_nombreArchivo'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ No se seleccionó ningún archivo'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate() &&
        _prioridad != null &&
        _departamento != null) {
      setState(() {
        _isLoading = true;
      });

      Map<String, dynamic> ticketData = {
        'id_usuario': 1, // 🔹 Reemplazar con el usuario autenticado
        'id_estado': _estado, // 🔹 Estado "Abierto"
        'id_prioridad': _prioridad,
        'id_departamento': _departamento,
        'titulo': _tituloController.text,
        'descripcion': _descripcionController.text,
      };

      try {
        // 🔹 Crear el ticket y recibir la respuesta con el ID
        var response = await apiService.createTicket(ticketData);

        if (response.containsKey('ticket_id')) {
          int ticketId = response['ticket_id']; // ✅ Ahora esto no dará error

          // 🔹 Si hay un archivo adjunto, subirlo
          if (_archivoBytes != null && _nombreArchivo != null) {
            await apiService.subirArchivo(
                _archivoBytes!, _nombreArchivo!, ticketId);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ Ticket creado con archivo adjunto'),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ Ticket creado exitosamente'),
                backgroundColor: Colors.green,
              ),
            );
          }

          Navigator.pop(context, true);
        } else {
          throw Exception("No se recibió un ticket_id en la respuesta");
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠️ Por favor completa todos los campos'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isFetchingData) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Crear Nuevo Ticket',
            style: TextStyle(
              color: secondaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: primaryColor,
          elevation: 4,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
              SizedBox(height: 16),
              Text(
                'Cargando datos...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Crear Nuevo Ticket',
          style: TextStyle(
            color: secondaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 4,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCard(
                  title: 'Información del Ticket',
                  icon: Icons.info_outline,
                  children: [
                    _buildTextField(_tituloController, 'Título', Icons.title),
                    const SizedBox(height: 16),
                    _buildTextField(
                      _descripcionController,
                      'Descripción',
                      Icons.description,
                      maxLines: 5,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildCard(
                  title: 'Clasificación',
                  icon: Icons.category,
                  children: [
                    _buildDropdown(
                      label: 'Departamento',
                      value: _departamento,
                      items: departamentos,
                      icon: Icons.business,
                      onChanged: (v) => setState(() => _departamento = v),
                    ),
                    const SizedBox(height: 16),
                    _buildDropdown(
                      label: 'Prioridad',
                      value: _prioridad,
                      items: prioridades,
                      icon: Icons.flag,
                      onChanged: (v) => setState(() => _prioridad = v),
                    ),
                    const SizedBox(height: 16),
                    _buildReadonlyField('Estado', 'Abierto', Icons.info),
                  ],
                ),
                const SizedBox(height: 16),
                _buildCard(
                  title: 'Archivo Adjunto',
                  icon: Icons.attach_file,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _seleccionarArchivo,
                      icon: const Icon(Icons.attach_file),
                      label: const Text('Seleccionar Archivo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: secondaryColor,
                        padding:
                            EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    if (_nombreArchivo != null)
                      Container(
                        margin: EdgeInsets.only(top: 12),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.insert_drive_file, color: primaryColor),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _nombreArchivo!,
                                style: TextStyle(fontWeight: FontWeight.w500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  _archivoBytes = null;
                                  _nombreArchivo = null;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(primaryColor),
                        ),
                      )
                    : ElevatedButton(
                        onPressed: _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: secondaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 4,
                        ),
                        child: Text(
                          'Crear Ticket',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
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
                Icon(icon, color: primaryColor),
                SizedBox(width: 8),
                Text(
                  title,
                  style: cardTitleStyle,
                ),
              ],
            ),
            Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: primaryColor),
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
      validator: (v) => v == null || v.isEmpty ? 'Campo requerido' : null,
    );
  }

  Widget _buildDropdown({
    required String label,
    required int? value,
    required List<dynamic> items,
    required IconData icon,
    required ValueChanged<int?> onChanged,
  }) {
    return DropdownButtonFormField<int>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: primaryColor),
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
      items: items.map<DropdownMenuItem<int>>((item) {
        return DropdownMenuItem<int>(
          value: item['id'],
          child: Text(item['nombre']),
        );
      }).toList(),
      onChanged: onChanged,
      validator: (v) => v == null ? 'Selecciona una opción' : null,
    );
  }

  Widget _buildReadonlyField(String label, String value, IconData icon) {
    return TextFormField(
      initialValue: value,
      enabled: false,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        filled: true,
        fillColor: Colors.grey[100],
      ),
      style: TextStyle(color: Colors.grey[600]),
    );
  }
}
