import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/usuario_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/usuario_provider.dart';

class CrearUsuarioScreen extends StatefulWidget {
  const CrearUsuarioScreen({super.key});

  @override
  State<CrearUsuarioScreen> createState() => _CrearUsuarioScreenState();
}

class _CrearUsuarioScreenState extends State<CrearUsuarioScreen> {
  final _formKey   = GlobalKey<FormState>();
  bool  _isLoading = false;

  // Controladores
  final _nombreCtrl    = TextEditingController();
  final _apellidoCtrl  = TextEditingController();
  final _cedulaCtrl    = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _telefonoCtrl  = TextEditingController();

  // Selección de barrios
  String?      _barrioSeleccionado;           // vacunador: un solo barrio
  List<String> _barriosSeleccionados = [];    // coordinador_brigada: varios

  @override
  void initState() {
    super.initState();
    // Cargar barrios disponibles
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UsuarioProvider>().cargarBarrios();
    });
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _cedulaCtrl.dispose();
    _emailCtrl.dispose();
    _telefonoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth     = context.watch<AuthProvider>();
    final provider = context.watch<UsuarioProvider>();
    final esCampana = auth.esCoordinadorCampana;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(esCampana ? 'Nuevo Coordinador de Brigada' : 'Nuevo Vacunador'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Datos personales ────────────────────────────────────────
              _SectionTitle(title: 'Datos personales'),
              const SizedBox(height: 8),
              _Campo(
                controller: _nombreCtrl,
                label: 'Nombres',
                icon: Icons.person_outline,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Campo obligatorio' : null,
              ),
              const SizedBox(height: 12),
              _Campo(
                controller: _apellidoCtrl,
                label: 'Apellidos',
                icon: Icons.person_outline,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Campo obligatorio' : null,
              ),
              const SizedBox(height: 12),
              _Campo(
                controller: _cedulaCtrl,
                label: 'Cédula',
                icon: Icons.badge_outlined,
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Campo obligatorio';
                  if (v.trim().length != 10) return 'La cédula debe tener 10 dígitos';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _Campo(
                controller: _emailCtrl,
                label: 'Correo electrónico',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Campo obligatorio';
                  if (!v.contains('@')) return 'Correo inválido';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _Campo(
                controller: _telefonoCtrl,
                label: 'Teléfono',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Campo obligatorio' : null,
              ),
              const SizedBox(height: 20),

              // ── Asignación de barrios ────────────────────────────────────
              _SectionTitle(title: esCampana ? 'Barrios a administrar (opcional)' : 'Barrio asignado'),
              const SizedBox(height: 8),

              if (provider.barrios.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Cargando barrios...',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              else if (esCampana)
                _SelectorBarriosMultiple(
                  barrios: provider.barrios,
                  seleccionados: _barriosSeleccionados,
                  onChanged: (lista) => setState(() => _barriosSeleccionados = lista),
                )
              else
                _SelectorBarrioUnico(
                  // coordinador_brigada solo ve SUS barrios asignados
                  barrios: provider.barrios
                      .where((b) => auth.barriosIds.contains(b.id))
                      .toList(),
                  seleccionado: _barrioSeleccionado,
                  onChanged: (id) => setState(() => _barrioSeleccionado = id),
                ),
              if (!esCampana &&
                  provider.barrios.isNotEmpty &&
                  auth.barriosIds.isEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    border: Border.all(color: Colors.orange.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'No tienes barrios asignados. Contacta al coordinador de campaña para que te asigne barrios antes de crear vacunadores.',
                    style: TextStyle(fontSize: 13, color: Colors.deepOrange),
                  ),
                ),

              const SizedBox(height: 28),

              // ── Botón guardar ────────────────────────────────────────────
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
                      : const Icon(Icons.check),
                  label: Text(_isLoading ? 'Creando...' : 'Crear usuario'),
                  onPressed: _isLoading ? null : () => _submit(context, provider, esCampana),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit(
    BuildContext context,
    UsuarioProvider provider,
    bool esCampana,
  ) async {
    if (!_formKey.currentState!.validate()) return;

    // Validar barrio obligatorio para vacunador
    if (!esCampana && _barrioSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes seleccionar un barrio para el vacunador.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    Map<String, dynamic> result;

    if (esCampana) {
      result = await provider.crearCoordinadorBrigada(
        nombre:     _nombreCtrl.text.trim(),
        apellido:   _apellidoCtrl.text.trim(),
        cedula:     _cedulaCtrl.text.trim(),
        email:      _emailCtrl.text.trim(),
        telefono:   _telefonoCtrl.text.trim(),
        barriosIds: _barriosSeleccionados.isEmpty ? null : _barriosSeleccionados,
      );
    } else {
      result = await provider.crearVacunador(
        nombre:   _nombreCtrl.text.trim(),
        apellido: _apellidoCtrl.text.trim(),
        cedula:   _cedulaCtrl.text.trim(),
        email:    _emailCtrl.text.trim(),
        telefono: _telefonoCtrl.text.trim(),
        barrioId: _barrioSeleccionado!,
      );
    }

    setState(() => _isLoading = false);

    if (!context.mounted) return;

    if (result['statusCode'] == 201) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['data']['msg'] ?? 'Usuario creado exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['data']['msg'] ?? 'Error al crear usuario'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widgets auxiliares
// ─────────────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1565C0),
      ),
    );
  }
}

class _Campo extends StatelessWidget {
  final TextEditingController controller;
  final String                label;
  final IconData              icon;
  final TextInputType?        keyboardType;
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
        labelText:   label,
        prefixIcon:  Icon(icon),
        filled:      true,
        fillColor:   Colors.white,
        border:      OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}

class _SelectorBarrioUnico extends StatelessWidget {
  final List<BarrioResumen> barrios;
  final String?             seleccionado;
  final ValueChanged<String?> onChanged;

  const _SelectorBarrioUnico({
    required this.barrios,
    required this.seleccionado,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value:       seleccionado,
      isExpanded:  true,
      hint:        const Text('Selecciona un barrio'),
      onChanged:   onChanged,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.location_on_outlined),
        filled:     true,
        fillColor:  Colors.white,
        border:     OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      items: barrios.map((b) {
        return DropdownMenuItem<String>(
          value: b.id,
          child: Text('${b.nombre} — ${b.sector}', overflow: TextOverflow.ellipsis),
        );
      }).toList(),
    );
  }
}

class _SelectorBarriosMultiple extends StatelessWidget {
  final List<BarrioResumen> barrios;
  final List<String>        seleccionados;
  final ValueChanged<List<String>> onChanged;

  const _SelectorBarriosMultiple({
    required this.barrios,
    required this.seleccionados,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: barrios.map((b) {
        final marcado = seleccionados.contains(b.id);
        return CheckboxListTile(
          dense:         true,
          value:         marcado,
          title:         Text('${b.nombre} — ${b.sector}'),
          activeColor:   const Color(0xFF1565C0),
          contentPadding: EdgeInsets.zero,
          onChanged: (checked) {
            final nueva = List<String>.from(seleccionados);
            if (checked == true) {
              nueva.add(b.id);
            } else {
              nueva.remove(b.id);
            }
            onChanged(nueva);
          },
        );
      }).toList(),
    );
  }
}
