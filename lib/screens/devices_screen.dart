import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proyecto_final_moviles/screens/admin_reports_screen.dart';

import '../components/app_end_drawer.dart';
import '../components/cached_storage_image.dart';
import '../models/device_model.dart';
import '../models/salon_model.dart';
import '../models/user_model.dart';
import '../providers/device_provider.dart';
import '../providers/salon_provider.dart';






class DevicesScreen extends ConsumerWidget {
  final UserModel userData;
  final Future<void> Function() onLogout;

  const DevicesScreen({
    super.key,
    required this.userData,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dispositivosAsync = ref.watch(devicesProvider);
    final salonesAsync = ref.watch(salonesProvider);

    final salones = salonesAsync.asData?.value ?? <SalonModel>[];
    final esAdministrador = userData.role == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dispositivos del servidor'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Reportes de fallas',
            icon: const Icon(Icons.assignment_late_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AdminReportsScreen(
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
      endDrawer: AppEndDrawer(
        userData: userData,
        onLogout: onLogout,
      ),
      body: dispositivosAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
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
                  'No se pudieron cargar los dispositivos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    ref.invalidate(devicesProvider);
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
        data: (dispositivos) {
          if (dispositivos.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.devices_other,
                      size: 80,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No hay dispositivos registrados.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(devicesProvider);
              ref.invalidate(salonesProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _EncabezadoDispositivos(
                  cantidad: dispositivos.length,
                ),
                const SizedBox(height: 16),
                ...dispositivos.map((dispositivo) {
                  SalonModel? salon;

                  for (final elemento in salones) {
                    if (elemento.id == dispositivo.salonId) {
                      salon = elemento;
                      break;
                    }
                  }

                  return _TarjetaDispositivo(
                    dispositivo: dispositivo,
                    salon: salon,
                    salones: salones,
                    esAdministrador: esAdministrador,
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EncabezadoDispositivos extends StatelessWidget {
  final int cantidad;

  const _EncabezadoDispositivos({
    required this.cantidad,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.devices_other, size: 28),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dispositivos registrados',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '$cantidad ${cantidad == 1 ? 'dispositivo encontrado' : 'dispositivos encontrados'}',
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

class _TarjetaDispositivo extends ConsumerWidget {
  final DeviceModel dispositivo;
  final SalonModel? salon;
  final List<SalonModel> salones;
  final bool esAdministrador;

  const _TarjetaDispositivo({
    required this.dispositivo,
    required this.salon,
    required this.salones,
    required this.esAdministrador,
  });

  Future<void> _asignarSalon(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final Map<String, SalonModel> salonesUnicos = {};

    for (final elemento in salones) {
      final id = elemento.id.trim();

      if (id.isNotEmpty) {
        salonesUnicos.putIfAbsent(id, () => elemento);
      }
    }

    final opcionesSalones = salonesUnicos.values.toList();

    final salonActualId = dispositivo.salonId;

    String salonSeleccionado =
        salonActualId != null &&
                salonesUnicos.containsKey(salonActualId)
            ? salonActualId
            : '';

    final resultado = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Asignar salón'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dispositivo: ${dispositivo.deviceId}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: salonSeleccionado,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Salón',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: '',
                        child: Text('Sin asignar'),
                      ),
                      ...opcionesSalones.map(
                        (elemento) => DropdownMenuItem<String>(
                          value: elemento.id,
                          child: Text(
                            elemento.nombre,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (valor) {
                      setDialogState(() {
                        salonSeleccionado = valor ?? '';
                      });
                    },
                  ),
                  if (opcionesSalones.isEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'No hay salones registrados disponibles.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                  if (salonActualId != null &&
                      salonActualId.isNotEmpty &&
                      !salonesUnicos.containsKey(salonActualId)) ...[
                    const SizedBox(height: 12),
                    Text(
                      'El salón actualmente asignado ya no aparece '
                      'en la lista. Selecciona otro salón o deja '
                      'el dispositivo sin asignar.',
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(
                      dialogContext,
                      salonSeleccionado,
                    );
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (resultado == null) return;

    final nuevoSalonId = resultado.isEmpty ? null : resultado;

    if (nuevoSalonId == dispositivo.salonId) return;

    try {
      await ref.read(deviceServiceProvider).asignarSalon(
        deviceId: dispositivo.deviceId,
        salonId: nuevoSalonId,
      );

      ref.invalidate(devicesProvider);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Asignación actualizada correctamente.'),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo asignar el salón: $error'),
        ),
      );
    }
  }

  Future<void> _mostrarQr(
    BuildContext context,
    WidgetRef ref,
  ) async {
    try {
      final qrDataUrl = await ref
          .read(deviceServiceProvider)
          .obtenerQr(dispositivo.deviceId);

      if (!context.mounted) return;

      final partes = qrDataUrl.split(',');

      if (partes.length < 2) {
        throw Exception(
          'El formato de la imagen QR no es válido.',
        );
      }

      final imagenBytes = base64Decode(partes.last);

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Código QR del dispositivo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.memory(
                imagenBytes,
                width: 240,
                height: 240,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 12),
              Text(
                dispositivo.deviceId,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Escanea este código para consultar el dispositivo.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo obtener el QR: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final tieneFoto =
        salon?.fotoUrl != null && salon!.fotoUrl!.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (tieneFoto)
            CachedStorageImage(
              ruta: salon!.fotoUrl!,
              tipo: CachedImageType.salon,
              height: 170,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: const SizedBox(
                height: 150,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
              errorWidget: Container(
                height: 120,
                width: double.infinity,
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
                child: const Center(
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    size: 40,
                  ),
                ),
              ),
            ),
          ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(
                Icons.power,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            title: Text(
              dispositivo.deviceId,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.meeting_room_outlined,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          salon != null
                              ? salon!.nombre
                              : 'Sin salón asignado',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('MAC: ${dispositivo.macAddress}'),
                  const SizedBox(height: 4),
                  Text('Estado: ${dispositivo.estado}'),
                ],
              ),
            ),
            trailing: esAdministrador
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Mostrar código QR',
                        icon: const Icon(Icons.qr_code_2),
                        onPressed: () => _mostrarQr(context, ref),
                      ),
                      IconButton(
                        tooltip: 'Asignar o cambiar salón',
                        icon: const Icon(
                          Icons.edit_location_alt_outlined,
                        ),
                        onPressed: () => _asignarSalon(context, ref),
                      ),
                    ],
                  )
                : const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}


