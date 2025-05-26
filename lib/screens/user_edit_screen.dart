import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'dart:convert';
import 'package:flutter_typeahead/flutter_typeahead.dart';

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
  TextEditingController _colaboradorSearchController = TextEditingController();
  TextEditingController _colaboradorController = TextEditingController();

  List<dynamic> roles = [];
  List<dynamic> sucursales = [];
  List<dynamic> estados = [];
  List<dynamic> departamentos = [];
  List<dynamic> colaboradores = [];
  List<dynamic> colaboradoresFiltrados = [];
  List<String> selectedDepartamentos = [];

  String? selectedRol;
  String? selectedSucursal;
  String? selectedEstadoId;
  String? selectedColaborador;
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
    _nombreController =
        TextEditingController(text: widget.user?['usuario'] ?? '');
    _correoController =
        TextEditingController(text: widget.user?['correo'] ?? '');
    _colaboradorSearchController = TextEditingController();
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
    _nombreController.dispose();
    _correoController.dispose();
    _claveController.dispose();
    _colaboradorSearchController.dispose();
    _colaboradorController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);
      roles = await apiService.getRoles();
      sucursales = await apiService.getSucursales();
      estados = await apiService.getEstadosUsuarios();
      departamentos = await apiService.getDepartamentos();
      colaboradores = await apiService.getColaboradores();
      colaboradoresFiltrados = List.from(colaboradores);
      if (selectedEstadoId == null && estados.isNotEmpty) {
        selectedEstadoId = estados.first['id'].toString();
      }
      if (widget.user != null && widget.user!['id_colaborador'] != null) {
        selectedColaborador = widget.user!['id_colaborador'].toString();
        final colaborador = colaboradores.firstWhere(
          (c) => c['id'].toString() == selectedColaborador,
          orElse: () => null,
        );
        _colaboradorController.text = colaborador != null ? colaborador['nombre_completo'] : '';
      } else {
        _colaboradorController.text = '';
      }
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

  void _filtrarColaboradores(String query) {
    setState(() {
      if (query.isEmpty) {
        colaboradoresFiltrados = List.from(colaboradores);
      } else {
        colaboradoresFiltrados = colaboradores
            .where((colaborador) =>
                colaborador['nombre_completo']
                    .toString()
                    .toLowerCase()
                    .contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _saveUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_isNewUser) {
        // Crear nuevo usuario
        final response = await apiService.createUser({
          'usuario': _nombreController.text,
          'correo': _correoController.text,
          'clave': _claveController.text,
          'id_rol': selectedRol,
          'id_sucursalactiva': selectedSucursal,
          'id_departamento': selectedDepartamentos,
          'id_estado': selectedEstadoId,
          'id_colaborador': selectedColaborador != null ? int.parse(selectedColaborador!) : null,
        });
        // Asociar departamentos si es agente
        if (selectedRol == '2') {
          // Obtener el id del usuario creado (de la respuesta de createUser)
          String nuevoUsuarioId = '';
          if (response is Map && response.containsKey('id')) {
            nuevoUsuarioId = response['id'].toString();
          } else if (response is String) {
            nuevoUsuarioId = response;
          }
          if (nuevoUsuarioId.isNotEmpty && selectedDepartamentos.isNotEmpty) {
            await apiService.asignarDepartamentos(
              nuevoUsuarioId,
              selectedDepartamentos.map((e) => int.parse(e)).toList(),
            );
          }
        }
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
            _nombreController.text != widget.user!['usuario']) {
          updatedData['usuario'] = _nombreController.text;
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
            selectedSucursal != widget.user!['id_sucursalactiva']) {
          updatedData['id_sucursalactiva'] = selectedSucursal;
        }
        if (selectedEstadoId != null && selectedEstadoId != widget.user!['id_estado']?.toString()) {
          updatedData['id_estado'] = selectedEstadoId;
        }
        if (selectedColaborador != widget.user!['id_colaborador']?.toString()) {
          updatedData['id_colaborador'] = (selectedColaborador?.isNotEmpty ?? false)
              ? int.parse(selectedColaborador!)
              : null;
        }
        updatedData['id_departamento'] = selectedDepartamentos;

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
    Widget? suffixIcon,
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
        suffixIcon: suffixIcon,
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
    bool isRequired = true,
    TextEditingController? searchController,
    void Function(String)? onSearchChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<T>(
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
          isExpanded: true,
          dropdownColor: Colors.white,
          menuMaxHeight: 300,
          icon: Icon(Icons.arrow_drop_down, color: primaryColor),
        ),
        if (searchController != null && onSearchChanged != null)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Buscar...',
                prefixIcon: Icon(Icons.search, color: primaryColor),
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
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: onSearchChanged,
            ),
          ),
      ],
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
                          'Nombre de Usuario',
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
                          obscureText: _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: primaryColor,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        SizedBox(height: 16),
                        TypeAheadFormField<Map<String, dynamic>>(
                          textFieldConfiguration: TextFieldConfiguration(
                            controller: _colaboradorController,
                            decoration: InputDecoration(
                              labelText: 'Colaborador (Opcional)',
                              prefixIcon: Icon(Icons.person_outline, color: primaryColor),
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
                              hintText: 'Buscar colaborador...',
                            ),
                          ),
                          suggestionsCallback: (pattern) {
                            if (pattern.isEmpty) {
                              return colaboradores.cast<Map<String, dynamic>>();
                            }
                            return colaboradores
                                .where((colaborador) =>
                                    (colaborador['nombre_completo'] ?? '')
                                        .toLowerCase()
                                        .contains(pattern.toLowerCase()))
                                .cast<Map<String, dynamic>>();
                          },
                          itemBuilder: (context, Map<String, dynamic> suggestion) {
                            return ListTile(
                              title: Text(suggestion['nombre_completo'] ?? 'Sin nombre'),
                            );
                          },
                          onSuggestionSelected: (Map<String, dynamic> suggestion) {
                            setState(() {
                              selectedColaborador = suggestion['id'].toString();
                              _colaboradorController.text = suggestion['nombre_completo'] ?? '';
                            });
                          },
                          noItemsFoundBuilder: (context) => ListTile(
                            title: Text('No se encontraron colaboradores'),
                          ),
                          validator: (value) => null, // Opcional
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
                          label: 'Sucursal',
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
    );
  }
}
