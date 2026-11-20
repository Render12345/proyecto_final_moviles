import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/admin_users_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Descomenta y coloca tus datos cuando tengas listo Supabase Storage:
  // await Supabase.initialize(
  //   url: 'TU_SUPABASE_PROJECT_URL',
  //   anonKey: 'TU_SUPABASE_ANON_KEY',
  // );

  runApp(const ProviderScope(child: MyApp()));
}

Future<void> cerrarSesionSeguro(WidgetRef ref) async {
  final loggingOutNotifier = ref.read(isLoggingOutProvider.notifier);
  if (ref.read(isLoggingOutProvider)) return;

  loggingOutNotifier.state = true;
  try {
    ref.read(loginUiProvider.notifier).setLoading(false);
    await ref.read(authServiceProvider).cerrarSesion();
  } finally {
    loggingOutNotifier.state = false;
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggingOut = ref.watch(isLoggingOutProvider);
    final authState = ref.watch(firebaseAuthStateProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Control Aires ITC',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      home: isLoggingOut
          ? const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            )
          : authState.when(
              loading: () => const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Scaffold(
                body: Center(child: Text('Error de sesión: $e')),
              ),
              data: (user) {
                if (user == null) return const LoginScreen();

                final esCorreo =
                    user.providerData.any((p) => p.providerId == 'password');
                if (esCorreo && !user.emailVerified) {
                  return const VerifyEmailScreen();
                }

                final userDataAsync = ref.watch(currentUserDataProvider);
                return userDataAsync.when(
                  loading: () => const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Scaffold(
                    body: Center(child: Text('Error al cargar perfil: $e')),
                  ),
                  data: (userData) {
                    if (userData == null) {
                      return Scaffold(
                        appBar: AppBar(
                          title: const Text('Perfil no encontrado'),
                          actions: [
                            IconButton(
                              icon: const Icon(Icons.logout),
                              onPressed: () => cerrarSesionSeguro(ref),
                            ),
                          ],
                        ),
                        body: const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Tu usuario existe en Auth pero aún no tiene registro en Realtime Database.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      );
                    }

                    if (userData.role == 'admin') {
                      return const AdminUsersScreen();
                    }

                    return Scaffold(
                      appBar: AppBar(
                        title: Text('Hola, ${userData.nombre}'),
                        actions: [
                          IconButton(
                            icon: const Icon(Icons.logout),
                            onPressed: () => cerrarSesionSeguro(ref),
                          ),
                        ],
                      ),
                      body: Center(
                        child: Text(
                          userData.autorizado
                              ? 'Usuario autorizado: Listo para escanear QR'
                              : 'Cuenta pendiente de aprobación por un administrador',
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}