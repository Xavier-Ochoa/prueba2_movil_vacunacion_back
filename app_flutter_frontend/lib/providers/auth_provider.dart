import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();

  bool         _isLoading       = false;
  String       _rol             = '';
  String       _nombre          = '';
  String       _apellido        = '';
  String       _userId          = '';
  String       _email           = '';
  String       _cedula          = '';
  String       _telefono        = '';
  bool         _loggedIn        = false;
  List<String>              _barriosIds       = [];
  List<Map<String, String>> _barriosCompletos = [];

  bool         get isLoading       => _isLoading;
  String       get rol             => _rol;
  String       get nombre          => _nombre;
  String       get apellido        => _apellido;
  String       get userId          => _userId;
  String       get email           => _email;
  String       get cedula          => _cedula;
  String       get telefono        => _telefono;
  bool         get loggedIn        => _loggedIn;
  List<String>              get barriosIds       => _barriosIds;
  List<Map<String, String>> get barriosCompletos => _barriosCompletos;
  String       get nombreCompleto  => '$_nombre $_apellido'.trim();

  bool get esVacunador          => _rol == 'vacunador';
  bool get esCoordinadorBrigada => _rol == 'coordinador_brigada';
  bool get esCoordinadorCampana => _rol == 'coordinador_campana';
  bool get esCoordinador        => esCoordinadorBrigada || esCoordinadorCampana;

  Future<void> cargarSesion() async {
    final datos = await _authService.getDatosUsuario();
    _nombre      = datos['nombre']   ?? '';
    _apellido    = datos['apellido'] ?? '';
    _rol         = datos['rol']      ?? '';
    _userId      = datos['id']       ?? '';
    _email       = datos['email']    ?? '';
    _cedula      = datos['cedula']   ?? '';
    _telefono    = datos['telefono'] ?? '';
    _barriosIds       = await _authService.getBarriosIds();
    _barriosCompletos = await _authService.getBarriosCompletos();
    _loggedIn    = await _authService.isLoggedIn();
    notifyListeners();

    // Refrescar con los datos reales del backend (por si cedula/telefono
    // no se guardaron correctamente en el login, o cambiaron después).
    if (_loggedIn) {
      final perfilActualizado = await _authService.obtenerPerfil();
      if (perfilActualizado != null) {
        _nombre   = perfilActualizado['nombre']   ?? _nombre;
        _apellido = perfilActualizado['apellido'] ?? _apellido;
        _email    = perfilActualizado['email']    ?? _email;
        _cedula   = perfilActualizado['cedula']   ?? _cedula;
        _telefono = perfilActualizado['telefono'] ?? _telefono;
        _rol      = perfilActualizado['rol']      ?? _rol;
        notifyListeners();
      }
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _authService.login(email, password);
      if (result['statusCode'] == 200) {
        await cargarSesion();
      }
      return result;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    await _authService.logout();
    _rol        = '';
    _nombre     = '';
    _apellido   = '';
    _userId     = '';
    _email      = '';
    _cedula     = '';
    _telefono   = '';
    _barriosIds       = [];
    _barriosCompletos = [];
    _loggedIn   = false;
    _isLoading = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>> cambiarPassword(
    String actual, String nueva,
  ) async {
    return _authService.cambiarPassword(actual, nueva);
  }
}