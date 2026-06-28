import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../models/vacunacion_model.dart';
import '../../models/local/vacunacion_local.dart';

class DetalleVacunacionScreen extends StatelessWidget {
  final Vacunacion vacunacion;

  const DetalleVacunacionScreen({super.key, required this.vacunacion});

  @override
  Widget build(BuildContext context) {
    final v   = vacunacion;
    final fmt = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: Text(v.mascota.nombre),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          // Imagen (local si aún no se sincroniza, remota si ya existe en Cloudinary)
          Hero(
            tag: v.id,
            child: v.usarImagenLocal
                ? Image.file(
                    File(v.imagenLocalPath!),
                    height: 250,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 250,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.broken_image, size: 60),
                    ),
                  )
                : CachedNetworkImage(
                    imageUrl:    v.imagenUrl,
                    height:      250,
                    width:       double.infinity,
                    fit:         BoxFit.cover,
                    placeholder: (_, __) => Container(
                      height: 250,
                      color:  Colors.grey.shade200,
                      child:  const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      height: 250,
                      color:  Colors.grey.shade200,
                      child:  const Icon(Icons.broken_image, size: 60),
                    ),
                  ),
          ),

          if (v.estadoSync != EstadoSync.sincronizado)
            Container(
              width: double.infinity,
              color: v.estadoSync == EstadoSync.error
                  ? Colors.red.shade50
                  : Colors.orange.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    v.estadoSync == EstadoSync.error
                        ? Icons.error_outline
                        : Icons.cloud_upload_outlined,
                    size: 18,
                    color: v.estadoSync == EstadoSync.error
                        ? Colors.red
                        : Colors.orange.shade800,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      v.estadoSync == EstadoSync.error
                          ? 'No se pudo sincronizar todavía. Se reintentará automáticamente.'
                          : 'Pendiente de sincronizar con el servidor.',
                      style: TextStyle(
                        fontSize: 12,
                        color: v.estadoSync == EstadoSync.error
                            ? Colors.red.shade900
                            : Colors.orange.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Encabezado mascota
                Row(
                  children: [
                    Icon(
                      v.mascota.tipo == 'perro'
                          ? Icons.pets
                          : Icons.catching_pokemon,
                      color: const Color(0xFF1565C0),
                      size: 28,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      v.mascota.nombre,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${v.mascota.tipo.toUpperCase()} · ${v.mascota.sexo} · ${v.mascota.edad} años',
                  style: const TextStyle(color: Colors.grey),
                ),
                const Divider(height: 24),

                _InfoSection(
                  title: 'Propietario',
                  children: [
                    _InfoRow(Icons.person,  'Nombre',   v.propietario.nombre),
                    _InfoRow(Icons.badge,   'Cédula',   v.propietario.cedula),
                    _InfoRow(Icons.phone,   'Teléfono', v.propietario.telefono),
                  ],
                ),
                _InfoSection(
                  title: 'Vacunación',
                  children: [
                    _InfoRow(Icons.vaccines,    'Vacuna',        v.vacuna),
                    _InfoRow(Icons.location_city, 'Barrio',       '${v.barrioNombre} (${v.barrioSector})'),
                    _InfoRow(Icons.person_pin,  'Vacunador',     v.vacunadorNombre),
                    _InfoRow(Icons.access_time, 'Fecha/Hora',    fmt.format(v.fechaRegistro.toLocal())),
                    if (v.observaciones.isNotEmpty)
                      _InfoRow(Icons.notes, 'Observaciones', v.observaciones),
                  ],
                ),
                if (v.ubicacion.tieneUbicacion)
                  _InfoSection(
                    title: 'Ubicación GPS',
                    children: [
                      _InfoRow(Icons.location_on, 'Latitud',  v.ubicacion.latitud!.toStringAsFixed(6)),
                      _InfoRow(Icons.location_on, 'Longitud', v.ubicacion.longitud!.toStringAsFixed(6)),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _InfoSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1565C0),
            ),
          ),
          const SizedBox(height: 8),
          ...children,
          const Divider(height: 20),
        ],
      );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: Colors.grey),
            const SizedBox(width: 8),
            Text('$label: ', style: const TextStyle(color: Colors.grey, fontSize: 13)),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
}
