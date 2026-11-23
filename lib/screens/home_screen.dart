import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proyecto_final_moviles/screens/my_devices_screen.dart';

import '../providers/auth_provider.dart';
import '../screens/devices_screen.dart';
import '../screens/qr_scanner_screen.dart';
import '../components/app_end_drawer.dart';
import '../services/navigation_service.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userDataAsync = ref.watch(currentUserDataProvider);

    return userDataAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Error al cargar el perfil: $error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
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

        final esAdministrador = userData.role == 'admin';

        // Los profesores pendientes conservan su pantalla de espera.
        if (!esAdministrador && !userData.autorizado) {
          return Scaffold(
            appBar: AppBar(
              title: Text('Bienvenido , ${userData.nombre}'),
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
                    const Icon(
                      Icons.hourglass_top,
                      size: 64,
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Cuenta pendiente de aprobación',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Un administrador debe aprobar tu cuenta '
                      'para habilitar las funcionalidades.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (esAdministrador) {
          return DevicesScreen(
            userData: userData,
            onLogout: () => cerrarSesionSeguro(ref),
          );
        }

        return MyDevicesScreen(
          userData: userData,
          onLogout: () => cerrarSesionSeguro(ref),
        );
      },
    );
  }
}

/// Cierra la sesión y regresa a la pantalla raíz.
Future<void> cerrarSesionSeguro(WidgetRef ref) async {
  final isLoggingOut = ref.read(isLoggingOutProvider);

  if (isLoggingOut) return;

  final logoutController = ref.read(isLoggingOutProvider.notifier);
  final loginUiController = ref.read(loginUiProvider.notifier);
  final authService = ref.read(authServiceProvider);

  logoutController.state = true;

  try {
    loginUiController.setLoading(false);

    await authService.cerrarSesion();

    navigatorKey.currentState?.popUntil((route) => route.isFirst);
  } catch (e) {
    debugPrint('Error al cerrar sesión: $e');
  } finally {
    logoutController.state = false;
  }
}
