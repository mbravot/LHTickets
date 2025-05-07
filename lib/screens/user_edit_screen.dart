import 'package:flutter/material.dart';
import '../services/api_service.dart';

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

  @override
  void initState() {
    super.initState();
    _isNewUser = widget.user == null;
    _nombreController =
        TextEditingController(text: widget.user?['nombre'] ?? '');
    _correoController =
        TextEditingController(text: widget.user?['correo'] ?? '');
    selectedRol = widget.user?['id_rol'];
    selectedSucursal = widget.user?['id_sucursal'];
    selectedEstado = widget.user?['id_estado'];

    if (widget.user?.containsKey('departamentos') ?? false) {
      selectedDepartamentos =
          List<int>.from(widget.user!['departamentos'].map((d) => d['id']));
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
    _nombreController.dispose();
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
      setState(() {});
    } catch (e) {
      print("❌ Error al cargar datos: $e");
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
        await apiService.createUser({
          'nombre': _nombreController.text,
          'correo': _correoController.text,
          'clave': _claveController.text,
          'id_rol': selectedRol,
          'id_sucursal': selectedSucursal,
          'id_estado': selectedEstado,
          'id_departamento': selectedDepartamentos,
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Usuario creado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Actualizar usuario existente
        Map<String, dynamic> updatedData = {};

        if (_nombreController.text.isNotEmpty &&
            _nombreController.text != widget.user!['nombre']) {
          updatedData['nombre'] = _nombreController.text;
        }
        if (_correoController.text.isNotEmpty &&
            _correoController.text != widget.user!['correo']) {
          updatedData['correo'] = _correoController.text;
        }
        if (_claveController.text.isNotEmpty) {
          updatedData['clave'] = _claveController.text;
        }
        if (selectedRol != null && selectedRol != widget.user!['id_rol']) {
          updatedData['id_rol'] = selectedRol;
        }
        if (selectedSucursal != null &&
            selectedSucursal != widget.user!['id_sucursal']) {
          updatedData['id_sucursal'] = selectedSucursal;
        }
        if (selectedEstado != null &&
            selectedEstado != widget.user!['id_estado']) {
          updatedData['id_estado'] = selectedEstado;
        }
        if (selectedDepartamentos.isNotEmpty) {
          updatedData['id_departamento'] = selectedDepartamentos;
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

        await apiService.updateUser(widget.user!['id'], updatedData);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al eliminar usuario'),
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
      validator: (value) {
        if (_isNewUser) {
          return value!.isEmpty ? 'Campo requerido' : null;
        } else {
          // En edición, no es obligatorio
          return null;
        }
      },
    );
  }

  Widget _buildDropdownField<T>({
    required T? value,
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(_isNewUser ? Icons.person_add : Icons.edit,
                color: secondaryColor),
            SizedBox(width: 8),
            Text(
              _isNewUser ? 'Nuevo Usuario' : 'Editar Usuario',
              style: TextStyle(
                color: secondaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        backgroundColor: primaryColor,
        elevation: 4,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
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
                            Icon(Icons.person, color: primaryColor),
                            SizedBox(width: 8),
                            Text(
                              'Información Personal',
                              style: cardTitleStyle,
                            ),
                          ],
                        ),
                        Divider(height: 24),
                        _buildTextField(
                          _nombreController,
                          'Nombre Completo',
                          Icons.person_outline,
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
                          obscureText: true,
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
                        _buildDropdownField<int>(
                          value: selectedRol,
                          label: 'Rol',
                          icon: Icons.people_outline,
                          items: roles.map<DropdownMenuItem<int>>((rol) {
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
                        _buildDropdownField<int>(
                          value: selectedSucursal,
                          label: 'Sucursal',
                          icon: Icons.business_outlined,
                          items:
                              sucursales.map<DropdownMenuItem<int>>((sucursal) {
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
                        _buildDropdownField<int>(
                          value: selectedEstado,
                          label: 'Estado',
                          icon: Icons.toggle_on_outlined,
                          items: estados.map<DropdownMenuItem<int>>((estado) {
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
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Card(
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
                                Icon(Icons.category, color: primaryColor),
                                SizedBox(width: 8),
                                Text(
                                  'Departamentos',
                                  style: cardTitleStyle,
                                ),
                              ],
                            ),
                            Divider(height: 24),
                            Wrap(
                              spacing: 8.0,
                              runSpacing: 8.0,
                              children:
                                  departamentos.map<Widget>((departamento) {
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
                                  selectedColor: primaryColor.withOpacity(0.2),
                                  checkmarkColor: primaryColor,
                                  labelStyle: TextStyle(
                                    color: selectedDepartamentos
                                            .contains(departamento['id'])
                                        ? primaryColor
                                        : Colors.grey[800],
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
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
                            icon: Icon(
                                _isNewUser ? Icons.person_add : Icons.save),
                            label: Text(
                              _isNewUser ? 'Crear Usuario' : 'Guardar Cambios',
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
    );
  }
}
