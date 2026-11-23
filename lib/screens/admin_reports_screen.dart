import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/report_model.dart';
import '../models/user_model.dart';
import '../providers/report_provider.dart';
import '../components/app_end_drawer.dart';

class AdminReportsScreen extends ConsumerStatefulWidget {
  final UserModel userData;
  final Future<void> Function() onLogout;

  const AdminReportsScreen({
    super.key,
    required this.userData,
    required this.onLogout,
  });

  @override
  ConsumerState<AdminReportsScreen> createState() =>
      _AdminReportsScreenState();
}

class _AdminReportsScreenState extends ConsumerState<AdminReportsScreen> {
  String _filtro = 'pending';

  Future<void> _marcarComoAtendido(ReportModel reporte) async {
    try {
      await ref
          .read(reportServiceProvider)
          .marcarComoAtendido(reporte.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reporte marcado como atendido.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo actualizar el reporte: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportesAsync = ref.watch(reportsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes de fallas'),
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
        userData: widget.userData,
        onLogout: widget.onLogout,
      ),
      body: reportesAsync.when(
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
                  'No se pudieron cargar los reportes.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    ref.invalidate(reportsProvider);
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
        data: (reportes) {
          final pendientes = reportes
              .where((reporte) => reporte.estaPendiente)
              .length;

          final atendidos = reportes.length - pendientes;

          final reportesFiltrados = reportes.where((reporte) {
            if (_filtro == 'pending') {
              return reporte.estaPendiente;
            }

            if (_filtro == 'attended') {
              return !reporte.estaPendiente;
            }

            return true;
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _ResumenReporte(
                            titulo: 'Pendientes',
                            cantidad: pendientes,
                            icono: Icons.pending_actions,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ResumenReporte(
                            titulo: 'Atendidos',
                            cantidad: atendidos,
                            icono: Icons.task_alt,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'pending',
                            label: Text('Pendientes'),
                            icon: Icon(Icons.pending_actions),
                          ),
                          ButtonSegment(
                            value: 'attended',
                            label: Text('Atendidos'),
                            icon: Icon(Icons.check_circle_outline),
                          ),
                          ButtonSegment(
                            value: 'all',
                            label: Text('Todos'),
                            icon: Icon(Icons.list),
                          ),
                        ],
                        selected: {_filtro},
                        onSelectionChanged: (seleccion) {
                          setState(() {
                            _filtro = seleccion.first;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: reportesFiltrados.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                size: 64,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _filtro == 'pending'
                                    ? 'No hay reportes pendientes.'
                                    : _filtro == 'attended'
                                        ? 'No hay reportes atendidos.'
                                        : 'Todavía no hay reportes.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium,
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Los nuevos reportes aparecerán aquí '
                                'automáticamente.',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(reportsProvider);
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(
                            16,
                            0,
                            16,
                            24,
                          ),
                          itemCount: reportesFiltrados.length,
                          itemBuilder: (context, index) {
                            final reporte = reportesFiltrados[index];

                            return _TarjetaReporte(
                              reporte: reporte,
                              onAtender: () =>
                                  _marcarComoAtendido(reporte),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ResumenReporte extends StatelessWidget {
  final String titulo;
  final int cantidad;
  final IconData icono;
  final Color color;

  const _ResumenReporte({
    required this.titulo,
    required this.cantidad,
    required this.icono,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icono, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cantidad.toString(),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    titulo,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TarjetaReporte extends StatelessWidget {
  final ReportModel reporte;
  final VoidCallback onAtender;

  const _TarjetaReporte({
    required this.reporte,
    required this.onAtender,
  });

  String _formatearFecha(int timestamp) {
    final fecha = DateTime.fromMillisecondsSinceEpoch(timestamp).toLocal();

    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    final anio = fecha.year.toString();
    final hora = fecha.hour.toString().padLeft(2, '0');
    final minuto = fecha.minute.toString().padLeft(2, '0');

    return '$dia/$mes/$anio a las $hora:$minuto';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pendiente = reporte.estaPendiente;

    final color = pendiente ? Colors.orange : Colors.green;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    reporte.tipoDescripcion,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    pendiente ? 'Pendiente' : 'Atendido',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _DatoReporte(
              icono: Icons.meeting_room_outlined,
              etiqueta: 'Salón',
              valor: reporte.salonNombre,
            ),
            const SizedBox(height: 8),
            _DatoReporte(
              icono: Icons.power,
              etiqueta: 'Dispositivo',
              valor: reporte.deviceId,
            ),
            const SizedBox(height: 8),
            _DatoReporte(
              icono: Icons.person_outline,
              etiqueta: 'Reportado por',
              valor: reporte.userEmail,
            ),
            const SizedBox(height: 8),
            _DatoReporte(
              icono: Icons.calendar_today_outlined,
              etiqueta: 'Fecha',
              valor: _formatearFecha(reporte.fechaCreacion),
            ),
            if (reporte.descripcion.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text(
                'Descripción',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(reporte.descripcion),
            ],
            if (!pendiente && reporte.fechaAtencion != null) ...[
              const SizedBox(height: 12),
              _DatoReporte(
                icono: Icons.check_circle_outline,
                etiqueta: 'Atendido el',
                valor: _formatearFecha(reporte.fechaAtencion!),
              ),
            ],
            if (pendiente) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onAtender,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Marcar como atendido'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DatoReporte extends StatelessWidget {
  final IconData icono;
  final String etiqueta;
  final String valor;

  const _DatoReporte({
    required this.icono,
    required this.etiqueta,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icono,
          size: 18,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodyMedium,
              children: [
                TextSpan(
                  text: '$etiqueta: ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: valor),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
