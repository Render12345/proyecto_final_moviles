import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/navigation_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
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
      home: const AuthGate(),
    );
  }
}

/// Pantalla raíz: siempre muestra la vista correspondiente
/// al estado actual de autenticación de Firebase.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(firebaseAuthStateProvider);

    return authState.when(
      loading: () => const _PantallaCarga(),
      error: (error, stackTrace) =>
          _PantallaError(mensaje: 'Error al verificar la sesión: $error'),
      data: (authUser) {
        if (authUser == null) {
          return const LoginScreen();
        }

        final esCuentaCorreo = authUser.providerData.any(
          (provider) => provider.providerId == 'password',
        );

        if (esCuentaCorreo && !authUser.emailVerified) {
          return const VerifyEmailScreen();
        }

        return const HomeScreen();
      },
    );
  }
}

class _PantallaCarga extends StatelessWidget {
  const _PantallaCarga();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

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
