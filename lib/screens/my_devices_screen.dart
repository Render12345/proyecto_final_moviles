import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/app_end_drawer.dart';
import '../models/device_model.dart';
import '../models/salon_model.dart';
import '../models/schedule_model.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/report_provider.dart';
import '../providers/salon_provider.dart';
import '../providers/schedule_provider.dart';
import '../screens/device_detail_screen.dart';
import '../screens/qr_scanner_screen.dart';
import '../services/device_service.dart';
import '../services/storage_service.dart';

// ============================================================
// ESTADOS VISUALES DEL DISPOSITIVO
// ============================================================

enum _EstadoVisualDispositivo { fueraDeHora, encendido, apagado }

_EstadoVisualDispositivo _obtenerEstadoVisual(
  List<ScheduleModel> programaciones,
) {
  final ahora = DateTime.now();

  final pendientes = programaciones
      .where((p) => p.status == 'scheduled')
      .toList();

  final fueraDeHora = pendientes.any((p) => !ahora.isBefore(p.endAt));

  if (fueraDeHora) {
    return _EstadoVisualDispositivo.fueraDeHora;
  }

  final encendido = pendientes.any(
    (p) => !ahora.isBefore(p.startAt) && ahora.isBefore(p.endAt),
  );

  if (encendido) {
    return _EstadoVisualDispositivo.encendido;
  }

  return _EstadoVisualDispositivo.apagado;
}

int _obtenerPrioridadDispositivo(List<ScheduleModel> programaciones) {
  switch (_obtenerEstadoVisual(programaciones)) {
    case _EstadoVisualDispositivo.fueraDeHora:
      return 0;
    case _EstadoVisualDispositivo.encendido:
      return 1;
    case _EstadoVisualDispositivo.apagado:
      return 2;
  }
}

// ============================================================
// ETIQUETA DEL ESTADO
// ============================================================

Widget _etiquetaEstadoDispositivo(
  BuildContext context,
  _EstadoVisualDispositivo estado,
) {
  late final String texto;
  late final Color color;
  late final IconData icono;

  switch (estado) {
    case _EstadoVisualDispositivo.fueraDeHora:
      texto = 'Fuera de hora';
      color = Colors.red;
      icono = Icons.warning_amber_rounded;
      break;
    case _EstadoVisualDispositivo.encendido:
      texto = 'Encendido';
      color = Colors.green;
      icono = Icons.power;
      break;
    case _EstadoVisualDispositivo.apagado:
      texto = 'Apagado';
      color = Colors.grey;
      icono = Icons.power_off;
      break;
  }

  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icono, size: 18, color: color),
      const SizedBox(width: 6),
      Text(
        texto,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    ],
  );
}

// ============================================================
// PANTALLA PRINCIPAL
// ============================================================

class MyDevicesScreen extends ConsumerWidget {
  final UserModel userData;
  final Future<void> Function() onLogout;

  const MyDevicesScreen({
    super.key,
    required this.userData,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuarioAsync = ref.watch(currentUserDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis dispositivos'),
        centerTitle: true,
      ),
      endDrawer: AppEndDrawer(userData: userData, onLogout: onLogout),
      body: usuarioAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('No se pudo consultar tu perfil:\n$error'),
          ),
        ),
        data: (usuario) {
          if (usuario == null) {
            return const Center(
              child: Text('No se encontró la información del usuario.'),
            );
          }

          if (usuario.role != 'admin' && !usuario.autorizado) {
            return const _AccesoPendiente();
          }

          final dispositivosVinculados = usuario.dispositivosVinculados.entries
              .where((entrada) => entrada.value)
              .map((entrada) => entrada.key)
              .toList();

          if (dispositivosVinculados.isEmpty) {
            return _SinDispositivos(
              userData: usuario,
              onLogout: onLogout,
            );
          }

          return _ContenidoMisDispositivos(
            deviceIds: dispositivosVinculados,
            esAdmin: usuario.role == 'admin',
          );
        },
      ),
    );
  }
}

// ============================================================
// ACCESO PENDIENTE
// ============================================================

class _AccesoPendiente extends StatelessWidget {
  const _AccesoPendiente();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.hourglass_top_rounded,
              size: 64,
              color: Colors.orange.shade700,
            ),
            const SizedBox(height: 16),
            const Text(
              'Cuenta pendiente de autorización',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Cuando un administrador autorice tu cuenta, '
              'podrás consultar tus dispositivos vinculados.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// SIN DISPOSITIVOS
// ============================================================

class _SinDispositivos extends StatelessWidget {
  final UserModel userData;
  final Future<void> Function() onLogout;

  const _SinDispositivos({
    required this.userData,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.devices_other_rounded,
              size: 76,
              color: Colors.grey.shade500,
            ),
            const SizedBox(height: 16),
            const Text(
              'Aún no tienes dispositivos vinculados',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Puedes escanear el código QR de un dispositivo '
              'para agregarlo a tu cuenta.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QrScannerScreen(
                      userData: userData,
                      onLogout: onLogout,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Escanear dispositivo'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// CONTENIDO DE MIS DISPOSITIVOS
// ============================================================

class _ContenidoMisDispositivos extends ConsumerWidget {
  final List<String> deviceIds;
  final bool esAdmin;

  const _ContenidoMisDispositivos({
    required this.deviceIds,
    required this.esAdmin,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salonesAsync = ref.watch(salonesProvider);

    return salonesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('No se pudieron consultar los salones:\n$error'),
        ),
      ),
      data: (salones) {
        return _ListaDispositivosVinculados(
          deviceIds: deviceIds,
          salones: salones,
          esAdmin: esAdmin,
        );
      },
    );
  }
}

// ============================================================
// LISTA DE DISPOSITIVOS
// ============================================================

class _ListaDispositivosVinculados extends ConsumerStatefulWidget {
  final List<String> deviceIds;
  final List<SalonModel> salones;
  final bool esAdmin;

  const _ListaDispositivosVinculados({
    required this.deviceIds,
    required this.salones,
    required this.esAdmin,
  });

  @override
  ConsumerState<_ListaDispositivosVinculados> createState() =>
      _ListaDispositivosVinculadosState();
}

class _ListaDispositivosVinculadosState
    extends ConsumerState<_ListaDispositivosVinculados> {
  late Future<List<DeviceModel?>> _dispositivosFuture;

  Timer? _temporizador;

  @override
  void initState() {
    super.initState();

    _dispositivosFuture = _cargarDispositivos();

    _temporizador = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _temporizador?.cancel();
    super.dispose();
  }

  Future<List<DeviceModel?>> _cargarDispositivos() async {
    final servicio = DeviceService();

    return Future.wait(
      widget.deviceIds.map((deviceId) async {
        try {
          return await servicio.obtenerDispositivo(deviceId);
        } catch (_) {
          return null;
        }
      }),
    );
  }

  Future<void> _actualizar() async {
    setState(() {
      _dispositivosFuture = _cargarDispositivos();
    });

    ref.invalidate(schedulesProvider);

    await _dispositivosFuture;
  }

  @override
  Widget build(BuildContext context) {
    final programacionesAsync = ref.watch(schedulesProvider);

    return FutureBuilder<List<DeviceModel?>>(
      future: _dispositivosFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No se pudieron cargar tus dispositivos:\n'
                '${snapshot.error}',
              ),
            ),
          );
        }

        final dispositivos = (snapshot.data ?? [])
            .whereType<DeviceModel>()
            .toList();

        final programaciones = programacionesAsync.asData?.value ?? [];

        dispositivos.sort((a, b) {
          final programacionesA = programaciones
              .where((p) => p.deviceId == a.deviceId)
              .toList();

          final programacionesB = programaciones
              .where((p) => p.deviceId == b.deviceId)
              .toList();

          final prioridadA = _obtenerPrioridadDispositivo(programacionesA);
          final prioridadB = _obtenerPrioridadDispositivo(programacionesB);

          return prioridadA.compareTo(prioridadB);
        });

        if (dispositivos.isEmpty) {
          return const Center(
            child: Text(
              'No se encontraron dispositivos disponibles.',
              textAlign: TextAlign.center,
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _actualizar,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: dispositivos.length,
            itemBuilder: (context, index) {
              final dispositivo = dispositivos[index];

              SalonModel? salon;

              for (final elemento in widget.salones) {
                if (elemento.id == dispositivo.salonId) {
                  salon = elemento;
                  break;
                }
              }

              return _TarjetaMiDispositivo(
                dispositivo: dispositivo,
                salon: salon,
                esAdmin: widget.esAdmin,
              );
            },
          ),
        );
      },
    );
  }
}

// ============================================================
// TARJETA DE DISPOSITIVO
// ============================================================

class _TarjetaMiDispositivo extends ConsumerWidget {
  final DeviceModel dispositivo;
  final SalonModel? salon;
  final bool esAdmin;

  const _TarjetaMiDispositivo({
    required this.dispositivo,
    required this.salon,
    required this.esAdmin,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programacionesAsync = ref.watch(
      schedulesForDeviceProvider(dispositivo.deviceId),
    );

    final programaciones = programacionesAsync.asData?.value ?? [];

    final programacionesPendientes = programaciones
        .where((p) => p.estaPendiente)
        .length;

    final estadoVisual = _obtenerEstadoVisual(programaciones);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DeviceDetailScreen(
                    deviceId: dispositivo.deviceId,
                  ),
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FotoSalon(salon: salon),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        salon?.nombre ?? 'Sin aula asignada',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _etiquetaEstadoDispositivo(context, estadoVisual),
                      if (salon != null && salon!.edificio.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Edificio: ${salon!.edificio}',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ],
                      const SizedBox(height: 12),
                      const Divider(),
                      Row(
                        children: [
                          const Icon(Icons.memory_rounded),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              dispositivo.deviceId,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.fingerprint_rounded),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('MAC: ${dispositivo.macAddress}'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.verified_outlined),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('Registro: ${dispositivo.estado}'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Ver detalles →',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _mostrarDialogoCrear(context, ref),
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: const Text('Programar dispositivo'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _mostrarProgramaciones(context, ref),
                  icon: const Icon(Icons.schedule),
                  label: Text(
                    programacionesAsync.isLoading
                        ? 'Cargando programaciones...'
                        : 'Ver programaciones '
                            '($programacionesPendientes pendientes)',
                  ),
                ),

                // Los administradores no necesitan reportar fallas.
                if (!esAdmin) ...[
                  const SizedBox(height: 4),
                  OutlinedButton.icon(
                    onPressed: () => _mostrarDialogoReporte(context, ref),
                    icon: const Icon(Icons.report_problem_outlined),
                    label: const Text('Reportar falla'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade300),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // REPORTAR FALLA
  // ============================================================

  Future<void> _mostrarDialogoReporte(
    BuildContext context,
    WidgetRef ref,
  ) async {
    String tipoSeleccionado = 'no_apaga';
    bool guardando = false;

    final descripcionController = TextEditingController();

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.report_problem_outlined, color: Colors.red),
                    SizedBox(width: 10),
                    Expanded(child: Text('Reportar falla')),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Aula: ${salon?.nombre ?? 'Sin aula asignada'}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Dispositivo: ${dispositivo.deviceId}',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        '¿Qué problema presenta el aire acondicionado?',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: tipoSeleccionado,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.build_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'no_apaga',
                            child: Text('No apaga'),
                          ),
                          DropdownMenuItem(
                            value: 'no_enciende',
                            child: Text('No enciende'),
                          ),
                        ],
                        onChanged: guardando
                            ? null
                            : (valor) {
                                if (valor != null) {
                                  setDialogState(() {
                                    tipoSeleccionado = valor;
                                  });
                                }
                              },
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Descripción adicional (opcional)',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: descripcionController,
                        enabled: !guardando,
                        maxLength: 300,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Describe brevemente el problema...',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'El reporte será enviado a los administradores.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: guardando
                        ? null
                        : () => Navigator.pop(dialogContext),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton.icon(
                    onPressed: guardando
                        ? null
                        : () async {
                            setDialogState(() {
                              guardando = true;
                            });

                            try {
                              await ref
                                  .read(reportServiceProvider)
                                  .crearReporte(
                                    deviceId: dispositivo.deviceId,
                                    salonId: dispositivo.salonId ?? '',
                                    salonNombre:
                                        salon?.nombre ?? 'Sin aula asignada',
                                    tipo: tipoSeleccionado,
                                    descripcion:
                                        descripcionController.text.trim(),
                                  );

                              if (!dialogContext.mounted) return;

                              Navigator.pop(dialogContext);

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Reporte enviado correctamente.',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } catch (error) {
                              if (!dialogContext.mounted) return;

                              setDialogState(() {
                                guardando = false;
                              });

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'No se pudo enviar el reporte: $error',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                    icon: guardando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.send),
                    label: Text(
                      guardando ? 'Enviando...' : 'Enviar reporte',
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      descripcionController.dispose();
    }
  }

  // ============================================================
  // CREAR PROGRAMACIÓN
  // ============================================================

  Future<void> _mostrarDialogoCrear(
    BuildContext context,
    WidgetRef ref,
  ) async {
    int duracionSeleccionada = 2;
    bool guardando = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Encender dispositivo'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dispositivo: ${dispositivo.deviceId}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Duración de funcionamiento',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: duracionSeleccionada,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.timer_outlined),
                    ),
                    items: List.generate(
                      12,
                      (index) => DropdownMenuItem(
                        value: index + 1,
                        child: Text(
                          '${index + 1} ${index == 0 ? 'hora' : 'horas'}',
                        ),
                      ),
                    ),
                    onChanged: guardando
                        ? null
                        : (valor) {
                            if (valor != null) {
                              setDialogState(() {
                                duracionSeleccionada = valor;
                              });
                            }
                          },
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'El dispositivo comenzará inmediatamente '
                    'y la programación finalizará automáticamente '
                    'al cumplirse la duración seleccionada.',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: guardando
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                FilledButton.icon(
                  onPressed: guardando
                      ? null
                      : () async {
                          setDialogState(() {
                            guardando = true;
                          });

                          try {
                            await ref
                                .read(scheduleServiceProvider)
                                .crearProgramacion(
                                  deviceId: dispositivo.deviceId,
                                  durationHours: duracionSeleccionada,
                                );

                            ref.invalidate(schedulesProvider);

                            ref.invalidate(
                              schedulesForDeviceProvider(
                                dispositivo.deviceId,
                              ),
                            );

                            if (!dialogContext.mounted) return;

                            Navigator.pop(dialogContext);

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Dispositivo programado correctamente.',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (error) {
                            if (!dialogContext.mounted) return;

                            setDialogState(() {
                              guardando = false;
                            });

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'No se pudo programar el dispositivo: $error',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  icon: guardando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.power),
                  label: Text(
                    guardando ? 'Procesando...' : 'Encender ahora',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // CONSULTAR PROGRAMACIONES
  // ============================================================

  Future<void> _mostrarProgramaciones(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _DialogoProgramaciones(
        deviceId: dispositivo.deviceId,
      ),
    );
  }

  static String _formatearFecha(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    final anio = fecha.year.toString();

    return '$dia/$mes/$anio';
  }

  static String _formatearFechaHora(DateTime fecha) {
    final fechaLocal = fecha.toLocal();

    final hora = fechaLocal.hour.toString().padLeft(2, '0');
    final minuto = fechaLocal.minute.toString().padLeft(2, '0');

    return '${_formatearFecha(fechaLocal)} $hora:$minuto';
  }
}

// ============================================================
// DIÁLOGO DE PROGRAMACIONES
// ============================================================

class _DialogoProgramaciones extends ConsumerStatefulWidget {
  final String deviceId;

  const _DialogoProgramaciones({required this.deviceId});

  @override
  ConsumerState<_DialogoProgramaciones> createState() =>
      _DialogoProgramacionesState();
}

class _DialogoProgramacionesState
    extends ConsumerState<_DialogoProgramaciones> {
  Timer? _temporizador;

  @override
  void initState() {
    super.initState();

    _temporizador = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _temporizador?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final programacionesAsync = ref.watch(
      schedulesForDeviceProvider(widget.deviceId),
    );

    return AlertDialog(
      title: const Text('Programaciones'),
      content: SizedBox(
        width: double.maxFinite,
        child: programacionesAsync.when(
          loading: () => const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stackTrace) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 40),
              const SizedBox(height: 12),
              Text(
                'No se pudieron consultar las programaciones:\n$error',
                textAlign: TextAlign.center,
              ),
              TextButton.icon(
                onPressed: () {
                  ref.invalidate(schedulesProvider);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
          data: (programaciones) {
            if (programaciones.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.event_busy_outlined,
                      size: 48,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Este dispositivo no tiene programaciones.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            final ordenadas = [...programaciones];
            final ahora = DateTime.now();

            bool estaActiva(ScheduleModel p) {
              return p.status == 'scheduled' &&
                  !ahora.isBefore(p.startAt) &&
                  ahora.isBefore(p.endAt);
            }

            ordenadas.sort((a, b) {
              final activaA = estaActiva(a);
              final activaB = estaActiva(b);

              if (activaA != activaB) {
                return activaA ? -1 : 1;
              }

              final fechaA = a.createdAt ?? a.startAt;
              final fechaB = b.createdAt ?? b.startAt;

              return fechaB.compareTo(fechaA);
            });

            return SizedBox(
              height: 350,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: ordenadas.length,
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (context, index) {
                  return _ElementoProgramacion(
                    programacion: ordenadas[index],
                  );
                },
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

// ============================================================
// ELEMENTO DE PROGRAMACIÓN
// ============================================================

class _ElementoProgramacion extends ConsumerWidget {
  final ScheduleModel programacion;

  const _ElementoProgramacion({required this.programacion});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendiente = programacion.estaPendiente;
    final ahora = DateTime.now();

    final enCurso =
        pendiente &&
        !ahora.isBefore(programacion.startAt) &&
        ahora.isBefore(programacion.endAt);

    final fueraDeHora = pendiente && !ahora.isBefore(programacion.endAt);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                fueraDeHora
                    ? Icons.warning_amber_rounded
                    : enCurso
                        ? Icons.power
                        : pendiente
                            ? Icons.schedule
                            : programacion.estaCancelada
                                ? Icons.cancel_outlined
                                : Icons.check_circle_outline,
                color: fueraDeHora
                    ? Colors.red
                    : enCurso
                        ? Colors.green
                        : pendiente
                            ? Colors.orange
                            : programacion.estaCancelada
                                ? Colors.red
                                : Colors.green,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _nombreEstado(programacion, ahora),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Inicio: ${_formatearFechaHora(programacion.startAt)}'),
          Text('Fin: ${_formatearFechaHora(programacion.endAt)}'),
          Text(
            'Duración: ${programacion.durationHours} '
            '${programacion.durationHours == 1 ? 'hora' : 'horas'}',
          ),
          if (pendiente) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _cancelar(context, ref),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancelar programación'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _cancelar(BuildContext context, WidgetRef ref) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancelar programación'),
        content: const Text(
          '¿Estás seguro de que deseas cancelar esta programación?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );

    if (confirmar != true || !context.mounted) return;

    try {
      await ref
          .read(scheduleServiceProvider)
          .cancelarProgramacion(programacion.scheduleId);

      ref.invalidate(schedulesProvider);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Programación cancelada correctamente.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo cancelar la programación: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  static String _nombreEstado(ScheduleModel programacion, DateTime ahora) {
    if (programacion.status == 'scheduled') {
      if (!ahora.isBefore(programacion.endAt)) {
        return 'Fuera de hora';
      }

      if (!ahora.isBefore(programacion.startAt)) {
        return 'En curso';
      }

      return 'Programada';
    }

    switch (programacion.status) {
      case 'cancelled':
        return 'Cancelada';
      case 'completed':
        return 'Completada';
      default:
        return programacion.status;
    }
  }

  static String _formatearFechaHora(DateTime fecha) {
    final fechaLocal = fecha.toLocal();

    final dia = fechaLocal.day.toString().padLeft(2, '0');
    final mes = fechaLocal.month.toString().padLeft(2, '0');
    final anio = fechaLocal.year.toString();
    final hora = fechaLocal.hour.toString().padLeft(2, '0');
    final minuto = fechaLocal.minute.toString().padLeft(2, '0');

    return '$dia/$mes/$anio $hora:$minuto';
  }
}

// ============================================================
// FOTOGRAFÍA DEL SALÓN
// ============================================================

class _FotoSalon extends StatefulWidget {
  final SalonModel? salon;

  const _FotoSalon({required this.salon});

  @override
  State<_FotoSalon> createState() => _FotoSalonState();
}

class _FotoSalonState extends State<_FotoSalon> {
  late Future<String?> _fotoFuture;

  @override
  void initState() {
    super.initState();
    _fotoFuture = _obtenerFoto();
  }

  @override
  void didUpdateWidget(covariant _FotoSalon oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.salon?.fotoUrl != widget.salon?.fotoUrl) {
      _fotoFuture = _obtenerFoto();
    }
  }

  Future<String?> _obtenerFoto() async {
    final ruta = widget.salon?.fotoUrl;

    if (ruta == null || ruta.isEmpty) {
      return null;
    }

    if (ruta.startsWith('http://') || ruta.startsWith('https://')) {
      return ruta;
    }

    try {
      return await StorageService().obtenerUrlFotoSalon(ruta);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 180,
      child: FutureBuilder<String?>(
        future: _fotoFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              color: Colors.grey.shade200,
              child: const Center(child: CircularProgressIndicator()),
            );
          }

          final url = snapshot.data;

          if (url == null || url.isEmpty) {
            return _fotoNoDisponible();
          }

          return Image.network(
            url,
            width: double.infinity,
            height: 180,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _fotoNoDisponible();
            },
          );
        },
      ),
    );
  }

  Widget _fotoNoDisponible() {
    return Container(
      color: Colors.grey.shade200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.meeting_room_outlined,
            size: 48,
            color: Colors.grey.shade600,
          ),
          const SizedBox(height: 8),
          Text(
            widget.salon == null
                ? 'Salón sin asignar'
                : 'Sin fotografía del salón',
            style: TextStyle(color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}
