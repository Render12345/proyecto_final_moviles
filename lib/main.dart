import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/admin_users_screen.dart';
import 'components/app_end_drawer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const ProviderScope(child: MyApp()));
}

/// Cierra la sesión evitando que se ejecute más de una vez.
Future<void> cerrarSesionSeguro(WidgetRef ref) async {
  final isLoggingOut = ref.read(isLoggingOutProvider);

  if (isLoggingOut) return;

  ref.read(isLoggingOutProvider.notifier).state = true;

  try {
    ref.read(loginUiProvider.notifier).setLoading(false);

    await ref.read(authServiceProvider).cerrarSesion();
  } catch (e) {
    debugPrint('Error al cerrar sesión: $e');
  } finally {
    ref.read(isLoggingOutProvider.notifier).state = false;
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(firebaseAuthStateProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Control Aires ITC',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      home: authState.when(
        loading: () => const _PantallaCarga(),

        error: (error, stackTrace) =>
            _PantallaError(mensaje: 'Error al verificar la sesión: $error'),

        data: (authUser) {
          // No hay una sesión activa.
          if (authUser == null) {
            return const LoginScreen();
          }

          // Las cuentas registradas con correo deben verificarlo.
          final esCuentaCorreo = authUser.providerData.any(
            (provider) => provider.providerId == 'password',
          );

          if (esCuentaCorreo && !authUser.emailVerified) {
            return const VerifyEmailScreen();
          }

          // Obtener los datos del usuario desde Firebase Realtime Database.
          return const _CargarPerfil();
        },
      ),
    );
  }
}

/// Consulta el perfil del usuario autenticado.
class _CargarPerfil extends ConsumerWidget {
  const _CargarPerfil();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userDataAsync = ref.watch(currentUserDataProvider);

    return userDataAsync.when(
      loading: () => const _PantallaCarga(),

      error: (error, stackTrace) =>
          _PantallaError(mensaje: 'Error al cargar el perfil: $error'),

      data: (userData) {
        if (userData == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Perfil no encontrado')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_off, size: 64),
                    const SizedBox(height: 16),
                    const Text(
                      'No se encontraron los datos de tu perfil.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => cerrarSesionSeguro(ref),
                      icon: const Icon(Icons.logout),
                      label: const Text('Cerrar sesión'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Vista del administrador.
        if (userData.role == 'admin') {
          return AdminUsersScreen(
            userData: userData,
            onLogout: () => cerrarSesionSeguro(ref),
          );
        }

        // Vista del usuario normal.
        return Scaffold(
          appBar: AppBar(
            title: Text('Hola, ${userData.nombre}'),
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
            userData: userData,
            onLogout: () => cerrarSesionSeguro(ref),
          ),

          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    userData.autorizado
                        ? Icons.check_circle
                        : Icons.hourglass_top,
                    size: 64,
                    color: userData.autorizado ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    userData.autorizado
                        ? 'Usuario autorizado'
                        : 'Cuenta pendiente de aprobación',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    userData.autorizado
                        ? 'Ya puedes utilizar las funcionalidades de la aplicación.'
                        : 'Un administrador debe aprobar tu cuenta para habilitar las funcionalidades.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Pantalla mientras Firebase carga información.
class _PantallaCarga extends StatelessWidget {
  const _PantallaCarga();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

/// Pantalla para mostrar errores de autenticación o perfil.
class _PantallaError extends StatelessWidget {
  final String mensaje;

  const _PantallaError({required this.mensaje});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 56),
              const SizedBox(height: 16),
              Text(mensaje, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
