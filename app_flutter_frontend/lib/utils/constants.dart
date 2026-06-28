class AppConstants {
  // ── URL del backend ──────────────────────────────────────────────────────────
  // En desarrollo local (emulador Android): http://10.0.2.2:4000
  // En desarrollo local (dispositivo físico): http://TU_IP_LOCAL:4000
  // En producción Vercel: https://tu-proyecto.vercel.app
  static const String baseUrl = 'https://prueba2-movil-vacunacion-back.vercel.app';

  // ── Endpoints ────────────────────────────────────────────────────────────────
  static const String loginEndpoint         = '/api/auth/login';
  static const String logoutEndpoint        = '/api/auth/cerrar-sesion';
  static const String perfilEndpoint        = '/api/auth/perfil';
  static const String cambiarPasswordEndpoint = '/api/auth/cambiar-password';

  static const String vacunacionesEndpoint  = '/api/vacunaciones';
  static const String estadisticasEndpoint  = '/api/vacunaciones/estadisticas';
  static const String usuariosEndpoint      = '/api/usuarios';
  static const String barriosEndpoint       = '/api/barrios';

  // ── Shared Preferences keys ──────────────────────────────────────────────────
  static const String tokenKey    = 'jwt_token';
  static const String rolKey      = 'user_rol';
  static const String userIdKey   = 'user_id';
  static const String nombreKey   = 'user_nombre';
  static const String apellidoKey = 'user_apellido';

  // ── Roles ────────────────────────────────────────────────────────────────────
  static const String rolVacunador           = 'vacunador';
  static const String rolCoordinadorBrigada  = 'coordinador_brigada';
  static const String rolCoordinadorCampana  = 'coordinador_campana';

  // ── Colores ──────────────────────────────────────────────────────────────────
  static const int primaryColorValue   = 0xFF1565C0; // Azul institucional
  static const int secondaryColorValue = 0xFF00897B; // Verde salud
  static const int errorColorValue     = 0xFFD32F2F;
}
