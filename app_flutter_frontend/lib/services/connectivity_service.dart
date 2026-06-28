import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Envuelve `connectivity_plus` y expone una API simple:
///  - [tieneConexion]: chequeo puntual (true/false) en este instante.
///  - [onConexionRecuperada]: stream que emite un evento *solo* en el
///    momento exacto en que se pasa de "sin internet" a "con internet".
///    Es la señal que el [SyncEngine] usa para disparar la sincronización
///    automática, sin que nadie tenga que pedirla manualmente.
class ConnectivityService {
  ConnectivityService._internal() {
    _inicializar();
  }
  static final ConnectivityService _instancia = ConnectivityService._internal();
  factory ConnectivityService() => _instancia;

  final Connectivity _connectivity = Connectivity();
  final _conexionRecuperadaController = StreamController<void>.broadcast();

  bool _ultimoEstadoConectado = false;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// Emite cada vez que la conexión pasa de "no" a "sí".
  Stream<void> get onConexionRecuperada => _conexionRecuperadaController.stream;

  Future<void> _inicializar() async {
    _ultimoEstadoConectado = await tieneConexion();

    _subscription = _connectivity.onConnectivityChanged.listen((resultados) async {
      final conectadoAhora = _resultadosIndicanConexion(resultados);

      // Solo nos interesa el flanco de "se recuperó la señal".
      if (conectadoAhora && !_ultimoEstadoConectado) {
        // Verificación real (no solo "hay wifi", sino "hay internet de
        // verdad"), porque a veces el dispositivo está conectado a una
        // red sin salida real.
        final realmenteConectado = await tieneConexion();
        if (realmenteConectado) {
          _conexionRecuperadaController.add(null);
        }
        _ultimoEstadoConectado = realmenteConectado;
      } else {
        _ultimoEstadoConectado = conectadoAhora;
      }
    });
  }

  bool _resultadosIndicanConexion(List<ConnectivityResult> resultados) {
    return resultados.any((r) =>
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.ethernet);
  }

  /// Chequeo puntual: ¿hay conexión a internet ahora mismo?
  ///
  /// `connectivity_plus` solo dice si hay una interfaz de red activa
  /// (wifi/datos), no si esa red tiene salida real a internet. Para el
  /// propósito de este sprint (decidir si reintentar la sincronización)
  /// es suficiente, y evita depender de un servidor externo de "ping".
  Future<bool> tieneConexion() async {
    final resultados = await _connectivity.checkConnectivity();
    return _resultadosIndicanConexion(resultados);
  }

  void dispose() {
    _subscription?.cancel();
    _conexionRecuperadaController.close();
  }
}
