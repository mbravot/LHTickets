# 🚀 Guía de Despliegue - LHTickets

## 📋 Índice
1. [Prerrequisitos](#prerrequisitos)
2. [Configuración del Entorno](#configuración-del-entorno)
3. [Build de Producción](#build-de-producción)
4. [Despliegue en Firebase](#despliegue-en-firebase)
5. [Configuración de Dominio](#configuración-de-dominio)
6. [Monitoreo y Mantenimiento](#monitoreo-y-mantenimiento)
7. [Rollback](#rollback)
8. [Troubleshooting](#troubleshooting)

## 🔧 Prerrequisitos

### Herramientas Requeridas
```bash
# Verificar instalaciones
flutter --version
dart --version
node --version
npm --version
firebase --version
```

### Cuentas Necesarias
- ✅ Cuenta de Google Cloud Platform
- ✅ Proyecto de Firebase
- ✅ Firebase CLI configurado
- ✅ Permisos de administrador en el proyecto

## ⚙️ Configuración del Entorno

### 1. Configuración de Firebase
```bash
# Instalar Firebase CLI globalmente
npm install -g firebase-tools

# Login a Firebase
firebase login

# Inicializar proyecto Firebase
firebase init hosting
```

**Opciones de configuración:**
```bash
? What do you want to use as your public directory? build/web
? Configure as a single-page app (rewrite all urls to /index.html)? Yes
? Set up automatic builds and deploys with GitHub? No
? File build/web/404.html already exists. Overwrite? No
? File build/web/index.html already exists. Overwrite? No
```

### 2. Configuración de Variables de Entorno

**Crear archivo `.env` (para desarrollo):**
```env
# API Configuration
API_BASE_URL=https://apilhtickets-927498545444.us-central1.run.app/api

# Firebase Configuration
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_API_KEY=your-api-key
FIREBASE_AUTH_DOMAIN=your-project.firebaseapp.com
FIREBASE_STORAGE_BUCKET=your-project.appspot.com
FIREBASE_MESSAGING_SENDER_ID=123456789
FIREBASE_APP_ID=1:123456789:web:abcdef123456
```

### 3. Configuración de Firebase Hosting

**`firebase.json`:**
```json
{
  "hosting": {
    "public": "build/web",
    "ignore": [
      "firebase.json",
      "**/.*",
      "**/node_modules/**"
    ],
    "rewrites": [
      {
        "source": "**",
        "destination": "/index.html"
      }
    ],
    "headers": [
      {
        "source": "**/*.@(js|css)",
        "headers": [
          {
            "key": "Cache-Control",
            "value": "max-age=31536000"
          }
        ]
      },
      {
        "source": "**/*.@(jpg|jpeg|gif|png|svg|webp)",
        "headers": [
          {
            "key": "Cache-Control",
            "value": "max-age=31536000"
          }
        ]
      }
    ]
  }
}
```

## 🏗️ Build de Producción

### 1. Optimización del Build
```bash
# Limpiar build anterior
flutter clean

# Obtener dependencias
flutter pub get

# Build optimizado para producción
flutter build web --release --dart-define=FLUTTER_WEB_USE_SKIA=true
```

**Opciones de optimización:**
```bash
# Build con compresión
flutter build web --release --dart-define=FLUTTER_WEB_USE_SKIA=true --dart-define=FLUTTER_WEB_USE_SKIA_CANVASKIT=true

# Build con tree shaking
flutter build web --release --tree-shake-icons

# Build con análisis de bundle
flutter build web --release --analyze-size
```

### 2. Verificación del Build
```bash
# Verificar que el build se creó correctamente
ls -la build/web/

# Verificar archivos críticos
ls -la build/web/main.dart.js
ls -la build/web/index.html
ls -la build/web/assets/
```

### 3. Testing del Build Local
```bash
# Servir build localmente para testing
cd build/web
python -m http.server 8000

# O usar serve
npx serve -s . -l 8000
```

## 🔥 Despliegue en Firebase

### 1. Despliegue Inicial
```bash
# Desplegar a Firebase Hosting
firebase deploy --only hosting

# Verificar despliegue
firebase hosting:channel:list
```

### 2. Despliegue con Preview
```bash
# Crear canal de preview
firebase hosting:channel:deploy preview

# Obtener URL de preview
firebase hosting:channel:list
```

### 3. Despliegue a Producción
```bash
# Desplegar a producción
firebase deploy --only hosting

# Verificar estado
firebase hosting:sites:list
```

### 4. Configuración de CI/CD (Opcional)

**`.github/workflows/deploy.yml`:**
```yaml
name: Deploy to Firebase

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Flutter
      uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.6.1'
        channel: 'stable'
    
    - name: Install dependencies
      run: flutter pub get
    
    - name: Build web
      run: flutter build web --release
    
    - name: Deploy to Firebase
      uses: FirebaseExtended/action-hosting-deploy@v0
      with:
        repoToken: '${{ secrets.GITHUB_TOKEN }}'
        firebaseServiceAccount: '${{ secrets.FIREBASE_SERVICE_ACCOUNT }}'
        projectId: your-project-id
        channelId: live
```

## 🌐 Configuración de Dominio

### 1. Dominio Personalizado
```bash
# Agregar dominio personalizado
firebase hosting:sites:add your-domain.com

# Configurar DNS
# Agregar registros CNAME en tu proveedor DNS:
# your-domain.com -> your-project.web.app
```

### 2. Configuración de SSL
```bash
# Firebase maneja SSL automáticamente
# Verificar certificado
curl -I https://your-domain.com
```

### 3. Configuración de Redirecciones
```json
{
  "hosting": {
    "redirects": [
      {
        "source": "/old-page",
        "destination": "/new-page",
        "type": 301
      }
    ]
  }
}
```

## 📊 Monitoreo y Mantenimiento

### 1. Configuración de Analytics
```dart
// En main.dart
import 'package:firebase_analytics/firebase_analytics.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  runApp(MyApp());
}
```

### 2. Configuración de Crashlytics
```dart
// En main.dart
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // Configurar Crashlytics
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
  
  runApp(MyApp());
}
```

### 3. Monitoreo de Performance
```bash
# Verificar métricas de performance
firebase hosting:sites:list

# Ver logs de errores
firebase hosting:channel:list
```

### 4. Backup y Recuperación
```bash
# Backup de configuración
cp firebase.json firebase.json.backup
cp .firebaserc .firebaserc.backup

# Backup de build
cp -r build/web build/web.backup
```

## 🔄 Rollback

### 1. Rollback Automático
```bash
# Listar versiones disponibles
firebase hosting:releases:list

# Rollback a versión anterior
firebase hosting:releases:rollback VERSION_ID
```

### 2. Rollback Manual
```bash
# Revertir a commit anterior
git checkout HEAD~1

# Rebuild y redeploy
flutter build web --release
firebase deploy --only hosting
```

### 3. Rollback de Configuración
```bash
# Restaurar configuración anterior
cp firebase.json.backup firebase.json
cp .firebaserc.backup .firebaserc

# Redeploy
firebase deploy --only hosting
```

## 🐛 Troubleshooting

### Problemas Comunes

#### 1. Error de Build
```bash
# Limpiar cache
flutter clean
flutter pub get

# Verificar dependencias
flutter doctor

# Build con verbose
flutter build web --release --verbose
```

#### 2. Error de Despliegue
```bash
# Verificar configuración
firebase projects:list
firebase use --add

# Verificar permisos
firebase login --reauth

# Desplegar con debug
firebase deploy --only hosting --debug
```

#### 3. Error de Dominio
```bash
# Verificar configuración DNS
nslookup your-domain.com

# Verificar certificado SSL
curl -I https://your-domain.com

# Verificar configuración de Firebase
firebase hosting:sites:list
```

### Logs y Debugging

#### 1. Logs de Firebase
```bash
# Ver logs de hosting
firebase hosting:channel:list

# Ver logs de funciones
firebase functions:log

# Ver logs en tiempo real
firebase hosting:channel:list --debug
```

#### 2. Debug de Build
```bash
# Analizar tamaño del bundle
flutter build web --release --analyze-size

# Ver dependencias
flutter pub deps

# Ver configuración
flutter config
```

#### 3. Debug de Performance
```bash
# Lighthouse audit
npx lighthouse https://your-domain.com --output html --output-path ./lighthouse-report.html

# WebPageTest
# Visitar https://www.webpagetest.org/
```

## 📋 Checklist de Despliegue

### Antes del Despliegue
- [ ] Código probado en desarrollo
- [ ] Tests pasando
- [ ] Build exitoso localmente
- [ ] Variables de entorno configuradas
- [ ] Configuración de Firebase actualizada
- [ ] Backup de configuración anterior

### Durante el Despliegue
- [ ] Build de producción exitoso
- [ ] Despliegue a Firebase exitoso
- [ ] Verificación de archivos desplegados
- [ ] Testing de funcionalidad básica
- [ ] Verificación de SSL/HTTPS

### Después del Despliegue
- [ ] Testing completo de funcionalidades
- [ ] Verificación de performance
- [ ] Monitoreo de errores
- [ ] Documentación de cambios
- [ ] Notificación a usuarios (si aplica)

## 🔒 Seguridad

### Configuración de Seguridad
```json
{
  "hosting": {
    "headers": [
      {
        "source": "**/*.@(js|css)",
        "headers": [
          {
            "key": "X-Content-Type-Options",
            "value": "nosniff"
          },
          {
            "key": "X-Frame-Options",
            "value": "DENY"
          },
          {
            "key": "X-XSS-Protection",
            "value": "1; mode=block"
          }
        ]
      }
    ]
  }
}
```

### Validación de Seguridad
```bash
# Verificar headers de seguridad
curl -I https://your-domain.com

# Verificar certificado SSL
openssl s_client -connect your-domain.com:443 -servername your-domain.com

# Verificar configuración de seguridad
firebase hosting:sites:list
```

## 📈 Optimización

### 1. Optimización de Bundle
```bash
# Analizar tamaño del bundle
flutter build web --release --analyze-size

# Optimizar imágenes
flutter build web --release --tree-shake-icons

# Compresión de assets
flutter build web --release --dart-define=FLUTTER_WEB_USE_SKIA=true
```

### 2. Optimización de Performance
```json
{
  "hosting": {
    "headers": [
      {
        "source": "**/*.@(js|css)",
        "headers": [
          {
            "key": "Cache-Control",
            "value": "public, max-age=31536000"
          },
          {
            "key": "Content-Encoding",
            "value": "gzip"
          }
        ]
      }
    ]
  }
}
```

### 3. CDN y Caché
```bash
# Configurar CDN personalizado
firebase hosting:sites:add cdn.your-domain.com

# Configurar caché
firebase hosting:channel:deploy staging
```

---

**Guía de despliegue actualizada: Enero 2024** 📅 