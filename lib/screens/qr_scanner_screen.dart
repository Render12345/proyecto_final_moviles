
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/user_model.dart';
import '../components/app_end_drawer.dart';
import '../providers/auth_provider.dart';
import '../providers/device_provider.dart';
import 'device_detail_screen.dart';

class QrScannerScreen extends ConsumerStatefulWidget {
  final UserModel userData;
  final Future<void> Function() onLogout;

  const QrScannerScreen({
    super.key,
    required this.userData,
    required this.onLogout,
  });

  @override
  ConsumerState<QrScannerScreen> createState() =>
      _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
  static const String _prefijoQr = 'CONTROL-AIRES:DEVICE:';

  late final MobileScannerController _controller;

  bool _procesando = false;
  bool _camaraDetenida = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();

    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
  }

  bool _estaAutorizado(UserModel? usuario) {
    if (usuario == null) return false;

    return usuario.role == 'admin' || usuario.autorizado;
  }

  Future<void> _procesarCodigo(BarcodeCapture capture) async {
    if (_procesando || _disposed) return;

    // Consultar el perfil más reciente.
    final usuarioActual =
        ref.read(currentUserDataProvider).asData?.value;

    if (!_estaAutorizado(usuarioActual)) {
      _mostrarMensaje(
        'Tu cuenta no está autorizada para utilizar el escáner.',
        esError: true,
      );
      return;
    }

    final codigo = capture.barcodes.isEmpty
        ? null
        : capture.barcodes.first.rawValue;

    if (codigo == null || codigo.isEmpty) return;

    if (!codigo.startsWith(_prefijoQr)) {
      _mostrarMensaje(
        'Este código QR no pertenece a Control Aires ITC.',
        esError: true,
      );
      return;
    }

    final deviceId = codigo.substring(_prefijoQr.length).trim();

    if (deviceId.isEmpty) {
      _mostrarMensaje(
        'El código QR no contiene un dispositivo válido.',
        esError: true,
      );
      return;
    }

    _procesando = true;

    try {
      // Detener la cámara mientras se procesa el dispositivo.
      await _controller.stop();
      _camaraDetenida = true;

      if (!mounted || _disposed) return;

      // 1. Comprobar nuevamente la autorización.
      final usuarioAntesDeConsultar =
          ref.read(currentUserDataProvider).asData?.value;

      if (!_estaAutorizado(usuarioAntesDeConsultar)) {
        _mostrarMensaje(
          'Tu cuenta ya no está autorizada para realizar esta acción.',
          esError: true,
        );
        return;
      }

      // 2. Validar que el dispositivo exista en el backend.
      await ref
          .read(deviceServiceProvider)
          .obtenerDispositivo(deviceId);

      if (!mounted || _disposed) return;

      // 3. Comprobar nuevamente la autorización antes de vincular.
      final usuarioAntesDeGuardar =
          ref.read(currentUserDataProvider).asData?.value;

      if (!_estaAutorizado(usuarioAntesDeGuardar)) {
        _mostrarMensaje(
          'Tu cuenta ya no está autorizada para vincular dispositivos.',
          esError: true,
        );
        return;
      }

      // Usar el UID del perfil actual, no uno potencialmente desactualizado.
      final referencia = FirebaseDatabase.instance.ref(
        'users/${usuarioAntesDeGuardar!.uid}/dispositivos_vinculados/$deviceId',
      );

      final existente = await referencia.get();

      if (!mounted || _disposed) return;

      // 4. Guardar el dispositivo en el perfil del usuario.
      await referencia.set(true);

      // Actualizar los datos del usuario en Riverpod.
      ref.invalidate(currentUserDataProvider);

      if (!mounted || _disposed) return;

      _mostrarMensaje(
        existente.exists
            ? 'Este dispositivo ya estaba en tus dispositivos.'
            : '¡Dispositivo agregado correctamente!',
      );

      // 5. Abrir los detalles del dispositivo.
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DeviceDetailScreen(
            deviceId: deviceId,
          ),
        ),
      );
    } catch (error) {
      if (!mounted || _disposed) return;

      _mostrarMensaje(
        'No se pudo agregar el dispositivo: $error',
        esError: true,
      );
    } finally {
      // Reactivar la cámara únicamente si la pantalla sigue abierta
      // y nosotros mismos la habíamos detenido.
      if (mounted && !_disposed) {
        if (_camaraDetenida) {
          try {
            await _controller.start();
          } catch (error) {
            debugPrint(
              'No se pudo reactivar la cámara: $error',
            );
          }
        }

        if (mounted && !_disposed) {
          _camaraDetenida = false;
          _procesando = false;
        }
      }
    }
  }

  void _mostrarMensaje(
    String mensaje, {
    bool esError = false,
  }) {
    if (!mounted || _disposed) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: esError ? Colors.red : null,
      ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usuarioAsync = ref.watch(currentUserDataProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Escanear dispositivo'),
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
      body: usuarioAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No se pudo verificar tu autorización:\n$error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (usuario) {
          if (!_estaAutorizado(usuario)) {
            return const _AccesoNoAutorizado();
          }

          return _contenidoScanner();
        },
      ),
    );
  }

  Widget _contenidoScanner() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(
                Icons.qr_code_scanner,
                size: 48,
              ),
              SizedBox(height: 12),
              Text(
                'Escanea el código QR del dispositivo',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Coloca el código dentro del recuadro para '
                'consultar y guardar el dispositivo.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
                    controller: _controller,
                    onDetect: _procesarCodigo,
                    errorBuilder: (context, error) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.camera_alt_outlined,
                                size: 56,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No se pudo iniciar la cámara: '
                                '${error.errorCode.name}',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  IgnorePointer(
                    child: Center(
                      child: Container(
                        width: 240,
                        height: 240,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.white,
                            width: 4,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: OutlinedButton.icon(
            onPressed: () => _controller.toggleTorch(),
            icon: const Icon(Icons.flashlight_on),
            label: const Text(
              'Activar o desactivar linterna',
            ),
          ),
        ),
      ],
    );
  }
}

class _AccesoNoAutorizado extends StatelessWidget {
  const _AccesoNoAutorizado();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              size: 64,
              color: Colors.orange.shade700,
            ),
            const SizedBox(height: 16),
            const Text(
              'Acceso no autorizado',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Un administrador debe autorizar tu cuenta '
              'antes de que puedas escanear dispositivos.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
