import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../services/biometric_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  // HUELLA: true si hay sensor, huella registrada y credenciales guardadas
  bool _huellaLista = false;

  @override
  void initState() {
    super.initState();
    _revisarHuella();
  }

  Future<void> _revisarHuella() async {
    final listo =
        await BiometricService.disponible() &&
        await BiometricService.tieneCredenciales();

    if (mounted) setState(() => _huellaLista = listo);
  }

  Future<void> _recuperarPassword() async {
    final email = await showDialog<String>(
      context: context,
      builder: (_) => const _DialogoRecuperarPassword(),
    );

    if (!mounted || email == null) return;

    if (email.isEmpty || !email.contains('@')) {
      _mostrarMensaje('Ingresa un correo electrónico válido.', esError: true);
      return;
    }

    final uiNotifier = ref.read(loginUiProvider.notifier);

    uiNotifier.setLoading(true);

    try {
      await ref.read(authServiceProvider).recuperarPassword(email);

      _mostrarMensaje(
        'Se solicitó el envío del enlace. '
        'Revisa tu bandeja de entrada y spam.',
      );
    } on FirebaseAuthException catch (e) {
      _mostrarMensaje(
        'No se pudo enviar el correo: ${e.message ?? e.code}',
        esError: true,
      );
    } catch (e) {
      _mostrarMensaje('Error al recuperar contraseña: $e', esError: true);
    } finally {
      if (mounted) {
        uiNotifier.setLoading(false);
      }
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _reiniciarFormulario() {
    ref.read(loginUiProvider.notifier).setLoading(false);
  }

  void _mostrarMensaje(String msg, {bool esError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: esError ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  // ============================================================
  // HUELLA DACTILAR (opción adicional, no reemplaza ningún método)
  // ============================================================

  /// Devuelve true si después de iniciar sesión se deben guardar las
  /// credenciales para la huella.
  Future<bool> _preguntarActivarHuella() async {
    if (!await BiometricService.disponible()) return false;

    // Si ya hay huella activa, solo se actualizan las credenciales guardadas
    if (await BiometricService.tieneCredenciales()) return true;

    if (await BiometricService.rechazado()) return false;
    if (!mounted) return false;

    final activar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.fingerprint, size: 48),
        title: const Text('¿Activar acceso con huella?'),
        content: const Text(
          'La próxima vez podrás entrar con tu huella sin escribir '
          'tu contraseña.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Ahora no'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Activar'),
          ),
        ],
      ),
    );

    if (activar != true) await BiometricService.marcarRechazado();

    return activar == true;
  }

  Future<void> _loginConHuella() async {
    final uiNotifier = ref.read(loginUiProvider.notifier);
    final authService = ref.read(authServiceProvider);

    if (!await BiometricService.autenticar()) return;

    final cred = await BiometricService.obtenerCredenciales();

    if (cred == null) {
      if (mounted) setState(() => _huellaLista = false);
      return;
    }

    uiNotifier.setLoading(true);

    try {
      await authService.loginConCorreo(cred.email, cred.password);
    } on FirebaseAuthException catch (e) {
      const credencialesInvalidas = {
        'invalid-credential',
        'wrong-password',
        'user-not-found',
      };

      if (credencialesInvalidas.contains(e.code)) {
        await BiometricService.borrar();
        if (mounted) setState(() => _huellaLista = false);

        _mostrarMensaje(
          'Tu contraseña cambió. Inicia sesión con tu correo y vuelve a '
          'activar la huella.',
          esError: true,
        );
      } else {
        _mostrarMensaje('Error: ${e.message ?? e.code}', esError: true);
      }
    } catch (e) {
      _mostrarMensaje('Error: $e', esError: true);
    } finally {
      uiNotifier.setLoading(false);
    }
  }

  // INICIO DE SESIÓN CON CORREO
  Future<void> _submitCorreo() async {
    if (!_formKey.currentState!.validate()) return;

    final uiNotifier = ref.read(loginUiProvider.notifier);
    final authService = ref.read(authServiceProvider);
    final isRegister = ref.read(loginUiProvider).isRegisterMode;

    uiNotifier.setLoading(true);

    try {
      if (isRegister) {
        await authService.registrarConCorreo(
          nombre: _nombreCtrl.text,
          email: _emailCtrl.text,
          password: _passCtrl.text,
        );

        _mostrarMensaje('Cuenta creada. Revisa tu correo para verificarla.');
      } else {
        // Se capturan antes del await: al iniciar sesión esta pantalla
        // se destruye y los controladores dejan de ser válidos.
        final email = _emailCtrl.text.trim();
        final password = _passCtrl.text.trim();

        final guardarHuella = await _preguntarActivarHuella();

        await authService.loginConCorreo(email, password);

        if (guardarHuella) {
          await BiometricService.guardarCredenciales(email, password);
        }
      }
    } catch (e) {
      _mostrarMensaje('Error: $e', esError: true);
    } finally {
      uiNotifier.setLoading(false);
    }
  }

  // RECUPERAR CONTRASEÑA

  Future<String?> _mostrarOpcionesCuentaExistente() {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Esta cuenta ya existe'),
        content: const Text(
          'El correo de GitHub ya está registrado en Control Aires ITC. '
          'Inicia sesión con el método que utilizaste originalmente '
          'para asociar GitHub a tu cuenta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancelar'),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(ctx, 'password'),
            icon: const Icon(Icons.email_outlined),
            label: const Text('Correo'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, 'google'),
            icon: const Icon(Icons.g_mobiledata),
            label: const Text('Google'),
          ),
        ],
      ),
    );
  }

  Future<Map<String, String>?> _mostrarDialogoCredenciales(
    String correoPendiente,
  ) {
    return showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DialogoCredenciales(correoPendiente: correoPendiente),
    );
  }

  // CONTINUAR CON GITHUB
  Future<void> _iniciarConGitHub() async {
    final uiNotifier = ref.read(loginUiProvider.notifier);
    final authService = ref.read(authServiceProvider);

    uiNotifier.setLoading(true);

    try {
      try {
        await authService.loginConGitHub();
      } catch (e) {
        if (!authService.hayCredencialGitHubPendiente) {
          _mostrarMensaje('Error GitHub: $e', esError: true);
          return;
        }

        final correoPendiente = authService.correoGitHubPendiente;

        if (correoPendiente == null || correoPendiente.isEmpty) {
          _mostrarMensaje(
            'No se pudo identificar el correo de GitHub.',
            esError: true,
          );
          return;
        }

        if (!mounted) return;

        final metodo = await _mostrarOpcionesCuentaExistente();

        if (!mounted || metodo == null) return;

        try {
          if (metodo == 'google') {
            await authService.loginConGoogleParaVincular(correoPendiente);
          } else if (metodo == 'password') {
            final credenciales = await _mostrarDialogoCredenciales(
              correoPendiente,
            );

            if (!mounted || credenciales == null) return;

            await authService.loginConCorreo(
              credenciales['email']!,
              credenciales['password']!,
            );
          }

          // Vincular GitHub a la cuenta original autenticada.
          final resultado = await authService.completarVinculacionGitHub();

          if (!mounted) return;

          if (resultado?.user != null) {
            _mostrarMensaje('¡GitHub se vinculó correctamente!');
          }
        } catch (error) {
          if (!mounted) return;

          _mostrarMensaje(
            'No se pudo completar la vinculación: $error',
            esError: true,
          );
        }
      }
    } finally {
      if (mounted) {
        uiNotifier.setLoading(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uiState = ref.watch(loginUiProvider);
    final uiNotifier = ref.read(loginUiProvider.notifier);
    final authService = ref.read(authServiceProvider);

    const verdePrincipal = Color(0xFF087443);

    ref.listen(firebaseAuthStateProvider, (previous, next) {
      if (previous?.asData?.value != next.asData?.value) {
        _reiniciarFormulario();
      }
    });

    Future<void> loginGoogle() async {
      uiNotifier.setLoading(true);

      try {
        await authService.loginConGoogle();
      } catch (e) {
        if (mounted) {
          _mostrarMensaje('Error Google: $e', esError: true);
        }
      } finally {
        if (mounted) {
          uiNotifier.setLoading(false);
        }
      }
    }

    Widget construirFormulario(bool compacto) {
      return Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              uiState.isRegisterMode ? 'Crear cuenta' : 'Bienvenido',
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              uiState.isRegisterMode
                  ? 'Completa tus datos para registrarte.'
                  : 'Inicia sesión con tu correo electrónico.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: compacto ? 16 : 28),

            if (uiState.isRegisterMode) ...[
              TextFormField(
                controller: _nombreCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre completo',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Ingresa tu nombre'
                    : null,
              ),
              const SizedBox(height: 16),
            ],

            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || !v.contains('@')) ? 'Correo inválido' : null,
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _passCtrl,
              obscureText: uiState.obscurePassword,
              decoration: InputDecoration(
                labelText: 'Contraseña',
                prefixIcon: const Icon(Icons.lock_outline),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    uiState.obscurePassword
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: uiNotifier.toggleObscurePassword,
                ),
              ),
              validator: (v) =>
                  (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
            ),

            if (!uiState.isRegisterMode)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: uiState.isLoading ? null : _recuperarPassword,
                  child: const Text('¿Olvidaste tu contraseña?'),
                ),
              ),

            SizedBox(height: compacto ? 8 : 16),

            FilledButton(
              onPressed: uiState.isLoading ? null : _submitCorreo,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                backgroundColor: verdePrincipal,
              ),
              child: uiState.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      uiState.isRegisterMode ? 'Registrarse' : 'Iniciar sesión',
                    ),
            ),

            if (_huellaLista && !uiState.isRegisterMode) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: uiState.isLoading ? null : _loginConHuella,
                icon: const Icon(Icons.fingerprint),
                label: const Text('Entrar con huella'),
              ),
            ],

            const SizedBox(height: 12),

            TextButton(
              onPressed: () {
                uiNotifier.setLoading(false);
                uiNotifier.toggleRegisterMode();
              },
              child: Text(
                uiState.isRegisterMode
                    ? '¿Ya tienes cuenta? Inicia sesión'
                    : '¿No tienes cuenta? Regístrate aquí',
              ),
            ),
          ],
        ),
      );
    }

    Widget construirPanelOAuth({required bool horizontal}) {
      final colorTexto = horizontal
          ? Colors.white
          : Theme.of(context).colorScheme.onSurface;

      final colorSecundario = horizontal
          ? Colors.white70
          : Theme.of(context).colorScheme.onSurfaceVariant;

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (horizontal) ...[
            const Icon(Icons.ac_unit_rounded, size: 76, color: Colors.white),
            const SizedBox(height: 18),
            Text(
              'Control Aires ITC',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(color: colorTexto, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Gestiona y controla los dispositivos de aire acondicionado '
              'de tu institución.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colorSecundario, fontSize: 15),
            ),
            const SizedBox(height: 36),
            Text(
              'Accede también con',
              textAlign: TextAlign.center,
              style: TextStyle(color: colorTexto, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 18),
          ] else ...[
            const Divider(height: 32),
            Text(
              'O continúa con',
              textAlign: TextAlign.center,
              style: TextStyle(color: colorSecundario),
            ),
            const SizedBox(height: 16),
          ],

          OutlinedButton.icon(
            onPressed: uiState.isLoading ? null : loginGoogle,
            style: OutlinedButton.styleFrom(
              foregroundColor: colorTexto,
              side: BorderSide(
                color: horizontal
                    ? Colors.white70
                    : Theme.of(context).dividerColor,
              ),
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
            icon: const Icon(Icons.g_mobiledata, size: 28),
            label: const Text('Continuar con Google'),
          ),

          const SizedBox(height: 12),

          OutlinedButton.icon(
            onPressed: uiState.isLoading ? null : _iniciarConGitHub,
            style: OutlinedButton.styleFrom(
              foregroundColor: colorTexto,
              side: BorderSide(
                color: horizontal
                    ? Colors.white70
                    : Theme.of(context).dividerColor,
              ),
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
            icon: const Icon(Icons.code),
            label: const Text('Continuar con GitHub'),
          ),

          if (horizontal) ...[
            const SizedBox(height: 32),
            Text(
              'Un acceso sencillo y seguro para administrar '
              'los equipos de tu institución.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colorSecundario, fontSize: 12),
            ),
          ],
        ],
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final ancho = constraints.maxWidth;
            final alto = constraints.maxHeight;

            final usarDosColumnas = ancho >= 700;
            final compacto = alto < 500;

            if (usarDosColumnas) {
              return SizedBox(
                height: alto,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // PANEL IZQUIERDO: OAuth
                    Expanded(
                      flex: 4,
                      child: Container(
                        color: verdePrincipal,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 20,
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: alto - 40),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 360,
                                ),
                                child: construirPanelOAuth(horizontal: true),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // PANEL DERECHO: Formulario
                    Expanded(
                      flex: 6,
                      child: Container(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        child: SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                            horizontal: ancho >= 1000 ? 48 : 20,
                            vertical: compacto ? 12 : 24,
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: alto - (compacto ? 24 : 48),
                            ),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 460,
                                ),
                                child: construirFormulario(compacto),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            // Diseño de una columna para celulares y pantallas estrechas.
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.ac_unit_rounded,
                        size: 64,
                        color: verdePrincipal,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Control Aires ITC',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 28),

                      construirFormulario(compacto),

                      construirPanelOAuth(horizontal: false),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}


class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() =>
      _VerifyEmailScreenState();
}

class _VerifyEmailScreenState
    extends ConsumerState<VerifyEmailScreen> {
  Timer? _temporizador;
  bool _verificando = false;
  bool _reenviando = false;
  bool _correoVerificado = false;

  @override
  void initState() {
    super.initState();

    _temporizador = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _comprobarVerificacion(),
    );

    // Primera comprobación al abrir la pantalla.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _comprobarVerificacion();
    });
  }

  Future<void> _comprobarVerificacion() async {
    if (!mounted || _verificando || _correoVerificado) return;

    _verificando = true;

    try {
      final authService = ref.read(authServiceProvider);
      final verificado =
          await authService.verificarSiYaConfirmoCorreo();

      if (!mounted) return;

      if (verificado) {
        _correoVerificado = true;
        _temporizador?.cancel();

        ref.invalidate(firebaseAuthStateProvider);
      }
    } catch (e) {
      debugPrint('Error al comprobar la verificación: $e');
    } finally {
      _verificando = false;
    }
  }

  Future<void> _reenviarCorreo() async {
    if (_reenviando) return;

    setState(() {
      _reenviando = true;
    });

    try {
      final authService = ref.read(authServiceProvider);
      await authService.reenviarVerificacion();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Correo de verificación reenviado.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo reenviar el correo: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _reenviando = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _temporizador?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = ref.read(authServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verificar Correo'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => authService.cerrarSesion(),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compacto = constraints.maxHeight < 500;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: constraints.maxWidth < 400 ? 20 : 24,
                vertical: compacto ? 12 : 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight -
                      (compacto ? 24 : 48),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 450,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.mark_email_unread_outlined,
                          size: compacto ? 55 : 80,
                          color: Colors.blue,
                        ),
                        SizedBox(height: compacto ? 10 : 16),
                        Text(
                          'Confirma tu correo electrónico',
                          style: TextStyle(
                            fontSize: compacto ? 19 : 22,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Enviamos un enlace de verificación a '
                          '${authService.currentUser?.email ?? ''}. '
                          'Confirma tu dirección para continuar.',
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: compacto ? 16 : 24),
                        FilledButton.icon(
                          onPressed:
                              _reenviando ? null : _reenviarCorreo,
                          icon: _reenviando
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.refresh),
                          label: Text(
                            _reenviando
                                ? 'Reenviando...'
                                : 'Reenviar correo de verificación',
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Esta pantalla detectará automáticamente '
                          'cuando confirmes tu correo.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}


class _DialogoCredenciales extends StatefulWidget {
  final String correoPendiente;

  const _DialogoCredenciales({required this.correoPendiente});

  @override
  State<_DialogoCredenciales> createState() => _DialogoCredencialesState();
}

class _DialogoRecuperarPassword extends StatefulWidget {
  const _DialogoRecuperarPassword();

  @override
  State<_DialogoRecuperarPassword> createState() =>
      _DialogoRecuperarPasswordState();
}

class _DialogoRecuperarPasswordState extends State<_DialogoRecuperarPassword> {
  final TextEditingController _emailCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  void _enviar() {
    final email = _emailCtrl.text.trim();

    Navigator.pop(context, email);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Recuperar contraseña'),
      content: TextField(
        controller: _emailCtrl,
        keyboardType: TextInputType.emailAddress,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Correo electrónico',
          prefixIcon: Icon(Icons.email_outlined),
          border: OutlineInputBorder(),
        ),
        onSubmitted: (_) => _enviar(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _enviar, child: const Text('Enviar enlace')),
      ],
    );
  }
}

class _DialogoCredencialesState extends State<_DialogoCredenciales> {
  late final TextEditingController _emailCtrl;
  final TextEditingController _passCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();

    _emailCtrl = TextEditingController(text: widget.correoPendiente);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _continuar() {
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;

    if (email.toLowerCase() != widget.correoPendiente.toLowerCase()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El correo no coincide con el de GitHub.'),
        ),
      );
      return;
    }

    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa tu contraseña original.')),
      );
      return;
    }

    Navigator.pop(context, {'email': email, 'password': password});
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Iniciar sesión con correo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Correo electrónico',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Contraseña',
              prefixIcon: Icon(Icons.lock_outline),
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _continuar(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _continuar, child: const Text('Continuar')),
      ],
    );
  }
}
