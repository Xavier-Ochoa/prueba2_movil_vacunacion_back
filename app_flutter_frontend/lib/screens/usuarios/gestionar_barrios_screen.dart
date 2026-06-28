import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/barrio_model.dart';
import '../../providers/barrio_provider.dart';

/// Gestión de barrios (sectores) — solo coordinador_campana.
/// Permite Crear, Editar, Eliminar y Visualizar los barrios del sistema.
class GestionarBarriosScreen extends StatefulWidget {
  const GestionarBarriosScreen({super.key});

  @override
  State<GestionarBarriosScreen> createState() => _GestionarBarriosScreenState();
}

class _GestionarBarriosScreenState extends State<GestionarBarriosScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BarrioProvider>().cargarBarrios();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BarrioProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Barrios / Sectores'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
            onPressed: () => provider.cargarBarrios(),
          ),
        ],
      ),
      body: _buildBody(context, provider),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Nuevo barrio'),
        onPressed: () => _abrirFormulario(context, provider),
      ),
    );
  }

  Widget _buildBody(BuildContext context, BarrioProvider provider) {
    if (provider.isLoading && provider.barrios.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error != null && provider.barrios.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(provider.error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => provider.cargarBarrios(),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (provider.barrios.isEmpty) {
      return const Center(
        child: Text('No hay barrios creados todavía.', style: TextStyle(color: Colors.grey)),
      );
    }

    // Agrupar por sector para que la lista sea más fácil de leer,
    // igual que se agrupan en el seeder y en el dashboard.
    final porSector = <String, List<Barrio>>{};
    for (final b in provider.barrios) {
      porSector.putIfAbsent(b.sector, () => []).add(b);
    }

    return RefreshIndicator(
      onRefresh: () => provider.cargarBarrios(),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: porSector.entries.map((entry) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 16, 8, 6),
                child: Text(
                  entry.key,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              ...entry.value.map((b) => _BarrioCard(
                    barrio: b,
                    onEditar: () => _abrirFormulario(context, provider, barrio: b),
                    onEliminar: () => _confirmarEliminar(context, provider, b),
                  )),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ─── Crear / Editar (mismo formulario, distinto título) ────────────────────
  void _abrirFormulario(
    BuildContext context,
    BarrioProvider provider, {
    Barrio? barrio,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _FormularioBarrio(barrio: barrio),
    );
  }

  // ─── Eliminar con confirmación ──────────────────────────────────────────────
  Future<void> _confirmarEliminar(
    BuildContext context,
    BarrioProvider provider,
    Barrio barrio,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar barrio'),
        content: Text(
          '¿Eliminar "${barrio.nombre}" (${barrio.sector})? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar != true || !context.mounted) return;

    final result = await provider.eliminarBarrio(barrio.id);
    if (!context.mounted) return;

    if (result['statusCode'] == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Barrio eliminado'), backgroundColor: Colors.green),
      );
    } else if (result['statusCode'] == 409 &&
        result['data']?['vacunadoresAfectados'] != null) {
      _mostrarVacunadoresAfectados(
        context,
        result['data']['msg'] ?? 'No se puede eliminar este barrio.',
        result['data']['vacunadoresAfectados'] as List,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['data']?['msg'] ?? 'Error al eliminar el barrio'),
          backgroundColor: Colors.red,
        ),
      );
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
            Text('No se puede eliminar'),
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
                'Vacunadores activos en este barrio:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              ...vacunadoresAfectados.map((v) {
                final nombre = v['nombre'] ?? 'Vacunador';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      const Icon(Icons.person, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(nombre, style: const TextStyle(fontSize: 13)),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Tarjeta de un barrio en la lista
// ─────────────────────────────────────────────────────────────────────────────

class _BarrioCard extends StatelessWidget {
  final Barrio barrio;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  const _BarrioCard({
    required this.barrio,
    required this.onEditar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: barrio.activo
              ? const Color(0xFF1565C0).withOpacity(0.12)
              : Colors.grey.withOpacity(0.15),
          child: Icon(
            Icons.location_city,
            color: barrio.activo ? const Color(0xFF1565C0) : Colors.grey,
          ),
        ),
        title: Text(barrio.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          barrio.tieneCoordinador
              ? 'Coordinador: ${barrio.coordinadorNombre}'
              : 'Sin coordinador asignado',
          style: TextStyle(
            fontSize: 12,
            color: barrio.tieneCoordinador ? Colors.grey.shade700 : Colors.orange.shade700,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ChipEstadoBarrio(activo: barrio.activo),
            PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'editar') onEditar();
                if (val == 'eliminar') onEliminar();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'editar',
                  child: Row(children: [
                    Icon(Icons.edit, size: 18),
                    SizedBox(width: 8),
                    Text('Editar'),
                  ]),
                ),
                const PopupMenuItem(
                  value: 'eliminar',
                  child: Row(children: [
                    Icon(Icons.delete, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Eliminar', style: TextStyle(color: Colors.red)),
                  ]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipEstadoBarrio extends StatelessWidget {
  final bool activo;
  const _ChipEstadoBarrio({required this.activo});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: activo ? Colors.green.shade50 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: activo ? Colors.green.shade200 : Colors.grey.shade400),
      ),
      child: Text(
        activo ? 'Activo' : 'Inactivo',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: activo ? Colors.green.shade800 : Colors.grey.shade700,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Formulario (bottom sheet) — Crear / Editar
// ─────────────────────────────────────────────────────────────────────────────

class _FormularioBarrio extends StatefulWidget {
  final Barrio? barrio; // null = creando uno nuevo

  const _FormularioBarrio({this.barrio});

  @override
  State<_FormularioBarrio> createState() => _FormularioBarrioState();
}

class _FormularioBarrioState extends State<_FormularioBarrio> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  String? _sectorSeleccionado;
  String  _estadoSeleccionado = 'activo';
  bool    _isLoading = false;

  bool get _esEdicion => widget.barrio != null;

  @override
  void initState() {
    super.initState();
    if (widget.barrio != null) {
      _nombreCtrl.text       = widget.barrio!.nombre;
      _sectorSeleccionado    = widget.barrio!.sector;
      _estadoSeleccionado    = widget.barrio!.estado;
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar(BuildContext context) async {
    if (!_formKey.currentState!.validate() || _sectorSeleccionado == null) {
      if (_sectorSeleccionado == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona un sector')),
        );
      }
      return;
    }

    setState(() => _isLoading = true);
    final provider = context.read<BarrioProvider>();

    final result = _esEdicion
        ? await provider.actualizarBarrio(
            id:     widget.barrio!.id,
            nombre: _nombreCtrl.text.trim(),
            sector: _sectorSeleccionado,
            estado: _estadoSeleccionado,
          )
        : await provider.crearBarrio(
            nombre: _nombreCtrl.text.trim(),
            sector: _sectorSeleccionado!,
          );

    setState(() => _isLoading = false);
    if (!context.mounted) return;

    final exito = result['statusCode'] == 200 || result['statusCode'] == 201;
    if (exito) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_esEdicion ? 'Barrio actualizado' : 'Barrio creado'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (result['statusCode'] == 409 &&
        result['data']?['vacunadoresAfectados'] != null) {
      _mostrarVacunadoresAfectados(
        context,
        result['data']['msg'] ?? 'No se puede inactivar este barrio.',
        result['data']['vacunadoresAfectados'] as List,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['data']?['msg'] ?? 'Error al guardar el barrio'),
          backgroundColor: Colors.red,
        ),
      );
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
            Text('No se puede inactivar'),
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
                'Vacunadores activos en este barrio:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              ...vacunadoresAfectados.map((v) {
                final nombre = v['nombre'] ?? 'Vacunador';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      const Icon(Icons.person, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(nombre, style: const TextStyle(fontSize: 13)),
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _esEdicion ? 'Editar barrio' : 'Nuevo barrio',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _nombreCtrl,
              decoration: InputDecoration(
                labelText: 'Nombre del barrio',
                prefixIcon: const Icon(Icons.location_city),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'El nombre es obligatorio' : null,
            ),
            const SizedBox(height: 14),

            DropdownButtonFormField<String>(
              value: _sectorSeleccionado,
              isExpanded: true,
              hint: const Text('Selecciona un sector'),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.map_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              items: Barrio.sectoresValidos
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _sectorSeleccionado = v),
            ),

            // El estado solo se edita en barrios existentes; al crear uno
            // nuevo siempre nace 'activo' (igual que el default del backend).
            if (_esEdicion) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  const Text('Estado:', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 12),
                  ChoiceChip(
                    label: const Text('Activo'),
                    selected: _estadoSeleccionado == 'activo',
                    onSelected: (_) => setState(() => _estadoSeleccionado = 'activo'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Inactivo'),
                    selected: _estadoSeleccionado == 'inactivo',
                    onSelected: (_) => setState(() => _estadoSeleccionado = 'inactivo'),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: _isLoading
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(_isLoading
                    ? 'Guardando...'
                    : (_esEdicion ? 'Guardar cambios' : 'Crear barrio')),
                onPressed: _isLoading ? null : () => _guardar(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
