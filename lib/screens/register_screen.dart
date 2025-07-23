import 'package:flutter/material.dart';
import '../services/api_service.dart';

class RegisterScreen extends StatefulWidget {
  final String userRole;

  const RegisterScreen({Key? key, required this.userRole}) : super(key: key);

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final ApiService apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usuarioController = TextEditingController();
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _apellidoPaternoController = TextEditingController();
  final TextEditingController _apellidoMaternoController = TextEditingController();
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
    _usuarioController.dispose();
    _nombreController.dispose();
    _apellidoPaternoController.dispose();
    _apellidoMaternoController.dispose();
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
        final userData = {
          'usuario': _usuarioController.text,
          'nombre': _nombreController.text,
          'apellido_paterno': _apellidoPaternoController.text,
          'apellido_materno': _apellidoMaternoController.text.isNotEmpty 
              ? _apellidoMaternoController.text 
              : null,
          'correo': _correoController.text,
          'clave': _claveController.text,
          'id_rol': _selectedRol,
          'id_sucursalactiva': _selectedSucursal,
        };

        await apiService.register(userData);

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
            content: Text('❌ Error al registrar usuario: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() => _isLoading = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Registrar Usuario'),
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
                          DropdownButtonFormField<int>(
                            value: _selectedRol,
                            decoration: InputDecoration(
                              labelText: 'Rol',
                              prefixIcon: Icon(Icons.people_outline, color: primaryColor),
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
                            validator: (value) {
                              return value == null ? 'Selecciona un rol' : null;
                            },
                          ),
                          SizedBox(height: 16),
                          DropdownButtonFormField<int>(
                            value: _selectedSucursal,
                            decoration: InputDecoration(
                              labelText: 'Sucursal Activa',
                              prefixIcon: Icon(Icons.business_outlined, color: primaryColor),
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
                            validator: (value) {
                              return value == null ? 'Selecciona una sucursal' : null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 24),

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
                            'Registrar Usuario',
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
