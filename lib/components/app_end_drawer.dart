import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../screens/edit_account_screen.dart';
import '../screens/admin_users_screen.dart';
import '../screens/devices_screen.dart';
import '../screens/salones_screen.dart';
import '../screens/my_devices_screen.dart';
import '../screens/qr_scanner_screen.dart';
import '../services/storage_service.dart';

class AppEndDrawer extends ConsumerWidget {
  final UserModel userData;
  final Future<void> Function() onLogout;

  const AppEndDrawer({
    super.key,
    required this.userData,
    required this.onLogout,
  });

  Future<String?> _obtenerFoto(String ruta) async {
    if (ruta.isEmpty) return null;

    if (ruta.startsWith('http://') || ruta.startsWith('https://')) {
      return ruta;
    }

    if (ruta.startsWith('perfiles/')) {
      return StorageService().obtenerUrlImagen(ruta);
    }

    return null;
  }

  void _mostrarInformacionCorreo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Información de la cuenta'),
        content: const Text(
          'La cuenta se encuentra vinculada con otro método de sesión, '
          'favor de acceder a la app y vincular la sesión y añadir a su '
          'cuenta correspondiente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Obtener el perfil actualizado desde Firebase.
    final perfilActual =
        ref.watch(currentUserDataProvider).asData?.value ?? userData;

    final esAdministrador = perfilActual.role == 'admin';

    // Administradores y profesores autorizados pueden usar dispositivos.
    final puedeUsarDispositivos = esAdministrador || perfilActual.autorizado;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Información del usuario.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Column(
                children: [
                  FutureBuilder<String?>(
                    future: _obtenerFoto(perfilActual.fotoUrl),
                    builder: (context, snapshot) {
                      final foto = snapshot.data;

                      return CircleAvatar(
                        radius: 42,
                        backgroundImage: foto != null
                            ? NetworkImage(foto)
                            : null,
                        child: foto == null
                            ? const Icon(Icons.person, size: 42)
                            : null,
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    perfilActual.nombre.isEmpty
                        ? 'Usuario'
                        : perfilActual.nombre,
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () => _mostrarInformacionCorreo(context),
                    child: Text(
                      perfilActual.email,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Chip(
                    avatar: Icon(
                      esAdministrador
                          ? Icons.admin_panel_settings
                          : Icons.person,
                      size: 18,
                    ),
                    label: Text(esAdministrador ? 'Administrador' : 'Usuario'),
                  ),
                  if (!esAdministrador && !perfilActual.autorizado) ...[
                    const SizedBox(height: 4),
                    const Chip(
                      avatar: Icon(Icons.hourglass_top, size: 18),
                      label: Text('Pendiente de aprobación'),
                    ),
                  ],
                ],
              ),
            ),

            // Opciones de navegación.
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.account_circle_outlined),
                      title: const Text('Editar cuenta'),
                      subtitle: const Text('Perfil y métodos de acceso'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                EditAccountScreen(userData: perfilActual),
                          ),
                        );
                      },
                    ),

                    // Opciones exclusivas del administrador.
                    if (esAdministrador) ...[
                      ListTile(
                        leading: const Icon(Icons.manage_accounts_outlined),
                        title: const Text('Administrar usuarios'),
                        subtitle: const Text('Gestionar cuentas y permisos'),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AdminUsersScreen(
                                userData: perfilActual,
                                onLogout: onLogout,
                              ),
                            ),
                          );
                        },
                      ),

                      ListTile(
                        leading: const Icon(Icons.devices_other),
                        title: const Text('Inventario de dispositivos'),
                        subtitle: const Text(
                          'Administrar dispositivos y códigos QR',
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DevicesScreen(
                                userData: perfilActual,
                                onLogout: onLogout,
                              ),
                            ),
                          );
                        },
                      ),

                      ListTile(
                        leading: const Icon(Icons.meeting_room_outlined),
                        title: const Text('Administrar aulas'),
                        subtitle: const Text('Gestionar salones y fotografías'),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SalonesScreen(
                                userData: perfilActual,
                                esAdministrador: true,
                                onLogout: onLogout,
                              ),
                            ),
                          );
                        },
                      ),
                    ],

                    // Opciones para administradores y profesores autorizados.
                    if (puedeUsarDispositivos) ...[
                      ListTile(
                        leading: const Icon(Icons.qr_code_scanner),
                        title: const Text('Escanear dispositivo'),
                        subtitle: const Text('Leer el código QR de un equipo'),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => QrScannerScreen(
                                userData: perfilActual,
                                onLogout: onLogout,
                              ),
                            ),
                          );
                        },
                      ),

                      ListTile(
                        leading: const Icon(Icons.devices),
                        title: const Text('Mis dispositivos'),
                        subtitle: const Text(
                          'Consultar dispositivos vinculados',
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MyDevicesScreen(
                                userData: perfilActual,
                                onLogout: onLogout,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Cerrar sesión.
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Cerrar sesión',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () async {
                Navigator.pop(context);
                await onLogout();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
