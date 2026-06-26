# 🩺 Sistema de Vacunación — Backend Sprint 1

API REST construida con **Node.js + Express + MongoDB**.

---

## 🚀 Instalación

```bash
npm install
```

Copia el archivo de variables de entorno y complétalo:

```bash
cp .env.example .env
```

---

## ⚙️ Variables de entorno (`.env`)

| Variable       | Descripción                              |
|----------------|------------------------------------------|
| `PORT`         | Puerto del servidor (default: 4000)      |
| `MONGODB_URI`  | Cadena de conexión MongoDB Atlas         |
| `JWT_SECRET`   | Clave secreta para firmar JWT            |
| `EMAIL_USER`   | Correo Gmail para enviar notificaciones  |
| `EMAIL_PASS`   | App Password de Gmail (no la contraseña) |
| `URL_FRONTEND` | URL del frontend para CORS               |

---

## ▶️ Ejecutar

```bash
# Desarrollo (con hot reload)
npm run dev

# Producción
npm start

# Cargar los 25 barrios de Quito
npm run seed
```

---

## 👤 Crear Coordinador de Campaña (en DB directamente)

El Coordinador de Campaña es el rol más alto y se crea manualmente en MongoDB.
Usar `bcryptjs` para hashear la contraseña o ejecutar este script en la DB:

```js
// En MongoDB Compass o mongosh
db.usuarios.insertOne({
  nombre: "Admin",
  apellido: "Sistema",
  cedula: "1700000001",
  email: "coordinador@vacunacion.gob.ec",
  password: "$2a$10$...",   // hash de bcrypt
  rol: "coordinador_campana",
  passwordCambiada: true,
  estado: "activo",
  barriosAsignados: [],
  createdAt: new Date(),
  updatedAt: new Date()
})
```

O usar el script utilitario incluido:

```bash
node src/seeders/crear_coordinador_campana.js
```

---

## 🔐 Roles del sistema

| Rol                    | Puede crear              | Acceso                         |
|------------------------|--------------------------|--------------------------------|
| `coordinador_campana`  | Coordinadores de Brigada | CRUD barrios, asignar barrios  |
| `coordinador_brigada`  | Vacunadores              | Ver barrios asignados          |
| `vacunador`            | —                        | Funciones de vacunación        |

---

## 📡 Endpoints

### 🔓 Auth — `/api/auth`

| Método | Ruta                          | Descripción                         | Auth |
|--------|-------------------------------|-------------------------------------|------|
| POST   | `/login`                      | Iniciar sesión                      | ❌   |
| POST   | `/logout`                     | Cerrar sesión (invalida JWT)        | ✅   |
| GET    | `/perfil`                     | Ver perfil del usuario autenticado  | ✅   |
| POST   | `/cambiar-password`           | Cambiar contraseña (autenticado)    | ✅   |
| POST   | `/recuperar-password`         | Solicitar token de recuperación     | ❌   |
| GET    | `/verificar-token/:token`     | Verificar token de recuperación     | ❌   |
| POST   | `/nuevo-password/:token`      | Crear nueva contraseña              | ❌   |

### 👥 Usuarios — `/api/usuarios`

| Método | Ruta                          | Descripción                              | Rol requerido           |
|--------|-------------------------------|------------------------------------------|-------------------------|
| POST   | `/coordinador-brigada`        | Crear Coordinador de Brigada             | coordinador_campana     |
| POST   | `/vacunador`                  | Crear Vacunador                          | coordinador_brigada     |
| GET    | `/mis-usuarios`               | Listar usuarios que yo creé              | coordinador_*           |
| GET    | `/:id`                        | Obtener un usuario por ID                | coordinador_*           |
| PATCH  | `/:id/desactivar`             | Desactivar un usuario                    | su creador / coord. campaña |

### 🏙️ Barrios — `/api/barrios`

| Método | Ruta                  | Descripción                          | Rol requerido         |
|--------|-----------------------|--------------------------------------|-----------------------|
| GET    | `/`                   | Listar barrios (filtros: sector)     | cualquier autenticado |
| GET    | `/:id`                | Obtener barrio por ID                | cualquier autenticado |
| POST   | `/`                   | Crear barrio                         | coordinador_campana   |
| PUT    | `/:id`                | Actualizar barrio                    | coordinador_campana   |
| DELETE | `/:id`                | Eliminar barrio                      | coordinador_campana   |
| POST   | `/asignar`            | Asignar barrio a coordinador         | coordinador_campana   |
| PATCH  | `/:id/desasignar`     | Quitar coordinador de un barrio      | coordinador_campana   |

---

## 🏙️ 25 Barrios precargados

| Sector        | Barrios                                                              |
|---------------|----------------------------------------------------------------------|
| Norte         | Cotocollao, Ponceano, Comité del Pueblo, El Condado, Carcelén        |
| Centro Norte  | La Mariscal, Iñaquito, Rumipamba, Belisario Quevedo, La Floresta     |
| Centro        | Centro Histórico, La Tola, San Juan, La Vicentina, Itchimbía         |
| Sur           | Solanda, La Magdalena, Chillogallo, Quitumbe, Guamaní                |
| Valles        | Cumbayá, Tumbaco, San Rafael, Sangolquí, La Armenia                  |

---

## 🔑 Contraseña inicial

Todos los usuarios creados por el sistema reciben la contraseña inicial:

```
Ecuador2026
```

Al hacer login por primera vez, el sistema responde con `requiereCambioPassword: true`.
El usuario **debe** llamar a `POST /api/auth/cambiar-password` antes de poder usar el sistema.

---

## 📁 Estructura del proyecto

```
src/
├── config/
│   ├── database.js          # Conexión MongoDB
│   └── nodemailer.js        # Transporte de correo
├── controllers/
│   ├── auth_controller.js   # Login, logout, recuperación
│   ├── usuario_controller.js # Crear coord/vacunador
│   └── barrio_controller.js  # CRUD + asignación de barrios
├── helpers/
│   └── sendMail.js          # Plantillas de correo HTML
├── middlewares/
│   └── JWT.js               # Token + middlewares de roles
├── models/
│   ├── Usuario.js           # Modelo de usuarios
│   ├── Barrio.js            # Modelo de barrios
│   └── TokenBlacklist.js    # Tokens invalidados
├── routes/
│   ├── auth_routes.js
│   ├── usuario_routes.js
│   └── barrio_routes.js
├── seeders/
│   └── barrios.seeder.js    # Precarga los 25 barrios
├── index.js                 # Entry point
└── server.js                # Express + rutas
```
