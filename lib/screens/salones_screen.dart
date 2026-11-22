import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import '../models/salon_model.dart';
import '../providers/salon_provider.dart';
import '../components/app_end_drawer.dart';
import 'admin_users_screen.dart';
import 'salon_form_screen.dart';
import '../services/storage_service.dart';

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
        title: Text(esAdministrador ? 'Salones (Edición)' : 'Salones'),
        centerTitle: true,
        actions: [
          if (esAdministrador)
            IconButton(
              tooltip: 'Administrar usuarios',
              icon: const Icon(Icons.manage_accounts_outlined),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdminUsersScreen(
                      userData: userData,
                      onLogout: onLogout,
                    ),
                  ),
                );
              },
            ),
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
      endDrawer: AppEndDrawer(userData: userData, onLogout: onLogout),
      body: salonesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 12),
                const Text(
                  'No se pudieron cargar los salones.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(error.toString(), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(salonesProvider),
                  child: const Text('Reintentar'),
                ),
              ],
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
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _EncabezadoSalones(cantidad: salonesVisibles.length),
                const SizedBox(height: 16),
                ...salonesVisibles.map(
                  (salon) => _TarjetaSalon(
                    salon: salon,
                    esAdministrador: esAdministrador,
                    onEditar: () => _abrirFormulario(context, salon: salon),
                    onEliminar: () => _confirmarEliminar(context, ref, salon),
                    onCambiarEstado: (activo) =>
                        _cambiarEstado(context, ref, salon, activo),
                  ),
                ),
              ],
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
      MaterialPageRoute(builder: (_) => SalonFormScreen(salon: salon)),
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
        content: Text(
          '¿Estás seguro de eliminar "${salon.nombre}"? '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
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
        const SnackBar(content: Text('Salón eliminado correctamente.')),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _cambiarEstado(
    BuildContext context,
    WidgetRef ref,
    SalonModel salon,
    bool activo,
  ) async {
    try {
      await ref
          .read(salonServiceProvider)
          .cambiarEstadoSalon(salonId: salon.id, activo: activo);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(activo ? 'Salón activado.' : 'Salón desactivado.'),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}

class _EncabezadoSalones extends StatelessWidget {
  final int cantidad;

  const _EncabezadoSalones({required this.cantidad});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.meeting_room_outlined, size: 28),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Espacios disponibles',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                '$cantidad ${cantidad == 1 ? 'salón registrado' : 'salones registrados'}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

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

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: salon.fotoUrl == null || salon.fotoUrl!.isEmpty
                ? Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.meeting_room_outlined,
                      size: 64,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                : FutureBuilder<String>(
                    future: StorageService().obtenerUrlFotoSalon(
                      salon.fotoUrl!,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      if (snapshot.hasError || !snapshot.hasData) {
                        return Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: const Icon(
                            Icons.broken_image_outlined,
                            size: 48,
                          ),
                        );
                      }

                      return Image.network(
                        snapshot.data!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: const Icon(
                              Icons.broken_image_outlined,
                              size: 48,
                            ),
                          );
                        },
                      );
                    },
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
                      const Icon(Icons.business_outlined, size: 18),
                      const SizedBox(width: 6),
                      Text('Edificio ${salon.edificio}'),
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
                        salon.activo ? Icons.check_circle : Icons.pause_circle,
                        color: salon.activo ? Colors.green : Colors.orange,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(salon.activo ? 'Activo' : 'Inactivo'),
                      const Spacer(),
                      Switch(value: salon.activo, onChanged: onCambiarEstado),
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
}

class _EstadoVacio extends StatelessWidget {
  final bool esAdministrador;
  final VoidCallback? onAgregar;

  const _EstadoVacio({required this.esAdministrador, this.onAgregar});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.meeting_room_outlined,
              size: 80,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 20),
            Text(
              esAdministrador
                  ? 'Todavía no hay salones registrados'
                  : 'No hay salones disponibles',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              esAdministrador ? 'Comienza registrando el primer espacio.' : 'Por el momento no hay espacios habilitados para consultar.',
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
    );
  }
}
