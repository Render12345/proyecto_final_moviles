import 'dart:math';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import '../providers/auth_provider.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  final UserModel userData;

  const SubscriptionScreen({super.key, required this.userData});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titularController = TextEditingController();
  final _numeroController = TextEditingController();
  final _vencimientoController = TextEditingController();
  final _cvvController = TextEditingController();

  String _planSeleccionado = 'profesional';
  String _modalidadSeleccionada = 'mensual';

  bool _procesando = false;
  bool _mostrarCvv = false;

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
  void dispose() {
    _titularController.dispose();
    _numeroController.dispose();
    _vencimientoController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _planActual {
    return _planes.firstWhere((plan) => plan['id'] == _planSeleccionado);
  }

  int get _precio {
    return _modalidadSeleccionada == 'mensual'
        ? _planActual['mensual'] as int
        : _planActual['anual'] as int;
  }

  String get _nombrePlan => _planActual['nombre'] as String;

  String get _uid => widget.userData.uid;

  String get _ultimosDigitos {
    final numero = _numeroController.text.replaceAll(' ', '');
    if (numero.length < 4) return '----';
    return numero.substring(numero.length - 4);
  }

  String? _validarNumero(String? value) {
    final numero = (value ?? '').replaceAll(' ', '');

    if (numero.isEmpty) {
      return 'Introduce el número de tarjeta';
    }

    if (!RegExp(r'^\d{16}$').hasMatch(numero)) {
      return 'La tarjeta debe tener 16 dígitos';
    }

    return null;
  }

  String? _validarVencimiento(String? value) {
    final texto = (value ?? '').trim();

    if (!RegExp(r'^(0[1-9]|1[0-2])\/\d{2}$').hasMatch(texto)) {
      return 'Usa el formato MM/AA';
    }

    final partes = texto.split('/');
    final mes = int.parse(partes[0]);
    final anio = 2000 + int.parse(partes[1]);

    final ahora = DateTime.now();
    final vencimiento = DateTime(anio, mes + 1, 0);

    if (vencimiento.isBefore(DateTime(ahora.year, ahora.month, 1))) {
      return 'La tarjeta está vencida';
    }

    return null;
  }

  String? _validarCvv(String? value) {
    if (value == null || !RegExp(r'^\d{3,4}$').hasMatch(value)) {
      return 'Introduce un CVV de 3 o 4 dígitos';
    }

    return null;
  }

  Future<void> _activarPlanGratuito() async {
    setState(() => _procesando = true);

    try {
      final ahora = DateTime.now();
      final fechaFin = ahora.add(const Duration(days: 365));

      await FirebaseDatabase.instance.ref('users/$_uid').update({
        'plan_suscripcion': _planSeleccionado,
        'suscripcion': {
          'nombre_plan': _nombrePlan,
          'modalidad': 'gratuita',
          'precio_simulado': 0,
          'moneda': 'MXN',
          'estado': 'activa',
          'fecha_inicio': ahora.toIso8601String(),
          'fecha_fin': fechaFin.toIso8601String(),
          'simulada': true,
          'metodo_pago': 'sin_costo',
        },
      });

      ref.invalidate(currentUserDataProvider);

      if (!mounted) return;

      _mostrarResultado(
        aprobado: true,
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

  Future<void> _procesarPago() async {
    if (_procesando) return;

    // Primero comprobamos si el plan es gratuito.
    // No necesita validar un formulario de tarjeta.
    if (_precio <= 0) {
      await _activarPlanGratuito();
      return;
    }

    // Validamos la tarjeta solamente para planes de pago.
    final formState = _formKey.currentState;

    if (formState == null || !formState.validate()) {
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar pago simulado'),
        content: Text(
          'Se realizará una simulación de pago por '
          '\$$_precio MXN para el plan $_nombrePlan '
          'con modalidad $_modalidadSeleccionada.\n\n'
          'No se realizará ningún cobro real.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Simular pago'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    setState(() => _procesando = true);

    try {
      final aprobado = Random().nextInt(2) == 0;

      final ahora = DateTime.now();

      final fechaFin = _modalidadSeleccionada == 'mensual'
          ? DateTime(ahora.year, ahora.month + 1, ahora.day)
          : DateTime(ahora.year + 1, ahora.month, ahora.day);

      final transaccionRef = FirebaseDatabase.instance
          .ref('users/$_uid/transacciones')
          .push();

      final transaccionId = transaccionRef.key;

      if (transaccionId == null) {
        throw Exception('No se pudo generar el registro de transacción.');
      }

      final transaccion = {
        'id': transaccionId,
        'plan': _planSeleccionado,
        'nombre_plan': _nombrePlan,
        'modalidad': _modalidadSeleccionada,
        'importe': _precio,
        'moneda': 'MXN',
        'resultado': aprobado ? 'completado' : 'saldo_insuficiente',
        'mensaje': aprobado ? 'Pago simulado completado' : 'Saldo insuficiente',
        'metodo_pago': 'tarjeta_virtual_demo',
        'ultimos_digitos': _ultimosDigitos,
        'fecha': ahora.toIso8601String(),
        'simulado': true,
      };

      final updates = <String, dynamic>{
        'users/$_uid/transacciones/$transaccionId': transaccion,
      };

      if (aprobado) {
        updates['users/$_uid/plan_suscripcion'] = _planSeleccionado;

        updates['users/$_uid/suscripcion'] = {
          'nombre_plan': _nombrePlan,
          'modalidad': _modalidadSeleccionada,
          'precio_simulado': _precio,
          'moneda': 'MXN',
          'estado': 'activa',
          'fecha_inicio': ahora.toIso8601String(),
          'fecha_fin': fechaFin.toIso8601String(),
          'simulada': true,
          'metodo_pago': 'tarjeta_virtual_demo',
          'pago_aprobado': true,
        };
      }

      await FirebaseDatabase.instance.ref().update(updates);

      if (aprobado) {
        ref.invalidate(currentUserDataProvider);
      }

      if (!mounted) return;

      _mostrarResultado(
        aprobado: aprobado,
        mensaje: aprobado
            ? '¡Pago completado! Tu suscripción $_nombrePlan está activa.'
            : 'No se pudo completar el pago porque la tarjeta no tiene saldo suficiente.',
      );
    } catch (e) {
      if (!mounted) return;
      _mostrarError('Ocurrió un error al procesar el pago: $e');
    } finally {
      if (mounted) {
        setState(() => _procesando = false);
      }
    }
  }

  void _mostrarResultado({required bool aprobado, required String mensaje}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          aprobado ? Icons.check_circle : Icons.cancel,
          color: aprobado ? Colors.green : Colors.red,
          size: 55,
        ),
        title: Text(aprobado ? 'Pago completado' : 'Pago rechazado'),
        content: Text(
          '$mensaje\n\n'
          'Este resultado corresponde a una simulación académica. '
          'No se realizó ningún cobro real.',
          textAlign: TextAlign.center,
        ),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
    );
  }

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
        onTap: _procesando
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
                          : '\$$precio MXN / ${_modalidadSeleccionada == 'mensual' ? 'mes' : 'año'}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Radio<String>(
                value: plan['id'] as String,
                groupValue: _planSeleccionado,
                onChanged: _procesando
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

  Widget _construirCampo({
    required String etiqueta,
    required TextEditingController controller,
    required String? Function(String?) validator,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? hint,
    Widget? suffixIcon,
    bool obscureText = false,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        obscureText: obscureText,
        textCapitalization: textCapitalization,
        enabled: !_procesando,
        decoration: InputDecoration(
          labelText: etiqueta,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }

  Widget _construirFormularioTarjeta() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.credit_card),
                  SizedBox(width: 10),
                  Text(
                    'Datos de tarjeta de prueba',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Introduce datos ficticios. No utilices una tarjeta bancaria real.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF243B55), Color(0xFF141E30)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'CONTROL AIRES ITC',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Icon(Icons.credit_card, color: Colors.white, size: 30),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Text(
                      _numeroController.text.isEmpty
                          ? '•••• •••• •••• ••••'
                          : _numeroController.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _titularController.text.isEmpty
                                ? 'NOMBRE DEL TITULAR'
                                : _titularController.text.toUpperCase(),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Text(
                          _vencimientoController.text.isEmpty
                              ? 'MM/AA'
                              : _vencimientoController.text,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              _construirCampo(
                etiqueta: 'Nombre del titular',
                controller: _titularController,
                hint: 'Ej. JUAN PEREZ',
                textCapitalization: TextCapitalization.characters,
                validator: (value) {
                  if (value == null || value.trim().length < 3) {
                    return 'Introduce el nombre del titular';
                  }
                  return null;
                },
              ),
              _construirCampo(
                etiqueta: 'Número de tarjeta',
                controller: _numeroController,
                hint: '16 dígitos',
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(16),
                  _SeparadorTarjetaFormatter(),
                ],
                validator: _validarNumero,
              ),
              Row(
                children: [
                  Expanded(
                    child: _construirCampo(
                      etiqueta: 'Vencimiento',
                      controller: _vencimientoController,
                      hint: 'MM/AA',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                        _VencimientoFormatter(),
                      ],
                      validator: _validarVencimiento,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _construirCampo(
                      etiqueta: 'CVV',
                      controller: _cvvController,
                      hint: '123',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      obscureText: !_mostrarCvv,
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _mostrarCvv = !_mostrarCvv;
                          });
                        },
                        icon: Icon(
                          _mostrarCvv ? Icons.visibility_off : Icons.visibility,
                        ),
                      ),
                      validator: _validarCvv,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              const Row(
                children: [
                  Icon(Icons.lock_outline, size: 16, color: Colors.green),
                  SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Los datos de tarjeta no se almacenan. El pago es ficticio.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usuarioActual =
        ref.watch(currentUserDataProvider).asData?.value ?? widget.userData;

    return Scaffold(
      appBar: AppBar(title: const Text('Planes y suscripciones')),
      body: SafeArea(
        child: SingleChildScrollView(
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
              ..._planes.map(_construirPlan),
              const SizedBox(height: 20),
              const Text(
                'Modalidad de suscripción',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              SegmentedButton<String>(
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
                onSelectionChanged: _procesando
                    ? null
                    : (selection) {
                        setState(() {
                          _modalidadSeleccionada = selection.first;
                        });
                      },
              ),
              const SizedBox(height: 22),
              if (_precio > 0) ...[
                _construirFormularioTarjeta(),
                const SizedBox(height: 18),
              ],
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total a pagar',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _precio == 0 ? 'Gratis' : '\$$_precio MXN',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
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
                  onPressed: _procesando ? null : _procesarPago,
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
                        : 'Pagar \$$_precio MXN',
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'CONTROL AIRES ITC · SIMULACIÓN ACADÉMICA',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeparadorTarjetaFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(' ', '');

    final buffer = StringBuffer();

    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write(' ');
      }
      buffer.write(digits[i]);
    }

    final texto = buffer.toString();

    return TextEditingValue(
      text: texto,
      selection: TextSelection.collapsed(offset: texto.length),
    );
  }
}


class _VencimientoFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    final limitedDigits = digits.length > 4
        ? digits.substring(0, 4)
        : digits;

    String formatted = limitedDigits;

    if (limitedDigits.length >= 2) {
      formatted =
          '${limitedDigits.substring(0, 2)}/${limitedDigits.substring(2)}';
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: formatted.length,
      ),
    );
  }
}
