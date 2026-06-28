import 'package:flutter/foundation.dart';
import '../models/barrio_model.dart';
import '../services/barrio_service.dart';

/// Provider para la pantalla de gestión de barrios (CRUD) del
/// coordinador de campaña. Independiente de `UsuarioProvider.barrios`
/// (que usa `BarrioResumen`, un modelo más liviano para selectores).
class BarrioProvider with ChangeNotifier {
  final BarrioService _barrioService = BarrioService();

  List<Barrio> _barrios   = [];
  bool         _isLoading = false;
  String?      _error;

  List<Barrio> get barrios   => _barrios;
  bool         get isLoading => _isLoading;
  String?      get error     => _error;

  Future<void> cargarBarrios() async {
    _isLoading = true;
    _error     = null;
    notifyListeners();

    try {
      final result = await _barrioService.listarBarrios();
      if (result['statusCode'] == 200) {
        final data  = result['data'];
        final lista = data['data'] as List? ?? [];
        _barrios = lista
            .map((b) => Barrio.fromJson(b as Map<String, dynamic>))
            .toList()
          ..sort((a, b) => a.nombre.compareTo(b.nombre));
      } else {
        _error = result['data']['msg'] ?? 'Error al cargar barrios';
      }
    } catch (e) {
      _error = 'Error inesperado: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>> crearBarrio({
    required String nombre,
    required String sector,
  }) async {
    final result = await _barrioService.crearBarrio(nombre: nombre, sector: sector);
    if (result['statusCode'] == 201) {
      await cargarBarrios();
    }
    return result;
  }

  Future<Map<String, dynamic>> actualizarBarrio({
    required String id,
    String? nombre,
    String? sector,
    String? estado,
  }) async {
    final result = await _barrioService.actualizarBarrio(
      id: id,
      nombre: nombre,
      sector: sector,
      estado: estado,
    );
    if (result['statusCode'] == 200) {
      await cargarBarrios();
    }
    return result;
  }

  Future<Map<String, dynamic>> eliminarBarrio(String id) async {
    final result = await _barrioService.eliminarBarrio(id);
    if (result['statusCode'] == 200) {
      await cargarBarrios();
    }
    return result;
  }
}
