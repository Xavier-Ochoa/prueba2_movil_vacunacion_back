import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/auth_provider.dart';
import '../../providers/vacunacion_provider.dart';
import '../../models/vacunacion_model.dart';
import '../../models/usuario_model.dart';
import '../vacunacion/lista_vacunaciones_screen.dart';
import '../vacunacion/form_vacunacion_screen.dart';
import '../auth/login_screen.dart';
import '../usuarios/lista_usuarios_screen.dart';
import '../usuarios/editar_usuario_screen.dart';
import '../usuarios/gestionar_barrios_screen.dart';

/// Dashboard avanzado del Sprint 3.
///
/// Sobre el dashboard básico del Sprint 2 (tarjetas + lista simple por
/// barrio), se agrega:
///  - Gráfico circular perros vs. gatos.
///  - Gráfico de barras de vacunaciones por barrio.
///  - Desglose por vacunador (visible solo para coordinadores, que son
///    quienes necesitan comparar el desempeño de su equipo).
///  - Aviso de registros pendientes de sincronizar, con acceso directo
///    a forzar la sincronización.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VacunacionProvider>().cargarEstadisticas();
      context.read<VacunacionProvider>().cargarVacunaciones();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth         = context.watch<AuthProvider>();
    final vacProvider  = context.watch<VacunacionProvider>();
    final stats        = vacProvider.estadisticas;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              await auth.logout();
              if (!context.mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await context.read<VacunacionProvider>().cargarEstadisticas();
          await context.read<VacunacionProvider>().cargarVacunaciones();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Saludo
            Text(
              'Hola, ${auth.nombreCompleto}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(
              _labelRol(auth.rol),
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // ── Aviso de sincronización pendiente ────────────────────────
            if (vacProvider.totalPendientes > 0)
              _AvisoSincronizacion(
                total: vacProvider.totalPendientes,
                sincronizando: vacProvider.sincronizando,
                onSincronizar: () => vacProvider.intentarSincronizarAhora(),
              ),

            const SizedBox(height: 8),

            // ── Tarjetas de estadísticas ──────────────────────────────────
            if (stats != null) ...[
              Row(
                children: [
                  _StatCard(
                    label: 'Total Vacunaciones',
                    value: stats.total.toString(),
                    icon:  Icons.vaccines,
                    color: const Color(0xFF1565C0),
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    label: 'Perros',
                    value: stats.perros.toString(),
                    icon:  Icons.pets,
                    color: Colors.orange,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _StatCard(
                    label: 'Gatos',
                    value: stats.gatos.toString(),
                    icon:  Icons.catching_pokemon,
                    color: const Color(0xFF00897B),
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    label: 'Barrios',
                    value: stats.porBarrio.length.toString(),
                    icon:  Icons.location_city,
                    color: Colors.purple,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Gráfico circular: perros vs gatos ────────────────────────
              if (stats.total > 0) ...[
                const Text(
                  'Distribución por Especie',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _GraficoEspecies(stats: stats),
                const SizedBox(height: 24),
              ],

              // ── Gráfico de barras: vacunaciones por barrio ──────────────
              if (stats.porBarrio.isNotEmpty) ...[
                const Text(
                  'Vacunaciones por Barrio',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _GraficoBarrios(porBarrio: stats.porBarrio),
                const SizedBox(height: 24),
              ],

              // ── Por vacunador (solo coordinadores) ──────────────────────
              if (auth.esCoordinador && stats.porVacunador.isNotEmpty) ...[
                const Text(
                  'Desempeño por Vacunador',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...stats.porVacunador.map(
                  (v) => _VacunadorRow(vacunador: v, total: stats.total),
                ),
                const SizedBox(height: 24),
              ],
            ] else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              ),

            // ── Acceso rápido ────────────────────────────────────────────
            const Text(
              'Acceso Rápido',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _MenuCard(
              icon:  Icons.list_alt,
              label: 'Ver Vacunaciones',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ListaVacunacionesScreen(),
                ),
              ),
            ),
            if (auth.esVacunador)
              _MenuCard(
                icon:  Icons.add_circle_outline,
                label: 'Registrar Vacunación',
                color: const Color(0xFF00897B),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const FormVacunacionScreen(),
                  ),
                ).then((_) {
                  context.read<VacunacionProvider>().cargarEstadisticas();
                  context.read<VacunacionProvider>().cargarVacunaciones();
                }),
              ),
            if (auth.esCoordinador)
              _MenuCard(
                icon:  Icons.group_outlined,
                label: 'Gestionar mi equipo',
                color: Colors.deepPurple,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ListaUsuariosScreen(),
                  ),
                ),
              ),
            if (auth.esCoordinadorCampana)
              _MenuCard(
                icon:  Icons.location_city,
                label: 'Barrios / Sectores',
                color: const Color(0xFF6D4C41),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const GestionarBarriosScreen(),
                  ),
                ),
              ),
            _MenuCard(
              icon:  Icons.account_circle_outlined,
              label: 'Mi perfil',
              color: Colors.blueGrey,
              onTap: () {
                // Construir la lista de barrios a partir de los datos
                // guardados en SharedPreferences al hacer login, que
                // incluyen nombre y sector además del ID.
                final barrios = auth.barriosCompletos.map((b) => BarrioResumen(
                  id:     b['id']     ?? '',
                  nombre: b['nombre'] ?? '',
                  sector: b['sector'] ?? '',
                )).toList();

                final usuario = Usuario(
                  id:               auth.userId,
                  nombre:           auth.nombre,
                  apellido:         auth.apellido,
                  cedula:           auth.cedula,
                  email:            auth.email,
                  telefono:         auth.telefono,
                  rol:              auth.rol,
                  estado:           'activo',
                  barriosAsignados: barrios,
                );
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditarUsuarioScreen(usuario: usuario),
                  ),
                ).then((_) => context.read<AuthProvider>().cargarSesion());
              },
            ),
          ],
        ),
      ),
    );
  }

  String _labelRol(String rol) {
    switch (rol) {
      case 'vacunador':           return 'Vacunador';
      case 'coordinador_brigada': return 'Coordinador de Brigada';
      case 'coordinador_campana': return 'Coordinador de Campaña';
      default:                    return rol;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Aviso de sincronización pendiente
// ─────────────────────────────────────────────────────────────────────────

class _AvisoSincronizacion extends StatelessWidget {
  final int total;
  final bool sincronizando;
  final VoidCallback onSincronizar;

  const _AvisoSincronizacion({
    required this.total,
    required this.sincronizando,
    required this.onSincronizar,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.orange.shade50,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.orange.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.cloud_upload_outlined, color: Colors.orange.shade800),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                sincronizando
                    ? 'Sincronizando registros pendientes...'
                    : '$total registro${total == 1 ? "" : "s"} esperando conexión para sincronizarse.',
                style: TextStyle(fontSize: 13, color: Colors.orange.shade900),
              ),
            ),
            if (sincronizando)
              const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              TextButton(
                onPressed: onSincronizar,
                child: const Text('Reintentar'),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Tarjeta de estadística simple
// ─────────────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Gráfico circular: perros vs gatos
// ─────────────────────────────────────────────────────────────────────────

class _GraficoEspecies extends StatelessWidget {
  final Estadisticas stats;

  const _GraficoEspecies({required this.stats});

  @override
  Widget build(BuildContext context) {
    const colorPerros = Colors.orange;
    const colorGatos  = Color(0xFF00897B);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              height: 140,
              width: 140,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 32,
                  sections: [
                    PieChartSectionData(
                      value: stats.perros.toDouble(),
                      color: colorPerros,
                      title: stats.total > 0
                          ? '${(stats.perros / stats.total * 100).round()}%'
                          : '0%',
                      radius: 26,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    PieChartSectionData(
                      value: stats.gatos.toDouble(),
                      color: colorGatos,
                      title: stats.total > 0
                          ? '${(stats.gatos / stats.total * 100).round()}%'
                          : '0%',
                      radius: 26,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _LeyendaItem(color: colorPerros, label: 'Perros', valor: stats.perros),
                  const SizedBox(height: 8),
                  _LeyendaItem(color: colorGatos, label: 'Gatos', valor: stats.gatos),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeyendaItem extends StatelessWidget {
  final Color color;
  final String label;
  final int valor;

  const _LeyendaItem({required this.color, required this.label, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12, height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(fontSize: 13)),
        Text('$valor', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Gráfico de barras: vacunaciones por barrio
// ─────────────────────────────────────────────────────────────────────────

class _GraficoBarrios extends StatelessWidget {
  final List<BarrioStat> porBarrio;

  const _GraficoBarrios({required this.porBarrio});

  @override
  Widget build(BuildContext context) {
    // Mostramos como máximo los 6 barrios con más vacunaciones para que
    // las barras y sus etiquetas no queden ilegibles en pantallas
    // angostas. El resto se puede ver en detalle en la lista de abajo.
    final topBarrios = porBarrio.take(6).toList();
    final maxValor = topBarrios.map((b) => b.total).fold(0, (a, b) => a > b ? a : b);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
        child: Column(
          children: [
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxValor == 0 ? 1 : (maxValor * 1.2),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) => Text(
                          value.toInt().toString(),
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= topBarrios.length) return const SizedBox.shrink();
                          final nombre = topBarrios[i].barrio;
                          final corto = nombre.length > 8 ? '${nombre.substring(0, 7)}…' : nombre;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              corto,
                              style: const TextStyle(fontSize: 9, color: Colors.grey),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(topBarrios.length, (i) {
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: topBarrios[i].total.toDouble(),
                          color: const Color(0xFF1565C0),
                          width: 22,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Desglose por vacunador (coordinadores)
// ─────────────────────────────────────────────────────────────────────────

class _VacunadorRow extends StatelessWidget {
  final VacunadorStat vacunador;
  final int total;

  const _VacunadorRow({required this.vacunador, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? vacunador.total / total : 0.0;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    vacunador.nombreCompleto,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${vacunador.total}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation(Color(0xFF1565C0)),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${vacunador.perros} perros · ${vacunador.gatos} gatos',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Acceso rápido
// ─────────────────────────────────────────────────────────────────────────

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String   label;
  final VoidCallback onTap;
  final Color    color;

  const _MenuCard({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = const Color(0xFF1565C0),
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Icon(icon, color: color),
        ),
        title: Text(label),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}