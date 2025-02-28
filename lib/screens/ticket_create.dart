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
        SnackBar(content: Text('Error al cargar los datos: $e')),
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
        SnackBar(content: Text('📂 Archivo seleccionado: $_nombreArchivo')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ No se seleccionó ningún archivo')),
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
          SnackBar(content: Text('❌ Error: $e')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⚠️ Por favor completa todos los campos')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Crear Nuevo Ticket')),
      body: _isFetchingData
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _tituloController,
                              decoration: InputDecoration(labelText: 'Título'),
                              validator: (value) => value!.isEmpty
                                  ? 'Por favor ingresa un título'
                                  : null,
                            ),
                            TextFormField(
                              controller: _descripcionController,
                              decoration:
                                  InputDecoration(labelText: 'Descripción'),
                              maxLines: 3,
                              validator: (value) => value!.isEmpty
                                  ? 'Por favor ingresa una descripción'
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 16.0),
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            DropdownButtonFormField<int>(
                              value: _departamento,
                              decoration:
                                  InputDecoration(labelText: 'Departamento'),
                              items: departamentos.map((departamento) {
                                return DropdownMenuItem<int>(
                                  value: departamento['id'],
                                  child: Text(departamento['nombre']),
                                );
                              }).toList(),
                              onChanged: (value) =>
                                  setState(() => _departamento = value),
                              validator: (value) => value == null
                                  ? 'Por favor selecciona un departamento'
                                  : null,
                            ),
                            DropdownButtonFormField<int>(
                              value: _prioridad,
                              decoration:
                                  InputDecoration(labelText: 'Prioridad'),
                              items: prioridades.map((prioridad) {
                                return DropdownMenuItem<int>(
                                  value: prioridad['id'],
                                  child: Text(prioridad['nombre']),
                                );
                              }).toList(),
                              onChanged: (value) =>
                                  setState(() => _prioridad = value),
                              validator: (value) => value == null
                                  ? 'Por favor selecciona una prioridad'
                                  : null,
                            ),
                            TextFormField(
                              initialValue: "Abierto", // Mostrar el estado fijo
                              decoration: InputDecoration(labelText: 'Estado'),
                              enabled: false, // Bloquea la edición
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 16.0),
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            ElevatedButton.icon(
                              onPressed: _seleccionarArchivo,
                              icon: Icon(Icons.attach_file),
                              label: Text('Adjuntar Archivo'),
                            ),
                            if (_nombreArchivo != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text('📂 $_nombreArchivo',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    _isLoading
                        ? Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: _submitForm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green, // 🔹 Fondo verde
                              foregroundColor: Colors.white, // 🔹 Texto blanco
                            ),
                            child: Text('Crear Ticket'),
                          ),
                  ],
                ),
              ),
            ),
    );
  }
}
