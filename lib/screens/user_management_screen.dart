import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'user_edit_screen.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  _UserManagementScreenState createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen>
    with TickerProviderStateMixin {
  final ApiService apiService = ApiService();
  List<dynamic> usuarios = [];
  bool _isLoading = false;
  TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _currentPage = 0;
  final int _itemsPerPage = 10; // Número de usuarios por página

  // Tabs
  late TabController _tabController;
  List<String> sucursales = [];
  String _selectedSucursal = 'Todos';

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
    _loadUsuarios();

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

  void _initializeTabController() {
    // Obtener sucursales únicas de los usuarios
    Set<String> sucursalesSet = {};
    for (var usuario in usuarios) {
      if (usuario['sucursal_activa']?['nombre'] != null) {
        sucursalesSet.add(usuario['sucursal_activa']['nombre']);
      }
    }
    sucursales = ['Todos', ...sucursalesSet.toList()..sort()];
    
    // Inicializar TabController
    _tabController = TabController(
      length: sucursales.length,
      vsync: this,
    );
    
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _selectedSucursal = sucursales[_tabController.index];
          _currentPage = 0; // Resetear página al cambiar tab
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _loadUsuarios() async {
    try {
      setState(() => _isLoading = true);
      final users = await apiService.getUsuariosActivos();
      setState(() {
        usuarios = List.from(users)
          ..sort((a, b) => (a['nombre'] as String)
              .toLowerCase()
              .compareTo((b['nombre'] as String).toLowerCase()));
        _isLoading = false;
      });
      
      // Inicializar TabController después de cargar usuarios
      _initializeTabController();
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error al cargar los usuarios'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<dynamic> _filtrarUsuarios(List<dynamic> usuarios) {
    List<dynamic> usuariosFiltrados = usuarios;
    
    // Filtrar por sucursal seleccionada
    if (_selectedSucursal != 'Todos') {
      usuariosFiltrados = usuariosFiltrados.where((user) =>
          user['sucursal_activa']?['nombre'] == _selectedSucursal).toList();
    }
    
    // Filtrar por búsqueda de texto
    if (_searchQuery.isNotEmpty) {
      usuariosFiltrados = usuariosFiltrados
          .where((user) =>
              user['nombre'].toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }
    
    return usuariosFiltrados;
  }

  List<dynamic> _obtenerUsuariosPaginados(List<dynamic> usuarios) {
    int startIndex = _currentPage * _itemsPerPage;
    int endIndex = startIndex + _itemsPerPage;
    if (endIndex > usuarios.length) {
      endIndex = usuarios.length;
    }
    return usuarios.sublist(startIndex, endIndex);
  }

  bool _hayMasPaginas(List<dynamic> usuariosFiltrados) {
    int startIndex = (_currentPage + 1) * _itemsPerPage;
    return startIndex < usuariosFiltrados.length;
  }

  int _getUserCountForSucursal(String sucursal) {
    if (sucursal == 'Todos') {
      return usuarios.length;
    }
    return usuarios.where((user) =>
        user['sucursal_activa']?['nombre'] == sucursal).length;
  }

  Widget _buildUserCard(dynamic user) {
    // Construir nombre completo
    String nombreCompleto = user['nombre'] ?? '';
    if (user['apellido_paterno'] != null && user['apellido_paterno'].isNotEmpty) {
      nombreCompleto += ' ${user['apellido_paterno']}';
    }
    if (user['apellido_materno'] != null && user['apellido_materno'].isNotEmpty) {
      nombreCompleto += ' ${user['apellido_materno']}';
    }
    
    // Si no hay nombre, usar el usuario
    if (nombreCompleto.trim().isEmpty) {
      nombreCompleto = user['usuario'] ?? 'Sin nombre';
    }

    return Card(
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserEditScreen(user: user),
            ),
          );

          if (result == true) {
            _loadUsuarios(); // Recargar lista tras edición
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: primaryColor.withOpacity(0.1),
                    child: Icon(
                      Icons.person,
                      color: primaryColor,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nombreCompleto,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        Text(
                          user['correo'] ?? 'Sin correo',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (user['usuario'] != null)
                          Text(
                            '@${user['usuario']}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green[500],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  _buildInfoChip(
                    Icons.people_outline,
                    user['rol'] ?? 'Sin asignar',
                    Colors.orange,
                  ),
                  SizedBox(width: 8),
                  _buildInfoChip(
                    Icons.business_outlined,
                    user['sucursal_activa']?['nombre'] ?? 'Sin asignar',
                    Colors.blue,
                  ),
                  SizedBox(width: 8),
                  _buildInfoChip(
                    Icons.toggle_on_outlined,
                    (user['estado'] ?? 'Desconocido').toUpperCase(),
                    user['estado'] == 'ACTIVO' ? Colors.green : Colors.red,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: color,
          ),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationControls(int totalItems) {
    int totalPages = (totalItems / _itemsPerPage).ceil();

    return Container(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton.icon(
            icon: Icon(Icons.arrow_back),
            label: Text('Anterior'),
            onPressed: _currentPage > 0
                ? () {
                    setState(() {
                      _currentPage--;
                    });
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "Página ${_currentPage + 1} de $totalPages",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton.icon(
            icon: Icon(Icons.arrow_forward),
            label: Text('Siguiente'),
            onPressed: _currentPage < totalPages - 1
                ? () {
                    setState(() {
                      _currentPage++;
                    });
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usuariosFiltrados = _filtrarUsuarios(usuarios);
    final usuariosPaginados = _obtenerUsuariosPaginados(usuariosFiltrados);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.people, color: secondaryColor),
            SizedBox(width: 8),
            Text(
              'Gestión de Usuarios',
              style: TextStyle(
                color: secondaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        backgroundColor: primaryColor,
        elevation: 4,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: secondaryColor),
            onPressed: _loadUsuarios,
            tooltip: 'Recargar lista',
          ),
        ],
        bottom: sucursales.isNotEmpty
            ? TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: sucursales.map((sucursal) {
                  int count = _getUserCountForSucursal(sucursal);
                  return Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(sucursal),
                        SizedBox(width: 4),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            count.toString(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              )
            : null,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                ),
              )
            : Column(
                children: [
                  // Buscador
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Buscar usuario...',
                              prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Lista de usuarios
                  Expanded(
                    child: usuariosPaginados.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No se encontraron usuarios',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (_searchQuery.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      'Intenta con otro término de búsqueda',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            itemCount: usuariosPaginados.length,
                            itemBuilder: (context, index) {
                              return _buildUserCard(usuariosPaginados[index]);
                            },
                          ),
                  ),

                  // Controles de paginación
                  if (usuariosFiltrados.isNotEmpty)
                    _buildPaginationControls(usuariosFiltrados.length),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserEditScreen(user: null),
            ),
          );

          if (result == true) {
            _loadUsuarios(); // Recargar lista tras crear usuario
          }
        },
        backgroundColor: primaryColor,
        foregroundColor: secondaryColor,
        icon: Icon(Icons.person_add),
        label: Text(
          'Nuevo Usuario',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 4,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
