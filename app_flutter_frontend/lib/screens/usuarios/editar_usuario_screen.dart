import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/usuario_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/usuario_provider.dart';

class EditarUsuarioScreen extends StatefulWidget {
  final Usuario usuario;
  const EditarUsuarioScreen({super.key, required this.usuario});

  @override
  State<EditarUsuarioScreen> createState() => _EditarUsuarioScreenState();
}

class _EditarUsuarioScreenState extends State<EditarUsuarioScreen> {
  final _formKey    = GlobalKey<FormState>();
  bool  _isLoading  = false;
  bool  _modoEdicion = false;

  late final TextEditingController _nombreCtrl;
  late final TextEditingController _apellidoCtrl;
  late final TextEditingController _telefonoCtrl;

  List<String> _barriosSeleccionados = [];

  bool get _esPropietario =>
      widget.usuario.id == context.read<AuthProvider>().userId;

  bool get _puedeEditarBarrios {
    final auth = context.read<AuthProvider>();
    return auth.esCoordinadorCampana &&
        widget.usuario.rol == 'coordinador_brigada';
  }

  @override
  void initState() {
    super.initState();
    _nombreCtrl   = TextEditingController(text: widget.usuario.nombre);
    _apellidoCtrl = TextEditingController(text: widget.usuario.apellido);
    _telefonoCtrl = TextEditingController(text: widget.usuario.telefono);

    _barriosSeleccionados = widget.usuario.barriosAsignados
        .map((b) => b.id)
        .where((id) => id.isNotEmpty)
        .toList();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_puedeEditarBarrios) {
        context.read<UsuarioProvider>().cargarBarrios();
      }
    });
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _telefonoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UsuarioProvider>();

    // ── Caso: ni propietario ni puede editar barrios → solo lectura ──
    if (!_esPropietario && !_puedeEditarBarrios) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Detalle de usuario'),
          backgroundColor: const Color(0xFF1565C0),
          foregroundColor: Colors.white,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _PerfilVistaCard(usuario: widget.usuario),
              const SizedBox(height: 20),
              const Text(
                'Solo el propio usuario puede editar su perfil.',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // ── Caso: coordinador_campana editando barrios de brigada ──
    if (!_esPropietario && _puedeEditarBarrios) {
      return _PantallaBarrios(
        usuario:              widget.usuario,
        barriosSeleccionados: _barriosSeleccionados,
        provider:             provider,
        isLoading:            _isLoading,
        onChanged: (lista) => setState(() => _barriosSeleccionados = lista),
        onGuardar: () => _guardarBarrios(context, provider),
        onDesactivar: () => _confirmarDesactivar(context, provider),
      );
    }

    // ── Caso: propio usuario → vista o edición ──
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(_modoEdicion ? 'Editar perfil' : 'Mi perfil'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        actions: [
          if (!_modoEdicion)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Editar',
              onPressed: () => setState(() => _modoEdicion = true),
            ),
          if (_modoEdicion)
            TextButton(
              onPressed: () => setState(() => _modoEdicion = false),
              child: const Text('Cancelar', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: _modoEdicion
          ? _FormularioEdicion(
              formKey:      _formKey,
              nombreCtrl:   _nombreCtrl,
              apellidoCtrl: _apellidoCtrl,
              telefonoCtrl: _telefonoCtrl,
              isLoading:    _isLoading,
              onGuardar:    () => _guardarPerfil(context, provider),
            )
          : _VistaPerfilCompleta(usuario: widget.usuario),
    );
  }

  // ─── Guardar datos personales ───────────────────────────────────────────────
  Future<void> _guardarPerfil(BuildContext context, UsuarioProvider provider) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final result = await provider.editarUsuario(
      widget.usuario.id,
      nombre:   _nombreCtrl.text.trim(),
      apellido: _apellidoCtrl.text.trim(),
      telefono: _telefonoCtrl.text.trim(),
    );

    setState(() => _isLoading = false);
    if (!context.mounted) return;

    if (result['statusCode'] == 200) {
      await context.read<AuthProvider>().cargarSesion();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Perfil actualizado correctamente'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() => _modoEdicion = false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['data']['msg'] ?? 'Error al guardar'),
        backgroundColor: Colors.red,
      ));
    }
  }

  // ─── Guardar barrios ────────────────────────────────────────────────────────
  Future<void> _guardarBarrios(BuildContext context, UsuarioProvider provider) async {
    setState(() => _isLoading = true);
    final result = await provider.actualizarBarriosCoordinador(
      widget.usuario.id,
      _barriosSeleccionados,
    );
    setState(() => _isLoading = false);
    if (!context.mounted) return;

    if (result['statusCode'] == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Barrios actualizados correctamente'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else if (result['statusCode'] == 409 &&
        result['data']?['vacunadoresAfectados'] != null) {
      _mostrarVacunadoresAfectados(
        context,
        result['data']['msg'] ?? 'No se pueden quitar esos barrios.',
        result['data']['vacunadoresAfectados'] as List,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['data']['msg'] ?? 'Error al actualizar barrios'),
        backgroundColor: Colors.red,
      ));
    }
  }

  void _mostrarVacunadoresAfectados(
    BuildContext context,
    String mensaje,
    List vacunadoresAfectados,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('No se puede quitar el barrio'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(mensaje),
              const SizedBox(height: 12),
              const Text(
                'Vacunadores activos en ese barrio:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              ...vacunadoresAfectados.map((v) {
                final nombre  = v['nombre'] ?? 'Vacunador';
                final barrios = (v['barrios'] as List?)?.join(', ') ?? '';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.person, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('$nombre — $barrios',
                            style: const TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  // ─── Confirmar desactivar ───────────────────────────────────────────────────
  Future<void> _confirmarDesactivar(BuildContext context, UsuarioProvider provider) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desactivar usuario'),
        content: Text('¿Desactivar a ${widget.usuario.nombreCompleto}? Ya no podrá ingresar.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Desactivar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmar == true && context.mounted) {
      setState(() => _isLoading = true);
      final result = await provider.desactivarUsuario(widget.usuario.id);
      setState(() => _isLoading = false);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['statusCode'] == 200
            ? 'Usuario desactivado'
            : (result['data']['msg'] ?? 'Error')),
        backgroundColor: result['statusCode'] == 200 ? Colors.green : Colors.red,
      ));
      if (result['statusCode'] == 200) Navigator.pop(context);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Vista de perfil completa (modo lectura)
// ═══════════════════════════════════════════════════════════════════════════════
class _VistaPerfilCompleta extends StatelessWidget {
  final Usuario usuario;
  const _VistaPerfilCompleta({required this.usuario});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Avatar
          Center(
            child: CircleAvatar(
              radius: 44,
              backgroundColor: const Color(0xFF1565C0).withOpacity(0.12),
              child: Text(
                _iniciales(usuario.nombreCompleto),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1565C0),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            usuario.nombreCompleto,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          _ChipRol(rol: usuario.rol),
          const SizedBox(height: 20),

          // Datos
          _SeccionDatos(titulo: 'Información personal', filas: [
            _FilaDato(icon: Icons.badge_outlined,   label: 'Cédula',   value: usuario.cedula.isEmpty   ? '—' : usuario.cedula),
            _FilaDato(icon: Icons.email_outlined,   label: 'Correo',   value: usuario.email.isEmpty    ? '—' : usuario.email),
            _FilaDato(icon: Icons.phone_outlined,   label: 'Teléfono', value: usuario.telefono.isEmpty ? '—' : usuario.telefono),
          ]),

          if (usuario.barriosAsignados.isNotEmpty) ...[
            const SizedBox(height: 12),
            _SeccionDatos(titulo: 'Barrios asignados', filas: [
              ...usuario.barriosAsignados.map((b) => _FilaDato(
                icon: Icons.location_on_outlined,
                label: b.sector,
                value: b.nombre,
              )),
            ]),
          ],

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Editar perfil', style: TextStyle(fontSize: 16)),
              onPressed: () {
                // Subir al estado padre
                context.findAncestorStateOfType<_EditarUsuarioScreenState>()
                    ?._modoEdicionSetter(true);
              },
            ),
          ),
        ],
      ),
    );
  }

  String _iniciales(String nombre) {
    final partes = nombre.trim().split(' ');
    if (partes.length >= 2) return '${partes[0][0]}${partes[1][0]}'.toUpperCase();
    if (partes.isNotEmpty && partes[0].isNotEmpty) return partes[0][0].toUpperCase();
    return '?';
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Formulario de edición (modo edición)
// ═══════════════════════════════════════════════════════════════════════════════
class _FormularioEdicion extends StatelessWidget {
  final GlobalKey<FormState>     formKey;
  final TextEditingController    nombreCtrl;
  final TextEditingController    apellidoCtrl;
  final TextEditingController    telefonoCtrl;
  final bool                     isLoading;
  final VoidCallback             onGuardar;

  const _FormularioEdicion({
    required this.formKey,
    required this.nombreCtrl,
    required this.apellidoCtrl,
    required this.telefonoCtrl,
    required this.isLoading,
    required this.onGuardar,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Datos editables',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            _Campo(
              controller: nombreCtrl,
              label: 'Nombres',
              icon: Icons.person_outline,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null,
            ),
            const SizedBox(height: 12),
            _Campo(
              controller: apellidoCtrl,
              label: 'Apellidos',
              icon: Icons.person_outline,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null,
            ),
            const SizedBox(height: 12),
            _Campo(
              controller: telefonoCtrl,
              label: 'Teléfono',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null,
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: isLoading
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(isLoading ? 'Guardando...' : 'Guardar cambios'),
                onPressed: isLoading ? null : onGuardar,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Pantalla de edición de barrios (coordinador_campana → coordinador_brigada)
// ═══════════════════════════════════════════════════════════════════════════════
class _PantallaBarrios extends StatelessWidget {
  final Usuario             usuario;
  final List<String>        barriosSeleccionados;
  final UsuarioProvider     provider;
  final bool                isLoading;
  final ValueChanged<List<String>> onChanged;
  final VoidCallback        onGuardar;
  final VoidCallback        onDesactivar;

  const _PantallaBarrios({
    required this.usuario,
    required this.barriosSeleccionados,
    required this.provider,
    required this.isLoading,
    required this.onChanged,
    required this.onGuardar,
    required this.onDesactivar,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Editar barrios asignados'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PerfilVistaCard(usuario: usuario),
            const SizedBox(height: 20),
            const Text(
              'Barrios asignados',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1565C0)),
            ),
            const SizedBox(height: 4),
            const Text(
              'Selecciona los barrios que administrará este coordinador',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            if (provider.barrios.isEmpty)
              const Text('Cargando barrios...', style: TextStyle(color: Colors.grey))
            else
              ...provider.barrios.map((b) {
                final marcado = barriosSeleccionados.contains(b.id);
                return CheckboxListTile(
                  dense:          true,
                  value:          marcado,
                  title:          Text('${b.nombre} — ${b.sector}'),
                  activeColor:    const Color(0xFF1565C0),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (checked) {
                    final nueva = List<String>.from(barriosSeleccionados);
                    if (checked == true) nueva.add(b.id); else nueva.remove(b.id);
                    onChanged(nueva);
                  },
                );
              }),
            const SizedBox(height: 28),
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: isLoading
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(isLoading ? 'Guardando...' : 'Guardar barrios'),
                onPressed: isLoading ? null : onGuardar,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                side: BorderSide(color: Colors.red.shade300),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.person_off_outlined),
              label: const Text('Desactivar usuario'),
              onPressed: isLoading ? null : onDesactivar,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Widgets auxiliares
// ═══════════════════════════════════════════════════════════════════════════════

class _PerfilVistaCard extends StatelessWidget {
  final Usuario usuario;
  const _PerfilVistaCard({required this.usuario});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFF1565C0).withOpacity(0.12),
              child: Text(
                _iniciales(usuario.nombreCompleto),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1565C0),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(usuario.nombreCompleto,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(usuario.email,
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  _ChipRol(rol: usuario.rol),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _iniciales(String nombre) {
    final partes = nombre.trim().split(' ');
    if (partes.length >= 2) return '${partes[0][0]}${partes[1][0]}'.toUpperCase();
    if (partes.isNotEmpty && partes[0].isNotEmpty) return partes[0][0].toUpperCase();
    return '?';
  }
}

class _SeccionDatos extends StatelessWidget {
  final String        titulo;
  final List<_FilaDato> filas;
  const _SeccionDatos({required this.titulo, required this.filas});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1565C0),
            )),
            const SizedBox(height: 10),
            ...filas,
          ],
        ),
      ),
    );
  }
}

class _FilaDato extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  const _FilaDato({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 10),
          SizedBox(
            width: 72,
            child: Text(label,
                style: const TextStyle(fontSize: 13, color: Colors.grey)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

class _ChipRol extends StatelessWidget {
  final String rol;
  const _ChipRol({required this.rol});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: _color(rol).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color(rol).withOpacity(0.4)),
      ),
      child: Text(
        _label(rol),
        style: TextStyle(fontSize: 11, color: _color(rol), fontWeight: FontWeight.w600),
      ),
    );
  }

  Color _color(String rol) {
    switch (rol) {
      case 'coordinador_campana': return Colors.purple;
      case 'coordinador_brigada': return const Color(0xFF1565C0);
      case 'vacunador':           return const Color(0xFF00897B);
      default:                    return Colors.grey;
    }
  }

  String _label(String rol) {
    switch (rol) {
      case 'coordinador_campana': return 'Coordinador de Campaña';
      case 'coordinador_brigada': return 'Coordinador de Brigada';
      case 'vacunador':           return 'Vacunador';
      default:                    return rol;
    }
  }
}

class _Campo extends StatelessWidget {
  final TextEditingController      controller;
  final String                     label;
  final IconData                   icon;
  final TextInputType?             keyboardType;
  final String? Function(String?)? validator;

  const _Campo({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller:   controller,
      keyboardType: keyboardType,
      validator:    validator,
      decoration: InputDecoration(
        labelText:  label,
        prefixIcon: Icon(icon),
        filled:     true,
        fillColor:  Colors.white,
        border:     OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}

// Extension para acceder al setter desde el widget hijo
extension on _EditarUsuarioScreenState {
  void _modoEdicionSetter(bool valor) => setState(() => _modoEdicion = valor);
}
