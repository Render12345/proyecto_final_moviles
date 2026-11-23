import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/device_model.dart';
import '../models/salon_model.dart';
import '../providers/auth_provider.dart';
import '../providers/device_provider.dart';
import '../providers/salon_provider.dart';
import '../providers/report_provider.dart';
import '../services/storage_service.dart';

class DeviceDetailScreen extends ConsumerWidget {
  final String deviceId;

  const DeviceDetailScreen({
    super.key,
    required this.deviceId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dispositivoAsync = ref.watch(
      deviceDetailProvider(deviceId),
    );

    final salonesAsync = ref.watch(salonesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Información del dispositivo'),
        centerTitle: true,
      ),
      body: dispositivoAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 56,
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No se pudo consultar el dispositivo.',
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
                    ref.invalidate(
                      deviceDetailProvider(deviceId),
                    );
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
        data: (dispositivo) {
          return salonesAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(),
            ),
            error: (error, stackTrace) => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No se pudo consultar la información del salón.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            data: (salones) {
              SalonModel? salon;

              for (final elemento in salones) {
                if (elemento.id == dispositivo.salonId) {
                  salon = elemento;
                  break;
                }
              }

              return _ContenidoDispositivo(
                dispositivo: dispositivo,
                salon: salon,
              );
            },
          );
        },
      ),
    );
  }
}

class _ContenidoDispositivo extends ConsumerWidget {
  final DeviceModel dispositivo;
  final SalonModel? salon;

  const _ContenidoDispositivo({
    required this.dispositivo,
    required this.salon,
  });

  Future<void> _reportarFalla(
    BuildContext context,
    WidgetRef ref,
    String tipo,
  ) async {
    if (salon == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No puedes reportar una falla: el dispositivo no tiene salón asignado.',
          ),
        ),
      );
      return;
    }

    final descripcionController = TextEditingController();

    final descripcion = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            tipo == 'no_enciende'
                ? 'Reportar: No enciende'
                : 'Reportar: No apaga',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Salón: ${salon!.nombre}',
              ),
              const SizedBox(height: 12),
              const Text(
                'Puedes agregar una descripción de la falla (opcional).',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descripcionController,
                maxLines: 3,
                maxLength: 300,
                decoration: const InputDecoration(
                  hintText: 'Describe qué está sucediendo...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  descripcionController.text.trim(),
                );
              },
              icon: const Icon(Icons.send),
              label: const Text('Enviar reporte'),
            ),
          ],
        );
      },
    );

    descripcionController.dispose();

    if (descripcion == null) return;

    try {
      await ref.read(reportServiceProvider).crearReporte(
        deviceId: dispositivo.deviceId,
        salonId: salon!.id,
        salonNombre: salon!.nombre,
        tipo: tipo,
        descripcion: descripcion,
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Reporte enviado correctamente. Los administradores podrán revisarlo.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo enviar el reporte: $e',
          ),
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

    final usuarioAsync = ref.watch(currentUserDataProvider);
    final esAdministrador =
        usuarioAsync.asData?.value?.role == 'admin';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (tieneFoto) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _FotoSalon(ruta: salon!.fotoUrl!),
          ),
          const SizedBox(height: 20),
        ] else ...[
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.meeting_room_outlined,
                  size: 64,
                  color: Colors.grey,
                ),
                SizedBox(height: 8),
                Text('Este salón no tiene fotografía.'),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        Text(
          salon?.nombre ?? 'Dispositivo sin salón asignado',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),

        if (salon != null &&
            salon!.edificio.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Edificio: ${salon!.edificio}',
            style: theme.textTheme.bodyLarge,
          ),
        ],

        if (salon != null &&
            salon!.descripcion.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(salon!.descripcion),
        ],

        const SizedBox(height: 24),

        const Text(
          'Información del dispositivo',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 12),

        _DatoDispositivo(
          icono: Icons.devices,
          titulo: 'Identificador',
          valor: dispositivo.deviceId,
        ),

        _DatoDispositivo(
          icono: Icons.memory,
          titulo: 'Dirección MAC',
          valor: dispositivo.macAddress,
        ),

        _DatoDispositivo(
          icono: Icons.info_outline,
          titulo: 'Estado de registro',
          valor: dispositivo.estado,
        ),

        if (dispositivo.firmwareVersion != null &&
            dispositivo.firmwareVersion!.isNotEmpty)
          _DatoDispositivo(
            icono: Icons.system_update,
            titulo: 'Firmware',
            valor: dispositivo.firmwareVersion!,
          ),

        _DatoDispositivo(
          icono: Icons.calendar_today,
          titulo: 'Fecha de registro',
          valor: dispositivo.fechaRegistro.isEmpty
              ? 'No disponible'
              : dispositivo.fechaRegistro,
        ),

        if (!esAdministrador) ...[
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),

          const Text(
            'Reportar una falla',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Si tienes problemas para controlar el aire acondicionado, informa a los administradores.',
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: salon == null
                  ? null
                  : () => _reportarFalla(
                        context,
                        ref,
                        'no_enciende',
                      ),
              icon: const Icon(Icons.power),
              label: const Text('El aire no enciende'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                ),
                foregroundColor: theme.colorScheme.error,
              ),
            ),
          ),

          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: salon == null
                  ? null
                  : () => _reportarFalla(
                        context,
                        ref,
                        'no_apaga',
                      ),
              icon: const Icon(Icons.power_off),
              label: const Text('El aire no apaga'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                ),
                foregroundColor: Colors.orange,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _DatoDispositivo extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String valor;

  const _DatoDispositivo({
    required this.icono,
    required this.titulo,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icono),
        title: Text(titulo),
        subtitle: Text(
          valor,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _FotoSalon extends StatefulWidget {
  final String ruta;

  const _FotoSalon({
    required this.ruta,
  });

  @override
  State<_FotoSalon> createState() => _FotoSalonState();
}

class _FotoSalonState extends State<_FotoSalon> {
  late Future<String> _urlFuture;

  @override
  void initState() {
    super.initState();
    _cargarUrl();
  }

  @override
  void didUpdateWidget(covariant _FotoSalon oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.ruta != widget.ruta) {
      _cargarUrl();
    }
  }

  void _cargarUrl() {
    _urlFuture = StorageService().obtenerUrlFotoSalon(widget.ruta);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _urlFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 200,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Container(
            height: 180,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Center(
              child: Icon(
                Icons.image_not_supported_outlined,
                size: 48,
              ),
            ),
          );
        }

        return Image.network(
          snapshot.data!,
          height: 220,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              height: 180,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  size: 48,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
