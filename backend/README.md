# 🩺 Sistema de Vacunación Canina y Felina — Backend

**Autor:** Luis Xavier Ochoa Calle

API REST construida con **Node.js + Express + MongoDB**, con subida de imágenes a **Cloudinary** y envío de correos con **Nodemailer**. Da soporte a la app móvil Flutter del mismo proyecto: maneja autenticación con roles, gestión de usuarios en cascada (coordinador de campaña → coordinador de brigada → vacunador), barrios/sectores, registro de vacunaciones con foto + GPS, y estadísticas para el dashboard.

> Sobre la elección de tecnología: el enunciado de la prueba sugiere Firebase o Supabase como backend. Este proyecto resuelve las mismas piezas (autenticación, base de datos, almacenamiento de imágenes) con una arquitectura propia: **JWT + bcrypt** en lugar de Firebase/Supabase Auth, **MongoDB** en lugar de Firestore/Postgres, y **Cloudinary** en lugar de Firebase/Supabase Storage. Funcionalmente cubre los mismos puntos del enunciado.

---

## Índice

1. [Stack y dependencias](#stack-y-dependencias)
2. [Instalación](#instalación)
3. [Variables de entorno](#variables-de-entorno)
4. [Ejecutar el proyecto](#ejecutar-el-proyecto)
5. [Modelo de datos](#modelo-de-datos)
6. [Roles y reglas de negocio](#roles-y-reglas-de-negocio)
7. [Endpoints de la API](#endpoints-de-la-api)
8. [Seguridad implementada](#seguridad-implementada)
9. [Despliegue en Vercel](#despliegue-en-vercel)
10. [Estructura de carpetas](#estructura-de-carpetas)

---

## Stack y dependencias

| Pieza | Tecnología |
|---|---|
| Servidor | Node.js + Express 5 |
| Base de datos | MongoDB + Mongoose |
| Autenticación | JWT (`jsonwebtoken`) + `bcryptjs` para hash de contraseñas |
| Imágenes | Cloudinary (subida, transformación y borrado) + `multer` (recepción del archivo en memoria) |
| Correos | Nodemailer (Gmail) |
| Validación | `express-validator` (disponible en el proyecto) |
| Despliegue | Vercel (`@vercel/node`) |

Todas las dependencias están en `package.json`. El proyecto usa ES Modules (`"type": "module"`), no CommonJS — los imports son `import x from 'y'`, no `require()`.

---

## Instalación

```bash
cd backend
npm install
```

Crea un archivo `.env` en la carpeta `backend/` con las variables de la siguiente sección.

---

## Variables de entorno

| Variable | Descripción |
|---|---|
| `PORT` | Puerto del servidor en local (por defecto 4000) |
| `NODE_ENV` | `development` o `production` |
| `MONGODB_URI` | Cadena de conexión a MongoDB (Atlas o local) |
| `JWT_SECRET` | Clave secreta para firmar los tokens JWT |
| `EMAIL_USER` | Cuenta de Gmail que envía los correos del sistema |
| `EMAIL_PASS` | **App Password** de Gmail (no la contraseña normal de la cuenta — se genera en la configuración de seguridad de Google) |
| `CLOUDINARY_CLOUD_NAME` | Nombre de la cuenta de Cloudinary |
| `CLOUDINARY_API_KEY` | API Key de Cloudinary |
| `CLOUDINARY_API_SECRET` | API Secret de Cloudinary |

Ejemplo de `.env`:

```env
PORT=4000
NODE_ENV=development
MONGODB_URI=mongodb+srv://usuario:password@cluster.mongodb.net/vacunacion
JWT_SECRET=una_clave_larga_y_aleatoria
EMAIL_USER=tu_correo@gmail.com
EMAIL_PASS=app_password_de_16_caracteres
CLOUDINARY_CLOUD_NAME=tu_cloud_name
CLOUDINARY_API_KEY=123456789012345
CLOUDINARY_API_SECRET=tu_api_secret
```

---

## Ejecutar el proyecto

```bash
# Desarrollo (recarga automática con --watch de Node)
npm run dev

# Producción
npm start
```

El servidor arranca en `http://localhost:4000` (o el puerto que definas en `PORT`).

### Primer usuario del sistema

El rol más alto, **`coordinador_campana`**, no se crea por la API — el enunciado especifica que los usuarios no se autoregistran, y este rol no tiene un superior que lo cree. Hay que insertarlo directamente en MongoDB (Compass, `mongosh`, o Atlas UI):

```js
db.usuarios.insertOne({
  nombre: "Admin",
  apellido: "Sistema",
  cedula: "1700000001",
  email: "coordinador@vacunacion.gob.ec",
  password: "$2a$10$...",   // hash de bcrypt de la contraseña inicial (ver más abajo)
  rol: "coordinador_campana",
  passwordCambiada: false,
  estado: "activo",
  barriosAsignados: [],
  createdAt: new Date(),
  updatedAt: new Date()
})
```

Para generar el hash de la contraseña inicial (`Ecuador2026`), puedes correr en una consola de Node con `bcryptjs` instalado:

```js
const bcrypt = require('bcryptjs')
bcrypt.hash('Ecuador2026', 10).then(console.log)
```

### Barrios precargados

El proyecto está pensado para arrancar con un conjunto de barrios/sectores ya cargados (el enunciado lo exige). **Importante:** este repositorio **no incluye actualmente un script seeder** para generarlos automáticamente, aunque sí existe la opción de cargarlos manualmente:

- **Opción recomendada:** usar el CRUD de barrios desde la app Flutter (rol `coordinador_campana` → "Barrios / Sectores" → "Nuevo barrio"), que ya está implementado y conectado a los endpoints de abajo.
- **Opción alternativa:** insertarlos directamente en MongoDB, respetando el enum de sectores válido: `Norte`, `Centro Norte`, `Centro`, `Sur`, `Valles`.

```js
db.barrios.insertMany([
  { nombre: "Cotocollao", sector: "Norte", estado: "activo" },
  { nombre: "Solanda",    sector: "Sur",   estado: "activo" },
  // ...
])
```

---

## Modelo de datos

### `Usuario` (colección `usuarios`)

| Campo | Tipo | Notas |
|---|---|---|
| `nombre`, `apellido` | String | Obligatorios |
| `cedula` | String | Obligatoria, única |
| `email` | String | Obligatorio, único, se guarda en minúsculas |
| `telefono` | String | Obligatorio |
| `password` | String | Hash con bcrypt |
| `rol` | enum | `coordinador_campana` \| `coordinador_brigada` \| `vacunador` |
| `estado` | enum | `activo` \| `inactivo`. Oculto por defecto (`select: false`) |
| `passwordCambiada` | Boolean | `false` hasta que el usuario cambie la contraseña inicial. Oculto por defecto |
| `token`, `tokenExpira` | String, Date | Código OTP de recuperación de contraseña y su expiración. Ocultos por defecto |
| `creadoPor` | ObjectId → `Usuario` | Quién creó a este usuario (cadena de jerarquía) |
| `barriosAsignados` | [ObjectId → `Barrio`] | Para `coordinador_brigada`: 0, 1 o varios barrios. Para `vacunador`: siempre exactamente 1 (todo el código del backend garantiza este límite) |

### `Barrio` (colección `barrios`)

| Campo | Tipo | Notas |
|---|---|---|
| `nombre` | String | Obligatorio, único |
| `sector` | enum | `Norte` \| `Centro Norte` \| `Centro` \| `Sur` \| `Valles` |
| `coordinadorAsignado` | ObjectId → `Usuario` | `null` si no tiene coordinador de brigada asignado |
| `estado` | enum | `activo` \| `inactivo` (visible por defecto) |

### `Vacunacion` (colección `vacunaciones`)

| Campo | Tipo | Notas |
|---|---|---|
| `propietario.{nombre, cedula, telefono}` | String | Obligatorios |
| `mascota.tipo` | enum | `perro` \| `gato` |
| `mascota.{nombre, edad, sexo}` | String/Number/enum | `sexo`: `macho` \| `hembra` |
| `vacuna` | String | Obligatoria |
| `observaciones` | String | Opcional |
| `imagenUrl`, `imagenPublicId` | String | URL pública de Cloudinary y su ID interno (para poder borrarla luego) |
| `ubicacion.{latitud, longitud}` | Number | GPS al momento del registro |
| `vacunador` | ObjectId → `Usuario` | Quién hizo el registro |
| `barrio` | ObjectId → `Barrio` | En qué barrio se aplicó (se asigna automáticamente, ver más abajo) |
| `fechaRegistro` | Date | Fecha real de la vacunación (puede ser anterior si el registro se hizo offline) |
| `fechaSincronizacion` | Date | Cuándo llegó el registro al servidor |
| `clienteId` | String, único, sparse | UUID generado en el dispositivo antes de tener conexión; evita duplicados si la app reintenta subir el mismo registro |

### `TokenBlacklist` (colección `token_blacklist`)

Tokens JWT invalidados manualmente vía logout. Tiene un índice TTL (`expires: 0`) que hace que MongoDB borre el documento automáticamente en la fecha de expiración del token — no se acumulan registros viejos.

---

## Roles y reglas de negocio

### Jerarquía de creación

```
coordinador_campana  →  crea  →  coordinador_brigada  →  crea  →  vacunador
   (se crea en DB)
```

### Reglas clave que aplica el backend (no solo la UI)

- **Un vacunador siempre tiene exactamente 1 barrio.** Tanto al crearlo como al reasignarlo, el backend guarda `barriosAsignados` como un array de un solo elemento, reemplazándolo por completo en cada reasignación — nunca se acumulan barrios.
- **Un coordinador de brigada puede tener 0, 1, 2 o más barrios.** No hay mínimo obligatorio.
- **Reasignar el barrio de un vacunador** solo es posible si el coordinador de brigada administra 2 o más barrios (si solo tiene 1, no hay a dónde reasignar) y solo el coordinador que **creó** a ese vacunador puede hacerlo.
- **No se puede quitar un barrio a un coordinador de brigada**, ni **inactivar** ni **eliminar** un barrio, si todavía tiene vacunadores con `estado: 'activo'` trabajando en él. El backend responde `409` con el detalle de qué vacunadores están bloqueando la operación.
- **Reactivar un vacunador** que estuvo inactivo se bloquea si, mientras estuvo inactivo, le quitaron a su coordinador el barrio que tenía asignado (quedaría con un barrio que su coordinador ya no administra).
- **Editar/corregir un registro de vacunación**: lo puede hacer el vacunador que lo creó, o el coordinador de brigada que **creó** a ese vacunador (no se basa en si el barrio del registro sigue siendo del coordinador, sino en la relación de creación).
- **Eliminar un registro de vacunación**: solo el vacunador que lo creó.
- El `barrioId` que llega al crear una vacunación se valida contra los barrios reales del vacunador autenticado — si alguien intenta forzar un barrio ajeno (por ejemplo, llamando a la API directamente sin pasar por la app), el backend lo ignora y usa el barrio real del vacunador.
- **Cambio de contraseña obligatorio**: ningún usuario puede usar el resto de la API (excepto login y recuperar/restablecer contraseña) hasta que cambie la contraseña inicial `Ecuador2026`.

---

## Endpoints de la API

Base URL: `/api`

Convenciones:
- 🔓 = no requiere token. 🔒 = requiere header `Authorization: Bearer <token>`.
- Los endpoints 🔒 (salvo login/recuperación) además exigen que el usuario ya haya cambiado su contraseña inicial.

### Auth — `/api/auth`

| Método | Ruta | Auth | Descripción | Body |
|---|---|---|---|---|
| POST | `/login` | 🔓 | Iniciar sesión | `{ email, password }` |
| POST | `/recuperar-password` | 🔓 | Pide un código OTP de 6 dígitos por correo (expira en 15 min) | `{ email }` |
| POST | `/restablecer-password` | 🔓 | Verifica el código y define la nueva contraseña, en un solo paso | `{ email, codigo, passwordNueva }` |
| POST | `/logout` | 🔒 | Invalida el token actual (lo agrega a la blacklist) | — |
| POST | `/cambiar-password` | 🔒 | Cambia la contraseña estando autenticado (login normal o primer cambio obligatorio) | `{ passwordActual, passwordNueva }` |
| GET | `/perfil` | 🔒 | Devuelve los datos del usuario autenticado | — |

La respuesta de `/login` incluye `requiereCambioPassword: true` si el usuario todavía no cambió la contraseña inicial.

### Usuarios — `/api/usuarios`

| Método | Ruta | Rol requerido | Descripción | Body |
|---|---|---|---|---|
| POST | `/coordinador-brigada` | `coordinador_campana` | Crea un coordinador de brigada | `{ nombre, apellido, cedula, email, telefono, barriosIds? }` |
| POST | `/vacunador` | `coordinador_brigada` | Crea un vacunador | `{ nombre, apellido, cedula, email, telefono, barrioId }` |
| GET | `/mis-usuarios` | cualquier coordinador | Lista los usuarios que el autenticado creó | — |
| GET | `/:id` | cualquier coordinador | Detalle de un usuario por ID | — |
| PUT | `/:id` | cualquier coordinador | Edita nombre/apellido/teléfono de un usuario | `{ nombre?, apellido?, telefono? }` |
| PUT | `/:id/barrios` | `coordinador_campana` (creador) | Reemplaza los barrios de un coordinador de brigada | `{ barriosIds: [] }` |
| PUT | `/:id/reasignar-barrio` | `coordinador_brigada` (creador, con 2+ barrios) | Cambia el barrio de un vacunador | `{ barrioId }` |
| PATCH | `/:id/desactivar` | creador del usuario | Pone `estado: 'inactivo'` | — |
| PATCH | `/:id/activar` | creador del usuario | Pone `estado: 'activo'` (con validación de barrio en vacunadores) | — |

Todos creados con la contraseña inicial `Ecuador2026` y reciben sus credenciales por correo automáticamente.

### Barrios — `/api/barrios`

| Método | Ruta | Rol requerido | Descripción | Body |
|---|---|---|---|---|
| GET | `/` | cualquier autenticado | Lista todos los barrios. Filtros opcionales por query: `?sector=` y `?estado=` | — |
| GET | `/:id` | cualquier autenticado | Detalle de un barrio | — |
| POST | `/` | `coordinador_campana` | Crea un barrio | `{ nombre, sector }` |
| PUT | `/:id` | `coordinador_campana` | Edita nombre, sector o estado | `{ nombre?, sector?, estado? }` |
| DELETE | `/:id` | `coordinador_campana` | Elimina un barrio (bloqueado si tiene vacunadores activos) | — |
| POST | `/asignar` | `coordinador_campana` | Asigna un barrio a un coordinador de brigada | `{ barrioId, coordinadorId }` |
| PATCH | `/:id/desasignar` | `coordinador_campana` | Quita el coordinador de un barrio | — |

`sector` debe ser uno de: `Norte`, `Centro Norte`, `Centro`, `Sur`, `Valles`.

### Vacunaciones — `/api/vacunaciones`

| Método | Ruta | Auth | Descripción | Body |
|---|---|---|---|---|
| GET | `/estadisticas` | 🔒 | Datos para el dashboard (ver abajo) | — |
| POST | `/` | 🔒 (vacunador) | Registra una vacunación. **multipart/form-data**, campo de archivo `imagen` | ver tabla siguiente |
| GET | `/` | 🔒 | Lista vacunaciones (filtradas según el rol) | — |
| GET | `/:id` | 🔒 | Detalle de una vacunación | — |
| PUT | `/:id` | 🔒 | Edita una vacunación. multipart/form-data, `imagen` opcional | mismos campos que crear, todos opcionales |
| DELETE | `/:id` | 🔒 (vacunador dueño) | Elimina una vacunación (y su imagen en Cloudinary) | — |

**Campos del body al crear una vacunación** (`multipart/form-data`):

`propietarioNombre`, `propietarioCedula`, `propietarioTelefono`, `mascotaTipo` (`perro`/`gato`), `mascotaNombre`, `mascotaEdad`, `mascotaSexo` (`macho`/`hembra`), `vacuna`, `observaciones`, `latitud`, `longitud`, `clienteId` (UUID del dispositivo, para soporte offline), `fechaRegistro` (opcional, fecha real si el registro se hizo sin conexión), `imagen` (archivo).

`barrioId` es opcional en el body — si no se manda, o si se manda uno que no pertenece al vacunador, el backend usa automáticamente el barrio real asignado al vacunador.

**Filtrado por rol en `GET /` y `GET /estadisticas`:**
- `vacunador` → solo sus propios registros.
- `coordinador_brigada` → registros de los vacunadores que él creó.
- `coordinador_campana` → registros de todos los vacunadores bajo sus coordinadores de brigada.

**Respuesta de `/estadisticas`:**
```json
{
  "success": true,
  "estadisticas": {
    "total": 120,
    "perros": 80,
    "gatos": 40,
    "porBarrio": [{ "_id": "Cotocollao", "sector": "Norte", "total": 30 }],
    "porVacunador": [{ "_id": "...", "nombre": "...", "apellido": "...", "total": 30, "perros": 20, "gatos": 10 }]
  }
}
```

---

## Seguridad implementada

- Contraseñas con hash `bcrypt` (10 rondas de salt), nunca en texto plano.
- JWT firmado con `JWT_SECRET`, verificado en cada request a una ruta protegida.
- Logout real: el token se invalida agregándolo a una blacklist con expiración automática (TTL de MongoDB), no solo se borra del lado del cliente.
- Recuperación de contraseña con código OTP de 6 dígitos, expira en 15 minutos, de un solo uso.
- Cambio de contraseña obligatorio en el primer login, forzado por middleware (`verificarPasswordCambiada`) en casi todas las rutas protegidas.
- Verificación de jerarquía en cada operación sensible: un coordinador o vacunador solo puede actuar sobre usuarios/registros que él mismo creó (campo `creadoPor`), nunca sobre los de otra rama del árbol.
- Validación de pertenencia de barrios: cualquier `barrioId` que llegue del cliente se valida contra los barrios reales asignados al usuario antes de aceptarlo, en lugar de confiar ciegamente en lo que mande el body.
- Protecciones de integridad de datos: no se puede eliminar/inactivar un barrio, ni quitarle un barrio a un coordinador, si eso dejaría a vacunadores activos "huérfanos" de un barrio inexistente o fuera del alcance de su coordinador.

---

## Despliegue en Vercel

El proyecto incluye `vercel.json` configurado para desplegar `src/index.js` como función serverless con `@vercel/node`. Pasos:

1. Conecta el repositorio a Vercel.
2. Configura las variables de entorno de la sección anterior en el dashboard de Vercel (Settings → Environment Variables).
3. Despliega. Vercel detecta automáticamente la configuración de `vercel.json`.

> Nota técnica: en Vercel no es necesario que `app.listen()` mantenga un proceso corriendo — la plataforma maneja el ciclo de vida de la función. El archivo `index.js` llama a `app.listen()` para que el mismo código funcione también en local (`npm start`) sin cambios.

---

## Estructura de carpetas

```
backend/
├── src/
│   ├── config/
│   │   ├── database.js       # Conexión a MongoDB
│   │   ├── cloudinary.js     # Configuración de Cloudinary + multer
│   │   └── nodemailer.js     # Transporte de correo (Gmail)
│   ├── controllers/
│   │   ├── auth_controller.js        # Login, logout, recuperación, perfil
│   │   ├── usuario_controller.js     # Crear/listar/editar/activar/desactivar usuarios
│   │   ├── barrio_controller.js      # CRUD de barrios + asignación a coordinadores
│   │   └── vacunacion_controller.js  # CRUD de vacunaciones + estadísticas
│   ├── helpers/
│   │   └── sendMail.js       # Plantillas HTML de correo
│   ├── middlewares/
│   │   └── JWT.js            # Generar/verificar token, middlewares de rol
│   ├── models/
│   │   ├── Usuario.js
│   │   ├── Barrio.js
│   │   ├── Vacunacion.js
│   │   └── TokenBlacklist.js
│   ├── routes/
│   │   ├── auth_routes.js
│   │   ├── usuario_routes.js
│   │   ├── barrio_routes.js
│   │   └── vacunacion_routes.js
│   ├── index.js              # Entry point (carga .env, conecta DB, arranca el server)
│   └── server.js             # Configuración de Express y montaje de rutas
├── package.json
└── vercel.json
```
