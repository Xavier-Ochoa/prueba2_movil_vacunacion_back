# 🐾 Sistema de Vacunación Canina y Felina — App Móvil (Flutter)

**Autor:** Luis Xavier Ochoa Calle

App móvil hecha en **Flutter** para gestionar campañas de vacunación de perros y gatos en una ciudad, dividida en barrios/sectores. Funciona con tres roles (coordinador de campaña, coordinador de brigada y vacunador), registra vacunaciones con foto y GPS, funciona sin conexión a internet y sincroniza solo cuando vuelve la señal.

Este documento es, sobre todo, una **guía de uso**: qué puede hacer cada rol y cómo hacerlo desde la app. Al final hay un apartado técnico sobre cómo conectar la app con el backend.

---

## 🎥 Video demostrativo de la App

En el siguiente video se muestra el funcionamiento de la aplicación, incluyendo el registro de vacunaciones, uso de cámara, GPS y sincronización de datos.

https://youtu.be/9IS0w6ixsB8

👉 **[▶️ VER VIDEO DEMOSTRATIVO](https://youtu.be/9IS0w6ixsB8)** 👈

## 📦 APK de la App

La aplicación móvil se encuentra disponible en formato APK.  
Puede descargarse desde el siguiente enlace:

https://drive.google.com/drive/folders/1UC40AyJa6rrExfJiZTT1K4NlXa8tXLn2?usp=sharing


## Índice

1. [Instalación rápida](#instalación-rápida)
2. [Conceptos generales](#conceptos-generales)
3. [Primer ingreso y contraseña inicial](#primer-ingreso-y-contraseña-inicial)
4. [Guía del Coordinador de Campaña](#guía-del-coordinador-de-campaña)
5. [Guía del Coordinador de Brigada](#guía-del-coordinador-de-brigada)
6. [Guía del Vacunador](#guía-del-vacunador)
7. [Funcionamiento sin conexión (modo offline)](#funcionamiento-sin-conexión-modo-offline)
8. [El Dashboard](#el-dashboard)
9. [Apartado técnico: conexión con el backend](#apartado-técnico-conexión-con-el-backend)

---

## Instalación rápida

```bash
flutter pub get
flutter run
```

La URL del backend está fija en `lib/utils/constants.dart` (constante `baseUrl`). Si vas a correr tu propio backend en local, cambia esa URL antes de compilar — más detalle en el [apartado técnico](#apartado-técnico-conexión-con-el-backend).

---

## Conceptos generales

- **Barrio / sector:** zona geográfica de la ciudad donde se hacen vacunaciones. Cada barrio pertenece a uno de 5 sectores: Norte, Centro Norte, Centro, Sur, Valles.
- **Jerarquía de usuarios:** el Coordinador de Campaña crea Coordinadores de Brigada, y estos crean Vacunadores. Nadie se autoregistra — todas las cuentas las crea alguien de un rol superior.
- **Contraseña inicial:** toda cuenta nueva nace con la contraseña `Ecuador2026`, y debe cambiarla obligatoriamente la primera vez que inicia sesión.
- **Activo / Inactivo:** un usuario o un barrio puede desactivarse sin borrarlo. Un usuario inactivo no puede iniciar sesión.

---

## Primer ingreso y contraseña inicial

1. Abre la app e ingresa tu correo y la contraseña inicial `Ecuador2026`.
2. La app te pedirá obligatoriamente definir una nueva contraseña antes de dejarte usar el resto de funciones.
3. Si olvidaste tu contraseña en cualquier momento posterior, en la pantalla de login usa la opción de recuperación: te llega un código de 6 dígitos por correo (válido 15 minutos) para definir una contraseña nueva.

---

## Guía del Coordinador de Campaña

Es el rol más alto. Su trabajo es organizar la estructura de la campaña: qué sectores existen y quién las coordina.

### Qué puede hacer

| Función | Dónde encontrarla |
|---|---|
| Crear coordinadores de brigada | Dashboard → **Gestionar mi equipo** → botón "Nuevo" |
| Asignar uno o varios barrios a un coordinador de brigada | Al crearlo, o después desde su tarjeta → menú → **Barrios** |
| Crear, editar, eliminar y ver los barrios/sectores | Dashboard → **Barrios / Sectores** |
| Activar / desactivar coordinadores de brigada | Lista de "Mi equipo" → botón **Desactivar** / **Activar** en cada tarjeta |
| Ver el dashboard general de toda la campaña | Pantalla principal al iniciar sesión |

### Crear un coordinador de brigada

1. Ve a **Gestionar mi equipo** → botón flotante **"Nuevo"**.
2. Completa nombre, apellido, cédula, correo y teléfono (todos obligatorios).
3. Marca uno o varios barrios que va a administrar (es opcional dejarlo sin barrios por ahora y asignárselos después).
4. Al guardar, el sistema le envía sus credenciales (correo + contraseña inicial) por email automáticamente.

### Gestionar los barrios/sectores de la ciudad

Desde **Barrios / Sectores**:
- **Crear uno nuevo:** botón "Nuevo barrio" → nombre + sector (Norte, Centro Norte, Centro, Sur o Valles).
- **Editar:** menú de tres puntos en la tarjeta del barrio → Editar (puedes cambiar nombre, sector o ponerlo Activo/Inactivo).
- **Eliminar:** menú de tres puntos → Eliminar, con confirmación.

> Si un barrio todavía tiene vacunadores trabajando activamente en él, el sistema **no te va a dejar** eliminarlo ni marcarlo como Inactivo — te va a mostrar exactamente qué vacunadores están asignados ahí, para que primero los reasignes o los desactives.

### Cambiar los barrios de un coordinador de brigada ya existente

Desde "Mi equipo", en la tarjeta de ese coordinador → menú → **Barrios** → marca o desmarca los barrios que le correspondan → Guardar.

> Mismo cuidado que arriba: no puedes quitarle un barrio si todavía tiene vacunadores activos trabajando ahí.

---

## Guía del Coordinador de Brigada

Administra uno o varios barrios y a los vacunadores que trabajan en ellos.

### Qué puede hacer

| Función | Dónde encontrarla |
|---|---|
| Ver los barrios que le asignaron | Su perfil / al crear un vacunador, solo le aparecen esos barrios para elegir |
| Crear vacunadores | Dashboard → **Gestionar mi equipo** → "Nuevo" |
| Asignar el barrio de un vacunador nuevo | Al crearlo, eligiendo entre sus propios barrios |
| Reasignar el barrio de un vacunador existente | Tarjeta del vacunador → **Reasignar** |
| Corregir cualquier registro de vacunación hecho por sus vacunadores | Lista de Vacunaciones → menú en cada registro → "Corregir registro" |
| Activar / desactivar a sus vacunadores | Tarjeta del vacunador → **Desactivar** / **Activar** |
| Ver el dashboard de su equipo | Pantalla principal al iniciar sesión |

### Crear un vacunador

1. **Gestionar mi equipo** → "Nuevo".
2. Completa los datos obligatorios (cédula, nombres, apellidos, teléfono, correo).
3. Elige **un** barrio — la lista que aparece son solo los barrios que a ti te asignó el coordinador de campaña, nunca los de otro coordinador.
4. El vacunador recibe sus credenciales por correo.

### Reasignar el barrio de un vacunador

Solo tiene sentido (y solo aparece la opción) si tú administras **2 o más barrios** — si solo tienes uno, no hay otro barrio al cual moverlo.

1. En la tarjeta del vacunador, botón **Reasignar**.
2. Elige el nuevo barrio entre los tuyos.
3. Los registros de vacunación que ese vacunador ya había hecho **no cambian de barrio** — conservan el barrio donde realmente se hizo la vacunación. Solo cambia a qué barrio va a registrar sus próximas vacunaciones.

### Corregir un registro de vacunación de tu equipo

En la **lista de vacunaciones**, cualquier registro que aparezca ahí (el sistema ya te muestra solo los de tus vacunadores) tiene un menú con la opción **"Corregir registro"** — abre el mismo formulario de edición que usa el vacunador, para arreglar un dato mal escrito, por ejemplo. No puedes eliminar registros, solo corregirlos.

### Activar / Desactivar un vacunador

Desde su tarjeta en "Mi equipo". Si lo reactivas después de un tiempo inactivo, el sistema revisa que el barrio que tenía siga siendo uno de los tuyos — si mientras estuvo inactivo perdiste ese barrio, no podrás reactivarlo hasta asignarle uno válido primero.

---

## Guía del Vacunador

Es quien está en el campo, vacunando mascotas.

### Qué puede hacer

| Función | Dónde encontrarla |
|---|---|
| Registrar una nueva vacunación | Dashboard → **Registrar Vacunación** |
| Ver sus propios registros | Dashboard → **Ver Vacunaciones** |
| Editar un registro propio | Lista de vacunaciones → menú en el registro → "Editar" |
| Eliminar un registro propio | Lista de vacunaciones → menú en el registro → "Eliminar" |
| Ver su dashboard personal | Pantalla principal al iniciar sesión |

### Registrar una vacunación

1. Dashboard → **Registrar Vacunación**.
2. Completa los datos del propietario: nombre, cédula, teléfono.
3. Completa los datos de la mascota: tipo (perro/gato), nombre, edad aproximada, sexo.
4. Indica la vacuna aplicada y, si quieres, observaciones.
5. Toma una foto (botón de cámara) — puedes elegir entre **tomar la foto en el momento** o elegir una de la galería.
6. La ubicación GPS se captura automáticamente al abrir el formulario (la app te pide permiso de ubicación la primera vez).
7. Guarda. El barrio del registro se asigna automáticamente según el barrio que tienes asignado — no necesitas elegirlo a mano.

> Si no tienes conexión a internet en ese momento, el registro **se guarda igual en tu celular** y se sube solo más tarde — ver la siguiente sección.

### Editar o eliminar un registro propio

En la lista de vacunaciones, toca el menú (los tres puntos) sobre tu registro:
- **Editar:** abre el mismo formulario para corregir cualquier dato (excepto la fotografía es opcional volver a tomarla).
- **Eliminar:** borra el registro definitivamente, incluida la foto.

Solo puedes editar/eliminar tus propios registros — los de otros vacunadores no aparecen en tu lista.

---

## Funcionamiento sin conexión (modo offline)

La app está diseñada para usarse en campo, donde puede no haber señal:

- Si registras una vacunación sin conexión, se guarda en el celular (con su foto) y queda marcada como **pendiente de sincronización**.
- En el Dashboard verás un aviso si tienes registros pendientes, con un botón para forzar la sincronización manualmente.
- Apenas el celular recupera señal (wifi o datos), la app **sincroniza automáticamente** los registros pendientes, sin que tengas que hacer nada.
- Si por algún motivo el mismo registro se llega a enviar dos veces (por ejemplo, se cortó la señal justo después de subirlo), el sistema lo reconoce y no lo duplica.

---

## El Dashboard

Lo primero que ves al iniciar sesión. Muestra, según tu rol (tus datos, los de tu equipo, o los de toda la campaña):

- Total de vacunaciones.
- Cuántos son perros y cuántos gatos (con gráfico circular).
- Vacunaciones por barrio (gráfico de barras).
- Desempeño por vacunador (solo lo ven los coordinadores).
- Registros pendientes de sincronizar, con acceso directo para sincronizar ahora.

Desliza hacia abajo en cualquier momento para refrescar los datos.

---

## Apartado técnico: conexión con el backend 

https://prueba2-movil-vacunacion-back.vercel.app/

La app no incluye un backend propio — se conecta a una API REST (Node.js + Express + MongoDB) mediante HTTP. Esta sección es un resumen rápido pensado para quien necesite levantar o apuntar a un backend propio; el detalle completo de endpoints, modelos y variables de entorno está en el README del proyecto de backend.

### Configurar la URL del backend

En `lib/utils/constants.dart`:

```dart
static const String baseUrl = 'https://tu-backend.vercel.app';
```

Cámbiala por la URL de tu backend desplegado, o por `http://10.0.2.2:4000` si estás corriendo el backend en tu propia máquina y probando en el emulador de Android.

### Cómo se autentica la app

1. `POST /api/auth/login` con `{ email, password }` → devuelve un token JWT.
2. Ese token se guarda en el dispositivo (`shared_preferences`) y se manda en el header `Authorization: Bearer <token>` en cada petición posterior.
3. Si el login indica `requiereCambioPassword: true`, la app obliga a pasar por la pantalla de cambio de contraseña antes de mostrar cualquier otra cosa.

### Endpoints que usa cada pantalla, en resumen

| Pantalla / función en la app | Endpoint del backend |
|---|---|
| Login | `POST /api/auth/login` |
| Cambiar contraseña | `POST /api/auth/cambiar-password` |
| Recuperar contraseña | `POST /api/auth/recuperar-password` → `POST /api/auth/restablecer-password` |
| Cerrar sesión | `POST /api/auth/logout` |
| Mi perfil | `GET /api/auth/perfil` |
| Crear coordinador de brigada | `POST /api/usuarios/coordinador-brigada` |
| Crear vacunador | `POST /api/usuarios/vacunador` |
| Mi equipo (lista) | `GET /api/usuarios/mis-usuarios` |
| Editar usuario | `PUT /api/usuarios/:id` |
| Cambiar barrios de un coordinador | `PUT /api/usuarios/:id/barrios` |
| Reasignar barrio de un vacunador | `PUT /api/usuarios/:id/reasignar-barrio` |
| Activar / Desactivar usuario | `PATCH /api/usuarios/:id/activar` / `:id/desactivar` |
| Listar barrios | `GET /api/barrios` |
| Crear / editar / eliminar barrio | `POST` / `PUT` / `DELETE /api/barrios/:id` |
| Registrar vacunación | `POST /api/vacunaciones` (multipart, con la foto) |
| Listar / ver vacunaciones | `GET /api/vacunaciones` / `GET /api/vacunaciones/:id` |
| Editar / eliminar vacunación | `PUT` / `DELETE /api/vacunaciones/:id` |
| Datos del Dashboard | `GET /api/vacunaciones/estadisticas` |

### Persistencia local (modo offline)

Las vacunaciones creadas sin conexión se guardan localmente con **Hive** (`lib/services/vacunacion_local_repository.dart`) y se suben solas cuando `connectivity_plus` detecta que volvió la señal (`lib/services/sync_engine.dart` + `connectivity_service.dart`). Cada registro local lleva un `clienteId` (UUID generado en el dispositivo) que el backend usa para no duplicar el registro si se reintenta el envío.

### Estructura de carpetas relevante

```
lib/
├── models/        # Usuario, Barrio, Vacunacion (y su versión local para Hive)
├── providers/      # Estado de la app (Provider): Auth, Usuario, Barrio, Vacunacion
├── services/       # Llamadas HTTP al backend + Hive + conectividad + sincronización
├── screens/
│   ├── auth/        # Login, cambiar/recuperar contraseña
│   ├── dashboard/    # Pantalla principal con estadísticas
│   ├── usuarios/     # Crear/editar/listar usuarios, gestionar barrios, reasignar
│   └── vacunacion/   # Registrar, listar, ver detalle de vacunaciones
└── utils/          # Constantes (URLs, claves de SharedPreferences, colores)
```

Para más detalle de cada endpoint (parámetros exactos, reglas de negocio, modelos de datos), consulta el README del backend.
