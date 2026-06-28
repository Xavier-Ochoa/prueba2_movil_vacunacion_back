import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/auth_provider.dart';
import '../../providers/vacunacion_provider.dart';
import '../../models/vacunacion_model.dart';
import '../../models/local/vacunacion_local.dart';
import 'form_vacunacion_screen.dart';
import 'detalle_vacunacion_screen.dart';

class ListaVacunacionesScreen extends StatefulWidget {
  const ListaVacunacionesScreen({super.key});

  @override
  State<ListaVacunacionesScreen> createState() => _ListaVacunacionesScreenState();
}

class _ListaVacunacionesScreenState extends State<ListaVacunacionesScreen> {
  String _busqueda = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VacunacionProvider>().cargarVacunaciones();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth        = context.watch<AuthProvider>();
    final vacProvider = context.watch<VacunacionProvider>();
    final lista       = vacProvider.vacunaciones
        .where((v) =>
            v.propietario.nombre.toLowerCase().contains(_busqueda.toLowerCase()) ||
            v.mascota.nombre.toLowerCase().contains(_busqueda.toLowerCase()) ||
            v.barrioNombre.toLowerCase().contains(_busqueda.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vacunaciones'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        actions: [
          if (vacProvider.totalPendientes > 0)
            IconButton(
              tooltip: vacProvider.sincronizando
                  ? (vacProvider.estadoSync.isEmpty
                      ? 'Sincronizando...'
                      : vacProvider.estadoSync)
                  : 'Sincronizar ahora (${vacProvider.totalPendientes} pendientes)',
              icon: Badge(
                label: Text('${vacProvider.totalPendientes}'),
                child: vacProvider.sincronizando
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload_outlined),
              ),
              onPressed: vacProvider.sincronizando
                  ? null
                  : () => vacProvider.intentarSincronizarAhora(),
            ),
        ],
      ),
      floatingActionButton: auth.esVacunador
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF1565C0),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Registrar', style: TextStyle(color: Colors.white)),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FormVacunacionScreen()),
              ).then((_) => context.read<VacunacionProvider>().cargarVacunaciones()),
            )
          : null,
      body: Column(
        children: [
          // Buscador
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText:     'Buscar por propietario, mascota o barrio...',
                prefixIcon:   const Icon(Icons.search),
                border:       OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                filled:       true,
                fillColor:    Colors.white,
              ),
              onChanged: (v) => setState(() => _busqueda = v),
            ),
          ),

          // Lista
          Expanded(
            child: vacProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : (lista.isEmpty && vacProvider.error.isNotEmpty)
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
                              const SizedBox(height: 12),
                              Text(
                                vacProvider.error,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.grey),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.refresh),
                                label: const Text('Reintentar'),
                                onPressed: () =>
                                    context.read<VacunacionProvider>().cargarVacunaciones(),
                              ),
                            ],
                          ),
                        ),
                      )
                    : lista.isEmpty
                    ? const Center(
                        child: Text(
                          'No hay vacunaciones registradas',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: vacProvider.cargarVacunaciones,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: lista.length,
                          itemBuilder: (ctx, i) =>
                              _VacunacionCard(vacunacion: lista[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _VacunacionCard extends StatelessWidget {
  final Vacunacion vacunacion;

  const _VacunacionCard({required this.vacunacion});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DetalleVacunacionScreen(vacunacion: vacunacion),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Imagen (local si aún no se sincroniza, remota si ya existe en Cloudinary)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: vacunacion.usarImagenLocal
                    ? Image.file(
                        File(vacunacion.imagenLocalPath!),
                        width:  70,
                        height: 70,
                        fit:    BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 70, height: 70,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.broken_image, color: Colors.grey),
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl:    vacunacion.imagenUrl,
                        width:       70,
                        height:      70,
                        fit:         BoxFit.cover,
                        placeholder: (_, __) => Container(
                          width: 70, height: 70,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.pets, color: Colors.grey),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          width: 70, height: 70,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.broken_image, color: Colors.grey),
                        ),
                      ),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            vacunacion.mascota.nombre,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (vacunacion.estadoSync != EstadoSync.sincronizado)
                          _BadgeEstado(estado: vacunacion.estadoSync),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          vacunacion.mascota.tipo == 'perro'
                              ? Icons.pets
                              : Icons.catching_pokemon,
                          size: 14,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${vacunacion.mascota.tipo} · ${vacunacion.mascota.sexo} · ${vacunacion.mascota.edad} años',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Propietario: ${vacunacion.propietario.nombre}',
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Barrio: ${vacunacion.barrioNombre.isEmpty ? "(pendiente de asignar)" : vacunacion.barrioNombre}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),

              // Acciones disponibles según rol:
              // - Vacunador: puede editar y eliminar SUS propios registros
              //   (o los locales aún no sincronizados, que siempre son suyos).
              // - Coordinador de brigada: puede EDITAR (no eliminar) los
              //   registros de los vacunadores que él creó. Como esta lista
              //   ya viene filtrada por el backend solo con esos registros,
              //   cualquier ítem visible aquí es uno que puede corregir.
              // El backend ya filtra: el vacunador solo recibe sus propios registros,
              // el coordinador de brigada solo los de sus vacunadores, y el coordinador
              // de campaña solo los de toda su jerarquía. Por eso las condiciones aquí
              // son simples: si eres vacunador, puedes editar y eliminar todo lo que ves.
              if (auth.esVacunador)
                PopupMenuButton<String>(
                  onSelected: (val) {
                    final clave = vacunacion.clienteId ?? vacunacion.id;
                    if (val == 'editar') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FormVacunacionScreen(
                              vacunacion: vacunacion),
                        ),
                      ).then((_) => context
                          .read<VacunacionProvider>()
                          .cargarVacunaciones());
                    } else if (val == 'eliminar') {
                      _confirmarEliminar(context, clave);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                        value: 'editar',
                        child: Row(children: [
                          Icon(Icons.edit, size: 18),
                          SizedBox(width: 8),
                          Text('Editar'),
                        ])),
                    const PopupMenuItem(
                        value: 'eliminar',
                        child: Row(children: [
                          Icon(Icons.delete, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Eliminar', style: TextStyle(color: Colors.red)),
                        ])),
                  ],
                )
              // Si eres coordinador de brigada, puedes corregir todo lo que ves
              // porque el backend ya te devolvió solo los registros de tus vacunadores.
              else if (auth.esCoordinadorBrigada)
                PopupMenuButton<String>(
                  onSelected: (val) {
                    if (val == 'editar') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FormVacunacionScreen(
                              vacunacion: vacunacion),
                        ),
                      ).then((_) => context
                          .read<VacunacionProvider>()
                          .cargarVacunaciones());
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                        value: 'editar',
                        child: Row(children: [
                          Icon(Icons.edit, size: 18),
                          SizedBox(width: 8),
                          Text('Corregir registro'),
                        ])),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmarEliminar(BuildContext context, String clienteIdOId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar Vacunación'),
        content: const Text(
          '¿Seguro que deseas eliminar este registro?\n\n'
          'Si no tienes internet en este momento, se eliminará '
          'igual y se confirmará con el servidor cuando vuelva la señal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await context
                  .read<VacunacionProvider>()
                  .eliminarVacunacion(clienteIdOId);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Registro eliminado'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _BadgeEstado extends StatelessWidget {
  final EstadoSync estado;

  const _BadgeEstado({required this.estado});

  @override
  Widget build(BuildContext context) {
    final (texto, color, icono) = switch (estado) {
      EstadoSync.pendiente => ('Pendiente', Colors.orange, Icons.cloud_upload_outlined),
      EstadoSync.sincronizando => ('Subiendo...', Colors.blue, Icons.sync),
      EstadoSync.error => ('Error', Colors.red, Icons.error_outline),
      EstadoSync.pendienteEliminar => ('Eliminando...', Colors.red, Icons.delete_outline),
      EstadoSync.sincronizado => ('Sincronizado', Colors.green, Icons.cloud_done_outlined),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            texto,
            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}