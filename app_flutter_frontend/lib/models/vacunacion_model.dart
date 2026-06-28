import 'local/vacunacion_local.dart';

class Propietario {
  final String nombre;
  final String cedula;
  final String telefono;

  Propietario({
    required this.nombre,
    required this.cedula,
    required this.telefono,
  });

  factory Propietario.fromJson(Map<String, dynamic> json) => Propietario(
        nombre:   json['nombre']   ?? '',
        cedula:   json['cedula']   ?? '',
        telefono: json['telefono'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'nombre':   nombre,
        'cedula':   cedula,
        'telefono': telefono,
      };
}

class Mascota {
  final String tipo;
  final String nombre;
  final int edad;
  final String sexo;

  Mascota({
    required this.tipo,
    required this.nombre,
    required this.edad,
    required this.sexo,
  });

  factory Mascota.fromJson(Map<String, dynamic> json) => Mascota(
        tipo:   json['tipo']   ?? '',
        nombre: json['nombre'] ?? '',
        edad:   json['edad']   ?? 0,
        sexo:   json['sexo']   ?? '',
      );
}

class Ubicacion {
  final double? latitud;
  final double? longitud;

  Ubicacion({this.latitud, this.longitud});

  factory Ubicacion.fromJson(Map<String, dynamic> json) => Ubicacion(
        latitud:  (json['latitud']  as num?)?.toDouble(),
        longitud: (json['longitud'] as num?)?.toDouble(),
      );

  bool get tieneUbicacion => latitud != null && longitud != null;
}

class Vacunacion {
  final String id;
  final Propietario propietario;
  final Mascota mascota;
  final String vacuna;
  final String observaciones;
  final String imagenUrl;
  final Ubicacion ubicacion;
  final String vacunadorId;
  final String vacunadorNombre;
  final String barrioNombre;
  final String barrioSector;
  final DateTime fechaRegistro;

  // ── Soporte offline (Sprint 3) ───────────────────────────────────────
  /// clienteId del registro local que originó esta vacunación. Null si
  /// el registro fue creado directamente en el backend (p. ej. ya
  /// existía antes del Sprint 3) y nunca pasó por Hive en este
  /// dispositivo.
  final String? clienteId;

  /// Estado de sincronización tal como lo ve la UI. Para registros que
  /// vienen del backend (ya consolidados) siempre es 'sincronizado'.
  final EstadoSync estadoSync;

  /// Ruta local de la imagen, válida solo mientras el registro no se
  /// haya sincronizado (estadoSync != sincronizado).
  final String? imagenLocalPath;

  Vacunacion({
    required this.id,
    required this.propietario,
    required this.mascota,
    required this.vacuna,
    required this.observaciones,
    required this.imagenUrl,
    required this.ubicacion,
    required this.vacunadorId,
    required this.vacunadorNombre,
    required this.barrioNombre,
    required this.barrioSector,
    required this.fechaRegistro,
    this.clienteId,
    this.estadoSync = EstadoSync.sincronizado,
    this.imagenLocalPath,
  });

  /// true mientras la imagen deba mostrarse desde el archivo local
  /// (todavía no existe en Cloudinary).
  bool get usarImagenLocal =>
      estadoSync != EstadoSync.sincronizado &&
      imagenLocalPath != null &&
      imagenLocalPath!.isNotEmpty;

  factory Vacunacion.fromJson(Map<String, dynamic> json) {
    final vacunador = json['vacunador'];
    final barrio    = json['barrio'];

    return Vacunacion(
      id:               json['_id'] ?? '',
      propietario:      Propietario.fromJson(json['propietario'] ?? {}),
      mascota:          Mascota.fromJson(json['mascota'] ?? {}),
      vacuna:           json['vacuna']        ?? '',
      observaciones:    json['observaciones'] ?? '',
      imagenUrl:        json['imagenUrl']     ?? '',
      ubicacion:        Ubicacion.fromJson(json['ubicacion'] ?? {}),
      vacunadorId:      vacunador is Map ? vacunador['_id'] ?? '' : '',
      vacunadorNombre:  vacunador is Map
          ? '${vacunador['nombre']} ${vacunador['apellido']}'
          : '',
      barrioNombre:     barrio is Map ? barrio['nombre'] ?? '' : '',
      barrioSector:     barrio is Map ? barrio['sector'] ?? '' : '',
      fechaRegistro:    DateTime.tryParse(json['fechaRegistro'] ?? '') ?? DateTime.now(),
      clienteId:        json['clienteId'],
      estadoSync:       EstadoSync.sincronizado,
    );
  }

  /// Construye una Vacunacion "de pantalla" a partir de un registro de
  /// Hive (offline). [barrioNombre]/[barrioSector] se resuelven aparte
  /// (el registro local solo guarda el barrioId) porque la pantalla de
  /// lista ya tiene el catálogo de barrios cargado.
  factory Vacunacion.fromLocal(
    VacunacionLocal l, {
    String vacunadorId    = '',
    String vacunadorNombre = 'Tú (pendiente de sincronizar)',
    String barrioNombre = '',
    String barrioSector = '',
  }) {
    return Vacunacion(
      id: l.mongoId ?? l.clienteId,
      propietario: Propietario(
        nombre: l.propietarioNombre,
        cedula: l.propietarioCedula,
        telefono: l.propietarioTelefono,
      ),
      mascota: Mascota(
        tipo: l.mascotaTipo,
        nombre: l.mascotaNombre,
        edad: l.mascotaEdad,
        sexo: l.mascotaSexo,
      ),
      vacuna: l.vacuna,
      observaciones: l.observaciones,
      imagenUrl: l.imagenUrlRemota ?? '',
      ubicacion: Ubicacion(latitud: l.latitud, longitud: l.longitud),
      vacunadorId:    vacunadorId,
      vacunadorNombre: vacunadorNombre,
      barrioNombre: barrioNombre,
      barrioSector: barrioSector,
      fechaRegistro: l.fechaRegistro,
      clienteId: l.clienteId,
      estadoSync: l.estadoEnum,
      imagenLocalPath: l.imagenLocalPath,
    );
  }
}

class Estadisticas {
  final int total;
  final int perros;
  final int gatos;
  final List<BarrioStat> porBarrio;
  final List<VacunadorStat> porVacunador;

  Estadisticas({
    required this.total,
    required this.perros,
    required this.gatos,
    required this.porBarrio,
    this.porVacunador = const [],
  });

  factory Estadisticas.fromJson(Map<String, dynamic> json) => Estadisticas(
        total:     json['total']  ?? 0,
        perros:    json['perros'] ?? 0,
        gatos:     json['gatos']  ?? 0,
        porBarrio: (json['porBarrio'] as List<dynamic>? ?? [])
            .map((b) => BarrioStat.fromJson(b))
            .toList(),
        porVacunador: (json['porVacunador'] as List<dynamic>? ?? [])
            .map((v) => VacunadorStat.fromJson(v))
            .toList(),
      );
}

class BarrioStat {
  final String barrio;
  final String sector;
  final int total;

  BarrioStat({required this.barrio, required this.sector, required this.total});

  factory BarrioStat.fromJson(Map<String, dynamic> json) => BarrioStat(
        barrio: json['_id']    ?? '',
        sector: json['sector'] ?? '',
        total:  json['total']  ?? 0,
      );
}

class VacunadorStat {
  final String id;
  final String nombre;
  final String apellido;
  final int total;
  final int perros;
  final int gatos;

  VacunadorStat({
    required this.id,
    required this.nombre,
    required this.apellido,
    required this.total,
    required this.perros,
    required this.gatos,
  });

  String get nombreCompleto => '$nombre $apellido'.trim();

  factory VacunadorStat.fromJson(Map<String, dynamic> json) => VacunadorStat(
        id:       json['_id']      ?? '',
        nombre:   json['nombre']   ?? '',
        apellido: json['apellido'] ?? '',
        total:    json['total']    ?? 0,
        perros:   json['perros']   ?? 0,
        gatos:    json['gatos']    ?? 0,
      );
}
