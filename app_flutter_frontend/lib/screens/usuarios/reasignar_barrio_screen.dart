import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/usuario_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/usuario_provider.dart';

class ReasignarBarrioScreen extends StatefulWidget {
  final Usuario usuario;

  const ReasignarBarrioScreen({super.key, required this.usuario});

  @override
  State<ReasignarBarrioScreen> createState() => _ReasignarBarrioScreenState();
}

class _ReasignarBarrioScreenState extends State<ReasignarBarrioScreen> {
  String? _barrioSeleccionado;
  bool    _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-seleccionar el barrio actual si existe
    final barrios = widget.usuario.barriosAsignados;
    if (barrios.isNotEmpty) {
      _barrioSeleccionado = barrios.first.id;
    }
    // Cargar barrios disponibles
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UsuarioProvider>().cargarBarrios();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth     = context.watch<AuthProvider>();
    final provider = context.watch<UsuarioProvider>();

    // Solo se pueden reasignar los barrios que el coordinador tiene
    // asignados (mismo criterio que al crear un vacunador).
    final barriosPermitidos = provider.barrios
        .where((b) => auth.barriosIds.contains(b.id))
        .toList();

    // Si el barrio actual del vacunador no está entre los permitidos
    // (p. ej. fue asignado por otro coordinador), no lo dejamos
    // preseleccionado para no romper el Dropdown ni reasignar "sin querer"
    // un barrio que no le pertenece a este coordinador.
    final valorDropdown = barriosPermitidos.any((b) => b.id == _barrioSeleccionado)
        ? _barrioSeleccionado
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Reasignar barrio'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info del vacunador
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFFE3F2FD),
                      child: Icon(Icons.medical_services_outlined, color: Color(0xFF1565C0)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.usuario.nombreCompleto,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Barrio actual: ${_barrioActualNombre(provider)}',
                            style: const TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Seleccionar nuevo barrio',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1565C0),
              ),
            ),
            const SizedBox(height: 8),

            // Selector de barrios
            if (provider.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (barriosPermitidos.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'No tienes barrios asignados. Contacta al coordinador de campaña para que te asigne barrios antes de reasignar.',
                  style: TextStyle(fontSize: 13, color: Colors.deepOrange),
                ),
              )
            else if (barriosPermitidos.length < 2)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Solo tienes un barrio asignado, así que no hay otro barrio al cual reasignar. '
                  'Contacta al coordinador de campaña si necesitas un barrio adicional.',
                  style: TextStyle(fontSize: 13, color: Colors.deepOrange),
                ),
              )
            else
              DropdownButtonFormField<String>(
                value:      valorDropdown,
                isExpanded: true,
                hint:       const Text('Selecciona un barrio'),
                onChanged:  (id) => setState(() => _barrioSeleccionado = id),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  filled:     true,
                  fillColor:  Colors.white,
                  border:     OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: barriosPermitidos.map((b) {
                  return DropdownMenuItem<String>(
                    value: b.id,
                    child: Text('${b.nombre} — ${b.sector}', overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
              ),

            const SizedBox(height: 12),
            const Text(
              'Nota: los registros de vacunación anteriores conservan su barrio original.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const Spacer(),

            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: _isLoading
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.swap_horiz),
                label: Text(_isLoading ? 'Reasignando...' : 'Reasignar'),
                onPressed: (_isLoading || valorDropdown == null)
                    ? null
                    : () => _reasignar(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _barrioActualNombre(UsuarioProvider provider) {
    final barrios = widget.usuario.barriosAsignados;
    if (barrios.isEmpty) return 'Sin barrio';
    return '${barrios.first.nombre} (${barrios.first.sector})';
  }

  Future<void> _reasignar(BuildContext context) async {
    if (_barrioSeleccionado == null) return;

    setState(() => _isLoading = true);

    final provider = context.read<UsuarioProvider>();
    final result = await provider.reasignarBarrio(
      widget.usuario.id,
      _barrioSeleccionado!,
    );

    setState(() => _isLoading = false);

    if (!context.mounted) return;

    if (result['statusCode'] == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['data']['msg'] ?? 'Barrio reasignado correctamente'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['data']['msg'] ?? 'Error al reasignar barrio'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
