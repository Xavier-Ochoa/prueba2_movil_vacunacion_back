import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../utils/constants.dart';

class BarrioService {
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _authHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Devuelve todos los barrios disponibles.
  /// Cada elemento tiene: { _id, nombre, sector, estado, coordinadorAsignado? }
  Future<Map<String, dynamic>> listarBarrios() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}${AppConstants.barriosEndpoint}'),
        headers: await _authHeaders(),
      );
      return {
        'statusCode': response.statusCode,
        'data': jsonDecode(response.body),
      };
    } catch (e) {
      return {'statusCode': 500, 'data': {'msg': 'Error de red: $e'}};
    }
  }

  // ── Crear barrio (solo coordinador_campana) ─────────────────────────────────
  Future<Map<String, dynamic>> crearBarrio({
    required String nombre,
    required String sector,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}${AppConstants.barriosEndpoint}'),
        headers: await _authHeaders(),
        body: jsonEncode({'nombre': nombre, 'sector': sector}),
      );
      return {'statusCode': response.statusCode, 'data': jsonDecode(response.body)};
    } catch (e) {
      return {'statusCode': 500, 'data': {'msg': 'Error de red: $e'}};
    }
  }

  // ── Actualizar barrio (solo coordinador_campana) ────────────────────────────
  Future<Map<String, dynamic>> actualizarBarrio({
    required String id,
    String? nombre,
    String? sector,
    String? estado,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (nombre != null) body['nombre'] = nombre;
      if (sector != null) body['sector'] = sector;
      if (estado != null) body['estado'] = estado;

      final response = await http.put(
        Uri.parse('${AppConstants.baseUrl}${AppConstants.barriosEndpoint}/$id'),
        headers: await _authHeaders(),
        body: jsonEncode(body),
      );
      return {'statusCode': response.statusCode, 'data': jsonDecode(response.body)};
    } catch (e) {
      return {'statusCode': 500, 'data': {'msg': 'Error de red: $e'}};
    }
  }

  // ── Eliminar barrio (solo coordinador_campana) ──────────────────────────────
  Future<Map<String, dynamic>> eliminarBarrio(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('${AppConstants.baseUrl}${AppConstants.barriosEndpoint}/$id'),
        headers: await _authHeaders(),
      );
      return {'statusCode': response.statusCode, 'data': jsonDecode(response.body)};
    } catch (e) {
      return {'statusCode': 500, 'data': {'msg': 'Error de red: $e'}};
    }
  }
}
