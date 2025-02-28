import 'package:flutter/material.dart';
import '../services/api_service.dart';

class UserEditScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const UserEditScreen({super.key, required this.user});

  @override
  _UserEditScreenState createState() => _UserEditScreenState();
}

class _UserEditScreenState extends State<UserEditScreen> {
  final ApiService apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nombreController;
  late TextEditingController _correoController;
  TextEditingController _claveController = TextEditingController();

  List<dynamic> roles = [];
  List<dynamic> sucursales = [];
  List<dynamic> estados = [];
  List<dynamic> departamentos = [];
  List<int> selectedDepartamentos = [];

  int? selectedRol;
  int? selectedSucursal;
  int? selectedEstado;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nombreController = TextEditingController(text: widget.user['nombre']);
    _correoController = TextEditingController(text: widget.user['correo']);
    selectedRol = widget.user['id_rol'];
    selectedSucursal = widget.user['id_sucursal'];
    selectedEstado = widget.user['id_estado'];

    if (widget.user.containsKey('departamentos')) {
      selectedDepartamentos =
          List<int>.from(widget.user['departamentos'].map((d) => d['id']));
    }

    _loadData();
  }

  Future<void> _loadData() async {
    try {
      roles = await apiService.getRoles();
      sucursales = await apiService.getSucursales();
      estados = await apiService.getEstadosUsuarios();
      departamentos = await apiService.getDepartamentos();
      setState(() {});
    } catch (e) {
      print("❌ Error al cargar datos: $e");
    }
  }

  void _updateUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    Map<String, dynamic> updatedData = {};

    if (_nombreController.text.isNotEmpty &&
        _nombreController.text != widget.user['nombre']) {
      updatedData['nombre'] = _nombreController.text;
    }
    if (_correoController.text.isNotEmpty &&
        _correoController.text != widget.user['correo']) {
      updatedData['correo'] = _correoController.text;
    }
    if (_claveController.text.isNotEmpty) {
      updatedData['clave'] = _claveController.text;
    }
    if (selectedRol != null && selectedRol != widget.user['id_rol']) {
      updatedData['id_rol'] = selectedRol;
    }
    if (selectedSucursal != null &&
        selectedSucursal != widget.user['id_sucursal']) {
      updatedData['id_sucursal'] = selectedSucursal;
    }
    if (selectedEstado != null && selectedEstado != widget.user['id_estado']) {
      updatedData['id_estado'] = selectedEstado;
    }
    if (selectedDepartamentos.isNotEmpty) {
      updatedData['id_departamento'] = selectedDepartamentos;
    }

    if (updatedData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("No hay cambios para actualizar")),
      );
      return;
    }

    try {
      await apiService.updateUser(widget.user['id'], updatedData);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Usuario actualizado exitosamente')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _deleteUser() async {
    bool confirmDelete = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Confirmar eliminación'),
            content: Text('¿Estás seguro de que deseas eliminar este usuario?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('Eliminar', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmDelete) {
      try {
        await apiService.deleteUser(widget.user['id']);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Usuario eliminado correctamente')),
        );
        Navigator.pop(context, true);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error al eliminar usuario')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Editar Usuario'),
        backgroundColor: Colors.green, // Fondo verde
        foregroundColor: Colors.white, // Texto blanco
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nombreController,
                        decoration: InputDecoration(
                          labelText: 'Nombre',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => value!.isEmpty
                            ? 'Por favor ingresa el nombre'
                            : null,
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _correoController,
                        decoration: InputDecoration(
                          labelText: 'Correo',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => value!.isEmpty
                            ? 'Por favor ingresa el correo'
                            : null,
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _claveController,
                        decoration: InputDecoration(
                          labelText: 'Nueva Clave (opcional)',
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      DropdownButtonFormField<int>(
                        value: selectedRol,
                        decoration: InputDecoration(
                          labelText: 'Rol',
                          border: OutlineInputBorder(),
                        ),
                        items: roles.map((rol) {
                          return DropdownMenuItem<int>(
                            value: rol['id'],
                            child: Text(rol['rol']),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedRol = value;
                          });
                        },
                      ),
                      SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        value: selectedSucursal,
                        decoration: InputDecoration(
                          labelText: 'Sucursal',
                          border: OutlineInputBorder(),
                        ),
                        items: sucursales.map((sucursal) {
                          return DropdownMenuItem<int>(
                            value: sucursal['id'],
                            child: Text(sucursal['nombre']),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedSucursal = value;
                          });
                        },
                      ),
                      SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        value: selectedEstado,
                        decoration: InputDecoration(
                          labelText: 'Estado',
                          border: OutlineInputBorder(),
                        ),
                        items: estados.map((estado) {
                          return DropdownMenuItem<int>(
                            value: estado['id'],
                            child: Text(estado['nombre']),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedEstado = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              if (selectedRol ==
                  2) // Si el usuario es un agente, mostrar departamentos
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Departamentos", style: TextStyle(fontSize: 16)),
                        Wrap(
                          spacing: 8.0,
                          children: departamentos.map<Widget>((departamento) {
                            return FilterChip(
                              label: Text(departamento['nombre']),
                              selected: selectedDepartamentos
                                  .contains(departamento['id']),
                              onSelected: (bool selected) {
                                setState(() {
                                  if (selected) {
                                    selectedDepartamentos
                                        .add(departamento['id']);
                                  } else {
                                    selectedDepartamentos
                                        .remove(departamento['id']);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              SizedBox(height: 16),
              _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        ElevatedButton(
                          onPressed: _updateUser,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            minimumSize: Size(double.infinity, 50),
                          ),
                          child: Text('Actualizar Usuario'),
                        ),
                        SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _deleteUser,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            minimumSize: Size(double.infinity, 50),
                          ),
                          child: Text('Eliminar Usuario'),
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
