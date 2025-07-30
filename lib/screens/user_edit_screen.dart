import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class UserEditScreen extends StatefulWidget {
  final Map<String, dynamic>? user;

  const UserEditScreen({super.key, this.user});

  @override
  _UserEditScreenState createState() => _UserEditScreenState();
}

class _UserEditScreenState extends State<UserEditScreen>
    with SingleTickerProviderStateMixin {
  final ApiService apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _usuarioController;
  late TextEditingController _nombreController;
  late TextEditingController _apellidoPaternoController;
  late TextEditingController _apellidoMaternoController;
  late TextEditingController _correoController;
  TextEditingController _claveController = TextEditingController();

  List<dynamic> roles = [];
  List<dynamic> sucursales = [];
  List<dynamic> estados = [];
  List<dynamic> departamentos = [];
  List<String> selectedDepartamentos = [];
  List<String> selectedSucursalesAutorizadas = [];

  String? selectedRol;
  String? selectedSucursal;
  String? selectedEstadoId;
  bool _isLoading = false;
  bool _isNewUser = false;

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

  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _isNewUser = widget.user == null;
    
    // Inicializar el campo nombre de usuario
    // El backend ahora devuelve el nombre de usuario en el campo 'usuario'
    String nombreUsuario = widget.user?['usuario'] ?? 
                          widget.user?['id'] ?? 
                          widget.user?['username'] ?? 
                          widget.user?['user'] ?? 
                          '';
    _usuarioController = TextEditingController(text: nombreUsuario);
    
    // Separar nombre y apellidos si el backend envía el nombre completo
    String nombreCompleto = widget.user?['nombre'] ?? '';
    List<String> partesNombre = nombreCompleto.trim().split(' ');
    
    if (partesNombre.length >= 2) {
      // Si hay al menos 2 partes, la primera es el nombre y la segunda el apellido paterno
      _nombreController = TextEditingController(text: partesNombre[0]);
      _apellidoPaternoController = TextEditingController(text: partesNombre[1]);
      
      // Si hay más de 2 partes, el resto es el apellido materno
      if (partesNombre.length > 2) {
        _apellidoMaternoController = TextEditingController(
          text: partesNombre.sublist(2).join(' ')
        );
      } else {
        _apellidoMaternoController = TextEditingController(
          text: widget.user?['apellido_materno'] ?? ''
        );
      }
    } else {
      // Si solo hay una parte o está vacío, usar el valor original
      _nombreController = TextEditingController(text: nombreCompleto);
      _apellidoPaternoController = TextEditingController(
        text: widget.user?['apellido_paterno'] ?? ''
      );
      _apellidoMaternoController = TextEditingController(
        text: widget.user?['apellido_materno'] ?? ''
      );
    }
    
    _correoController =
        TextEditingController(text: widget.user?['correo'] ?? '');
    selectedRol = widget.user?['id_rol']?.toString();
    selectedSucursal = widget.user?['id_sucursalactiva']?.toString();
    selectedEstadoId = widget.user?['id_estado']?.toString();

    if (widget.user?.containsKey('departamentos') ?? false) {
      selectedDepartamentos =
          List<String>.from(widget.user!['departamentos'].map((d) => d['id'].toString()));
    }

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

    _loadData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _usuarioController.dispose();
    _nombreController.dispose();
    _apellidoPaternoController.dispose();
    _apellidoMaternoController.dispose();
    _correoController.dispose();
    _claveController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);
      roles = await apiService.getRoles();
      sucursales = await apiService.getSucursales();
      estados = await apiService.getEstadosUsuarios();
      departamentos = await apiService.getDepartamentos();
      if (selectedEstadoId == null && estados.isNotEmpty) {
        selectedEstadoId = estados.first['id'].toString();
      }
      if (widget.user != null && widget.user!['sucursales_autorizadas'] != null) {
        selectedSucursalesAutorizadas = List<String>.from(
          widget.user!['sucursales_autorizadas'].map((s) => s['id'].toString()),
        );
      }
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error al cargar los datos'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _saveUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_isNewUser) {
        // Crear nuevo usuario
        Map<String, dynamic> userData = {
          'usuario': _usuarioController.text,
          'nombre': _nombreController.text,
          'apellido_paterno': _apellidoPaternoController.text,
          'apellido_materno': _apellidoMaternoController.text.isNotEmpty 
              ? _apellidoMaternoController.text 
              : null,
          'correo': _correoController.text,
          'clave': _claveController.text,
          'id_rol': selectedRol,
          'id_sucursalactiva': selectedSucursal,
          'id_estado': selectedEstadoId,
        };

        // Agregar sucursales autorizadas si se han seleccionado
        if (selectedSucursalesAutorizadas.isNotEmpty) {
          userData['sucursales_autorizadas'] = selectedSucursalesAutorizadas;
        }

        await apiService.register(userData);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Usuario creado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Actualizar usuario existente
        Map<String, dynamic> updatedData = {};

        // Obtener el ID correcto del usuario (puede estar en 'id' o en otro campo)
        String userId = widget.user!['id']?.toString() ?? 
                       widget.user!['usuario']?.toString() ?? 
                       '';

        if (_usuarioController.text.isNotEmpty &&
            _usuarioController.text != widget.user!['usuario']) {
          updatedData['usuario'] = _usuarioController.text;
        }
        if (_nombreController.text.isNotEmpty &&
            _nombreController.text != widget.user!['nombre']) {
          updatedData['nombre'] = _nombreController.text;
        }
        if (_apellidoPaternoController.text.isNotEmpty &&
            _apellidoPaternoController.text != widget.user!['apellido_paterno']) {
          updatedData['apellido_paterno'] = _apellidoPaternoController.text;
        }
        if (_apellidoMaternoController.text != widget.user!['apellido_materno']) {
          updatedData['apellido_materno'] = _apellidoMaternoController.text.isNotEmpty 
              ? _apellidoMaternoController.text 
              : null;
        }
        if (_correoController.text.isNotEmpty &&
            _correoController.text != widget.user!['correo']) {
          updatedData['correo'] = _correoController.text;
        }
        if (_claveController.text.isNotEmpty) {
          updatedData['clave'] = _claveController.text;
        }
        if (selectedRol != null && selectedRol != widget.user!['id_rol']?.toString()) {
          updatedData['id_rol'] = selectedRol;
        }
        if (selectedSucursal != null &&
            selectedSucursal != widget.user!['id_sucursalactiva']?.toString()) {
          updatedData['id_sucursalactiva'] = selectedSucursal;
        }
        if (selectedEstadoId != null && selectedEstadoId != widget.user!['id_estado']?.toString()) {
          updatedData['id_estado'] = selectedEstadoId;
        }

        // Agregar sucursales autorizadas si han cambiado
        if (widget.user != null && widget.user!['sucursales_autorizadas'] != null) {
          final sucursalesActuales = List<String>.from(
            widget.user!['sucursales_autorizadas'].map((s) => s['id'].toString()),
          );
          if (!listEquals(sucursalesActuales, selectedSucursalesAutorizadas)) {
            updatedData['sucursales_autorizadas'] = selectedSucursalesAutorizadas;
          }
        } else if (selectedSucursalesAutorizadas.isNotEmpty) {
          updatedData['sucursales_autorizadas'] = selectedSucursalesAutorizadas;
        }

        if (updatedData.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("ℹ️ No hay cambios para actualizar"),
              backgroundColor: Colors.blue,
            ),
          );
          return;
        }

        await apiService.updateUser(userId, updatedData);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Usuario actualizado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _deleteUser() async {
    if (_isNewUser) return;

    bool confirmDelete = await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red),
                SizedBox(width: 8),
                Text('Confirmar eliminación'),
              ],
            ),
            content: Text('¿Estás seguro de que deseas eliminar este usuario?'),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: Text('Eliminar'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmDelete) {
      try {
        await apiService.deleteUser(widget.user!['id']);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Usuario eliminado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } catch (e) {
        String errorMsg = e.toString();
        // Buscar mensaje específico del backend
        if (errorMsg.contains('tickets asociados')) {
          errorMsg = 'No se puede eliminar el usuario porque tiene tickets asociados.';
        } else {
          // Extraer mensaje del backend si viene en formato JSON
          final regex = RegExp(r'\{.*\}');
          final match = regex.firstMatch(errorMsg);
          if (match != null) {
            try {
              final Map<String, dynamic> json = jsonDecode(match.group(0)!);
              if (json['error'] != null) errorMsg = json['error'];
            } catch (_) {}
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ $errorMsg'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    bool isRequired = true,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
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
        fillColor: Colors.grey[100],
      ),
      validator: isRequired ? (value) {
        return value!.isEmpty ? 'Campo requerido' : null;
      } : null,
    );
  }

  Widget _buildDropdownField<T>({
    required T? value,
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
    bool isRequired = true,
  }) {
    return DropdownButtonFormField<T>(
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
        fillColor: Colors.grey[100],
      ),
      items: items,
      onChanged: onChanged,
      validator: isRequired ? (value) => value == null ? 'Campo requerido' : null : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNewUser ? 'Crear Usuario' : 'Editar Usuario'),
        backgroundColor: primaryColor,
        foregroundColor: secondaryColor,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [primaryColor.withOpacity(0.1), backgroundColor],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Tarjeta de información personal
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
                              Icon(Icons.person_outline, color: primaryColor),
                              SizedBox(width: 8),
                              Text(
                                'Información Personal',
                                style: cardTitleStyle,
                              ),
                            ],
                          ),
                          Divider(height: 24),
                          _buildTextField(
                            _usuarioController,
                            'Nombre de Usuario',
                            Icons.account_circle_outlined,
                            isRequired: _isNewUser, // Solo requerido para usuarios nuevos
                          ),
                          SizedBox(height: 16),
                          _buildTextField(
                            _nombreController,
                            'Nombre',
                            Icons.person_outline,
                          ),
                          SizedBox(height: 16),
                          _buildTextField(
                            _apellidoPaternoController,
                            'Apellido Paterno',
                            Icons.person_outline,
                          ),
                          SizedBox(height: 16),
                          _buildTextField(
                            _apellidoMaternoController,
                            'Apellido Materno (Opcional)',
                            Icons.person_outline,
                            isRequired: false,
                          ),
                          SizedBox(height: 16),
                          _buildTextField(
                            _correoController,
                            'Correo Electrónico',
                            Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          SizedBox(height: 16),
                          _buildTextField(
                            _claveController,
                            _isNewUser
                                ? 'Contraseña'
                                : 'Nueva Contraseña (opcional)',
                            Icons.lock_outline,
                            obscureText: _obscurePassword,
                            isRequired: _isNewUser,
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 16),

                  // Tarjeta de asignación
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
                              Icon(Icons.assignment_ind, color: primaryColor),
                              SizedBox(width: 8),
                              Text(
                                'Asignación',
                                style: cardTitleStyle,
                              ),
                            ],
                          ),
                          Divider(height: 24),
                          _buildDropdownField<String>(
                            value: selectedRol,
                            label: 'Rol',
                            icon: Icons.people_outline,
                            items: roles.map<DropdownMenuItem<String>>((rol) {
                              return DropdownMenuItem<String>(
                                value: rol['id'].toString(),
                                child: Text(rol['rol']),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedRol = value;
                              });
                            },
                            isRequired: _isNewUser,
                          ),
                          SizedBox(height: 16),
                          _buildDropdownField<String>(
                            value: selectedSucursal,
                            label: 'Sucursal activa',
                            icon: Icons.business_outlined,
                            items:
                                sucursales.map<DropdownMenuItem<String>>((sucursal) {
                              return DropdownMenuItem<String>(
                                value: sucursal['id'].toString(),
                                child: Text(sucursal['nombre']),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedSucursal = value;
                              });
                            },
                            isRequired: _isNewUser,
                          ),
                          SizedBox(height: 16),
                          if (estados.isNotEmpty)
                            Row(
                              children: [
                                Icon(Icons.toggle_on_outlined, color: primaryColor),
                                SizedBox(width: 8),
                                Text('Estado', style: cardTitleStyle),
                                Spacer(),
                                Switch(
                                  value: selectedEstadoId == estados.first['id'].toString(),
                                  onChanged: (bool value) {
                                    setState(() {
                                      selectedEstadoId = value
                                          ? estados.first['id'].toString()
                                          : (estados.length > 1 ? estados[1]['id'].toString() : estados.first['id'].toString());
                                    });
                                  },
                                  activeColor: primaryColor,
                                ),
                                Text(
                                  selectedEstadoId == estados.first['id'].toString()
                                      ? estados.first['nombre']
                                      : (estados.length > 1 ? estados[1]['nombre'] : estados.first['nombre']),
                                  style: TextStyle(
                                    color: selectedEstadoId == estados.first['id'].toString()
                                        ? Colors.green
                                        : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          SizedBox(height: 16),
                          // Campo multiselección de sucursales autorizadas
                          Text('Sucursales autorizadas', style: cardTitleStyle),
                          SizedBox(height: 8),
                          ...sucursales.map((sucursal) {
                            final id = sucursal['id'].toString();
                            return CheckboxListTile(
                              value: selectedSucursalesAutorizadas.contains(id),
                              title: Text(sucursal['nombre']),
                              onChanged: (checked) {
                                setState(() {
                                  if (checked == true) {
                                    if (!selectedSucursalesAutorizadas.contains(id)) {
                                      selectedSucursalesAutorizadas.add(id);
                                    }
                                  } else {
                                    selectedSucursalesAutorizadas.remove(id);
                                  }
                                });
                              },
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.symmetric(horizontal: 8),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 24),

                  _isLoading
                      ? Center(
                          child: CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(primaryColor),
                          ),
                        )
                      : Column(
                          children: [
                            ElevatedButton.icon(
                              onPressed: _saveUser,
                              icon: Icon(_isNewUser ? Icons.person_add : Icons.save),
                              label: Text(
                                _isNewUser ? 'Crear Usuario' : 'Guardar Cambios',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                minimumSize: Size(double.infinity, 48),
                                backgroundColor: primaryColor,
                                foregroundColor: secondaryColor,
                                padding: EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 4,
                              ),
                            ),
                            if (!_isNewUser) ...[
                              SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _deleteUser,
                                icon: Icon(Icons.delete),
                                label: Text(
                                  'Eliminar Usuario',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  minimumSize: Size(double.infinity, 48),
                                  backgroundColor: Colors.red,
                                  foregroundColor: secondaryColor,
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 4,
                                ),
                              ),
                            ],
                          ],
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
