import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../providers/vacunacion_provider.dart';
import '../../models/vacunacion_model.dart';
import '../../services/connectivity_service.dart';

/// Modo de registro elegido por el usuario en la pantalla de creación.
enum ModoRegistro { online, offline }

class FormVacunacionScreen extends StatefulWidget {
  final Vacunacion? vacunacion; // null = crear, no null = editar

  const FormVacunacionScreen({super.key, this.vacunacion});

  @override
  State<FormVacunacionScreen> createState() => _FormVacunacionScreenState();
}

class _FormVacunacionScreenState extends State<FormVacunacionScreen> {
  final _formKey = GlobalKey<FormState>();

  // Modo de registro (solo aplica en creación, no en edición)
  ModoRegistro _modoRegistro = ModoRegistro.online;
  bool _verificandoConexion = false;

  // Controllers propietario
  final _propNombreCtrl   = TextEditingController();
  final _propCedulaCtrl   = TextEditingController();
  final _propTelefonoCtrl = TextEditingController();

  // Controllers mascota
  final _mascNombreCtrl = TextEditingController();
  final _mascEdadCtrl   = TextEditingController();
  String _mascTipo = 'perro';
  String _mascSexo = 'macho';

  // Controllers vacuna
  final _vacunaCtrl        = TextEditingController();
  final _observacionesCtrl = TextEditingController();

  // Imagen
  File? _imagenFile;
  bool  _imagenObligatoria = false;

  // GPS
  double? _latitud;
  double? _longitud;
  bool    _cargandoGps = false;
  String  _gpsStatus   = 'Obteniendo ubicación...';

  bool get _esEdicion => widget.vacunacion != null;

  @override
  void initState() {
    super.initState();
    if (_esEdicion) {
      final v = widget.vacunacion!;
      _propNombreCtrl.text    = v.propietario.nombre;
      _propCedulaCtrl.text    = v.propietario.cedula;
      _propTelefonoCtrl.text  = v.propietario.telefono;
      _mascNombreCtrl.text    = v.mascota.nombre;
      _mascEdadCtrl.text      = v.mascota.edad.toString();
      _mascTipo               = v.mascota.tipo;
      _mascSexo               = v.mascota.sexo;
      _vacunaCtrl.text        = v.vacuna;
      _observacionesCtrl.text = v.observaciones;
      if (v.ubicacion.tieneUbicacion) {
        _latitud   = v.ubicacion.latitud;
        _longitud  = v.ubicacion.longitud;
        _gpsStatus = 'Lat: ${_latitud!.toStringAsFixed(5)}, Lon: ${_longitud!.toStringAsFixed(5)}';
      } else {
        _gpsStatus = 'Sin ubicación';
      }
    } else {
      _capturarUbicacion();
    }
  }

  @override
  void dispose() {
    _propNombreCtrl.dispose();
    _propCedulaCtrl.dispose();
    _propTelefonoCtrl.dispose();
    _mascNombreCtrl.dispose();
    _mascEdadCtrl.dispose();
    _vacunaCtrl.dispose();
    _observacionesCtrl.dispose();
    super.dispose();
  }

  // ── IMAGEN ──────────────────────────────────────────────────────────────────
  Future<void> _seleccionarImagen(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source:       source,
      maxWidth:     800,
      maxHeight:    800,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() {
        _imagenFile        = File(picked.path);
        _imagenObligatoria = false;
      });
    }
  }

  void _mostrarOpcionesImagen() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Tomar foto'),
              onTap: () {
                Navigator.pop(context);
                _seleccionarImagen(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galería'),
              onTap: () {
                Navigator.pop(context);
                _seleccionarImagen(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── GPS ─────────────────────────────────────────────────────────────────────
  Future<void> _capturarUbicacion() async {
    if (!mounted) return;
    setState(() {
      _cargandoGps = true;
      _gpsStatus   = 'Obteniendo ubicación...';
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          setState(() {
            _cargandoGps = false;
            _gpsStatus   = 'No se pudo obtener ubicación (puedes continuar sin ella)';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _cargandoGps = false;
          _gpsStatus   = 'No se pudo obtener ubicación (puedes continuar sin ella)';
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      if (!mounted) return;
      setState(() {
        _latitud     = pos.latitude;
        _longitud    = pos.longitude;
        _cargandoGps = false;
        _gpsStatus   = 'Lat: ${_latitud!.toStringAsFixed(5)}, Lon: ${_longitud!.toStringAsFixed(5)}';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cargandoGps = false;
        _gpsStatus   = 'No se pudo obtener ubicación (puedes continuar sin ella)';
      });
    }
  }

  // ── CAMBIO DE MODO ───────────────────────────────────────────────────────────
  /// Al elegir modo online se verifica que haya internet de inmediato
  /// para advertir al usuario antes de que intente guardar.
  Future<void> _cambiarModo(ModoRegistro modo) async {
    if (modo == ModoRegistro.online) {
      setState(() => _verificandoConexion = true);
      final hayInternet = await ConnectivityService().tieneConexion();
      if (!mounted) return;
      setState(() => _verificandoConexion = false);

      if (!hayInternet) {
        // Mostramos el diálogo y dejamos el selector en offline.
        _mostrarDialogoSinConexion();
        return;
      }
    }
    setState(() => _modoRegistro = modo);
  }

  void _mostrarDialogoSinConexion() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: const [
            Icon(Icons.wifi_off, color: Colors.red),
            SizedBox(width: 8),
            Text('Sin conexión'),
          ],
        ),
        content: const Text(
          'No puedes registrar en modo online porque no hay conexión a internet.\n\n'
          'Puedes cambiar a modo offline para guardar el registro en este '
          'dispositivo y sincronizarlo manualmente cuando recuperes la señal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0)),
            onPressed: () {
              Navigator.pop(context);
              setState(() => _modoRegistro = ModoRegistro.offline);
            },
            child: const Text('Usar modo offline', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── GUARDAR ─────────────────────────────────────────────────────────────────
  Future<void> _guardar() async {
    if (!_esEdicion && _imagenFile == null) {
      setState(() => _imagenObligatoria = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:         Text('La fotografía de la mascota es obligatoria'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<VacunacionProvider>();

    if (_esEdicion) {
      // La edición mantiene el flujo offline-first original sin cambios.
      await provider.editarVacunacion(
        clienteId:           widget.vacunacion!.clienteId ?? widget.vacunacion!.id,
        propietarioNombre:   _propNombreCtrl.text.trim(),
        propietarioCedula:   _propCedulaCtrl.text.trim(),
        propietarioTelefono: _propTelefonoCtrl.text.trim(),
        mascotaTipo:         _mascTipo,
        mascotaNombre:       _mascNombreCtrl.text.trim(),
        mascotaEdad:         int.tryParse(_mascEdadCtrl.text) ?? 0,
        mascotaSexo:         _mascSexo,
        vacuna:              _vacunaCtrl.text.trim(),
        observaciones:       _observacionesCtrl.text.trim(),
        imagen:              _imagenFile,
        latitud:             _latitud,
        longitud:            _longitud,
        original:            widget.vacunacion,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:         Text('Cambios guardados. Se sincronizarán automáticamente.'),
          backgroundColor: Colors.green,
          duration:        Duration(seconds: 3),
        ),
      );
      Navigator.pop(context);
      return;
    }

    // ── CREACIÓN según modo elegido ──────────────────────────────────────────
    if (_modoRegistro == ModoRegistro.online) {
      await _guardarOnline(provider);
    } else {
      await _guardarOffline(provider);
    }
  }

  Future<void> _guardarOnline(VacunacionProvider provider) async {
    try {
      await provider.crearVacunacionOnline(
        propietarioNombre:   _propNombreCtrl.text.trim(),
        propietarioCedula:   _propCedulaCtrl.text.trim(),
        propietarioTelefono: _propTelefonoCtrl.text.trim(),
        mascotaTipo:         _mascTipo,
        mascotaNombre:       _mascNombreCtrl.text.trim(),
        mascotaEdad:         int.tryParse(_mascEdadCtrl.text) ?? 0,
        mascotaSexo:         _mascSexo,
        vacuna:              _vacunaCtrl.text.trim(),
        observaciones:       _observacionesCtrl.text.trim(),
        imagen:              _imagenFile!,
        latitud:             _latitud,
        longitud:            _longitud,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:         Text('Vacunación registrada exitosamente en el servidor.'),
          backgroundColor: Colors.green,
          duration:        Duration(seconds: 3),
        ),
      );
      Navigator.pop(context);
    } on SinConexionException catch (e) {
      if (!mounted) return;
      // El usuario perdió internet justo al guardar (raro, pero posible).
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(
            children: const [
              Icon(Icons.wifi_off, color: Colors.red),
              SizedBox(width: 8),
              Text('Sin conexión'),
            ],
          ),
          content: Text(e.mensaje),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0)),
              onPressed: () {
                Navigator.pop(context);
                setState(() => _modoRegistro = ModoRegistro.offline);
              },
              child: const Text('Cambiar a offline', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } on ErrorBackendException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:         Text('Error: ${e.mensaje}'),
          backgroundColor: Colors.red,
          duration:        const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _guardarOffline(VacunacionProvider provider) async {
    await provider.crearVacunacionOffline(
      propietarioNombre:   _propNombreCtrl.text.trim(),
      propietarioCedula:   _propCedulaCtrl.text.trim(),
      propietarioTelefono: _propTelefonoCtrl.text.trim(),
      mascotaTipo:         _mascTipo,
      mascotaNombre:       _mascNombreCtrl.text.trim(),
      mascotaEdad:         int.tryParse(_mascEdadCtrl.text) ?? 0,
      mascotaSexo:         _mascSexo,
      vacuna:              _vacunaCtrl.text.trim(),
      observaciones:       _observacionesCtrl.text.trim(),
      imagen:              _imagenFile!,
      latitud:             _latitud,
      longitud:            _longitud,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Registro guardado localmente. Usa el botón "Sincronizar" '
          'en la lista cuando tengas conexión.',
        ),
        backgroundColor: Colors.orange,
        duration:        Duration(seconds: 4),
      ),
    );
    Navigator.pop(context);
  }

  // ── BUILD ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<VacunacionProvider>().isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(_esEdicion ? 'Editar Vacunación' : 'Registrar Vacunación'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [

            // ── SELECTOR DE MODO (solo en creación) ───────────────────────────
            if (!_esEdicion) ...[
              _SectionTitle('Modo de registro'),
              _verificandoConexion
                  ? const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 10),
                          Text('Verificando conexión...', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: _ModoBoton(
                              icono:      Icons.cloud_upload_outlined,
                              etiqueta:   'Online',
                              descripcion: 'Directo al servidor',
                              seleccionado: _modoRegistro == ModoRegistro.online,
                              color:      const Color(0xFF1565C0),
                              onTap:      () => _cambiarModo(ModoRegistro.online),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ModoBoton(
                              icono:      Icons.save_outlined,
                              etiqueta:   'Offline',
                              descripcion: 'Guardar en dispositivo',
                              seleccionado: _modoRegistro == ModoRegistro.offline,
                              color:      Colors.orange.shade700,
                              onTap:      () => _cambiarModo(ModoRegistro.offline),
                            ),
                          ),
                        ],
                      ),
                    ),

              // Aviso contextual según modo
              if (_modoRegistro == ModoRegistro.offline)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    border: Border.all(color: Colors.orange.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange.shade700, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'El registro se guardará en este dispositivo. '
                          'Usa el botón "Sincronizar" en la lista de vacunaciones '
                          'para subirlo al servidor cuando quieras.',
                          style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                        ),
                      ),
                    ],
                  ),
                ),

              if (_modoRegistro == ModoRegistro.online)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    border: Border.all(color: Colors.blue.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'El registro se enviará directamente al servidor. '
                          'Requiere conexión a internet activa.',
                          style: TextStyle(fontSize: 12, color: Colors.blue.shade800),
                        ),
                      ),
                    ],
                  ),
                ),

              const Divider(height: 8),
              const SizedBox(height: 8),
            ],

            // ── IMAGEN ────────────────────────────────────────────────────────
            _SectionTitle('Fotografía de la Mascota'),
            GestureDetector(
              onTap: _mostrarOpcionesImagen,
              child: Container(
                height:      180,
                decoration: BoxDecoration(
                  color:  _imagenObligatoria
                      ? Colors.red.shade50
                      : Colors.grey.shade100,
                  border: Border.all(
                    color: _imagenObligatoria ? Colors.red : Colors.grey.shade300,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _imagenFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(_imagenFile!, fit: BoxFit.cover),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt,
                            size:  48,
                            color: _imagenObligatoria ? Colors.red : Colors.grey,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _esEdicion
                                ? 'Toca para cambiar foto'
                                : 'Toca para capturar foto *',
                            style: TextStyle(
                              color: _imagenObligatoria ? Colors.red : Colors.grey,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),

            // ── GPS ───────────────────────────────────────────────────────────
            _SectionTitle('Ubicación GPS (opcional)'),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _gpsStatus,
                    style: TextStyle(
                      fontSize: 13,
                      color: _latitud != null
                          ? Colors.green
                          : (_cargandoGps ? Colors.grey : Colors.orange.shade700),
                    ),
                  ),
                ),
                TextButton.icon(
                  icon: _cargandoGps
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                  label: Text(_cargandoGps ? 'Buscando...' : 'Reintentar'),
                  onPressed: _cargandoGps ? null : _capturarUbicacion,
                ),
              ],
            ),
            const Divider(height: 24),

            // ── PROPIETARIO ───────────────────────────────────────────────────
            _SectionTitle('Datos del Propietario'),
            _CampoTexto(
              controller: _propNombreCtrl,
              label:      'Nombre completo',
              icon:       Icons.person_outline,
              validator:  (v) => v!.isEmpty ? 'Requerido' : null,
            ),
            _CampoTexto(
              controller:   _propCedulaCtrl,
              label:        'Cédula',
              icon:         Icons.badge_outlined,
              keyboardType: TextInputType.number,
              validator:    (v) => v!.isEmpty ? 'Requerido' : null,
            ),
            _CampoTexto(
              controller:   _propTelefonoCtrl,
              label:        'Teléfono',
              icon:         Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              validator:    (v) => v!.isEmpty ? 'Requerido' : null,
            ),

            // ── MASCOTA ───────────────────────────────────────────────────────
            _SectionTitle('Datos de la Mascota'),
            _CampoTexto(
              controller: _mascNombreCtrl,
              label:      'Nombre de la mascota',
              icon:       Icons.pets,
              validator:  (v) => v!.isEmpty ? 'Requerido' : null,
            ),
            Row(
              children: [
                Expanded(
                  child: _DropdownField<String>(
                    label:     'Tipo',
                    value:     _mascTipo,
                    items:     const ['perro', 'gato'],
                    labels:    const ['Perro', 'Gato'],
                    onChanged: (v) => setState(() => _mascTipo = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DropdownField<String>(
                    label:     'Sexo',
                    value:     _mascSexo,
                    items:     const ['macho', 'hembra'],
                    labels:    const ['Macho', 'Hembra'],
                    onChanged: (v) => setState(() => _mascSexo = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _CampoTexto(
              controller:   _mascEdadCtrl,
              label:        'Edad (años)',
              icon:         Icons.cake_outlined,
              keyboardType: TextInputType.number,
              validator:    (v) {
                if (v!.isEmpty) return 'Requerido';
                if (int.tryParse(v) == null) return 'Solo números';
                return null;
              },
            ),

            // ── VACUNA ────────────────────────────────────────────────────────
            _SectionTitle('Vacuna'),
            _CampoTexto(
              controller: _vacunaCtrl,
              label:      'Vacuna aplicada',
              icon:       Icons.vaccines,
              validator:  (v) => v!.isEmpty ? 'Requerido' : null,
            ),
            _CampoTexto(
              controller: _observacionesCtrl,
              label:      'Observaciones',
              icon:       Icons.notes,
              maxLines:   3,
              validator:  (_) => null,
            ),

            const SizedBox(height: 24),

            // ── BOTÓN GUARDAR ─────────────────────────────────────────────────
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                icon: isLoading
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save, color: Colors.white),
                label: Text(
                  isLoading
                      ? 'Guardando...'
                      : _esEdicion
                          ? 'Actualizar'
                          : (_modoRegistro == ModoRegistro.online
                              ? 'Registrar Online'
                              : 'Guardar Offline'),
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
                onPressed: isLoading ? null : _guardar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _modoRegistro == ModoRegistro.offline && !_esEdicion
                      ? Colors.orange.shade700
                      : const Color(0xFF1565C0),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ── Widget selector de modo ──────────────────────────────────────────────────

class _ModoBoton extends StatelessWidget {
  final IconData icono;
  final String etiqueta;
  final String descripcion;
  final bool seleccionado;
  final Color color;
  final VoidCallback onTap;

  const _ModoBoton({
    required this.icono,
    required this.etiqueta,
    required this.descripcion,
    required this.seleccionado,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            color: seleccionado ? color.withOpacity(0.1) : Colors.grey.shade100,
            border: Border.all(
              color: seleccionado ? color : Colors.grey.shade300,
              width: seleccionado ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, color: seleccionado ? color : Colors.grey, size: 28),
              const SizedBox(height: 4),
              Text(
                etiqueta,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: seleccionado ? color : Colors.grey.shade700,
                  fontSize: 14,
                ),
              ),
              Text(
                descripcion,
                style: TextStyle(
                  fontSize: 10,
                  color: seleccionado ? color.withOpacity(0.8) : Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}

// ── Widgets helpers (sin cambios respecto al original) ───────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 10),
        child: Text(
          text,
          style: const TextStyle(
            fontSize:   15,
            fontWeight: FontWeight.bold,
            color:      Color(0xFF1565C0),
          ),
        ),
      );
}

class _CampoTexto extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final int maxLines;

  const _CampoTexto({
    required this.controller,
    required this.label,
    required this.icon,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.maxLines     = 1,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller:   controller,
          keyboardType: keyboardType,
          maxLines:     maxLines,
          validator:    validator,
          decoration: InputDecoration(
            labelText:  label,
            prefixIcon: Icon(icon),
            border:     const OutlineInputBorder(),
            isDense:    true,
          ),
        ),
      );
}

class _DropdownField<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> items;
  final List<String> labels;
  final ValueChanged<T?> onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.labels,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
        value:   value,
        decoration: InputDecoration(
          labelText: label,
          border:    const OutlineInputBorder(),
          isDense:   true,
        ),
        items: List.generate(
          items.length,
          (i) => DropdownMenuItem(value: items[i], child: Text(labels[i])),
        ),
        onChanged: onChanged,
      );
}