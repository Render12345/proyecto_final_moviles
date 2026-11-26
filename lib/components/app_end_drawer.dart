
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proyecto_final_moviles/screens/campus_map_screen.dart';

import '../components/cached_storage_image.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/typography_provider.dart';
import '../screens/edit_account_screen.dart';
import '../screens/admin_users_screen.dart';
import '../screens/devices_screen.dart';
import '../screens/salones_screen.dart';
import '../screens/my_devices_screen.dart';
import '../screens/qr_scanner_screen.dart';
import '../screens/subscription_screen.dart';

class AppEndDrawer extends ConsumerWidget {
  final UserModel userData;
  final Future<void> Function() onLogout;

  const AppEndDrawer({
    super.key,
    required this.userData,
    required this.onLogout,
  });

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
    final perfilActual =
        ref.watch(currentUserDataProvider).asData?.value ?? userData;

    final esAdministrador = perfilActual.role == 'admin';
    final puedeUsarDispositivos =
        esAdministrador || perfilActual.autorizado;

    final temaSeleccionado = ref.watch(themeModeProvider);
    final tipografiaSeleccionada = ref.watch(typographyProvider);

    final colores = Theme.of(context).colorScheme;

    return Drawer(
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Información del usuario.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 28,
                ),
                color: colores.primaryContainer,
                child: Column(
                  children: [
                    CachedProfileAvatar(
                      ruta: perfilActual.fotoUrl,
                      radius: 42,
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
                      label: Text(
                        esAdministrador ? 'Administrador' : 'Usuario',
                      ),
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
              Column(
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
                      subtitle: const Text(
                        'Gestionar cuentas y permisos',
                      ),
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
                      subtitle: const Text(
                        'Gestionar salones y fotografías',
                      ),
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
                      subtitle: const Text(
                        'Leer el código QR de un equipo',
                      ),
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
                    ListTile(
                      leading: const Icon(Icons.card_membership_outlined),
                      title: const Text('Planes y suscripciones'),
                      subtitle: const Text(
                        'Consultar y administrar tu plan',
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                SubscriptionScreen(userData: perfilActual),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.map_outlined),
                      title: const Text('Mapa del campus'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CampusMapScreen(),
                          ),
                        );
                      },
                    ),
                  ],

                  // Configuración de apariencia.
                  const Divider(),

                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Apariencia',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ),

                  RadioGroup<ThemeMode>(
                    groupValue: temaSeleccionado,
                    onChanged: (tema) {
                      if (tema != null) {
                        ref
                            .read(themeModeProvider.notifier)
                            .cambiarTema(tema);
                      }
                    },
                    child: const Column(
                      children: [
                        RadioListTile<ThemeMode>(
                          value: ThemeMode.light,
                          title: Text('Claro'),
                          secondary: Icon(Icons.light_mode_outlined),
                        ),
                        RadioListTile<ThemeMode>(
                          value: ThemeMode.dark,
                          title: Text('Oscuro'),
                          secondary: Icon(Icons.dark_mode_outlined),
                        ),
                      ],
                    ),
                  ),

                  const Divider(),

                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Tipografía',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ),

                  RadioGroup<AppTypography>(
                    groupValue: tipografiaSeleccionada,
                    onChanged: (tipografia) {
                      if (tipografia != null) {
                        ref
                            .read(typographyProvider.notifier)
                            .cambiarTipografia(tipografia);
                      }
                    },
                    child: Column(
                      children: AppTypography.values.map((tipografia) {
                        return RadioListTile<AppTypography>(
                          value: tipografia,
                          title: Text(
                            tipografia.nombre,
                            style: TextStyle(
                              fontFamily: tipografia.fontFamily,
                            ),
                          ),
                          secondary: const Icon(Icons.text_fields),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),

              // Cerrar sesión.
              const Divider(height: 1),
              ListTile(
                leading: const Icon(
                  Icons.logout,
                  color: Colors.red,
                ),
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
      ),
    );
  }
}
