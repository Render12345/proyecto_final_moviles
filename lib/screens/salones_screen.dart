import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/app_end_drawer.dart';
import '../components/cached_storage_image.dart';
import '../models/salon_model.dart';
import '../models/user_model.dart';
import '../providers/salon_provider.dart';
import 'salon_form_screen.dart';

class SalonesScreen extends ConsumerWidget {
  final UserModel userData;
  final bool esAdministrador;
  final Future<void> Function() onLogout;

  const SalonesScreen({
    super.key,
    required this.userData,
    required this.esAdministrador,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salonesAsync = ref.watch(salonesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          esAdministrador ? 'Salones (Edición)' : 'Salones',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        actions: [
          Builder(
            builder: (context) => IconButton(
              tooltip: 'Opciones de cuenta',
              icon: const Icon(Icons.menu),
              onPressed: () {
                Scaffold.of(context).openEndDrawer();
              },
            ),
          ),
        ],
      ),
      endDrawer: AppEndDrawer(
        userData: userData,
        onLogout: onLogout,
      ),
      body: salonesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No se pudieron cargar los salones.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(salonesProvider),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ),
        ),
        data: (salones) {
          final salonesVisibles = esAdministrador
              ? salones
              : salones.where((salon) => salon.activo).toList();

          if (salonesVisibles.isEmpty) {
            return _EstadoVacio(
              esAdministrador: esAdministrador,
              onAgregar: esAdministrador
                  ? () => _abrirFormulario(context)
                  : null,
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(salonesProvider);
            },
            child: LayoutBuilder(
              builder: (context, constraints) {
                final esHorizontal =
                    constraints.maxWidth > constraints.maxHeight;

                final columnas = esHorizontal ? 2 : 1;

                final ancho = (constraints.maxWidth - 32)
                    .clamp(0.0, 1400.0)
                    .toDouble();

                const separacion = 16.0;

                final anchoTarjeta =
                    (ancho - (separacion * (columnas - 1))) /
                        columnas;

                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 1400,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _EncabezadoSalones(
                              cantidad: salonesVisibles.length,
                            ),
                            const SizedBox(height: 20),
                            Wrap(
                              spacing: separacion,
                              runSpacing: separacion,
                              children: salonesVisibles.map((salon) {
                                return SizedBox(
                                  width: anchoTarjeta,
                                  child: _TarjetaSalon(
                                    salon: salon,
                                    esAdministrador: esAdministrador,
                                    onEditar: () => _abrirFormulario(
                                      context,
                                      salon: salon,
                                    ),
                                    onEliminar: () => _confirmarEliminar(
                                      context,
                                      ref,
                                      salon,
                                    ),
                                    onCambiarEstado: (activo) =>
                                        _cambiarEstado(
                                      context,
                                      ref,
                                      salon,
                                      activo,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: esAdministrador
          ? FloatingActionButton.extended(
              onPressed: () => _abrirFormulario(context),
              icon: const Icon(Icons.add),
              label: const Text('Nuevo salón'),
            )
          : null,
    );
  }

  void _abrirFormulario(BuildContext context, {SalonModel? salon}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SalonFormScreen(salon: salon),
      ),
    );
  }

  Future<void> _confirmarEliminar(
    BuildContext context,
    WidgetRef ref,
    SalonModel salon,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar salón'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Text(
            '¿Estás seguro de eliminar "${salon.nombre}"? '
            'Esta acción no se puede deshacer.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar != true || !context.mounted) return;

    try {
      await ref.read(salonServiceProvider).eliminarSalon(salon.id);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Salón eliminado correctamente.'),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _cambiarEstado(
    BuildContext context,
    WidgetRef ref,
    SalonModel salon,
    bool activo,
  ) async {
    try {
      await ref.read(salonServiceProvider).cambiarEstadoSalon(
            salonId: salon.id,
            activo: activo,
          );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            activo ? 'Salón activado.' : 'Salón desactivado.',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }
}

// ============================================================
// ENCABEZADO
// ============================================================

class _EncabezadoSalones extends StatelessWidget {
  final int cantidad;

  const _EncabezadoSalones({
    required this.cantidad,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.meeting_room_outlined,
          size: 28,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Espacios disponibles',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '$cantidad ${cantidad == 1 ? 'salón registrado' : 'salones registrados'}',
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================
// TARJETA DE SALÓN
// ============================================================

class _TarjetaSalon extends StatelessWidget {
  final SalonModel salon;
  final bool esAdministrador;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;
  final ValueChanged<bool> onCambiarEstado;

  const _TarjetaSalon({
    required this.salon,
    required this.esAdministrador,
    required this.onEditar,
    required this.onEliminar,
    required this.onCambiarEstado,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rutaFoto = salon.fotoUrl;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: rutaFoto == null || rutaFoto.isEmpty
                ? _fotoNoDisponible(theme)
                : CachedStorageImage(
                    ruta: rutaFoto,
                    tipo: CachedImageType.salon,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    errorWidget: _fotoNoDisponible(theme),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        salon.nombre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (esAdministrador)
                      PopupMenuButton<String>(
                        onSelected: (opcion) {
                          if (opcion == 'editar') onEditar();
                          if (opcion == 'eliminar') onEliminar();
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'editar',
                            child: ListTile(
                              leading: Icon(Icons.edit_outlined),
                              title: Text('Editar'),
                            ),
                          ),
                          PopupMenuItem(
                            value: 'eliminar',
                            child: ListTile(
                              leading: Icon(Icons.delete_outline),
                              title: Text('Eliminar'),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                if (salon.edificio.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.business_outlined,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Edificio ${salon.edificio}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (salon.descripcion.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(salon.descripcion),
                ],
                if (esAdministrador) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        salon.activo
                            ? Icons.check_circle
                            : Icons.pause_circle,
                        color: salon.activo
                            ? Colors.green
                            : Colors.orange,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        salon.activo ? 'Activo' : 'Inactivo',
                      ),
                      const Spacer(),
                      Switch(
                        value: salon.activo,
                        onChanged: onCambiarEstado,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fotoNoDisponible(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.meeting_room_outlined,
        size: 64,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

// ============================================================
// ESTADO VACÍO
// ============================================================

class _EstadoVacio extends StatelessWidget {
  final bool esAdministrador;
  final VoidCallback? onAgregar;

  const _EstadoVacio({
    required this.esAdministrador,
    this.onAgregar,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.meeting_room_outlined,
                size: 80,
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant,
              ),
              const SizedBox(height: 20),
              Text(
                esAdministrador
                    ? 'Todavía no hay salones registrados'
                    : 'No hay salones disponibles',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                esAdministrador
                    ? 'Comienza registrando el primer espacio.'
                    : 'Por el momento no hay espacios habilitados para consultar.',
                textAlign: TextAlign.center,
              ),
              if (esAdministrador && onAgregar != null) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onAgregar,
                  icon: const Icon(Icons.add),
                  label: const Text('Registrar salón'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
