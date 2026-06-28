import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class AuthService {
  // ── LOGIN ───────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}${AppConstants.loginEndpoint}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      // Guardar token y datos del usuario localmente
      await _guardarSesion(data);
    }

    return {'statusCode': response.statusCode, 'data': data};
  }

  // ── LOGOUT ──────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    try {
      final token = await getToken();
      if (token != null) {
        await http.post(
          Uri.parse('${AppConstants.baseUrl}${AppConstants.logoutEndpoint}'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
      }
    } catch (_) {
      // Ignorar errores de red al cerrar sesión
    } finally {
      await _limpiarSesion();
    }
  }

  // ── RECUPERAR CONTRASEÑA (solicitar código OTP) ──────────────────────────────
  Future<Map<String, dynamic>> recuperarPassword(String email) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/api/auth/recuperar-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    return {'statusCode': response.statusCode, 'data': jsonDecode(response.body)};
  }

  // ── RESTABLECER CONTRASEÑA (código + nueva contraseña en un paso) ─────────
  Future<Map<String, dynamic>> restablecerPassword(
    String email,
    String codigo,
    String passwordNueva,
  ) async {
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}/api/auth/restablecer-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email':        email,
        'codigo':       codigo,
        'passwordNueva': passwordNueva,
      }),
    );
    return {'statusCode': response.statusCode, 'data': jsonDecode(response.body)};
  }

  // ── CAMBIAR CONTRASEÑA ───────────────────────────────────────────────────────
  Future<Map<String, dynamic>> cambiarPassword(
    String passwordActual,
    String passwordNueva,
  ) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('${AppConstants.baseUrl}${AppConstants.cambiarPasswordEndpoint}'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'passwordActual': passwordActual,
        'passwordNueva': passwordNueva,
      }),
    );
    return {'statusCode': response.statusCode, 'data': jsonDecode(response.body)};
  }

  // ── PERFIL (datos actualizados desde el backend) ─────────────────────────────
  Future<Map<String, dynamic>?> obtenerPerfil() async {
    final token = await getToken();
    if (token == null || token.isEmpty) return null;

    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}${AppConstants.perfilEndpoint}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        // Mantener SharedPreferences sincronizado con los datos reales
        await _actualizarDatosUsuario(data);
        return data;
      }
    } catch (_) {
      // Si falla la red, se sigue usando lo que ya está en SharedPreferences
    }
    return null;
  }

  Future<void> _actualizarDatosUsuario(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    if (data['nombre']   != null) await prefs.setString(AppConstants.nombreKey,   data['nombre']);
    if (data['apellido'] != null) await prefs.setString(AppConstants.apellidoKey, data['apellido']);
    if (data['email']    != null) await prefs.setString('user_email',    data['email']);
    if (data['cedula']   != null) await prefs.setString('user_cedula',   data['cedula']);
    if (data['telefono'] != null) await prefs.setString('user_telefono', data['telefono']);
    if (data['rol']      != null) await prefs.setString(AppConstants.rolKey, data['rol']);

    // Actualizar también los barrios si el backend los devuelve populateados.
    // Sin esto, los barrios guardados al login nunca se refrescan y la
    // pantalla de perfil los muestra vacíos.
    final barriosRaw = data['barriosAsignados'];
    if (barriosRaw is List) {
      final ids      = <String>[];
      final nombres  = <String>[];
      final sectores = <String>[];
      for (final b in barriosRaw) {
        if (b is Map) {
          ids.add(b['_id']?.toString() ?? '');
          nombres.add(b['nombre']?.toString() ?? '');
          sectores.add(b['sector']?.toString() ?? '');
        } else if (b is String) {
          ids.add(b);
          nombres.add('');
          sectores.add('');
        }
      }
      await prefs.setStringList('user_barrios_ids',      ids);
      await prefs.setStringList('user_barrios_nombres',  nombres);
      await prefs.setStringList('user_barrios_sectores', sectores);
    }
  }

  // ── HELPERS LOCALES ─────────────────────────────────────────────────────────
  Future<void> _guardarSesion(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.tokenKey,    data['token']    ?? '');
    await prefs.setString(AppConstants.rolKey,      data['rol']      ?? '');
    await prefs.setString(AppConstants.userIdKey,   data['_id']      ?? '');
    await prefs.setString(AppConstants.nombreKey,   data['nombre']   ?? '');
    await prefs.setString(AppConstants.apellidoKey, data['apellido'] ?? '');
    await prefs.setString('user_email',    data['email']    ?? '');
    await prefs.setString('user_cedula',   data['cedula']   ?? '');
    await prefs.setString('user_telefono', data['telefono'] ?? '');

    // Guardar barrios asignados: IDs, nombres y sectores por separado
    // para poder mostrarlos en el perfil sin necesidad de otra llamada.
    final barriosRaw = data['barriosAsignados'];
    final barriosIds     = <String>[];
    final barriosNombres = <String>[];
    final barriosSectores= <String>[];
    if (barriosRaw is List) {
      for (final b in barriosRaw) {
        if (b is Map) {
          barriosIds.add(b['_id']?.toString() ?? '');
          barriosNombres.add(b['nombre']?.toString() ?? '');
          barriosSectores.add(b['sector']?.toString() ?? '');
        } else if (b is String) {
          barriosIds.add(b);
          barriosNombres.add('');
          barriosSectores.add('');
        }
      }
    }
    await prefs.setStringList('user_barrios_ids',      barriosIds);
    await prefs.setStringList('user_barrios_nombres',  barriosNombres);
    await prefs.setStringList('user_barrios_sectores', barriosSectores);
  }

  Future<void> _limpiarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.tokenKey);
  }

  Future<String?> getRol() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.rolKey);
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<Map<String, String?>> getDatosUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'id':       prefs.getString(AppConstants.userIdKey),
      'nombre':   prefs.getString(AppConstants.nombreKey),
      'apellido': prefs.getString(AppConstants.apellidoKey),
      'rol':      prefs.getString(AppConstants.rolKey),
      'email':    prefs.getString('user_email'),
      'cedula':   prefs.getString('user_cedula'),
      'telefono': prefs.getString('user_telefono'),
    };
  }

  Future<List<String>> getBarriosIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('user_barrios_ids') ?? [];
  }

  /// Devuelve los barrios del usuario logueado como lista de mapas
  /// {id, nombre, sector} para mostrarlos en el perfil.
  Future<List<Map<String, String>>> getBarriosCompletos() async {
    final prefs    = await SharedPreferences.getInstance();
    final ids      = prefs.getStringList('user_barrios_ids')      ?? [];
    final nombres  = prefs.getStringList('user_barrios_nombres')  ?? [];
    final sectores = prefs.getStringList('user_barrios_sectores') ?? [];
    final result   = <Map<String, String>>[];
    for (var i = 0; i < ids.length; i++) {
      result.add({
        'id':     ids[i],
        'nombre': i < nombres.length  ? nombres[i]  : '',
        'sector': i < sectores.length ? sectores[i] : '',
      });
    }
    return result;
  }

  Future<bool> requiereCambioPassword(Map<String, dynamic> loginData) async {
    return loginData['requiereCambioPassword'] == true;
  }
}