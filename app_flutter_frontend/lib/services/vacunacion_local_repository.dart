import 'package:hive_flutter/hive_flutter.dart';
import '../models/local/vacunacion_local.dart';

/// Acceso a la caja (box) de Hive donde viven las vacunaciones
/// registradas en el dispositivo, sin importar si ya se sincronizaron
/// o no. La clave de cada registro en la caja es su [clienteId].
class VacunacionLocalRepository {
  VacunacionLocalRepository._internal();
  static final VacunacionLocalRepository _instancia =
      VacunacionLocalRepository._internal();
  factory VacunacionLocalRepository() => _instancia;

  static const String boxName = 'vacunaciones_local';

  Box<VacunacionLocal> get _box => Hive.box<VacunacionLocal>(boxName);

  /// Debe llamarse una sola vez al iniciar la app, antes de runApp().
  static Future<void> inicializar() async {
    await Hive.initFlutter();
    Hive.registerAdapter(VacunacionLocalAdapter());
    await Hive.openBox<VacunacionLocal>(boxName);
  }

  Future<void> guardar(VacunacionLocal registro) async {
    await _box.put(registro.clienteId, registro);
  }

  VacunacionLocal? obtener(String clienteId) => _box.get(clienteId);

  Future<void> eliminarDeHive(String clienteId) async {
    await _box.delete(clienteId);
  }

  /// Todos los registros guardados localmente, sin filtrar.
  List<VacunacionLocal> obtenerTodos() => _box.values.toList();

  /// Registros que todavía no se han subido al backend, o que fallaron
  /// y deben reintentarse. Esta es la "cola" de sincronización.
  List<VacunacionLocal> obtenerPendientes() => _box.values
      .where((v) =>
          v.estadoEnum == EstadoSync.pendiente ||
          v.estadoEnum == EstadoSync.error ||
          v.estadoEnum == EstadoSync.pendienteEliminar)
      .toList();

  int get totalPendientes => obtenerPendientes().length;

  Future<void> marcarSincronizando(String clienteId) async {
    final r = obtener(clienteId);
    if (r == null) return;
    r.estadoEnum = EstadoSync.sincronizando;
    await r.save();
  }

  /// Marca el registro como sincronizado y persiste los datos que el
  /// backend devuelve en su respuesta: mongoId, URL de imagen en
  /// Cloudinary, y el barrio asignado (nombre y sector). Sin esto
  /// el barrio aparece como "pendiente de asignar" aunque ya esté
  /// guardado en la base de datos.
  Future<void> marcarSincronizado(
    String clienteId, {
    required String mongoId,
    required String imagenUrlRemota,
    String? barrioNombre,
    String? barrioSector,
  }) async {
    final r = obtener(clienteId);
    if (r == null) return;
    r.mongoId          = mongoId;
    r.imagenUrlRemota  = imagenUrlRemota;
    r.estadoEnum       = EstadoSync.sincronizado;
    r.ultimoError      = null;
    // Guardar el barrio que asignó el backend para que la lista
    // lo muestre correctamente sin necesidad de recargar del servidor.
    if (barrioNombre != null) r.barrioNombre = barrioNombre;
    if (barrioSector != null) r.barrioSector = barrioSector;
    await r.save();
  }

  Future<void> marcarError(String clienteId, String mensaje) async {
    final r = obtener(clienteId);
    if (r == null) return;
    r.estadoEnum  = EstadoSync.error;
    r.intentos   += 1;
    r.ultimoError = mensaje;
    await r.save();
  }
}