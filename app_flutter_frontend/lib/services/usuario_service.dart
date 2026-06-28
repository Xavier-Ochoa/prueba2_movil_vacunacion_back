import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../utils/constants.dart';

class UsuarioService {
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _authHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ── Crear coordinador de brigada (coordinador_campana) ─────────────────────
  Future<Map<String, dynamic>> crearCoordinadorBrigada({
    required String nombre,
    required String apellido,
    required String cedula,
    required String email,
    required String telefono,
    List<String>? barriosIds,
  }) async {
    try {
      final body = {
        'nombre':    nombre,
        'apellido':  apellido,
        'cedula':    cedula,
        'email':     email,
        'telefono':  telefono,
        if (barriosIds != null && barriosIds.isNotEmpty)
          'barriosIds': barriosIds,
      };
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}${AppConstants.usuariosEndpoint}/coordinador-brigada'),
        headers: await _authHeaders(),
        body: jsonEncode(body),
      );
      return {'statusCode': response.statusCode, 'data': jsonDecode(response.body)};
    } catch (e) {
      return {'statusCode': 500, 'data': {'msg': 'Error de red: $e'}};
    }
  }

  // ── Crear vacunador (coordinador_brigada) ─────────────────────────────────
  Future<Map<String, dynamic>> crearVacunador({
    required String nombre,
    required String apellido,
    required String cedula,
    required String email,
    required String telefono,
    required String barrioId,
  }) async {
    try {
      final body = {
        'nombre':   nombre,
        'apellido': apellido,
        'cedula':   cedula,
        'email':    email,
        'telefono': telefono,
        'barrioId': barrioId,
      };
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}${AppConstants.usuariosEndpoint}/vacunador'),
        headers: await _authHeaders(),
        body: jsonEncode(body),
      );
      return {'statusCode': response.statusCode, 'data': jsonDecode(response.body)};
    } catch (e) {
      return {'statusCode': 500, 'data': {'msg': 'Error de red: $e'}};
    }
  }

  // ── Listar usuarios creados por el autenticado ─────────────────────────────
  Future<Map<String, dynamic>> listarMisUsuarios() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}${AppConstants.usuariosEndpoint}/mis-usuarios'),
        headers: await _authHeaders(),
      );
      return {'statusCode': response.statusCode, 'data': jsonDecode(response.body)};
    } catch (e) {
      return {'statusCode': 500, 'data': {'msg': 'Error de red: $e'}};
    }
  }

  // ── Editar nombre / apellido / teléfono ───────────────────────────────────
  Future<Map<String, dynamic>> editarUsuario(
    String id, {
    String? nombre,
    String? apellido,
    String? telefono,
  }) async {
    try {
      final body = <String, String>{};
      if (nombre   != null) body['nombre']   = nombre;
      if (apellido != null) body['apellido'] = apellido;
      if (telefono != null) body['telefono'] = telefono;

      final response = await http.put(
        Uri.parse('${AppConstants.baseUrl}${AppConstants.usuariosEndpoint}/$id'),
        headers: await _authHeaders(),
        body: jsonEncode(body),
      );
      return {'statusCode': response.statusCode, 'data': jsonDecode(response.body)};
    } catch (e) {
      return {'statusCode': 500, 'data': {'msg': 'Error de red: $e'}};
    }
  }

  // ── Actualizar barrios de un coordinador de brigada ──────────────────────────
  Future<Map<String, dynamic>> actualizarBarriosCoordinador(
    String id,
    List<String> barriosIds,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('${AppConstants.baseUrl}${AppConstants.usuariosEndpoint}/$id/barrios'),
        headers: await _authHeaders(),
        body: jsonEncode({'barriosIds': barriosIds}),
      );
      return {'statusCode': response.statusCode, 'data': jsonDecode(response.body)};
    } catch (e) {
      return {'statusCode': 500, 'data': {'msg': 'Error de red: $e'}};
    }
  }


  Future<Map<String, dynamic>> reasignarBarrioVacunador(
    String id,
    String barrioId,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('${AppConstants.baseUrl}${AppConstants.usuariosEndpoint}/$id/reasignar-barrio'),
        headers: await _authHeaders(),
        body: jsonEncode({'barrioId': barrioId}),
      );
      return {'statusCode': response.statusCode, 'data': jsonDecode(response.body)};
    } catch (e) {
      return {'statusCode': 500, 'data': {'msg': 'Error de red: $e'}};
    }
  }

  // ── Desactivar usuario ────────────────────────────────────────────────────
  Future<Map<String, dynamic>> desactivarUsuario(String id) async {
    try {
      final response = await http.patch(
        Uri.parse('${AppConstants.baseUrl}${AppConstants.usuariosEndpoint}/$id/desactivar'),
        headers: await _authHeaders(),
      );
      return {'statusCode': response.statusCode, 'data': jsonDecode(response.body)};
    } catch (e) {
      return {'statusCode': 500, 'data': {'msg': 'Error de red: $e'}};
    }
  }

  // ── Activar usuario ───────────────────────────────────────────────────────
  Future<Map<String, dynamic>> activarUsuario(String id) async {
    try {
      final response = await http.patch(
        Uri.parse('${AppConstants.baseUrl}${AppConstants.usuariosEndpoint}/$id/activar'),
        headers: await _authHeaders(),
      );
      return {'statusCode': response.statusCode, 'data': jsonDecode(response.body)};
    } catch (e) {
      return {'statusCode': 500, 'data': {'msg': 'Error de red: $e'}};
    }
  }
}
