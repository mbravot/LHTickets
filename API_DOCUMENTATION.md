# 🔌 Documentación de API - LHTickets

## 📋 Información General

- **Base URL**: `https://apilhtickets-927498545444.us-central1.run.app/api`
- **Autenticación**: JWT Bearer Token
- **Formato de respuesta**: JSON
- **Codificación**: UTF-8

## 🔐 Autenticación

### Login
```http
POST /api/auth/login
Content-Type: application/json

{
  "correo": "usuario@lahornilla.cl",
  "clave": "password123"
}
```

**Respuesta exitosa (200):**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "usuario": {
    "id": 1,
    "nombre": "Juan Pérez",
    "correo": "juan@lahornilla.cl",
    "id_rol": 2,
    "activo": true,
    "sucursal_activa": {
      "id": 1,
      "nombre": "Sucursal Central"
    }
  }
}
```

**Respuesta de error (401):**
```json
{
  "detail": "Credenciales incorrectas"
}
```

### Refresh Token
```http
POST /api/auth/refresh
Authorization: Bearer <refresh_token>
Content-Type: application/json
```

**Respuesta exitosa (200):**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

### Register (Solo Admin)
```http
POST /api/auth/register
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "nombre": "Nuevo Usuario",
  "correo": "nuevo@lahornilla.cl",
  "clave": "password123",
  "id_rol": 1,
  "id_sucursal": 1
}
```

**Respuesta exitosa (201):**
```json
{
  "id": 15,
  "nombre": "Nuevo Usuario",
  "correo": "nuevo@lahornilla.cl",
  "id_rol": 1,
  "activo": true
}
```

## 🎫 Tickets

### Obtener Todos los Tickets
```http
GET /api/tickets
Authorization: Bearer <access_token>
```

**Respuesta exitosa (200):**
```json
[
  {
    "id": 1,
    "titulo": "Problema con impresora",
    "descripcion": "La impresora no imprime",
    "estado": "ABIERTO",
    "prioridad": "Normal",
    "departamento": {
      "id": 1,
      "nombre": "TI"
    },
    "agente": {
      "id": 2,
      "nombre": "Ana García"
    },
    "usuario": {
      "id": 1,
      "nombre": "Juan Pérez"
    },
    "fecha_creacion": "2024-01-15T10:30:00Z",
    "adjunto": "archivo.pdf",
    "sucursal": {
      "id": 1,
      "nombre": "Sucursal Central"
    }
  }
]
```

### Crear Ticket
```http
POST /api/tickets
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "titulo": "Nuevo ticket",
  "descripcion": "Descripción del problema",
  "prioridad": "Normal",
  "id_departamento": 1,
  "adjunto": "archivo.pdf"
}
```

**Respuesta exitosa (201):**
```json
{
  "ticket_id": 123,
  "mensaje": "Ticket creado exitosamente"
}
```

### Obtener Ticket por ID
```http
GET /api/tickets/{id}
Authorization: Bearer <access_token>
```

**Respuesta exitosa (200):**
```json
{
  "id": 1,
  "titulo": "Problema con impresora",
  "descripcion": "La impresora no imprime",
  "estado": "ABIERTO",
  "prioridad": "Normal",
  "departamento": {
    "id": 1,
    "nombre": "TI"
  },
  "agente": {
    "id": 2,
    "nombre": "Ana García"
  },
  "usuario": {
    "id": 1,
    "nombre": "Juan Pérez"
  },
  "fecha_creacion": "2024-01-15T10:30:00Z",
  "adjunto": "archivo.pdf",
  "comentarios": [
    {
      "id": 1,
      "contenido": "Ticket asignado al departamento TI",
      "usuario": "Ana García",
      "fecha": "2024-01-15T11:00:00Z"
    }
  ]
}
```

### Actualizar Ticket
```http
PUT /api/tickets/{id}
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "estado": "EN_PROCESO",
  "id_agente": 2,
  "prioridad": "Alta"
}
```

**Respuesta exitosa (200):**
```json
{
  "mensaje": "Ticket actualizado exitosamente"
}
```

### Agregar Comentario
```http
POST /api/tickets/{id}/comentarios
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "contenido": "Nuevo comentario sobre el ticket"
}
```

**Respuesta exitosa (201):**
```json
{
  "id": 5,
  "contenido": "Nuevo comentario sobre el ticket",
  "usuario": "Juan Pérez",
  "fecha": "2024-01-15T12:00:00Z"
}
```

## 👥 Usuarios

### Obtener Todos los Usuarios
```http
GET /api/usuarios
Authorization: Bearer <access_token>
```

**Respuesta exitosa (200):**
```json
[
  {
    "id": 1,
    "nombre": "Juan Pérez",
    "correo": "juan@lahornilla.cl",
    "id_rol": 2,
    "activo": true,
    "sucursal": {
      "id": 1,
      "nombre": "Sucursal Central"
    }
  }
]
```

### Obtener Usuario por ID
```http
GET /api/usuarios/{id}
Authorization: Bearer <access_token>
```

### Actualizar Usuario
```http
PUT /api/usuarios/{id}
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "nombre": "Juan Pérez Actualizado",
  "correo": "juan.nuevo@lahornilla.cl",
  "id_rol": 2,
  "activo": true,
  "id_sucursal": 1
}
```

### Desactivar Usuario
```http
DELETE /api/usuarios/{id}
Authorization: Bearer <access_token>
```

**Respuesta exitosa (200):**
```json
{
  "mensaje": "Usuario desactivado exitosamente"
}
```

### Cambiar Contraseña
```http
PUT /api/usuarios/{id}/password
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "clave_actual": "password123",
  "clave_nueva": "newpassword456"
}
```

## 🏢 Departamentos

### Obtener Todos los Departamentos
```http
GET /api/departamentos
Authorization: Bearer <access_token>
```

**Respuesta exitosa (200):**
```json
[
  {
    "id": 1,
    "nombre": "TI",
    "descripcion": "Departamento de Tecnología",
    "activo": true,
    "agentes": [
      {
        "id": 2,
        "nombre": "Ana García"
      }
    ]
  }
]
```

### Crear Departamento
```http
POST /api/departamentos
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "nombre": "Nuevo Departamento",
  "descripcion": "Descripción del departamento"
}
```

### Actualizar Departamento
```http
PUT /api/departamentos/{id}
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "nombre": "Departamento Actualizado",
  "descripcion": "Nueva descripción"
}
```

### Desactivar Departamento
```http
DELETE /api/departamentos/{id}
Authorization: Bearer <access_token>
```

## 📱 Aplicaciones

### Obtener Todas las Aplicaciones
```http
GET /api/apps
Authorization: Bearer <access_token>
```

**Respuesta exitosa (200):**
```json
[
  {
    "id": 1,
    "nombre": "Sistema ERP",
    "descripcion": "Sistema de gestión empresarial",
    "url": "https://erp.lahornilla.cl",
    "activo": true,
    "usuarios_asignados": [
      {
        "id": 1,
        "nombre": "Juan Pérez"
      }
    ]
  }
]
```

### Crear Aplicación
```http
POST /api/apps
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "nombre": "Nueva Aplicación",
  "descripcion": "Descripción de la aplicación",
  "url": "https://app.lahornilla.cl"
}
```

### Actualizar Aplicación
```http
PUT /api/apps/{id}
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "nombre": "Aplicación Actualizada",
  "descripcion": "Nueva descripción",
  "url": "https://app.nueva.lahornilla.cl"
}
```

### Asignar Usuario a Aplicación
```http
POST /api/apps/{id}/usuarios
Authorization: Bearer <access_token>
Content-Type: application/json

{
  "id_usuario": 1
}
```

### Desasignar Usuario de Aplicación
```http
DELETE /api/apps/{id}/usuarios/{usuario_id}
Authorization: Bearer <access_token>
```

## 🔍 Filtros y Búsqueda

### Tickets con Filtros
```http
GET /api/tickets?estado=ABIERTO&prioridad=Alta&departamento=1&usuario=1
Authorization: Bearer <access_token>
```

**Parámetros de consulta:**
- `estado`: ABIERTO, EN_PROCESO, CERRADO, CANCELADO
- `prioridad`: Baja, Normal, Alta, Crítica
- `departamento`: ID del departamento
- `usuario`: ID del usuario
- `agente`: ID del agente
- `fecha_desde`: YYYY-MM-DD
- `fecha_hasta`: YYYY-MM-DD

### Usuarios con Filtros
```http
GET /api/usuarios?rol=2&activo=true&sucursal=1
Authorization: Bearer <access_token>
```

**Parámetros de consulta:**
- `rol`: ID del rol
- `activo`: true/false
- `sucursal`: ID de la sucursal

## 📊 Estadísticas

### Estadísticas de Tickets
```http
GET /api/estadisticas/tickets
Authorization: Bearer <access_token>
```

**Respuesta exitosa (200):**
```json
{
  "total_tickets": 150,
  "tickets_abiertos": 25,
  "tickets_en_proceso": 15,
  "tickets_cerrados": 110,
  "tickets_por_prioridad": {
    "Baja": 20,
    "Normal": 80,
    "Alta": 35,
    "Crítica": 15
  },
  "tickets_por_departamento": {
    "TI": 50,
    "RRHH": 30,
    "Contabilidad": 40,
    "Ventas": 30
  }
}
```

### Estadísticas por Usuario
```http
GET /api/estadisticas/usuarios/{id}
Authorization: Bearer <access_token>
```

## 📁 Archivos

### Subir Archivo
```http
POST /api/archivos/upload
Authorization: Bearer <access_token>
Content-Type: multipart/form-data

{
  "archivo": <file>,
  "tipo": "ticket" // ticket, perfil, etc.
}
```

**Respuesta exitosa (200):**
```json
{
  "nombre_archivo": "documento.pdf",
  "url": "https://storage.googleapis.com/...",
  "tamaño": 1024000
}
```

### Descargar Archivo
```http
GET /api/archivos/{nombre_archivo}
Authorization: Bearer <access_token>
```

## ⚠️ Códigos de Error

### Errores HTTP Comunes

| Código | Descripción | Solución |
|--------|-------------|----------|
| 400 | Bad Request | Verificar formato de datos enviados |
| 401 | Unauthorized | Token inválido o expirado |
| 403 | Forbidden | Sin permisos para la operación |
| 404 | Not Found | Recurso no encontrado |
| 422 | Unprocessable Entity | Datos de validación incorrectos |
| 500 | Internal Server Error | Error interno del servidor |

### Ejemplos de Respuestas de Error

**400 - Bad Request:**
```json
{
  "detail": "Datos de entrada inválidos",
  "errors": [
    {
      "field": "correo",
      "message": "Formato de correo inválido"
    }
  ]
}
```

**401 - Unauthorized:**
```json
{
  "detail": "Token de acceso expirado"
}
```

**403 - Forbidden:**
```json
{
  "detail": "No tienes permisos para realizar esta acción"
}
```

**422 - Unprocessable Entity:**
```json
{
  "detail": "El departamento especificado no existe"
}
```

## 🔒 Seguridad

### Headers Requeridos
```http
Authorization: Bearer <access_token>
Content-Type: application/json
Accept: application/json
```

### Validación de Tokens
- Los tokens JWT tienen una duración de 20 minutos
- Se debe usar el refresh token para renovar automáticamente
- Los tokens expirados devuelven error 401

### Rate Limiting
- Máximo 100 requests por minuto por IP
- Máximo 1000 requests por hora por usuario

### Validación de Datos
- Todos los campos requeridos deben estar presentes
- Los emails deben tener formato válido
- Las URLs deben ser válidas
- Los archivos deben ser de tipos permitidos

## 📝 Notas de Implementación

### Manejo de Errores en el Cliente
```dart
try {
  final response = await apiService.getTickets();
  // Procesar respuesta
} catch (e) {
  if (e.toString().contains('401')) {
    // Token expirado - renovar automáticamente
    await sessionService.refreshToken();
  } else {
    // Mostrar error al usuario
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: ${e.toString()}')),
    );
  }
}
```

### Paginación (Futuro)
```http
GET /api/tickets?page=1&limit=20
```

**Respuesta con paginación:**
```json
{
  "data": [...],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 150,
    "pages": 8
  }
}
```

---

**Última actualización: Enero 2024** 📅 