# 🎫 Sistema de Tickets La Hornilla (LHTickets)

## 📋 Descripción General

LHTickets es una aplicación web desarrollada en Flutter que proporciona un sistema completo de gestión de tickets para La Hornilla. La aplicación permite a los usuarios crear, gestionar y dar seguimiento a tickets de soporte técnico, con funcionalidades avanzadas de administración de usuarios, departamentos y aplicaciones.

## 🏗️ Arquitectura del Proyecto

### Tecnologías Utilizadas

- **Frontend**: Flutter Web
- **Backend**: API REST (Python/FastAPI)
- **Base de Datos**: PostgreSQL
- **Autenticación**: JWT (JSON Web Tokens)
- **Hosting**: Firebase Hosting
- **Estado**: SharedPreferences para persistencia local

### Estructura del Proyecto

```
LHTickets/
├── lib/
│   ├── main.dart                 # Punto de entrada de la aplicación
│   ├── screens/                  # Pantallas de la aplicación
│   │   ├── login_screen.dart     # Pantalla de inicio de sesión
│   │   ├── ticket_list.dart      # Lista principal de tickets
│   │   ├── ticket_create.dart    # Creación de tickets
│   │   ├── ticket_edit.dart      # Edición de tickets
│   │   ├── ticket_detail_screen.dart # Detalle de tickets
│   │   ├── ticket_comments.dart  # Comentarios de tickets
│   │   ├── user_management_screen.dart # Gestión de usuarios
│   │   ├── agent_management_screen.dart # Gestión de agentes
│   │   ├── department_management_screen.dart # Gestión de departamentos
│   │   ├── admin_app_management_screen.dart # Gestión de aplicaciones
│   │   └── ...                   # Otras pantallas
│   └── services/
│       ├── api_service.dart      # Servicio de comunicación con API
│       └── session_service.dart  # Gestión de sesiones
├── assets/                       # Recursos estáticos
├── web/                         # Configuración para web
└── pubspec.yaml                 # Dependencias del proyecto
```

## 🚀 Funcionalidades Principales

### 🔐 Autenticación y Autorización
- **Login seguro** con JWT tokens
- **Renovación automática** de tokens
- **Gestión de sesiones** con expiración automática
- **Roles de usuario** (Admin, Agente, Usuario)

### 📝 Gestión de Tickets
- **Creación de tickets** con adjuntos
- **Asignación automática** a departamentos
- **Sistema de prioridades** (Baja, Normal, Alta, Crítica)
- **Estados de tickets** (Abierto, En Proceso, Cerrado, Cancelado)
- **Comentarios y seguimiento**
- **Filtros avanzados** por estado, prioridad, departamento

### 👥 Administración de Usuarios
- **Gestión de usuarios** (crear, editar, desactivar)
- **Asignación de roles** y permisos
- **Gestión de agentes** por departamento
- **Cambio de contraseñas** seguro

### 🏢 Gestión de Departamentos
- **Creación y edición** de departamentos
- **Asignación de agentes** a departamentos
- **Configuración de flujos** de trabajo

### 📱 Gestión de Aplicaciones
- **Registro de aplicaciones** con nombre, descripción y URL
- **Asignación de usuarios** a aplicaciones
- **Búsqueda y filtrado** de aplicaciones

## 🔧 Configuración del Entorno

### Prerrequisitos
- Flutter SDK 3.6.1 o superior
- Dart SDK
- Node.js (para Firebase CLI)
- Cuenta de Firebase

### Instalación

1. **Clonar el repositorio**
```bash
git clone <repository-url>
cd LHTickets
```

2. **Instalar dependencias**
```bash
flutter pub get
```

3. **Configurar Firebase**
```bash
npm install -g firebase-tools
firebase login
firebase init hosting
```

4. **Ejecutar en modo desarrollo**
```bash
flutter run -d chrome
```

### Variables de Entorno

El proyecto utiliza las siguientes configuraciones de API:

```dart
// En lib/services/api_service.dart
final String baseUrl = 'https://apilhtickets-927498545444.us-central1.run.app/api';
```

## 📦 Dependencias Principales

### Core Dependencies
- `flutter`: Framework principal
- `http: ^1.3.0`: Cliente HTTP para API
- `shared_preferences: ^2.1.0`: Persistencia local
- `cupertino_icons: ^1.0.8`: Iconos de iOS

### UI/UX Dependencies
- `file_picker: ^10.1.9`: Selección de archivos
- `url_launcher: ^6.3.1`: Apertura de URLs
- `flutter_typeahead: ^4.0.0`: Autocompletado

### Firebase Dependencies
- `firebase_core: ^3.13.0`: Core de Firebase
- `firebase_auth: ^5.5.3`: Autenticación
- `cloud_firestore: ^5.6.7`: Base de datos
- `firebase_storage: ^12.4.5`: Almacenamiento

### Utilities
- `printing: ^5.11.0`: Generación de PDFs
- `pdf: ^3.10.8`: Manipulación de PDFs
- `intl: ^0.20.2`: Internacionalización
- `path_provider: ^2.1.1`: Gestión de rutas
- `open_file: ^3.3.2`: Apertura de archivos

## 🔌 Servicios Principales

### ApiService (`lib/services/api_service.dart`)

Maneja toda la comunicación con el backend:

```dart
class ApiService {
  // Autenticación
  Future<Map<String, dynamic>> login(String correo, String clave)
  Future<String> refreshToken(String refreshToken)
  Future<void> logout()
  
  // Gestión de tickets
  Future<List<dynamic>> getTickets()
  Future<Map<String, dynamic>> createTicket(Map<String, dynamic> ticketData)
  Future<void> updateTicket(int ticketId, Map<String, dynamic> ticketData)
  
  // Gestión de usuarios
  Future<List<dynamic>> getUsuarios()
  Future<void> register(Map<String, dynamic> userData)
  
  // Gestión de departamentos
  Future<List<dynamic>> getDepartamentos()
  Future<void> createDepartamento(Map<String, dynamic> data)
  
  // Gestión de aplicaciones
  Future<List<dynamic>> getApps()
  Future<void> createApp(Map<String, dynamic> appData)
}
```

### SessionService (`lib/services/session_service.dart`)

Gestiona la sesión del usuario y renovación automática de tokens:

```dart
class SessionService {
  // Gestión de sesión
  Future<void> saveSession(String accessToken, String refreshToken, Map<String, dynamic> userData)
  Future<bool> hasActiveSession()
  Future<void> clearSession()
  
  // Renovación automática
  void _startTokenRefreshTimer()
  Future<void> _checkAndRefreshToken()
}
```

## 🎨 Pantallas Principales

### LoginScreen
- **Ubicación**: `lib/screens/login_screen.dart`
- **Funcionalidad**: Autenticación de usuarios
- **Características**: 
  - Validación de formularios
  - Animaciones de entrada
  - Manejo de errores de autenticación
  - Redirección automática si ya hay sesión

### TicketListScreen
- **Ubicación**: `lib/screens/ticket_list.dart`
- **Funcionalidad**: Vista principal de tickets
- **Características**:
  - Lista paginada de tickets
  - Filtros avanzados
  - Búsqueda en tiempo real
  - Acciones rápidas (editar, ver detalle)
  - Indicadores de estado visual

### TicketCreateScreen
- **Ubicación**: `lib/screens/ticket_create.dart`
- **Funcionalidad**: Creación de nuevos tickets
- **Características**:
  - Formulario completo con validación
  - Selección de archivos adjuntos
  - Asignación automática de departamento
  - Preview de archivos

## 🔒 Seguridad

### Autenticación JWT
- **Tokens de acceso**: 20 minutos de duración
- **Tokens de renovación**: Renovación automática cada 15 minutos
- **Logout automático**: Al cerrar el navegador
- **Manejo de errores**: Redirección al login en caso de expiración

### Validación de Datos
- **Validación de formularios**: En tiempo real
- **Sanitización de inputs**: Prevención de XSS
- **Validación de archivos**: Tipos y tamaños permitidos

## 🚀 Despliegue

### Build para Producción
```bash
flutter build web --release
```

### Despliegue en Firebase
```bash
firebase deploy --only hosting
```

### URL de Producción
La aplicación está desplegada en: `https://lhtickets.web.app`

## 📊 Características Técnicas

### Rendimiento
- **Lazy loading**: Carga progresiva de datos
- **Caché local**: Persistencia de datos críticos
- **Optimización de imágenes**: Compresión automática
- **Bundle splitting**: Carga modular de recursos

### Responsividad
- **Diseño adaptativo**: Funciona en desktop y móvil
- **Breakpoints**: Múltiples tamaños de pantalla
- **Touch-friendly**: Interfaz optimizada para touch

### Accesibilidad
- **Navegación por teclado**: Soporte completo
- **Screen readers**: Compatible con lectores de pantalla
- **Contraste**: Cumple estándares WCAG

## 🐛 Solución de Problemas

### Problemas Comunes

1. **Error de conexión a API**
   - Verificar URL en `api_service.dart`
   - Comprobar conectividad de red
   - Verificar estado del servidor

2. **Token expirado**
   - El sistema renueva automáticamente
   - Si persiste, hacer logout y login nuevamente

3. **Error de build**
   - Ejecutar `flutter clean`
   - Verificar dependencias con `flutter pub get`

## 🤝 Contribución

### Guías de Desarrollo
1. **Código limpio**: Seguir convenciones de Dart
2. **Comentarios**: Documentar funciones complejas
3. **Testing**: Agregar tests para nuevas funcionalidades
4. **Commits**: Usar mensajes descriptivos

### Estructura de Commits
```
feat: nueva funcionalidad
fix: corrección de bug
docs: documentación
style: formato de código
refactor: refactorización
test: tests
chore: tareas de mantenimiento
```

## 📞 Soporte

Para soporte técnico o reportar bugs:
- **Email**: ti@lahornilla.cl
- **Sistema**: Crear ticket en la aplicación
- **Documentación**: Consultar este README

## 📄 Licencia

Este proyecto es propiedad de La Hornilla y está destinado para uso interno.

---

**Desarrollado por el departamento de TI de La Hornilla** 🏢
