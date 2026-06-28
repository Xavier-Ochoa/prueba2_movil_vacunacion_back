import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'connectivity_service.dart';
import 'vacunacion_local_repository.dart';
import 'vacunacion_service.dart';
import '../models/local/vacunacion_local.dart';

/// Orquesta la sincronización MANUAL de la cola local hacia el backend.
///
/// A diferencia del comportamiento anterior, este motor ya NO dispara
/// sincronizaciones automáticas cuando se recupera la conectividad.
/// El usuario decide cuándo sincronizar mediante el botón en la lista
/// de vacunaciones. Esto aplica únicamente a los registros creados en
/// modo offline; los registros de edición/eliminación sí se sincronizan
/// de forma automática (ver [_debenSincronizarseAutomaticamente]).
class SyncEngine extends ChangeNotifier {
  SyncEngine._internal();
  static final SyncEngine _instancia = SyncEngine._internal();
  factory SyncEngine() => _instancia;

  final ConnectivityService _connectivity = ConnectivityService();
  final VacunacionLocalRepository _repo = VacunacionLocalRepository();
  final VacunacionService _service = VacunacionService();

  bool _sincronizando = false;
  String _estadoTexto = '';

  bool   get sincronizando   => _sincronizando;
  String get estadoTexto     => _estadoTexto;
  int    get totalPendientes => _repo.totalPendientes;

  /// Sincroniza todos los registros pendientes.
  /// Es el único punto de entrada: se llama desde el botón manual de la UI
  /// y también desde [editarVacunacion] / [eliminarVacunacion] del provider,
  /// que siguen usando el flujo offline-first original.
  Future<void> sincronizarTodo() async {
    if (_sincronizando) return;

    final pendientes = _repo.obtenerPendientes();
    if (pendientes.isEmpty) return;

    final hayInternet = await _connectivity.tieneConexion();
    if (!hayInternet) return;

    _sincronizando = true;
    notifyListeners();

    for (final registro in pendientes) {
      if (!await _connectivity.tieneConexion()) break;

      if (registro.estadoEnum == EstadoSync.pendienteEliminar) {
        await _sincronizarEliminacion(registro);
      } else {
        await _sincronizarRegistro(registro);
      }
      notifyListeners();
    }

    _sincronizando = false;
    _estadoTexto = '';
    notifyListeners();
  }

  Future<void> _sincronizarRegistro(VacunacionLocal registro) async {
    _estadoTexto = 'Subiendo ${registro.mascotaNombre}...';
    notifyListeners();

    await _repo.marcarSincronizando(registro.clienteId);

    try {
      final esEdicionDeRegistroYaExistente = registro.mongoId != null;
      final archivoImagen = File(registro.imagenLocalPath);
      final archivoImagenExiste = await archivoImagen.exists();

      if (!archivoImagenExiste) {
        if (esEdicionDeRegistroYaExistente && registro.imagenUrlRemota != null) {
          final resultado = await _service.editarVacunacion(
            id:                  registro.mongoId!,
            propietarioNombre:   registro.propietarioNombre,
            propietarioCedula:   registro.propietarioCedula,
            propietarioTelefono: registro.propietarioTelefono,
            mascotaTipo:         registro.mascotaTipo,
            mascotaNombre:       registro.mascotaNombre,
            mascotaEdad:         registro.mascotaEdad,
            mascotaSexo:         registro.mascotaSexo,
            vacuna:              registro.vacuna,
            observaciones:       registro.observaciones,
            imagen:              null,
            latitud:             registro.latitud,
            longitud:            registro.longitud,
          );
          await _procesarResultadoSync(registro, resultado);
        } else {
          await _repo.marcarError(
            registro.clienteId,
            'La foto ya no está disponible en el dispositivo',
          );
        }
        return;
      }

      final Map<String, dynamic> resultado = esEdicionDeRegistroYaExistente
          ? await _service.editarVacunacion(
              id:                  registro.mongoId!,
              propietarioNombre:   registro.propietarioNombre,
              propietarioCedula:   registro.propietarioCedula,
              propietarioTelefono: registro.propietarioTelefono,
              mascotaTipo:         registro.mascotaTipo,
              mascotaNombre:       registro.mascotaNombre,
              mascotaEdad:         registro.mascotaEdad,
              mascotaSexo:         registro.mascotaSexo,
              vacuna:              registro.vacuna,
              observaciones:       registro.observaciones,
              imagen:              archivoImagen,
              latitud:             registro.latitud,
              longitud:            registro.longitud,
            )
          : await _service.crearVacunacion(
              propietarioNombre:   registro.propietarioNombre,
              propietarioCedula:   registro.propietarioCedula,
              propietarioTelefono: registro.propietarioTelefono,
              mascotaTipo:         registro.mascotaTipo,
              mascotaNombre:       registro.mascotaNombre,
              mascotaEdad:         registro.mascotaEdad,
              mascotaSexo:         registro.mascotaSexo,
              vacuna:              registro.vacuna,
              observaciones:       registro.observaciones,
              imagen:              archivoImagen,
              latitud:             registro.latitud,
              longitud:            registro.longitud,
              barrioId:            registro.barrioId,
              clienteId:           registro.clienteId,
              fechaRegistro:       registro.fechaRegistro,
            );

      await _procesarResultadoSync(registro, resultado, archivoLocal: archivoImagen);
    } catch (e) {
      await _repo.marcarError(registro.clienteId, e.toString());
    }
  }

  Future<void> _procesarResultadoSync(
    VacunacionLocal registro,
    Map<String, dynamic> resultado, {
    File? archivoLocal,
  }) async {
    final statusCode = resultado['statusCode'] as int;
    final ok = statusCode == 200 || statusCode == 201;

    if (ok) {
      final data = resultado['data'] as Map<String, dynamic>;
      final vacunacionJson = data['vacunacion'] as Map<String, dynamic>;
      final mongoId = vacunacionJson['_id'] as String;
      final imagenUrl = vacunacionJson['imagenUrl'] as String? ?? '';

      // El backend populatea el campo "barrio" con { nombre, sector }.
      // Lo extraemos aquí para persistirlo en Hive y que la lista
      // muestre el barrio correcto sin tener que recargar del servidor.
      final barrioJson = vacunacionJson['barrio'];
      final barrioNombre = barrioJson is Map
          ? barrioJson['nombre'] as String? ?? ''
          : null;
      final barrioSector = barrioJson is Map
          ? barrioJson['sector'] as String? ?? ''
          : null;

      await _repo.marcarSincronizado(
        registro.clienteId,
        mongoId:         mongoId,
        imagenUrlRemota: imagenUrl,
        barrioNombre:    barrioNombre,
        barrioSector:    barrioSector,
      );

      if (archivoLocal != null) {
        try {
          if (await archivoLocal.exists()) {
            await archivoLocal.delete();
          }
        } catch (_) {}
      }
    } else {
      final msg = (resultado['data']?['msg'] as String?) ??
          'Error del servidor ($statusCode)';
      await _repo.marcarError(registro.clienteId, msg);
    }
  }

  Future<void> _sincronizarEliminacion(VacunacionLocal registro) async {
    if (registro.mongoId == null) {
      await _repo.eliminarDeHive(registro.clienteId);
      return;
    }

    _estadoTexto = 'Eliminando ${registro.mascotaNombre}...';
    notifyListeners();

    try {
      final resultado = await _service.eliminarVacunacion(registro.mongoId!);
      final statusCode = resultado['statusCode'] as int;
      if (statusCode == 200) {
        await _repo.eliminarDeHive(registro.clienteId);
      } else {
        final msg = (resultado['data']?['msg'] as String?) ??
            'Error del servidor ($statusCode)';
        await _repo.marcarError(registro.clienteId, msg);
      }
    } catch (e) {
      await _repo.marcarError(registro.clienteId, e.toString());
    }
  }
}