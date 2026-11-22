
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';

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
        backgroundColor:
            esError ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
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

        _mostrarMensaje(
          'Cuenta creada. Revisa tu correo para verificarla.',
        );
      } else {
        await authService.loginConCorreo(
          _emailCtrl.text,
          _passCtrl.text,
        );
      }
    } catch (e) {
      _mostrarMensaje('Error: $e', esError: true);
    } finally {
      uiNotifier.setLoading(false);
    }
  }

  // RECUPERAR CONTRASEÑA
  void _dialogoRecuperarPassword() {
    final resetCtrl = TextEditingController(text: _emailCtrl.text);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recuperar contraseña'),
        content: TextField(
          controller: resetCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Ingresa tu correo registrado',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              if (resetCtrl.text.trim().isEmpty) return;

              try {
                await ref
                    .read(authServiceProvider)
                    .recuperarPassword(resetCtrl.text);

                if (ctx.mounted) Navigator.pop(ctx);

                _mostrarMensaje('Correo de recuperación enviado.');
              } catch (e) {
                _mostrarMensaje('Error: $e', esError: true);
              } finally {
                resetCtrl.dispose();
              }
            },
            child: const Text('Enviar enlace'),
          ),
        ],
      ),
    );
  }

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
    builder: (_) => _DialogoCredenciales(
      correoPendiente: correoPendiente,
    ),
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
        _mostrarMensaje(
          'Error GitHub: $e',
          esError: true,
        );
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
          await authService.loginConGoogleParaVincular(
            correoPendiente,
          );
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
        final resultado =
            await authService.completarVinculacionGitHub();

        if (!mounted) return;

        if (resultado?.user != null) {
          _mostrarMensaje(
            '¡GitHub se vinculó correctamente!',
          );
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

    ref.listen(firebaseAuthStateProvider, (previous, next) {
      if (previous?.asData?.value != next.asData?.value) {
        _reiniciarFormulario();
      }
    });

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.ac_unit_rounded,
                    size: 72,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    uiState.isRegisterMode
                        ? 'Crear Cuenta'
                        : 'Control Aires ITC',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),

                  if (uiState.isRegisterMode) ...[
                    TextFormField(
                      controller: _nombreCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre completo',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty)
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
                        (v == null || !v.contains('@'))
                            ? 'Correo inválido'
                            : null,
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
                        (v == null || v.length < 6)
                            ? 'Mínimo 6 caracteres'
                            : null,
                  ),

                  if (!uiState.isRegisterMode)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _dialogoRecuperarPassword,
                        child: const Text('¿Olvidaste tu contraseña?'),
                      ),
                    ),

                  const SizedBox(height: 12),

                  FilledButton(
                    onPressed:
                        uiState.isLoading ? null : _submitCorreo,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
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
                            uiState.isRegisterMode
                                ? 'Registrarse'
                                : 'Iniciar Sesión',
                          ),
                  ),

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

                  const Divider(height: 32),

                  OutlinedButton.icon(
                    onPressed: uiState.isLoading
                        ? null
                        : () async {
                            uiNotifier.setLoading(true);

                            try {
                              await authService.loginConGoogle();
                            } catch (e) {
                              _mostrarMensaje(
                                'Error Google: $e',
                                esError: true,
                              );
                            } finally {
                              if (mounted) {
                                uiNotifier.setLoading(false);
                              }
                            }
                          },
                    icon: const Icon(
                      Icons.g_mobiledata,
                      size: 28,
                    ),
                    label: const Text('Continuar con Google'),
                  ),

                  const SizedBox(height: 12),

                  OutlinedButton.icon(
                    onPressed:
                        uiState.isLoading ? null : _iniciarConGitHub,
                    icon: const Icon(Icons.code),
                    label: const Text('Continuar con GitHub'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class VerifyEmailScreen extends ConsumerWidget {
  const VerifyEmailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.read(authServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verificar Correo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => authService.cerrarSesion(),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.mark_email_unread_outlined,
                size: 80,
                color: Colors.orange,
              ),
              const SizedBox(height: 16),
              const Text(
                'Confirma tu correo electrónico',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Enviamos un enlace de verificación a '
                '${authService.currentUser?.email ?? ''}. '
                'Debes confirmarlo para continuar.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              FilledButton.icon(
                onPressed: () async {
                  final verificado =
                      await authService.verificarSiYaConfirmoCorreo();

                  if (!verificado && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Aún no aparece verificado. '
                          'Revisa tu bandeja o spam.',
                        ),
                      ),
                    );
                  } else if (verificado) {
                    ref.invalidate(firebaseAuthStateProvider);
                  }
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Ya verifiqué mi correo'),
              ),

              const SizedBox(height: 12),

              TextButton(
                onPressed: () async {
                  await authService.reenviarVerificacion();

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Correo de verificación reenviado.',
                        ),
                      ),
                    );
                  }
                },
                child: const Text(
                  'Reenviar correo de confirmación',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class _DialogoCredenciales extends StatefulWidget {
  final String correoPendiente;

  const _DialogoCredenciales({
    required this.correoPendiente,
  });

  @override
  State<_DialogoCredenciales> createState() =>
      _DialogoCredencialesState();
}

class _DialogoCredencialesState
    extends State<_DialogoCredenciales> {
  late final TextEditingController _emailCtrl;
  final TextEditingController _passCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();

    _emailCtrl = TextEditingController(
      text: widget.correoPendiente,
    );
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

    if (email.toLowerCase() !=
        widget.correoPendiente.toLowerCase()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'El correo no coincide con el de GitHub.',
          ),
        ),
      );
      return;
    }

    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa tu contraseña original.'),
        ),
      );
      return;
    }

    Navigator.pop(context, {
      'email': email,
      'password': password,
    });
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
        FilledButton(
          onPressed: _continuar,
          child: const Text('Continuar'),
        ),
      ],
    );
  }
}