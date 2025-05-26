import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  _ChangePasswordScreenState createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _isLoading = false;
  final ApiService apiService = ApiService();

  // Estados para mostrar/ocultar contraseñas
  bool _showOldPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

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
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('user_id');
    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: Usuario no autenticado'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoading = false);
      return;
    }

    try {
      await apiService.cambiarClave(
        userId,
        _oldPasswordController.text,
        _newPasswordController.text,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Contraseña actualizada con éxito'),
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
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildPasswordField(
    TextEditingController controller,
    String label,
    IconData icon, {
    String? Function(String?)? validator,
    required bool showPassword,
    required VoidCallback onTogglePassword,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: !showPassword,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: primaryColor),
        suffixIcon: IconButton(
          icon: Icon(
            showPassword ? Icons.visibility_off : Icons.visibility,
            color: primaryColor,
          ),
          onPressed: onTogglePassword,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: validator,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.lock, color: secondaryColor),
            SizedBox(width: 8),
            Text(
              'Cambiar Contraseña',
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
                // Tarjeta de cambio de contraseña
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
                            Icon(Icons.security, color: primaryColor),
                            SizedBox(width: 8),
                            Text(
                              'Seguridad',
                              style: cardTitleStyle,
                            ),
                          ],
                        ),
                        Divider(height: 24),
                        _buildPasswordField(
                          _oldPasswordController,
                          'Contraseña Actual',
                          Icons.lock_outline,
                          validator: (value) => value!.isEmpty
                              ? 'Ingrese su contraseña actual'
                              : null,
                          showPassword: _showOldPassword,
                          onTogglePassword: () {
                            setState(() {
                              _showOldPassword = !_showOldPassword;
                            });
                          },
                        ),
                        SizedBox(height: 16),
                        _buildPasswordField(
                          _newPasswordController,
                          'Nueva Contraseña',
                          Icons.lock_outline,
                          validator: (value) => value!.length < 6
                              ? 'La contraseña debe tener al menos 6 caracteres'
                              : null,
                          showPassword: _showNewPassword,
                          onTogglePassword: () {
                            setState(() {
                              _showNewPassword = !_showNewPassword;
                            });
                          },
                        ),
                        SizedBox(height: 16),
                        _buildPasswordField(
                          _confirmPasswordController,
                          'Confirmar Nueva Contraseña',
                          Icons.lock_outline,
                          validator: (value) =>
                              value != _newPasswordController.text
                                  ? 'Las contraseñas no coinciden'
                                  : null,
                          showPassword: _showConfirmPassword,
                          onTogglePassword: () {
                            setState(() {
                              _showConfirmPassword = !_showConfirmPassword;
                            });
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
                          valueColor:
                              AlwaysStoppedAnimation<Color>(primaryColor),
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: _changePassword,
                        icon: Icon(Icons.save),
                        label: Text(
                          'Actualizar Contraseña',
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
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
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
