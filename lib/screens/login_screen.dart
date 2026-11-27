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
    const green = Color(0xFF087443);
    const darkGreen = Color(0xFF123D32);
    const lime = Color(0xFFDDF36A);
    const background = Color(0xFFF3F6F2);

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
        if (mounted) _mostrarMensaje('Error Google: $e', esError: true);
      } finally {
        if (mounted) uiNotifier.setLoading(false);
      }
    }

    InputDecoration fieldDecoration({
      required String label,
      required IconData icon,
      Widget? suffix,
    }) {
      return InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFF7F9F7),
        floatingLabelStyle: const TextStyle(
          color: darkGreen,
          fontWeight: FontWeight.w600,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE1E7E2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: green, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.red.shade300),
        ),
      );
    }

    Widget brand({required bool onDark}) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: onDark ? lime : green,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.ac_unit_rounded,
              color: onDark ? darkGreen : Colors.white,
              size: 25,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Control Aires',
                style: TextStyle(
                  color: onDark ? Colors.white : darkGreen,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'ITC',
                style: TextStyle(
                  color: onDark ? lime : green,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3,
                ),
              ),
            ],
          ),
        ],
      );
    }

    Widget form(bool compact) {
      return Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4F1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _ModeButton(
                      label: 'Entrar',
                      selected: !uiState.isRegisterMode,
                      onTap: uiState.isRegisterMode
                          ? uiNotifier.toggleRegisterMode
                          : null,
                    ),
                  ),
                  Expanded(
                    child: _ModeButton(
                      label: 'Crear cuenta',
                      selected: uiState.isRegisterMode,
                      onTap: !uiState.isRegisterMode
                          ? uiNotifier.toggleRegisterMode
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: compact ? 16 : 24),
            Text(
              uiState.isRegisterMode ? 'Crear cuenta' : 'Bienvenido',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: darkGreen,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              uiState.isRegisterMode
                  ? 'Configura tu acceso al sistema de clima.'
                  : 'Accede al panel de Control Aires.',
              style: const TextStyle(color: Color(0xFF718078)),
            ),
            SizedBox(height: compact ? 14 : 24),
            if (uiState.isRegisterMode) ...[
              TextFormField(
                controller: _nombreCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: fieldDecoration(
                  label: 'Nombre completo',
                  icon: Icons.person_outline_rounded,
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Ingresa tu nombre'
                    : null,
              ),
              const SizedBox(height: 14),
            ],
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: fieldDecoration(
                label: 'Correo electrónico',
                icon: Icons.alternate_email_rounded,
              ),
              validator: (v) =>
                  (v == null || !v.contains('@')) ? 'Correo inválido' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _passCtrl,
              obscureText: uiState.obscurePassword,
              decoration: fieldDecoration(
                label: 'Contraseña',
                icon: Icons.lock_outline_rounded,
                suffix: IconButton(
                  icon: Icon(
                    uiState.obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
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
            SizedBox(height: compact ? 6 : 12),
            FilledButton(
              onPressed: uiState.isLoading ? null : _submitCorreo,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 17),
                backgroundColor: green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
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
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: uiState.isLoading ? null : _loginConHuella,
                icon: const Icon(Icons.fingerprint_rounded),
                label: const Text('Acceso biométrico'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  foregroundColor: darkGreen,
                  side: const BorderSide(color: Color(0xFFC9D5CD)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    Widget socialButtons({required bool onDark}) {
      final foreground = onDark ? Colors.white : darkGreen;
      final border = onDark ? Colors.white54 : const Color(0xFFCDD7D0);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Divider(color: border)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'o continúa con',
                  style: TextStyle(
                    color: onDark ? Colors.white70 : const Color(0xFF7A877F),
                    fontSize: 12,
                  ),
                ),
              ),
              Expanded(child: Divider(color: border)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: uiState.isLoading ? null : loginGoogle,
                  icon: const Icon(Icons.g_mobiledata_rounded, size: 24),
                  label: const Text('Google'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: foreground,
                    side: BorderSide(color: border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: uiState.isLoading ? null : _iniciarConGitHub,
                  icon: const Icon(Icons.code_rounded, size: 19),
                  label: const Text('GitHub'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: foreground,
                    side: BorderSide(color: border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 780;
          final compact = constraints.maxHeight < 620;

          if (wide) {
            return Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Expanded(
                    flex: 42,
                    child: Container(
                      margin: const EdgeInsets.only(right: 18),
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: darkGreen,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Positioned(
                            right: -90,
                            top: -70,
                            child: Container(
                              width: 230,
                              height: 230,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  width: 38,
                                ),
                              ),
                            ),
                          ),
                          SingleChildScrollView(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                compact ? 26 : 42,
                                compact ? 22 : 38,
                                compact ? 26 : 42,
                                compact ? 22 : 34,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  brand(onDark: true),
                                  SizedBox(height: compact ? 18 : 48),
                                  Container(
                                    width: compact ? 58 : 86,
                                    height: compact ? 58 : 86,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.08,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        compact ? 18 : 24,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.thermostat_auto_rounded,
                                      color: lime,
                                      size: compact ? 34 : 48,
                                    ),
                                  ),
                                  SizedBox(height: compact ? 14 : 24),
                                  Text(
                                    'El clima de tu\ninstitución, a control.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineLarge
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontSize: compact ? 30 : null,
                                          height: 1.05,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                  SizedBox(height: compact ? 8 : 14),
                                  Text(
                                    'Monitorea, configura y mantiene tus equipos en un solo lugar.',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.72,
                                      ),
                                      height: 1.4,
                                      fontSize: compact ? 13 : 14,
                                    ),
                                  ),
                                  SizedBox(height: compact ? 18 : 42),
                                  socialButtons(onDark: true),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 58,
                    child: Center(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                          horizontal: constraints.maxWidth >= 1100 ? 54 : 28,
                          vertical: compact ? 12 : 24,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: Container(
                            padding: EdgeInsets.fromLTRB(
                              30,
                              compact ? 22 : 34,
                              30,
                              compact ? 20 : 30,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: const Color(0xFFE4EAE5),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: darkGreen.withValues(alpha: 0.07),
                                  blurRadius: 36,
                                  offset: const Offset(0, 16),
                                ),
                              ],
                            ),
                            child: form(compact),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return SafeArea(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(18, compact ? 10 : 18, 18, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                      decoration: BoxDecoration(
                        color: darkGreen,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: brand(onDark: true),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        compact ? 18 : 24,
                        20,
                        20,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0xFFE2E8E3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          form(compact),
                          const SizedBox(height: 14),
                          socialButtons(onDark: false),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _ModeButton({required this.label, required this.selected, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFF123D32).withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF123D32) : const Color(0xFF7A877F),
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
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
      final verificado = await authService.verificarSiYaConfirmoCorreo();

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
        const SnackBar(content: Text('Correo de verificación reenviado.')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo reenviar el correo: $e')),
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
                  minHeight: constraints.maxHeight - (compacto ? 24 : 48),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 450),
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
                          onPressed: _reenviando ? null : _reenviarCorreo,
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
