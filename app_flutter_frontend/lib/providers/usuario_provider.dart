import 'package:flutter/foundation.dart';
import '../models/usuario_model.dart';
import '../services/usuario_service.dart';
import '../services/barrio_service.dart';

class UsuarioProvider with ChangeNotifier {
  final UsuarioService _usuarioService = UsuarioService();
  final BarrioService  _barrioService  = BarrioService();

  List<Usuario>       _usuarios        = [];
  List<BarrioResumen> _barrios         = [];
  bool                _isLoading       = false;
  String?             _error;

  List<Usuario>       get usuarios  => _usuarios;
  List<BarrioResumen> get barrios   => _barrios;
  bool                get isLoading => _isLoading;
  String?             get error     => _error;

  // ── Cargar usuarios del equipo ────────────────────────────────────────────
  Future<void> cargarMisUsuarios() async {
    _isLoading = true;
    _error     = null;
    notifyListeners();

    try {
      final result = await _usuarioService.listarMisUsuarios();
      if (result['statusCode'] == 200) {
        final data = result['data'];
        final lista = data['data'] as List? ?? [];
        _usuarios = lista
            .map((u) => Usuario.fromJson(u as Map<String, dynamic>))
            .toList();
      } else {
        _error = result['data']['msg'] ?? 'Error al cargar usuarios';
      }
    } catch (e) {
      _error = 'Error inesperado: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  // ── Cargar barrios disponibles ────────────────────────────────────────────
  Future<void> cargarBarrios() async {
    try {
      final result = await _barrioService.listarBarrios();
      if (result['statusCode'] == 200) {
        final data = result['data'];
        final lista = data['data'] as List? ?? [];
        _barrios = lista
            .map((b) => BarrioResumen.fromJson(b as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      // No es crítico si falla; mostramos lista vacía
    }
    notifyListeners();
  }

  // ── Crear coordinador de brigada ──────────────────────────────────────────
  Future<Map<String, dynamic>> crearCoordinadorBrigada({
    required String nombre,
    required String apellido,
    required String cedula,
    required String email,
    required String telefono,
    List<String>?   barriosIds,
  }) async {
    final result = await _usuarioService.crearCoordinadorBrigada(
      nombre:     nombre,
      apellido:   apellido,
      cedula:     cedula,
      email:      email,
      telefono:   telefono,
      barriosIds: barriosIds,
    );
    if (result['statusCode'] == 201) {
      await cargarMisUsuarios();
    }
    return result;
  }

  // ── Crear vacunador ───────────────────────────────────────────────────────
  Future<Map<String, dynamic>> crearVacunador({
    required String nombre,
    required String apellido,
    required String cedula,
    required String email,
    required String telefono,
    required String barrioId,
  }) async {
    final result = await _usuarioService.crearVacunador(
      nombre:   nombre,
      apellido: apellido,
      cedula:   cedula,
      email:    email,
      telefono: telefono,
      barrioId: barrioId,
    );
    if (result['statusCode'] == 201) {
      await cargarMisUsuarios();
    }
    return result;
  }

  // ── Editar usuario ────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> editarUsuario(
    String id, {
    String? nombre,
    String? apellido,
    String? telefono,
  }) async {
    final result = await _usuarioService.editarUsuario(
      id,
      nombre:   nombre,
      apellido: apellido,
      telefono: telefono,
    );
    if (result['statusCode'] == 200) {
      await cargarMisUsuarios();
    }
    return result;
  }

  // ── Actualizar barrios de coordinador de brigada ─────────────────────────────
  Future<Map<String, dynamic>> actualizarBarriosCoordinador(
    String id,
    List<String> barriosIds,
  ) async {
    final result = await _usuarioService.actualizarBarriosCoordinador(id, barriosIds);
    if (result['statusCode'] == 200) {
      await cargarMisUsuarios();
    }
    return result;
  }


  Future<Map<String, dynamic>> reasignarBarrio(String id, String barrioId) async {
    final result = await _usuarioService.reasignarBarrioVacunador(id, barrioId);
    if (result['statusCode'] == 200) {
      await cargarMisUsuarios();
    }
    return result;
  }

  // ── Desactivar usuario ────────────────────────────────────────────────────
  Future<Map<String, dynamic>> desactivarUsuario(String id) async {
    final result = await _usuarioService.desactivarUsuario(id);
    if (result['statusCode'] == 200) {
      await cargarMisUsuarios();
    }
    return result;
  }

  Future<Map<String, dynamic>> activarUsuario(String id) async {
    final result = await _usuarioService.activarUsuario(id);
    if (result['statusCode'] == 200) {
      await cargarMisUsuarios();
    }
    return result;
  }
}
