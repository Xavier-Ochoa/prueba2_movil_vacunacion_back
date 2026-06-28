import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/usuario_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/usuario_provider.dart';
import 'crear_usuario_screen.dart';
import 'editar_usuario_screen.dart';
import 'reasignar_barrio_screen.dart';

class ListaUsuariosScreen extends StatefulWidget {
  const ListaUsuariosScreen({super.key});

  @override
  State<ListaUsuariosScreen> createState() => _ListaUsuariosScreenState();
}

class _ListaUsuariosScreenState extends State<ListaUsuariosScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UsuarioProvider>().cargarMisUsuarios();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth     = context.watch<AuthProvider>();
    final provider = context.watch<UsuarioProvider>();

    final titulo = auth.esCoordinadorCampana
        ? 'Mis Coordinadores de Brigada'
        : 'Mis Vacunadores';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(titulo),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
            onPressed: () => provider.cargarMisUsuarios(),
          ),
        ],
      ),
      body: _buildBody(provider),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Nuevo'),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CrearUsuarioScreen()),
          ).then((_) => provider.cargarMisUsuarios());
        },
      ),
    );
  }

  Widget _buildBody(UsuarioProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(
              provider.error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => provider.cargarMisUsuarios(),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (provider.usuarios.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.group_off, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'Aún no has creado usuarios.\nToca el botón "+" para comenzar.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 15),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => provider.cargarMisUsuarios(),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: provider.usuarios.length,
        itemBuilder: (context, index) {
          final auth = context.read<AuthProvider>();
          return _UsuarioCard(
            usuario: provider.usuarios[index],
            auth:    auth,
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tarjeta de usuario
// ─────────────────────────────────────────────────────────────────────────────

class _UsuarioCard extends StatelessWidget {
  final Usuario     usuario;
  final AuthProvider auth;

  const _UsuarioCard({required this.usuario, required this.auth});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<UsuarioProvider>();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado: nombre + chip de estado
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: _colorRol(usuario.rol).withOpacity(0.15),
                  child: Icon(
                    _iconoRol(usuario.rol),
                    color: _colorRol(usuario.rol),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        usuario.nombreCompleto,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _labelRol(usuario.rol),
                        style: TextStyle(
                          fontSize: 12,
                          color: _colorRol(usuario.rol),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                _ChipEstado(activo: usuario.activo),
              ],
            ),
            const SizedBox(height: 10),

            // Datos de contacto
            _InfoRow(icon: Icons.phone, text: usuario.telefono),
            _InfoRow(icon: Icons.email_outlined, text: usuario.email),

            // Barrios asignados
            if (usuario.barriosAsignados.isNotEmpty) ...[
              const SizedBox(height: 4),
              _InfoRow(
                icon: Icons.location_on_outlined,
                text: usuario.barriosAsignados
                    .map((b) => '${b.nombre} (${b.sector})')
                    .join(', '),
              ),
            ],

            // Acciones
            const Divider(height: 18),
            if (usuario.activo) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Reasignar barrio — solo coordinador_brigada a sus
                  // vacunadores, y solo tiene sentido si administra 2+
                  // barrios (si solo tiene 1, no hay a dónde reasignar).
                  if (usuario.rol == 'vacunador' &&
                      auth.esCoordinadorBrigada &&
                      auth.barriosIds.length >= 2)
                    TextButton.icon(
                      icon: const Icon(Icons.swap_horiz, size: 18),
                      label: const Text('Reasignar'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.orange.shade700,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReasignarBarrioScreen(usuario: usuario),
                          ),
                        ).then((_) => provider.cargarMisUsuarios());
                      },
                    ),

                  // Editar barrios — solo coordinador_campana a sus coordinadores_brigada
                  if (usuario.rol == 'coordinador_brigada' && auth.esCoordinadorCampana)
                    TextButton.icon(
                      icon: const Icon(Icons.map_outlined, size: 18),
                      label: const Text('Barrios'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF1565C0),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditarUsuarioScreen(usuario: usuario),
                          ),
                        ).then((_) => provider.cargarMisUsuarios());
                      },
                    ),

                  const SizedBox(width: 4),
                  // Desactivar — solo el creador del usuario
                  TextButton.icon(
                    icon: const Icon(Icons.person_off_outlined, size: 18),
                    label: const Text('Desactivar'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                    ),
                    onPressed: () => _confirmarDesactivar(context, provider),
                  ),
                ],
              ),
            ] else ...[
              // Usuario inactivo: única acción disponible es reactivarlo
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                    label: const Text('Activar'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.green.shade700,
                    ),
                    onPressed: () => _confirmarActivar(context, provider),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmarDesactivar(
    BuildContext context,
    UsuarioProvider provider,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desactivar usuario'),
        content: Text(
          '¿Desactivar a ${usuario.nombreCompleto}? '
          'Ya no podrá ingresar a la aplicación.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Desactivar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar == true && context.mounted) {
      final result = await provider.desactivarUsuario(usuario.id);
      if (context.mounted) {
        final msg = result['statusCode'] == 200
            ? 'Usuario desactivado'
            : (result['data']['msg'] ?? 'Error al desactivar');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: result['statusCode'] == 200 ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmarActivar(
    BuildContext context,
    UsuarioProvider provider,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Activar usuario'),
        content: Text(
          '¿Activar a ${usuario.nombreCompleto}? '
          'Podrá volver a ingresar a la aplicación.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Activar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar == true && context.mounted) {
      final result = await provider.activarUsuario(usuario.id);
      if (context.mounted) {
        final exito = result['statusCode'] == 200;
        final msg = exito
            ? 'Usuario activado'
            : (result['data']['msg'] ?? 'Error al activar');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: exito ? Colors.green : Colors.red,
            duration: Duration(seconds: exito ? 3 : 6),
          ),
        );
      }
    }
  }

  Color _colorRol(String rol) {
    switch (rol) {
      case 'coordinador_brigada': return const Color(0xFF1565C0);
      case 'vacunador':           return const Color(0xFF00897B);
      default:                    return Colors.purple;
    }
  }

  IconData _iconoRol(String rol) {
    switch (rol) {
      case 'coordinador_brigada': return Icons.supervisor_account;
      case 'vacunador':           return Icons.medical_services_outlined;
      default:                    return Icons.person;
    }
  }

  String _labelRol(String rol) {
    switch (rol) {
      case 'coordinador_brigada': return 'Coordinador de Brigada';
      case 'vacunador':           return 'Vacunador';
      case 'coordinador_campana': return 'Coordinador de Campaña';
      default:                    return rol;
    }
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String   text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipEstado extends StatelessWidget {
  final bool activo;

  const _ChipEstado({required this.activo});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: activo ? Colors.green.shade50 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: activo ? Colors.green.shade300 : Colors.grey.shade400,
        ),
      ),
      child: Text(
        activo ? 'Activo' : 'Inactivo',
        style: TextStyle(
          fontSize: 11,
          color: activo ? Colors.green.shade800 : Colors.grey.shade700,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
