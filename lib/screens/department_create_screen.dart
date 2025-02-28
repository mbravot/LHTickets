import 'package:flutter/material.dart';
import '../services/api_service.dart';

class DepartmentCreateScreen extends StatefulWidget {
  const DepartmentCreateScreen({super.key});

  @override
  _DepartmentCreateScreenState createState() => _DepartmentCreateScreenState();
}

class _DepartmentCreateScreenState extends State<DepartmentCreateScreen> {
  final ApiService apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nombreController = TextEditingController();
  bool _isLoading = false; // Declaración e inicialización de _isLoading

  void _crearDepartamento() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true; // Activar el indicador de carga
      });

      try {
        await apiService.crearDepartamento(_nombreController.text);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Departamento creado correctamente')),
        );
        Navigator.pop(context, true); // Regresar y recargar la lista
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error al crear el departamento: $e')),
        );
      } finally {
        setState(() {
          _isLoading = false; // Desactivar el indicador de carga
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Crear Departamento'),
        backgroundColor: Colors.green, // Fondo verde
        foregroundColor: Colors.white, // Texto blanco
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nombreController,
                decoration: InputDecoration(
                  labelText: 'Nombre del Departamento',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Por favor ingresa el nombre' : null,
              ),
              SizedBox(height: 20), // Ajusta la altura según tus necesidades
              _isLoading
                  ? Center(
                      child:
                          CircularProgressIndicator()) // Muestra un indicador de carga si _isLoading es true
                  : ElevatedButton(
                      onPressed:
                          _crearDepartamento, // Función que se ejecuta al presionar el botón
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green, // Fondo verde
                        foregroundColor: Colors.white, // Texto blanco
                      ),
                      child: Text('Crear Departamento'), // Texto del botón
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
