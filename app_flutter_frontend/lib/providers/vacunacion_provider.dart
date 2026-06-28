import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/vacunacion_model.dart';
import '../models/local/vacunacion_local.dart';
import '../services/vacunacion_service.dart';
import '../services/vacunacion_local_repository.dart';
import '../services/sync_engine.dart';
import '../services/connectivity_service.dart';

class VacunacionProvider with ChangeNotifier {
  final VacunacionService _service = VacunacionService();
  final VacunacionLocalRepository _localRepo = VacunacionLocalRepository();
  final SyncEngine _syncEngine = SyncEngine();
  final ConnectivityService _connectivity = ConnectivityService();
  final _uuid = const Uuid();

  List<Vacunacion> _vacunaciones = [];
  Estadisticas?    _estadisticas;
  bool             _isLoading    = false;
  String           _error        = '';

  List<Vacunacion> get vacunaciones  => _vacunaciones;
  Estadisticas?    get estadisticas  => _estadisticas;
  bool             get isLoading     => _isLoading;
  String           get error         => _error;

  bool   get sincronizando    => _syncEngine.sincronizando;
  String get estadoSync       => _syncEngine.estadoTexto;
  int    get totalPendientes  => _localRepo.totalPendientes;

  VacunacionProvider() {
    _syncEngine.addListener(_recargarSoloLocal);
  }

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  // ── CARGAR LISTA (offline-first) ─────────────────────────────────────────────
  Future<void> cargarVacunaciones() async {
    _setLoading(true);
    _error = '';
    try {
      final remotas = await _service.listarVacunaciones();
      _combinarYNotificar(remotas);

      if (remotas == null) {
        _error = 'Sin conexión: mostrando solo lo guardado en este dispositivo';
      }
    } finally {
      _setLoading(false);
    }
  }

  void _recargarSoloLocal() {
    final remotasActuales = _vacunaciones
        .where((v) => v.estadoSync == EstadoSync.sincronizado && v.clienteId == null)
        .toList();
    _combinarYNotificar(remotasActuales, esRecargaLocal: true);
  }

  void _combinarYNotificar(List<Vacunacion>? remotas, {bool esRecargaLocal = false}) {
    final locales = _localRepo.obtenerTodos();

    final localesSincronizados = locales
        .where((l) => l.estadoEnum == EstadoSync.sincronizado)
        .map((l) => Vacunacion.fromLocal(
              l,
              barrioNombre: l.barrioNombre ?? '',
              barrioSector: l.barrioSector ?? '',
            ))
        .toList();

    final clienteIdsYaMostradosLocal = locales
        .where((l) => l.estadoEnum == EstadoSync.sincronizado ||
                      l.estadoEnum == EstadoSync.sincronizando)
        .map((l) => l.clienteId)
        .toSet();

    final mongoIdsPendientesDeEliminar = locales
        .where((l) => l.estadoEnum == EstadoSync.pendienteEliminar)
        .map((l) => l.mongoId)
        .whereType<String>()
        .toSet();

    final pendientesParaMostrar = locales
        .where((l) => l.estadoEnum != EstadoSync.sincronizado &&
                      l.estadoEnum != EstadoSync.pendienteEliminar)
        .map((l) => Vacunacion.fromLocal(
              l,
              barrioNombre: l.barrioNombre ?? '',
              barrioSector: l.barrioSector ?? '',
            ))
        .toList();

    final listaRemota = (remotas ?? (esRecargaLocal ? _vacunaciones : <Vacunacion>[]))
        .where((v) =>
            !clienteIdsYaMostradosLocal.contains(v.clienteId) &&
            !mongoIdsPendientesDeEliminar.contains(v.id))
        .toList();

    _vacunaciones = [...pendientesParaMostrar, ...localesSincronizados, ...listaRemota]
      ..sort((a, b) => b.fechaRegistro.compareTo(a.fechaRegistro));

    notifyListeners();
  }

  /// Sincronización MANUAL: el usuario presiona el botón explícitamente.
  Future<void> intentarSincronizarAhora() => _syncEngine.sincronizarTodo();

  // ── CARGAR ESTADÍSTICAS ───────────────────────────────────────────────────────
  Future<void> cargarEstadisticas() async {
    try {
      final stats = await _service.obtenerEstadisticas();
      if (stats != null) {
        _estadisticas = stats;
      } else {
        _error = 'Sin conexión: las estadísticas pueden no incluir lo registrado hoy';
      }
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // ── CREAR ONLINE (directo al backend) ────────────────────────────────────────
  /// Registra la vacunación directamente en el servidor.
  /// Lanza [SinConexionException] si no hay internet al momento de llamar.
  /// Lanza [ErrorBackendException] si el servidor responde con error.
  Future<void> crearVacunacionOnline({
    required String propietarioNombre,
    required String propietarioCedula,
    required String propietarioTelefono,
    required String mascotaTipo,
    required String mascotaNombre,
    required int    mascotaEdad,
    required String mascotaSexo,
    required String vacuna,
    String observaciones = '',
    required File imagen,
    double? latitud,
    double? longitud,
    String? barrioId,
    String? barrioNombre,
    String? barrioSector,
  }) async {
    // Validar conexión ANTES de intentar subir.
    final hayInternet = await _connectivity.tieneConexion();
    if (!hayInternet) {
      throw SinConexionException(
        'No puedes registrar en modo online porque no hay conexión a internet.',
      );
    }

    _setLoading(true);
    try {
      final clienteId = _uuid.v4();
      final resultado = await _service.crearVacunacion(
        propietarioNombre:   propietarioNombre,
        propietarioCedula:   propietarioCedula,
        propietarioTelefono: propietarioTelefono,
        mascotaTipo:         mascotaTipo,
        mascotaNombre:       mascotaNombre,
        mascotaEdad:         mascotaEdad,
        mascotaSexo:         mascotaSexo,
        vacuna:              vacuna,
        observaciones:       observaciones,
        imagen:              imagen,
        latitud:             latitud,
        longitud:            longitud,
        barrioId:            barrioId,
        clienteId:           clienteId,
        fechaRegistro:       DateTime.now(),
      );

      final statusCode = resultado['statusCode'] as int;
      if (statusCode != 200 && statusCode != 201) {
        final msg = (resultado['data']?['msg'] as String?) ??
            'Error del servidor ($statusCode)';
        throw ErrorBackendException(msg);
      }

      // Éxito: refrescamos la lista para que el nuevo registro aparezca.
      await cargarVacunaciones();
    } finally {
      _setLoading(false);
    }
  }

  // ── CREAR OFFLINE (solo local, sincronización manual) ─────────────────────────
  /// Guarda el registro en Hive con estado [pendiente].
  /// NO dispara sincronización automática: el usuario sincroniza
  /// manualmente con el botón en la lista de vacunaciones.
  Future<void> crearVacunacionOffline({
    required String propietarioNombre,
    required String propietarioCedula,
    required String propietarioTelefono,
    required String mascotaTipo,
    required String mascotaNombre,
    required int    mascotaEdad,
    required String mascotaSexo,
    required String vacuna,
    String observaciones = '',
    required File imagen,
    double? latitud,
    double? longitud,
    String? barrioId,
    String? barrioNombre,
    String? barrioSector,
  }) async {
    final clienteId = _uuid.v4();

    final rutaPersistida = await _persistirImagenLocal(imagen, clienteId);

    final registro = VacunacionLocal(
      clienteId:           clienteId,
      propietarioNombre:   propietarioNombre,
      propietarioCedula:   propietarioCedula,
      propietarioTelefono: propietarioTelefono,
      mascotaTipo:         mascotaTipo,
      mascotaNombre:       mascotaNombre,
      mascotaEdad:         mascotaEdad,
      mascotaSexo:         mascotaSexo,
      vacuna:              vacuna,
      observaciones:       observaciones,
      imagenLocalPath:     rutaPersistida,
      latitud:             latitud,
      longitud:            longitud,
      barrioId:            barrioId,
      barrioNombre:        barrioNombre,
      barrioSector:        barrioSector,
      fechaRegistro:       DateTime.now(),
      estado:              EstadoSync.pendiente.name,
    );

    await _localRepo.guardar(registro);
    _recargarSoloLocal();
    // NO se llama a _syncEngine.sincronizarTodo() — el usuario decide cuándo.
  }

  // ── MÉTODO LEGADO (mantiene compatibilidad con edición y eliminación) ─────────
  /// Usado internamente por [editarVacunacion] y [eliminarVacunacion].
  /// Sigue con el comportamiento offline-first original.
  Future<void> crearVacunacion({
    required String propietarioNombre,
    required String propietarioCedula,
    required String propietarioTelefono,
    required String mascotaTipo,
    required String mascotaNombre,
    required int    mascotaEdad,
    required String mascotaSexo,
    required String vacuna,
    String observaciones = '',
    required File imagen,
    double? latitud,
    double? longitud,
    String? barrioId,
    String? barrioNombre,
    String? barrioSector,
  }) async {
    final clienteId = _uuid.v4();
    final rutaPersistida = await _persistirImagenLocal(imagen, clienteId);

    final registro = VacunacionLocal(
      clienteId:           clienteId,
      propietarioNombre:   propietarioNombre,
      propietarioCedula:   propietarioCedula,
      propietarioTelefono: propietarioTelefono,
      mascotaTipo:         mascotaTipo,
      mascotaNombre:       mascotaNombre,
      mascotaEdad:         mascotaEdad,
      mascotaSexo:         mascotaSexo,
      vacuna:              vacuna,
      observaciones:       observaciones,
      imagenLocalPath:     rutaPersistida,
      latitud:             latitud,
      longitud:            longitud,
      barrioId:            barrioId,
      barrioNombre:        barrioNombre,
      barrioSector:        barrioSector,
      fechaRegistro:       DateTime.now(),
      estado:              EstadoSync.pendiente.name,
    );

    await _localRepo.guardar(registro);
    _recargarSoloLocal();
    unawaited(_syncEngine.sincronizarTodo());
  }

  Future<String> _persistirImagenLocal(File original, String clienteId) async {
    final carpeta = await _carpetaImagenesLocales();
    final extension = original.path.split('.').last;
    final destino = '${carpeta.path}/vac_$clienteId.$extension';
    final copia = await original.copy(destino);
    return copia.path;
  }

  Future<Directory> _carpetaImagenesLocales() async {
    final dir = await getApplicationDocumentsDirectory();
    final carpeta = Directory('${dir.path}/vacunaciones_offline');
    if (!await carpeta.exists()) {
      await carpeta.create(recursive: true);
    }
    return carpeta;
  }

  // ── EDITAR ────────────────────────────────────────────────────────────────────
  Future<void> editarVacunacion({
    required String clienteId,
    String? propietarioNombre,
    String? propietarioCedula,
    String? propietarioTelefono,
    String? mascotaTipo,
    String? mascotaNombre,
    int?    mascotaEdad,
    String? mascotaSexo,
    String? vacuna,
    String? observaciones,
    File?   imagen,
    double? latitud,
    double? longitud,
    Vacunacion? original,
  }) async {
    var registro = _localRepo.obtener(clienteId);

    if (registro == null) {
      if (original == null) return;
      final rutaImagen = imagen != null
          ? await _persistirImagenLocal(imagen, clienteId)
          : '';
      registro = VacunacionLocal(
        clienteId:           clienteId,
        mongoId:             original.id,
        propietarioNombre:   original.propietario.nombre,
        propietarioCedula:   original.propietario.cedula,
        propietarioTelefono: original.propietario.telefono,
        mascotaTipo:         original.mascota.tipo,
        mascotaNombre:       original.mascota.nombre,
        mascotaEdad:         original.mascota.edad,
        mascotaSexo:         original.mascota.sexo,
        vacuna:              original.vacuna,
        observaciones:       original.observaciones,
        imagenLocalPath:     rutaImagen,
        imagenUrlRemota:     original.imagenUrl,
        latitud:             original.ubicacion.latitud,
        longitud:            original.ubicacion.longitud,
        barrioNombre:        original.barrioNombre,
        barrioSector:        original.barrioSector,
        fechaRegistro:       original.fechaRegistro,
        estado:              EstadoSync.sincronizado.name,
      );
      await _localRepo.guardar(registro);
      imagen = null;
    }

    if (propietarioNombre   != null) registro.propietarioNombre   = propietarioNombre;
    if (propietarioCedula   != null) registro.propietarioCedula   = propietarioCedula;
    if (propietarioTelefono != null) registro.propietarioTelefono = propietarioTelefono;
    if (mascotaTipo         != null) registro.mascotaTipo         = mascotaTipo;
    if (mascotaNombre       != null) registro.mascotaNombre       = mascotaNombre;
    if (mascotaEdad         != null) registro.mascotaEdad         = mascotaEdad;
    if (mascotaSexo         != null) registro.mascotaSexo         = mascotaSexo;
    if (vacuna              != null) registro.vacuna              = vacuna;
    if (observaciones       != null) registro.observaciones       = observaciones;
    if (latitud             != null) registro.latitud             = latitud;
    if (longitud            != null) registro.longitud            = longitud;

    if (imagen != null) {
      final nuevaRuta = await _persistirImagenLocal(imagen, clienteId);
      final anterior = File(registro.imagenLocalPath);
      if (await anterior.exists()) {
        try { await anterior.delete(); } catch (_) {}
      }
      registro.imagenLocalPath = nuevaRuta;
    }

    registro.estadoEnum = EstadoSync.pendiente;
    await registro.save();

    _recargarSoloLocal();
    unawaited(_syncEngine.sincronizarTodo());
  }

  // ── ELIMINAR ──────────────────────────────────────────────────────────────────
  Future<void> eliminarVacunacion(String idOClienteId) async {
    var registro = _localRepo.obtener(idOClienteId);

    if (registro == null) {
      registro = VacunacionLocal(
        clienteId:           idOClienteId,
        mongoId:             idOClienteId,
        propietarioNombre:   '',
        propietarioCedula:   '',
        propietarioTelefono: '',
        mascotaTipo:         'perro',
        mascotaNombre:       '',
        mascotaEdad:         0,
        mascotaSexo:         'macho',
        vacuna:              '',
        observaciones:       '',
        imagenLocalPath:     '',
        fechaRegistro:       DateTime.now(),
        estado:              EstadoSync.pendienteEliminar.name,
      );
      await _localRepo.guardar(registro);
      _recargarSoloLocal();
      unawaited(_syncEngine.sincronizarTodo());
      return;
    }

    if (registro.mongoId == null) {
      await _localRepo.eliminarDeHive(idOClienteId);
      final archivo = File(registro.imagenLocalPath);
      if (await archivo.exists()) {
        try { await archivo.delete(); } catch (_) {}
      }
    } else {
      registro.estadoEnum = EstadoSync.pendienteEliminar;
      await registro.save();
    }

    _recargarSoloLocal();
    unawaited(_syncEngine.sincronizarTodo());
  }
}

// ── Excepciones personalizadas ────────────────────────────────────────────────

class SinConexionException implements Exception {
  final String mensaje;
  const SinConexionException(this.mensaje);
  @override
  String toString() => mensaje;
}

class ErrorBackendException implements Exception {
  final String mensaje;
  const ErrorBackendException(this.mensaje);
  @override
  String toString() => mensaje;
}