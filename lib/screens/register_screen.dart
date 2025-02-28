import 'package:flutter/material.dart';
import '../services/api_service.dart';

class RegisterScreen extends StatefulWidget {
  final String userRole; // Recibe el rol del usuario

  const RegisterScreen({Key? key, required this.userRole}) : super(key: key);

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final ApiService apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _correoController = TextEditingController();
  final TextEditingController _claveController = TextEditingController();
  int? _selectedRol;
  int? _selectedSucursal;
  bool _isLoading = false;
  List<dynamic> _roles = [];
  List<dynamic> _sucursales = [];

  @override
  void initState() {
    super.initState();
    _loadRoles();
    _loadSucursales();
  }

  Future<void> _loadRoles() async {
    try {
      List<dynamic> roles = await apiService.getRoles();
      setState(() {
        _roles = roles;
      });
    } catch (e) {
      print("Error al cargar roles: $e");
    }
  }

  Future<void> _loadSucursales() async {
    try {
      List<dynamic> sucursales = await apiService.getSucursales();
      setState(() {
        _sucursales = sucursales;
      });
    } catch (e) {
      print("Error al cargar sucursales: $e");
    }
  }

  void _register() async {
    if (_formKey.currentState!.validate() &&
        _selectedRol != null &&
        _selectedSucursal != null) {
      setState(() => _isLoading = true);

      try {
        await apiService.register({
          'nombre': _nombreController.text,
          'correo': _correoController.text,
          'clave': _claveController.text,
          'id_rol': _selectedRol,
          'id_sucursal': _selectedSucursal,
          'id_estado': 1 // Siempre activo por defecto
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Usuario registrado exitosamente')),
        );

        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.userRole != "1") {
      return Scaffold(
        body: Center(child: Text("Acceso denegado")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Registro de Usuario'),
        backgroundColor: Colors.green, // Fondo verde
        foregroundColor: Colors.white, // Texto blanco
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nombreController,
                decoration: InputDecoration(labelText: 'Nombre'),
                validator: (value) =>
                    value!.isEmpty ? 'Ingrese su nombre' : null,
              ),
              TextFormField(
                controller: _correoController,
                decoration: InputDecoration(labelText: 'Correo'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) =>
                    value!.isEmpty ? 'Ingrese su correo' : null,
              ),
              TextFormField(
                controller: _claveController,
                decoration: InputDecoration(labelText: 'Clave'),
                obscureText: true,
                validator: (value) =>
                    value!.isEmpty ? 'Ingrese una clave' : null,
              ),
              DropdownButtonFormField<int>(
                value: _selectedRol,
                hint: Text('Seleccionar Rol'),
                items: _roles.map<DropdownMenuItem<int>>((rol) {
                  return DropdownMenuItem<int>(
                    value: rol['id'],
                    child: Text(rol['rol']),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedRol = value;
                  });
                },
              ),
              DropdownButtonFormField<int>(
                value: _selectedSucursal,
                hint: Text('Seleccionar Sucursal'),
                items: _sucursales.map<DropdownMenuItem<int>>((sucursal) {
                  return DropdownMenuItem<int>(
                    value: sucursal['id'],
                    child: Text(sucursal['nombre']),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedSucursal = value;
                  });
                },
              ),
              SizedBox(height: 20),
              _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green, // 🔹 Fondo verde
                        foregroundColor: Colors.white, // 🔹 Texto blanco
                      ),
                      child: Text('Crear Usuario'),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
