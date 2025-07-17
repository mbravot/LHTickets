import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminAppManagementScreen extends StatefulWidget {
  final ApiService apiService;
  final SessionService sessionService;

  const AdminAppManagementScreen({
    Key? key,
    required this.apiService,
    required this.sessionService,
  }) : super(key: key);

  @override
  _AdminAppManagementScreenState createState() => _AdminAppManagementScreenState();
}

class _AdminAppManagementScreenState extends State<AdminAppManagementScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> apps = [];
  List<dynamic> usuariosApps = [];
  bool isLoading = true;
  String? userRole;
  String? userName;
  
  // Variables para búsqueda
  TextEditingController _searchAppsController = TextEditingController();
  TextEditingController _searchUsuariosController = TextEditingController();
  String _searchAppsQuery = '';
  String _searchUsuariosQuery = '';

  // Colores y estilos
  final Color primaryColor = Colors.green;
  final Color secondaryColor = Colors.white;
  final Color backgroundColor = Colors.grey[200]!;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      final sessionData = await widget.sessionService.getSessionData();
      userRole = sessionData['user_role'];
      userName = sessionData['nombre_usuario'] ?? "Usuario";

      await _loadApps();
      await _loadUsuariosApps();

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error al cargar los datos: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadApps() async {
    try {
      final appsData = await widget.apiService.getAdminApps();
      setState(() {
        apps = appsData;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error al cargar apps: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadUsuariosApps() async {
    try {
      // Obtener todos los usuarios y luego cargar las apps de cada uno
      final usuariosData = await widget.apiService.getUsuarios();
      List<dynamic> usuariosConApps = [];
      
      for (var usuario in usuariosData) {
        try {
          final appsUsuario = await widget.apiService.getUsuarioAppsById(usuario['id'].toString());
          usuariosConApps.add({
            ...usuario,
            'apps': appsUsuario['apps'] ?? [],
          });
        } catch (e) {
          // Si no se pueden obtener las apps, agregar el usuario sin apps
          usuariosConApps.add({
            ...usuario,
            'apps': [],
          });
        }
      }
      
      setState(() {
        usuariosApps = usuariosConApps;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error al cargar usuarios con apps: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchAppsController.dispose();
    _searchUsuariosController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    setState(() => isLoading = true);
    await Future.delayed(Duration(milliseconds: 500));
    await _loadApps();
    await _loadUsuariosApps();
    setState(() => isLoading = false);
  }

  // Funciones de filtrado
  List<dynamic> _filtrarApps(List<dynamic> apps) {
    if (_searchAppsQuery.isEmpty) {
      return apps;
    }
    return apps.where((app) {
      final nombre = (app['nombre'] ?? '').toString().toLowerCase();
      final descripcion = (app['descripcion'] ?? '').toString().toLowerCase();
      final url = (app['url'] ?? '').toString().toLowerCase();
      final query = _searchAppsQuery.toLowerCase();
      
      return nombre.contains(query) || 
             descripcion.contains(query) || 
             url.contains(query);
    }).toList();
  }

  List<dynamic> _filtrarUsuarios(List<dynamic> usuarios) {
    if (_searchUsuariosQuery.isEmpty) {
      return usuarios;
    }
    return usuarios.where((usuario) {
      final nombre = (usuario['nombre'] ?? '').toString().toLowerCase();
      final correo = (usuario['correo'] ?? '').toString().toLowerCase();
      final rol = (usuario['rol'] ?? '').toString().toLowerCase();
      final query = _searchUsuariosQuery.toLowerCase();
      
      return nombre.contains(query) || 
             correo.contains(query) || 
             rol.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Cargando...'),
          backgroundColor: primaryColor,
        ),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Icon(Icons.admin_panel_settings, color: secondaryColor),
              SizedBox(width: 8),
              Text(
                'Administración de Apps',
                style: TextStyle(
                  color: secondaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          backgroundColor: primaryColor,
          elevation: 4,
          bottom: TabBar(
            labelColor: secondaryColor,
            unselectedLabelColor: Colors.white70,
            indicatorColor: secondaryColor,
            indicatorWeight: 3,
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.apps, color: secondaryColor),
                    SizedBox(width: 8),
                    Text(
                      'Apps',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: secondaryColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${apps.length}',
                        style: TextStyle(
                          fontSize: 12,
                          color: secondaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people, color: secondaryColor),
                    SizedBox(width: 8),
                    Text(
                      'Usuarios',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: secondaryColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${usuariosApps.length}',
                        style: TextStyle(
                          fontSize: 12,
                          color: secondaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, color: secondaryColor),
                    SizedBox(width: 8),
                    Text(
                      'Nueva App',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.refresh, color: secondaryColor),
              onPressed: _refreshData,
              tooltip: 'Actualizar datos',
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _buildAppsTab(),
            _buildUsuariosTab(),
            _buildNuevaAppTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppsTab() {
    final appsFiltradas = _filtrarApps(apps);
    return Container(
      color: backgroundColor,
      child: Column(
        children: [
          // Buscador
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchAppsController,
              decoration: InputDecoration(
                hintText: 'Buscar aplicación por nombre, descripción o URL...',
                prefixIcon: Icon(Icons.search, color: primaryColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) {
                setState(() {
                  _searchAppsQuery = value;
                });
              },
            ),
          ),
          // Lista de apps
          Expanded(
            child: appsFiltradas.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          apps.isEmpty ? Icons.apps_outlined : Icons.search_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: 16),
                        Text(
                          apps.isEmpty
                              ? 'No hay aplicaciones configuradas'
                              : 'No se encontraron aplicaciones',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          apps.isEmpty
                              ? 'Crea una nueva aplicación en la pestaña "Nueva App"'
                              : 'Intenta con otro término de búsqueda',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    itemCount: appsFiltradas.length,
                    itemBuilder: (context, index) {
                      final app = appsFiltradas[index];
                      return AnimatedContainer(
                        duration: Duration(milliseconds: 300),
                        margin: EdgeInsets.only(bottom: 12),
                        child: Card(
                          elevation: 4,
                          shadowColor: Colors.black26,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: EdgeInsets.all(16),
                            leading: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: primaryColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.apps,
                                color: secondaryColor,
                                size: 24,
                              ),
                            ),
                            title: Text(
                              app['nombre'] ?? 'Sin nombre',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(height: 4),
                                Text(
                                  app['descripcion'] ?? 'Sin descripción',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.link,
                                      size: 16,
                                      color: Colors.grey[500],
                                    ),
                                    SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        app['url'] ?? 'Sin URL',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.green[500],
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            trailing: PopupMenuButton<String>(
                              icon: Icon(Icons.more_vert, color: primaryColor),
                              onSelected: (value) => _handleAppMenuSelection(value, app),
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, color: primaryColor),
                                      SizedBox(width: 8),
                                      Text('Editar'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Eliminar', style: TextStyle(color: Colors.red)),
                                    ],
                                  ),
                                ),
                                if (app['url'] != null && app['url'].isNotEmpty)
                                  PopupMenuItem(
                                    value: 'open',
                                    child: Row(
                                      children: [
                                        Icon(Icons.open_in_new, color: primaryColor),
                                        SizedBox(width: 8),
                                        Text('Abrir'),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            onTap: () {
                              _showAppDetails(app);
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsuariosTab() {
    final usuariosFiltrados = _filtrarUsuarios(usuariosApps);
    return Container(
      color: backgroundColor,
      child: Column(
        children: [
          // Buscador
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchUsuariosController,
              decoration: InputDecoration(
                hintText: 'Buscar usuario por nombre, correo o rol...',
                prefixIcon: Icon(Icons.search, color: primaryColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) {
                setState(() {
                  _searchUsuariosQuery = value;
                });
              },
            ),
          ),
          // Lista de usuarios
          Expanded(
            child: usuariosFiltrados.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          usuariosApps.isEmpty ? Icons.people_outline : Icons.search_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: 16),
                        Text(
                          usuariosApps.isEmpty
                              ? 'No hay usuarios con apps asignadas'
                              : 'No se encontraron usuarios',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          usuariosApps.isEmpty
                              ? 'Los usuarios aparecerán aquí cuando tengan apps asignadas'
                              : 'Intenta con otro término de búsqueda',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    itemCount: usuariosFiltrados.length,
                    itemBuilder: (context, index) {
                      final usuario = usuariosFiltrados[index];
                      final appsUsuario = usuario['apps'] ?? [];
                      return AnimatedContainer(
                        duration: Duration(milliseconds: 300),
                        margin: EdgeInsets.only(bottom: 12),
                        child: Card(
                          elevation: 4,
                          shadowColor: Colors.black26,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: EdgeInsets.all(16),
                            leading: CircleAvatar(
                              backgroundColor: primaryColor,
                              child: Icon(
                                Icons.person,
                                color: secondaryColor,
                              ),
                            ),
                            title: Text(
                              usuario['nombre'] ?? 'Usuario sin nombre',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(height: 4),
                                Text(
                                  usuario['correo'] ?? 'Sin correo',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Apps asignadas: ${appsUsuario.length}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: appsUsuario.length > 0 ? Colors.green[600] : Colors.red[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: Icon(Icons.edit, color: primaryColor),
                              onPressed: () {
                                _mostrarDialogoAsignarApps(usuario);
                              },
                              tooltip: 'Asignar apps',
                            ),
                            onTap: () {
                              _mostrarDetallesUsuario(usuario);
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNuevaAppTab() {
    final _formKey = GlobalKey<FormState>();
    final _nombreController = TextEditingController();
    final _descripcionController = TextEditingController();
    final _urlController = TextEditingController();

    return Container(
      color: backgroundColor,
      padding: EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Crear Nueva Aplicación',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 20),
                    TextFormField(
                      controller: _nombreController,
                      decoration: InputDecoration(
                        labelText: 'Nombre de la aplicación',
                        prefixIcon: Icon(Icons.apps, color: primaryColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor ingresa el nombre';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _descripcionController,
                      decoration: InputDecoration(
                        labelText: 'Descripción (opcional)',
                        prefixIcon: Icon(Icons.description, color: primaryColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      maxLines: 3,
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _urlController,
                      decoration: InputDecoration(
                        labelText: 'URL de la aplicación (opcional)',
                        prefixIcon: Icon(Icons.link, color: primaryColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          final uri = Uri.tryParse(value);
                          if (uri == null || !uri.hasScheme) {
                            return 'Por favor ingresa una URL válida (ej: https://ejemplo.com)';
                          }
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          if (_formKey.currentState!.validate()) {
                            Map<String, dynamic> appData = {
                              'nombre': _nombreController.text,
                            };
                            
                            // Agregar descripción solo si no está vacía
                            if (_descripcionController.text.isNotEmpty) {
                              appData['descripcion'] = _descripcionController.text;
                            }
                            
                            // Agregar URL solo si no está vacía
                            if (_urlController.text.isNotEmpty) {
                              appData['url'] = _urlController.text;
                            }
                            
                            await _crearApp(appData);
                          }
                        },
                        icon: Icon(Icons.add),
                        label: Text('Crear Aplicación'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: secondaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleAppMenuSelection(String value, dynamic app) {
    switch (value) {
      case 'edit':
        _mostrarDialogoEditarApp(app);
        break;
      case 'delete':
        _mostrarDialogoEliminarApp(app);
        break;
      case 'open':
        _openApp(app);
        break;
    }
  }

  void _showAppDetails(dynamic app) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.apps, color: primaryColor),
            SizedBox(width: 8),
            Text('Detalles de la Aplicación'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nombre:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(app['nombre'] ?? 'Sin nombre'),
            SizedBox(height: 12),
            Text(
              'Descripción:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(app['descripcion'] ?? 'Sin descripción'),
            SizedBox(height: 12),
            Text(
              'URL:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(app['url'] ?? 'Sin URL'),
            if (app['fecha_creacion'] != null) ...[
              SizedBox(height: 12),
              Text(
                'Fecha de creación:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(app['fecha_creacion']),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cerrar'),
          ),
          if (app['url'] != null && app['url'].isNotEmpty)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _openApp(app);
              },
              icon: Icon(Icons.open_in_new),
              label: Text('Abrir'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: secondaryColor,
              ),
            ),
        ],
      ),
    );
  }

  void _mostrarDialogoEditarApp(dynamic app) {
    final _formKey = GlobalKey<FormState>();
    final _nombreController = TextEditingController(text: app['nombre']);
    final _descripcionController = TextEditingController(text: app['descripcion']);
    final _urlController = TextEditingController(text: app['url']);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Editar Aplicación'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nombreController,
                decoration: InputDecoration(labelText: 'Nombre'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa el nombre';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _descripcionController,
                decoration: InputDecoration(labelText: 'Descripción'),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa la descripción';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _urlController,
                decoration: InputDecoration(labelText: 'URL'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa la URL';
                  }
                  final uri = Uri.tryParse(value);
                  if (uri == null || !uri.hasScheme) {
                    return 'Por favor ingresa una URL válida (ej: https://ejemplo.com)';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                Navigator.of(context).pop();
                await _actualizarApp(app['id'].toString(), {
                  'nombre': _nombreController.text,
                  'descripcion': _descripcionController.text,
                  'url': _urlController.text,
                });
              }
            },
            child: Text('Guardar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: secondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoEliminarApp(dynamic app) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmar eliminación'),
        content: Text('¿Estás seguro de que deseas eliminar la aplicación "${app['nombre']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _eliminarApp(app['id'].toString());
            },
            child: Text('Eliminar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: secondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarDetallesUsuario(dynamic usuario) {
    final appsUsuario = usuario['apps'] ?? [];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Apps de ${usuario['nombre']}'),
        content: Container(
          width: double.maxFinite,
          child: appsUsuario.isEmpty
              ? Text('Este usuario no tiene apps asignadas')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: appsUsuario.length,
                  itemBuilder: (context, index) {
                    final app = appsUsuario[index];
                    return ListTile(
                      leading: Icon(Icons.apps, color: primaryColor),
                      title: Text(app['nombre'] ?? 'Sin nombre'),
                      subtitle: Text(app['descripcion'] ?? 'Sin descripción'),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoAsignarApps(dynamic usuario) {
    List<String> selectedAppIds = [];
    
    // Obtener las apps actuales del usuario
    final appsUsuario = usuario['apps'] ?? [];
    selectedAppIds = appsUsuario.map<String>((app) => app['id'].toString()).toList();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Asignar Apps a ${usuario['nombre']}'),
          content: Container(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: apps.length,
              itemBuilder: (context, index) {
                final app = apps[index];
                final appId = app['id'].toString();
                final isSelected = selectedAppIds.contains(appId);
                
                return CheckboxListTile(
                  title: Text(app['nombre'] ?? 'Sin nombre'),
                  subtitle: Text(app['descripcion'] ?? 'Sin descripción'),
                  value: isSelected,
                  onChanged: (bool? value) {
                    setState(() {
                      if (value == true) {
                        selectedAppIds.add(appId);
                      } else {
                        selectedAppIds.remove(appId);
                      }
                    });
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _asignarAppsUsuario(usuario['id'].toString(), selectedAppIds);
              },
              child: Text('Guardar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: secondaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _crearApp(Map<String, dynamic> appData) async {
    try {
      await widget.apiService.createApp(appData);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Aplicación creada exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
      _refreshData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error al crear la aplicación: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _actualizarApp(String appId, Map<String, dynamic> appData) async {
    try {
      await widget.apiService.updateApp(appId, appData);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Aplicación actualizada exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
      _refreshData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error al actualizar la aplicación: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _eliminarApp(String appId) async {
    try {
      await widget.apiService.deleteApp(appId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Aplicación eliminada exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
      _refreshData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error al eliminar la aplicación: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _asignarAppsUsuario(String userId, List<String> appIds) async {
    try {
      await widget.apiService.asignarAppsUsuario(userId, appIds);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Apps asignadas exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
      _refreshData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error al asignar apps: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openApp(dynamic app) async {
    final url = app['url'];
    if (url != null && url.isNotEmpty) {
      try {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Abriendo aplicación: ${app['nombre']}'),
              backgroundColor: primaryColor,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No se pudo abrir la URL: $url'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al abrir la aplicación: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No hay URL disponible para esta aplicación'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }
} 