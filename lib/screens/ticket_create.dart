import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';

class TicketCreateScreen extends StatefulWidget {
  const TicketCreateScreen({super.key});

  @override
  _TicketCreateScreenState createState() => _TicketCreateScreenState();
}

class _TicketCreateScreenState extends State<TicketCreateScreen> {
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

  @override
  void initState() {
    super.initState();
    _fetchDropdownData();
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
  @override
  Widget build(BuildContext context) {
    const primaryColor = Colors.green;
    const secondaryColor = Colors.white;

    if (_isFetchingData) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Crear Nuevo Ticket',
              style: TextStyle(color: secondaryColor)),
          backgroundColor: primaryColor,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Nuevo Ticket',
            style: TextStyle(color: secondaryColor)),
        backgroundColor: primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildCard([
                _buildTextField(_tituloController, 'Título', Icons.title),
                const SizedBox(height: 12),
                _buildTextField(
                    _descripcionController, 'Descripción', Icons.description,
                    maxLines: 3),
              ]),
              const SizedBox(height: 16),
              _buildCard([
                _buildDropdown(
                  label: 'Departamento',
                  value: _departamento,
                  items: departamentos,
                  icon: Icons.business,
                  onChanged: (v) => setState(() => _departamento = v),
                ),
                const SizedBox(height: 12),
                _buildDropdown(
                  label: 'Prioridad',
                  value: _prioridad,
                  items: prioridades,
                  icon: Icons.flag,
                  onChanged: (v) => setState(() => _prioridad = v),
                ),
                const SizedBox(height: 12),
                _buildReadonlyField('Estado', 'Abierto', Icons.info),
              ]),
              const SizedBox(height: 16),
              _buildCard([
                ElevatedButton.icon(
                  onPressed: _seleccionarArchivo,
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Adjuntar Archivo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: secondaryColor,
                  ),
                ),
                if (_nombreArchivo != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('📂 $_nombreArchivo',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
              ]),
              const SizedBox(height: 24),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: secondaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Crear Ticket',
                          style: TextStyle(fontSize: 16)),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Card(
      color: Colors.grey[100],
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: children),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon,
      {int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      style: const TextStyle(color: Colors.grey),
    );
  }
}
