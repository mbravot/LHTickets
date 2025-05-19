import 'package:flutter/material.dart';
import '../services/api_service.dart';

class RegisterScreen extends StatefulWidget {
  final String userRole; // Recibe el rol del usuario

  const RegisterScreen({Key? key, required this.userRole}) : super(key: key);

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
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
    _loadRoles();
    _loadSucursales();

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
    _nombreController.dispose();
    _correoController.dispose();
    _claveController.dispose();
    super.dispose();
  }

  Future<void> _loadRoles() async {
    try {
      setState(() => _isLoading = true);
      List<dynamic> roles = await apiService.getRoles();
      setState(() {
        _roles = roles;
      });
    } catch (e) {
      print("❌ Error al cargar roles: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error al cargar los roles'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSucursales() async {
    try {
      setState(() => _isLoading = true);
      List<dynamic> sucursales = await apiService.getSucursales();
      setState(() {
        _sucursales = sucursales;
      });
    } catch (e) {
      print("❌ Error al cargar sucursales: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error al cargar las sucursales'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
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
          SnackBar(
            content: Text('✅ Usuario registrado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context);
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
    } else if (_selectedRol == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Debes seleccionar un rol'),
          backgroundColor: Colors.red,
        ),
      );
    } else if (_selectedSucursal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Debes seleccionar una sucursal'),
          backgroundColor: Colors.red,
        ),
      );
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
      validator: (value) => value!.isEmpty ? 'Campo requerido' : null,
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
    if (widget.userRole != "1") {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text(
                "Acceso denegado",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              SizedBox(height: 8),
              Text(
                "Solo los administradores pueden registrar usuarios",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        backgroundColor: Colors.grey[100],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.person_add, color: secondaryColor),
            SizedBox(width: 8),
            Text(
              'Registro de Usuario',
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
                          'Contraseña',
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
                          value: _selectedRol,
                          label: 'Rol',
                          icon: Icons.people_outline,
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
                        SizedBox(height: 16),
                        _buildDropdownField<int>(
                          value: _selectedSucursal,
                          label: 'Sucursal',
                          icon: Icons.business_outlined,
                          items: _sucursales
                              .map<DropdownMenuItem<int>>((sucursal) {
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
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 24),

                // Botón de crear usuario
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
                            Icon(Icons.save_alt, color: primaryColor),
                            SizedBox(width: 8),
                            Text(
                              'Guardar Usuario',
                              style: cardTitleStyle,
                            ),
                          ],
                        ),
                        Divider(height: 24),
                        _isLoading
                            ? Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                                ),
                              )
                            : ElevatedButton.icon(
                                onPressed: _register,
                                icon: Icon(Icons.person_add),
                                label: Text(
                                  'Crear Usuario',
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
                                  minimumSize: Size(double.infinity, 50),
                                ),
                              ),
                        SizedBox(height: 8),
                        Text(
                          'Al crear el usuario, se le enviará un correo electrónico con sus credenciales de acceso.',
                          style: cardSubtitleStyle,
                          textAlign: TextAlign.center,
                        ),
                      ],
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
}
