import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/vacunacion_model.dart';
import '../utils/constants.dart';
import 'auth_service.dart';

class VacunacionService {
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _headers() async {
    final token = await _authService.getToken();
    return {'Authorization': 'Bearer $token'};
  }

  // ── LISTAR ──────────────────────────────────────────────────────────────────
  /// Devuelve null si no se pudo contactar al backend (sin internet,
  /// timeout, error de servidor). El llamador decide qué mostrar en ese
  /// caso (típicamente: solo lo que haya en Hive).
  Future<List<Vacunacion>?> listarVacunaciones() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}${AppConstants.vacunacionesEndpoint}'),
        headers: await _headers(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['vacunaciones'] as List)
            .map((v) => Vacunacion.fromJson(v))
            .toList();
      }
      return null;
    } catch (_) {
      // Sin conexión, timeout, DNS, etc. — modo offline.
      return null;
    }
  }

  // ── ESTADÍSTICAS ─────────────────────────────────────────────────────────────
  /// Igual que [listarVacunaciones]: null si no hay forma de contactar
  /// al backend en este momento.
  Future<Estadisticas?> obtenerEstadisticas() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}${AppConstants.estadisticasEndpoint}'),
        headers: await _headers(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return Estadisticas.fromJson(data['estadisticas']);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── CREAR ────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> crearVacunacion({
    required String propietarioNombre,
    required String propietarioCedula,
    required String propietarioTelefono,
    required String mascotaTipo,
    required String mascotaNombre,
    required int mascotaEdad,
    required String mascotaSexo,
    required String vacuna,
    String observaciones = '',
    required File imagen,
    double? latitud,
    double? longitud,
    String? barrioId,
    String? clienteId,
    DateTime? fechaRegistro,
  }) async {
    final token = await _authService.getToken();

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConstants.baseUrl}${AppConstants.vacunacionesEndpoint}'),
    );

    request.headers['Authorization'] = 'Bearer $token';

    // Campos de texto
    request.fields.addAll({
      'propietarioNombre':   propietarioNombre,
      'propietarioCedula':   propietarioCedula,
      'propietarioTelefono': propietarioTelefono,
      'mascotaTipo':         mascotaTipo,
      'mascotaNombre':       mascotaNombre,
      'mascotaEdad':         mascotaEdad.toString(),
      'mascotaSexo':         mascotaSexo,
      'vacuna':              vacuna,
      'observaciones':       observaciones,
      if (latitud  != null) 'latitud':  latitud.toString(),
      if (longitud != null) 'longitud': longitud.toString(),
      if (barrioId != null) 'barrioId': barrioId,
      if (clienteId != null) 'clienteId': clienteId,
      if (fechaRegistro != null) 'fechaRegistro': fechaRegistro.toIso8601String(),
    });

    // Imagen
    final extension = imagen.path.split('.').last.toLowerCase();
    final mimeType  = extension == 'png' ? 'png' : 'jpeg';
    request.files.add(await http.MultipartFile.fromPath(
      'imagen',
      imagen.path,
      contentType: MediaType('image', mimeType),
    ));

    final streamed = await request.send();
    final body     = await streamed.stream.bytesToString();
    return {'statusCode': streamed.statusCode, 'data': jsonDecode(body)};
  }

  // ── EDITAR ───────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> editarVacunacion({
    required String id,
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
  }) async {
    final token = await _authService.getToken();

    final request = http.MultipartRequest(
      'PUT',
      Uri.parse('${AppConstants.baseUrl}${AppConstants.vacunacionesEndpoint}/$id'),
    );

    request.headers['Authorization'] = 'Bearer $token';

    if (propietarioNombre   != null) request.fields['propietarioNombre']   = propietarioNombre;
    if (propietarioCedula   != null) request.fields['propietarioCedula']   = propietarioCedula;
    if (propietarioTelefono != null) request.fields['propietarioTelefono'] = propietarioTelefono;
    if (mascotaTipo         != null) request.fields['mascotaTipo']         = mascotaTipo;
    if (mascotaNombre       != null) request.fields['mascotaNombre']       = mascotaNombre;
    if (mascotaEdad         != null) request.fields['mascotaEdad']         = mascotaEdad.toString();
    if (mascotaSexo         != null) request.fields['mascotaSexo']         = mascotaSexo;
    if (vacuna              != null) request.fields['vacuna']              = vacuna;
    if (observaciones       != null) request.fields['observaciones']       = observaciones;
    if (latitud             != null) request.fields['latitud']             = latitud.toString();
    if (longitud            != null) request.fields['longitud']            = longitud.toString();

    if (imagen != null) {
      final extension = imagen.path.split('.').last.toLowerCase();
      final mimeType  = extension == 'png' ? 'png' : 'jpeg';
      request.files.add(await http.MultipartFile.fromPath(
        'imagen',
        imagen.path,
        contentType: MediaType('image', mimeType),
      ));
    }

    final streamed = await request.send();
    final body     = await streamed.stream.bytesToString();
    return {'statusCode': streamed.statusCode, 'data': jsonDecode(body)};
  }

  // ── ELIMINAR ─────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> eliminarVacunacion(String id) async {
    final response = await http.delete(
      Uri.parse('${AppConstants.baseUrl}${AppConstants.vacunacionesEndpoint}/$id'),
      headers: await _headers(),
    );
    return {'statusCode': response.statusCode, 'data': jsonDecode(response.body)};
  }
}
