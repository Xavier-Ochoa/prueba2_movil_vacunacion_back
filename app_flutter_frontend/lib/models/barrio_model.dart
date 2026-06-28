/// Modelo completo de Barrio, usado en la pantalla de gestión
/// (crear / editar / eliminar / visualizar) del coordinador de campaña.
///
/// Nota: para usos más simples (selectores de barrio en otras pantallas)
/// se sigue usando `BarrioResumen` (en usuario_model.dart), que solo
/// necesita id, nombre y sector. Este modelo agrega estado y el
/// coordinador de brigada asignado, que sí se muestran en esta pantalla.
class Barrio {
  final String id;
  final String nombre;
  final String sector;
  final String estado; // 'activo' | 'inactivo'
  final String? coordinadorNombre; // null si no tiene coordinador asignado

  Barrio({
    required this.id,
    required this.nombre,
    required this.sector,
    required this.estado,
    this.coordinadorNombre,
  });

  bool get activo => estado == 'activo';
  bool get tieneCoordinador => coordinadorNombre != null;

  factory Barrio.fromJson(Map<String, dynamic> json) {
    String? coordNombre;
    final coord = json['coordinadorAsignado'];
    if (coord is Map<String, dynamic>) {
      final nombre   = coord['nombre']   ?? '';
      final apellido = coord['apellido'] ?? '';
      final completo = '$nombre $apellido'.trim();
      coordNombre = completo.isEmpty ? null : completo;
    }

    return Barrio(
      id:                json['_id']    ?? json['id']    ?? '',
      nombre:            json['nombre'] ?? '',
      sector:            json['sector'] ?? '',
      estado:            json['estado'] ?? 'activo',
      coordinadorNombre: coordNombre,
    );
  }

  /// Lista fija de sectores válidos (debe coincidir con el enum del backend).
  static const List<String> sectoresValidos = [
    'Norte',
    'Centro Norte',
    'Centro',
    'Sur',
    'Valles',
  ];
}
