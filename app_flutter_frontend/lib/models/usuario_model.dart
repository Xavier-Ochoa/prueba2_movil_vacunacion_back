class BarrioResumen {
  final String id;
  final String nombre;
  final String sector;

  BarrioResumen({
    required this.id,
    required this.nombre,
    required this.sector,
  });

  factory BarrioResumen.fromJson(Map<String, dynamic> json) {
    return BarrioResumen(
      id:     json['_id']    ?? json['id']    ?? '',
      nombre: json['nombre'] ?? '',
      sector: json['sector'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    '_id':    id,
    'nombre': nombre,
    'sector': sector,
  };
}

class Usuario {
  final String id;
  final String nombre;
  final String apellido;
  final String cedula;
  final String email;
  final String telefono;
  final String rol;
  final String estado;
  final List<BarrioResumen> barriosAsignados;

  Usuario({
    required this.id,
    required this.nombre,
    required this.apellido,
    required this.cedula,
    required this.email,
    required this.telefono,
    required this.rol,
    required this.estado,
    required this.barriosAsignados,
  });

  String get nombreCompleto => '$nombre $apellido'.trim();

  bool get activo => estado == 'activo';

  factory Usuario.fromJson(Map<String, dynamic> json) {
    final barriosRaw = json['barriosAsignados'];
    final barrios = <BarrioResumen>[];
    if (barriosRaw is List) {
      for (final b in barriosRaw) {
        if (b is Map<String, dynamic>) {
          barrios.add(BarrioResumen.fromJson(b));
        }
      }
    }

    return Usuario(
      id:               json['_id']      ?? json['id']    ?? '',
      nombre:           json['nombre']   ?? '',
      apellido:         json['apellido'] ?? '',
      cedula:           json['cedula']   ?? '',
      email:            json['email']    ?? '',
      telefono:         json['telefono'] ?? '',
      rol:              json['rol']      ?? '',
      estado:           json['estado']   ?? 'activo',
      barriosAsignados: barrios,
    );
  }
}
