import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/mercadopago_config.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../services/mercadopago_service.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  final UserModel userData;

  const SubscriptionScreen({super.key, required this.userData});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen>
    with WidgetsBindingObserver {
  String _planSeleccionado = 'profesional';
  String _modalidadSeleccionada = 'mensual';

  bool _procesando = false;
  bool _verificando = false;

  String? _pagoIdEspera;
  Map<String, dynamic>? _txEspera;
  String? _initPoint;
  String? _estadoMp;
  Timer? _timer;

  final List<Map<String, dynamic>> _planes = [
    {
      'id': 'basico',
      'nombre': 'Básico',
      'descripcion': 'Acceso básico a la plataforma.',
      'mensual': 0,
      'anual': 0,
      'icono': Icons.home_outlined,
    },
    {
      'id': 'profesional',
      'nombre': 'Profesional',
      'descripcion': 'Funciones para gestionar tus dispositivos.',
      'mensual': 99,
      'anual': 990,
      'icono': Icons.workspace_premium_outlined,
    },
    {
      'id': 'institucional',
      'nombre': 'Institucional',
      'descripcion': 'Una experiencia completa de administración.',
      'mensual': 199,
      'anual': 1990,
      'icono': Icons.apartment_outlined,
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _recuperarPendientes();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _verificarEspera();
    }
  }

  Map<String, dynamic> get _planActual =>
      _planes.firstWhere((plan) => plan['id'] == _planSeleccionado);

  int get _precio => _modalidadSeleccionada == 'mensual'
      ? _planActual['mensual'] as int
      : _planActual['anual'] as int;

  String get _nombrePlan => _planActual['nombre'] as String;

  String get _uid => widget.userData.uid;

  bool get _esperandoPago => _pagoIdEspera != null;

  bool get _bloqueado => _procesando || _esperandoPago;

  DatabaseReference get _userRef =>
      FirebaseDatabase.instance.ref('users/$_uid');

  // ============================================================
  // PLAN GRATUITO
  // ============================================================

  Future<void> _activarPlanGratuito() async {
    setState(() => _procesando = true);

    try {
      final ahora = DateTime.now();

      final susSnap = await _userRef.child('suscripcion').get();

      if (susSnap.exists && susSnap.value is Map) {
        final sus = Map<String, dynamic>.from(susSnap.value as Map);

        final fin = DateTime.tryParse(sus['fecha_fin']?.toString() ?? '');

        final precio = (sus['precio'] as num?) ?? 0;

        if (sus['estado'] == 'activa' &&
            precio > 0 &&
            fin != null &&
            fin.isAfter(ahora)) {
          if (mounted) {
            _mostrarError('Ya tienes un plan de pago activo.');
          }
          return;
        }
      }

      await _userRef.update({
        'plan_suscripcion': _planSeleccionado,
        'suscripcion': {
          'nombre_plan': _nombrePlan,
          'modalidad': 'gratuita',
          'precio': 0,
          'moneda': 'MXN',
          'estado': 'activa',
          'fecha_inicio': ahora.toIso8601String(),
          'fecha_fin': DateTime(
            ahora.year + 1,
            ahora.month,
            ahora.day,
          ).toIso8601String(),
          'metodo_pago': 'sin_costo',
        },
      });

      if (!mounted) return;

      _mostrarResultado(
        aprobado: true,
        titulo: 'Plan activado',
        mensaje: 'Tu plan gratuito está activo.',
      );
    } catch (e) {
      if (!mounted) return;
      _mostrarError('No se pudo activar el plan: $e');
    } finally {
      if (mounted) {
        setState(() => _procesando = false);
      }
    }
  }

  // ============================================================
  // INICIAR PAGO
  // ============================================================

  Future<void> _procesarPago() async {
    if (_bloqueado) return;

    if (_precio <= 0) {
      await _activarPlanGratuito();
      return;
    }

    if (!MercadoPagoConfig.configurado) {
      _mostrarError('Falta configurar el Access Token de prueba.');
      return;
    }

    setState(() => _procesando = true);

    try {
      final pagoRef = _userRef.child('transacciones').push();
      final pagoId = pagoRef.key!;

      final tx = <String, dynamic>{
        'id': pagoId,
        'plan': _planSeleccionado,
        'nombre_plan': _nombrePlan,
        'modalidad': _modalidadSeleccionada,
        'importe': _precio,
        'moneda': 'MXN',
        'estado': 'pendiente',
        'metodo_pago': 'mercadopago',
        'fecha': DateTime.now().toIso8601String(),
      };

      final pref = await MercadoPagoService.crearPreferencia(
        plan: _planSeleccionado,
        titulo: 'Suscripción $_nombrePlan ($_modalidadSeleccionada)',
        importe: _precio,
        externalReference: '$_uid:$pagoId',
      );

      await pagoRef.set({...tx, 'preference_id': pref.id});

      _iniciarEspera(pagoId, tx, pref.initPoint);

      final abierto = await launchUrl(
        Uri.parse(pref.initPoint),
        mode: LaunchMode.externalApplication,
      );

      if (!abierto) {
        _detenerEspera();

        if (mounted) {
          _mostrarError('No se pudo abrir MercadoPago.');
        }
      }
    } catch (e) {
      if (!mounted) return;
      _mostrarError('No se pudo iniciar el pago: $e');
    } finally {
      if (mounted) {
        setState(() => _procesando = false);
      }
    }
  }

  // ============================================================
  // ESPERA Y VERIFICACIÓN
  // ============================================================

  void _iniciarEspera(String pagoId, Map<String, dynamic> tx, String url) {
    _timer?.cancel();

    setState(() {
      _pagoIdEspera = pagoId;
      _txEspera = tx;
      _initPoint = url;
      _estadoMp = null;
    });

    _timer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _verificarEspera(),
    );
  }

  void _detenerEspera() {
    _timer?.cancel();
    _timer = null;

    if (!mounted) return;

    setState(() {
      _pagoIdEspera = null;
      _txEspera = null;
      _initPoint = null;
      _estadoMp = null;
    });
  }

  Future<void> _reabrirPago() async {
    final url = _initPoint;

    if (url == null) return;

    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Future<void> _verificarEspera({bool manual = false}) async {
    final id = _pagoIdEspera;
    final tx = _txEspera;

    if (id == null || tx == null) return;

    try {
      final status = await _verificarTransaccion(id, tx);

      if (!mounted || _pagoIdEspera != id) return;

      if (status == 'approved') {
        _detenerEspera();

        _mostrarResultado(
          aprobado: true,
          titulo: 'Pago completado',
          mensaje:
              '¡Pago completado! Tu suscripción '
              '${tx['nombre_plan']} está activa.',
        );
      } else if (status == 'monto_invalido') {
        _detenerEspera();

        _mostrarResultado(
          aprobado: false,
          titulo: 'Pago no válido',
          mensaje: 'El monto del pago no coincide con el plan seleccionado.',
        );
      } else if (status != null) {
        setState(() => _estadoMp = status);
      } else if (manual) {
        _mostrarError('Aún no hay un pago registrado en MercadoPago.');
      }
    } catch (e) {
      if (manual && mounted) {
        _mostrarError('No se pudo verificar: $e');
      }
    }
  }

  Future<String?> _verificarTransaccion(
    String pagoId,
    Map<String, dynamic> tx,
  ) async {
    if (_verificando) return null;

    _verificando = true;

    try {
      final pago = await MercadoPagoService.buscarPago('$_uid:$pagoId');

      if (pago == null) return null;

      final status = pago['status']?.toString();

      if (status != 'approved') return status;

      final monto = (pago['transaction_amount'] as num?)?.toDouble();

      final esperado = (tx['importe'] as num).toDouble();

      if (monto != esperado || pago['currency_id'] != tx['moneda']) {
        await _userRef
            .child('transacciones/$pagoId/estado')
            .set('monto_invalido');

        return 'monto_invalido';
      }

      await _activarSuscripcion(pagoId, tx, pago);

      return 'approved';
    } finally {
      _verificando = false;
    }
  }

  Future<void> _activarSuscripcion(
    String pagoId,
    Map<String, dynamic> tx,
    Map<String, dynamic> pago,
  ) async {
    final ahora = DateTime.now();

    DateTime base = ahora;
    String? inicioPrevio;

    final susSnap = await _userRef.child('suscripcion').get();
    final planSnap = await _userRef.child('plan_suscripcion').get();

    if (susSnap.exists && susSnap.value is Map) {
      final sus = Map<String, dynamic>.from(susSnap.value as Map);

      final finActual = DateTime.tryParse(sus['fecha_fin']?.toString() ?? '');

      if (sus['estado'] == 'activa' &&
          planSnap.value == tx['plan'] &&
          finActual != null &&
          finActual.isAfter(ahora)) {
        base = finActual;
        inicioPrevio = sus['fecha_inicio']?.toString();
      }
    }

    final fin = tx['modalidad'] == 'mensual'
        ? DateTime(base.year, base.month + 1, base.day)
        : DateTime(base.year + 1, base.month, base.day);

    await _userRef.update({
      'transacciones/$pagoId/estado': 'aprobado',
      'transacciones/$pagoId/mp_payment_id': pago['id'].toString(),
      'transacciones/$pagoId/mp_status': 'approved',
      'transacciones/$pagoId/fecha_aprobacion': ahora.toIso8601String(),
      'plan_suscripcion': tx['plan'],
      'suscripcion': {
        'nombre_plan': tx['nombre_plan'],
        'modalidad': tx['modalidad'],
        'precio': tx['importe'],
        'moneda': tx['moneda'],
        'estado': 'activa',
        'fecha_inicio': inicioPrevio ?? ahora.toIso8601String(),
        'fecha_fin': fin.toIso8601String(),
        'metodo_pago': 'mercadopago',
        'pago_id': pagoId,
      },
    });
  }

  Future<void> _recuperarPendientes() async {
    if (!MercadoPagoConfig.configurado) return;

    try {
      final snap = await _userRef.child('transacciones').get();

      if (!snap.exists || snap.value is! Map) return;

      final todas = Map<dynamic, dynamic>.from(snap.value as Map);

      for (final e in todas.entries) {
        if (e.value is! Map) continue;

        final tx = Map<String, dynamic>.from(e.value as Map);

        if (tx['estado'] != 'pendiente') continue;

        final status = await _verificarTransaccion(e.key.toString(), tx);

        if (status == 'approved' && mounted) {
          _mostrarResultado(
            aprobado: true,
            titulo: 'Pago confirmado',
            mensaje:
                'Detectamos un pago aprobado. Tu suscripción '
                '${tx['nombre_plan']} ya está activa.',
          );
          break;
        }
      }
    } catch (_) {
      // Comprobación de cortesía.
    }
  }

  // ============================================================
  // DIÁLOGOS
  // ============================================================

  void _mostrarResultado({
    required bool aprobado,
    required String titulo,
    required String mensaje,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          aprobado ? Icons.check_circle : Icons.cancel,
          color: aprobado ? Colors.green : Colors.red,
          size: 55,
        ),
        title: Text(titulo),
        content: Text(mensaje, textAlign: TextAlign.center),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);

              if (aprobado && mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
    );
  }

  // ============================================================
  // WIDGETS
  // ============================================================

  Widget _construirPlan(Map<String, dynamic> plan) {
    final seleccionado = _planSeleccionado == plan['id'];

    final precio = _modalidadSeleccionada == 'mensual'
        ? plan['mensual']
        : plan['anual'];

    return Card(
      elevation: seleccionado ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: seleccionado
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _bloqueado
            ? null
            : () {
                setState(() {
                  _planSeleccionado = plan['id'] as String;
                });
              },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                plan['icono'] as IconData,
                size: 34,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan['nombre'] as String,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      plan['descripcion'] as String,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 7),
                    Text(
                      precio == 0
                          ? 'Gratis'
                          : '\$$precio MXN / '
                                '${_modalidadSeleccionada == 'mensual' ? 'mes' : 'año'}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Radio<String>(
                value: plan['id'] as String,
                groupValue: _planSeleccionado,
                onChanged: _bloqueado
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() {
                            _planSeleccionado = value;
                          });
                        }
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirAvisoMercadoPago() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.lock_outline, color: Colors.green),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Serás redirigido a MercadoPago para pagar. '
                'La app nunca ve ni guarda los datos de tu tarjeta. '
                'Modo de pruebas: no se realizan cobros reales.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? get _textoEstadoMp {
    switch (_estadoMp) {
      case 'rejected':
      case 'cancelled':
        return 'El último intento fue rechazado. '
            'Puedes reintentar en MercadoPago.';
      case 'pending':
      case 'in_process':
        return 'Tu pago está en proceso en MercadoPago.';
      default:
        return null;
    }
  }

  Widget _construirEsperaPago() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text(
              'Esperando la confirmación de MercadoPago...',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Completa el pago y regresa a la app. '
              'Verificamos el pago automáticamente cada pocos segundos.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_textoEstadoMp != null) ...[
              const SizedBox(height: 10),
              Text(
                _textoEstadoMp!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => _verificarEspera(manual: true),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Ya pagué, verificar'),
                ),
                OutlinedButton.icon(
                  onPressed: _reabrirPago,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Abrir de nuevo'),
                ),
                TextButton(
                  onPressed: _detenerEspera,
                  child: const Text('Dejar de esperar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CONTENIDO RESPONSIVO
  // ============================================================

  Widget _construirContenido(
    BuildContext context,
    UserModel usuarioActual,
    double ancho,
  ) {
    final columnas = ancho >= 900
        ? 3
        : ancho >= 600
        ? 2
        : 1;

    const separacion = 16.0;

    final anchoTarjeta = columnas == 1
        ? ancho
        : (ancho - separacion * (columnas - 1)) / columnas;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.workspace_premium, size: 35),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tu suscripción actual',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          usuarioActual.planSuscripcion.toUpperCase(),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 22),

          const Text(
            'Selecciona un plan',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 12),

          Wrap(
            spacing: separacion,
            runSpacing: separacion,
            children: _planes.map((plan) {
              return SizedBox(width: anchoTarjeta, child: _construirPlan(plan));
            }).toList(),
          ),

          const SizedBox(height: 24),

          const Text(
            'Modalidad de suscripción',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'mensual',
                  label: Text('Mensual'),
                  icon: Icon(Icons.calendar_month),
                ),
                ButtonSegment(
                  value: 'anual',
                  label: Text('Anual'),
                  icon: Icon(Icons.calendar_today),
                ),
              ],
              selected: {_modalidadSeleccionada},
              onSelectionChanged: _bloqueado
                  ? null
                  : (selection) {
                      setState(() {
                        _modalidadSeleccionada = selection.first;
                      });
                    },
            ),
          ),

          const SizedBox(height: 22),

          if (_esperandoPago)
            _construirEsperaPago()
          else if (_precio > 0)
            _construirAvisoMercadoPago(),

          const SizedBox(height: 18),

          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Flexible(
                    child: Text(
                      'Total a pagar',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      _precio == 0 ? 'Gratis' : '\$$_precio MXN',
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _bloqueado ? null : _procesarPago,
              icon: _procesando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.lock),
              label: Text(
                _procesando
                    ? 'Procesando...'
                    : _precio == 0
                    ? 'Activar plan gratuito'
                    : 'Pagar \$$_precio MXN con MercadoPago',
                textAlign: TextAlign.center,
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),

          const SizedBox(height: 12),

          const Center(
            child: Text(
              'CONTROL AIRES ITC · DEMOSTRACIÓN CON MERCADOPAGO',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usuarioActual =
        ref.watch(currentUserDataProvider).asData?.value ?? widget.userData;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Planes y suscripciones',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: _construirContenido(
                  context,
                  usuarioActual,
                  ((constraints.maxWidth > 1100
                              ? 1100.0
                              : constraints.maxWidth) -
                          32)
                      .clamp(0.0, 1100.0)
                      .toDouble(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
