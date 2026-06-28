import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/vacunacion_provider.dart';
import 'providers/usuario_provider.dart';
import 'providers/barrio_provider.dart';
import 'services/vacunacion_local_repository.dart';
import 'services/sync_engine.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Hive debe estar listo ANTES de runApp(): los providers acceden a la
  // caja de vacunaciones locales desde su constructor.
  await VacunacionLocalRepository.inicializar();

  // El motor de sincronización empieza a escuchar conectividad desde
  // ya, aunque todavía no haya ninguna pantalla mostrando datos. Así,
  // si la app se abre ya con internet y hay pendientes de una sesión
  // anterior, se suben solos sin esperar a que el usuario entre a
  // ninguna pantalla en particular.
  SyncEngine().sincronizarTodo();

  runApp(const VacunacionApp());
}

class VacunacionApp extends StatelessWidget {
  const VacunacionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => VacunacionProvider()),
        ChangeNotifierProvider(create: (_) => UsuarioProvider()),
        ChangeNotifierProvider(create: (_) => BarrioProvider()),
      ],
      child: MaterialApp(
        title: 'Vacunación Mascotas',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1565C0),
            primary:   const Color(0xFF1565C0),
            secondary: const Color(0xFF00897B),
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1565C0),
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
        ),
        home: const _SplashRouter(),
      ),
    );
  }
}

/// Decide si mostrar login o dashboard según sesión guardada
class _SplashRouter extends StatefulWidget {
  const _SplashRouter();

  @override
  State<_SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<_SplashRouter> {
  @override
  void initState() {
    super.initState();
    _verificarSesion();
  }

  Future<void> _verificarSesion() async {
    final auth = context.read<AuthProvider>();
    await auth.cargarSesion();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            auth.loggedIn ? const DashboardScreen() : const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF1565C0),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.vaccines, size: 72, color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Sistema de Vacunación',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 32),
            CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
