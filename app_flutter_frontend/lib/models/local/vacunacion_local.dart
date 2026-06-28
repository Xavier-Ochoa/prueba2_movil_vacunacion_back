import 'package:hive/hive.dart';

part 'vacunacion_local.g.dart';

/// Estado de sincronización de un registro guardado localmente.
///
/// pendiente    → creado/editado sin internet, esperando subir al backend
/// sincronizando → está siendo subido en este momento (evita reintentos dobles)
/// sincronizado  → ya existe en el backend (tiene mongoId)
/// error         → un intento de subida falló; se reintentará más adelante
/// pendienteEliminar → el usuario lo borró sin internet; hay que avisar
///                      al backend en cuanto haya señal
enum EstadoSync {
  pendiente,
  sincronizando,
  sincronizado,
  error,
  pendienteEliminar,
}

/// Registro de vacunación almacenado en el dispositivo (Hive).
///
/// Mientras no se sincronice, [mongoId] es null: el registro solo existe
/// localmente y no se puede editar/eliminar contra el backend (no tiene id
/// de Mongo todavía). El [clienteId] es la clave estable que identifica al
/// registro durante todo su ciclo de vida, incluso antes de tener mongoId.
@HiveType(typeId: 0)
class VacunacionLocal extends HiveObject {
  /// Id único generado en el dispositivo al crear el registro (uuid v4).
  /// Es la clave primaria local y también la clave de Hive (`key`).
  @HiveField(0)
  String clienteId;

  /// Id asignado por MongoDB una vez sincronizado. Null mientras esté
  /// pendiente.
  @HiveField(1)
  String? mongoId;

  // ── Propietario ──────────────────────────────────────────────────────
  @HiveField(2)
  String propietarioNombre;
  @HiveField(3)
  String propietarioCedula;
  @HiveField(4)
  String propietarioTelefono;

  // ── Mascota ──────────────────────────────────────────────────────────
  @HiveField(5)
  String mascotaTipo; // perro | gato
  @HiveField(6)
  String mascotaNombre;
  @HiveField(7)
  int mascotaEdad;
  @HiveField(8)
  String mascotaSexo; // macho | hembra

  // ── Vacuna ───────────────────────────────────────────────────────────
  @HiveField(9)
  String vacuna;
  @HiveField(10)
  String observaciones;

  // ── Imagen ───────────────────────────────────────────────────────────
  /// Ruta local del archivo de imagen en el dispositivo. Se mantiene
  /// hasta que la sincronización confirma que ya se subió a Cloudinary;
  /// solo entonces se borra el archivo físico de la memoria del celular.
  @HiveField(11)
  String imagenLocalPath;

  /// URL final en Cloudinary, solo se llena tras sincronizar.
  @HiveField(12)
  String? imagenUrlRemota;

  // ── GPS ──────────────────────────────────────────────────────────────
  @HiveField(13)
  double? latitud;
  @HiveField(14)
  double? longitud;

  // ── Relaciones ───────────────────────────────────────────────────────
  @HiveField(15)
  String? barrioId;

  /// Nombre/sector del barrio, copiados en el momento de crear el
  /// registro (el formulario ya los tiene disponibles porque vienen
  /// del dropdown de barrios). Evita tener que resolver un catálogo
  /// aparte solo para mostrar el barrio mientras el registro sigue
  /// pendiente de sincronizar.
  @HiveField(20)
  String? barrioNombre;
  @HiveField(21)
  String? barrioSector;

  // ── Fechas ───────────────────────────────────────────────────────────
  /// Momento real en que se registró la vacunación en el dispositivo
  /// (independiente de cuándo se sincronice).
  @HiveField(16)
  DateTime fechaRegistro;

  // ── Estado de sincronización ────────────────────────────────────────
  @HiveField(17)
  String estado; // ver EstadoSync (guardado como string por compatibilidad)

  /// Número de intentos de sincronización fallidos. Sirve para backoff
  /// y para mostrarle al usuario "lleva 3 intentos fallidos".
  @HiveField(18)
  int intentos;

  /// Último mensaje de error de sincronización (para depurar/mostrar).
  @HiveField(19)
  String? ultimoError;

  VacunacionLocal({
    required this.clienteId,
    this.mongoId,
    required this.propietarioNombre,
    required this.propietarioCedula,
    required this.propietarioTelefono,
    required this.mascotaTipo,
    required this.mascotaNombre,
    required this.mascotaEdad,
    required this.mascotaSexo,
    required this.vacuna,
    required this.observaciones,
    required this.imagenLocalPath,
    this.imagenUrlRemota,
    this.latitud,
    this.longitud,
    this.barrioId,
    this.barrioNombre,
    this.barrioSector,
    required this.fechaRegistro,
    this.estado = 'pendiente',
    this.intentos = 0,
    this.ultimoError,
  });

  EstadoSync get estadoEnum => EstadoSync.values.firstWhere(
        (e) => e.name == estado,
        orElse: () => EstadoSync.pendiente,
      );

  set estadoEnum(EstadoSync nuevo) => estado = nuevo.name;

  bool get yaSincronizado => mongoId != null && estadoEnum == EstadoSync.sincronizado;

  /// Indica si este registro puede editarse/eliminarse contra el backend
  /// directamente (porque ya tiene id de Mongo) o si esos cambios deben
  /// resolverse solo localmente porque aún no existe en el servidor.
  bool get existeEnBackend => mongoId != null;
}
