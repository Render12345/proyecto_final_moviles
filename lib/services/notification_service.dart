import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../providers/auth_provider.dart';
import '../screens/admin_reports_screen.dart';
import '../screens/home_screen.dart';
import '../services/navigation_service.dart';

class NotificationService {
  static const String _baseUrl = 'https://qr-dispositivos.onrender.com';

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'control_aires_notifications',
    'Control Aires ITC',
    description: 'Avisos y notificaciones de Control Aires ITC',
    importance: Importance.high,
  );

  static bool _inicializado = false;
  static bool _abriendoReportes = false;

  static String? _ultimoFid;

  static Map<String, dynamic>? _notificacionPendiente;

  static Completer<String>? _solicitudFidParaDesvincular;

  static Future<void> initialize() async {
    if (_inicializado) return;

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;

        if (payload == null || payload.isEmpty) return;

        try {
          final data = jsonDecode(payload);

          if (data is Map) {
            _procesarDatosNotificacion(Map<String, dynamic>.from(data));
          }
        } catch (error) {
          debugPrint('No se pudo interpretar la notificación: $error');
        }
      },
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.createNotificationChannel(_channel);

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint('Permiso de notificaciones: ${settings.authorizationStatus}');

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Escuchar el identificador de instalación (FID).
    _messaging.onRegistered.listen(
      (installationId) {
        _ultimoFid = installationId;

        debugPrint('FID de instalación recibido.');

        final solicitud = _solicitudFidParaDesvincular;

        if (solicitud != null && !solicitud.isCompleted) {
          solicitud.complete(installationId);
          return;
        }

        unawaited(_enviarInstalacionAlBackend(installationId));
      },
      onError: (error) {
        debugPrint('Error obteniendo FID: $error');

        final solicitud = _solicitudFidParaDesvincular;

        if (solicitud != null && !solicitud.isCompleted) {
          solicitud.completeError(error);
        }
      },
    );

    FirebaseMessaging.onMessage.listen(_mostrarNotificacion);

    FirebaseMessaging.onMessageOpenedApp.listen(_procesarNotificacion);

    // Notificación que abrió la aplicación desde estado terminado.
    final mensajeInicial = await _messaging.getInitialMessage();

    if (mensajeInicial != null) {
      _notificacionPendiente = Map<String, dynamic>.from(mensajeInicial.data);
    }

    FirebaseAuth.instance.authStateChanges().listen((usuario) {
      if (usuario != null) {
        registrarDispositivo();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          procesarNotificacionPendiente();
        });
      }
    });

    _inicializado = true;
  }

  // Procesar notificaciones pendientes después de dibujar la pantalla.
  static void procesarNotificacionPendiente() {
    final data = _notificacionPendiente;

    if (data == null) return;

    _notificacionPendiente = null;

    _procesarDatosNotificacion(data);
  }

  static Future<void> _mostrarNotificacion(RemoteMessage message) async {
    final notification = message.notification;

    final title =
        notification?.title ?? message.data['title'] ?? 'Control Aires ITC';

    final body =
        notification?.body ??
        message.data['body'] ??
        'Tienes una nueva notificación';

    await _localNotifications.show(
      id: message.hashCode,
      title: title.toString(),
      body: body.toString(),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'control_aires_notifications',
          'Control Aires ITC',
          channelDescription: 'Avisos y notificaciones de Control Aires ITC',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  static void _procesarNotificacion(RemoteMessage message) {
    _procesarDatosNotificacion(Map<String, dynamic>.from(message.data));
  }

  static void _procesarDatosNotificacion(Map<String, dynamic> data) {
    if (data['type'] != 'new_report') return;

    final usuario = FirebaseAuth.instance.currentUser;

    if (usuario == null) {
      _notificacionPendiente = data;
      return;
    }

    _abrirReportesAdministrador();
  }

  static void _abrirReportesAdministrador() {
    if (_abriendoReportes) return;

    final navigator = navigatorKey.currentState;

    if (navigator == null) {
      _notificacionPendiente = {'type': 'new_report'};
      return;
    }

    _abriendoReportes = true;

    unawaited(
      navigator
          .push(
            MaterialPageRoute(
              builder: (context) {
                return Consumer(
                  builder: (context, ref, child) {
                    final userDataAsync = ref.watch(currentUserDataProvider);

                    return userDataAsync.when(
                      loading: () => const Scaffold(
                        body: Center(child: CircularProgressIndicator()),
                      ),
                      error: (error, stack) => Scaffold(
                        appBar: AppBar(title: const Text('Reportes de fallas')),
                        body: Center(
                          child: Text(
                            'No se pudo cargar el perfil: $error',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      data: (userData) {
                        if (userData == null || userData.role != 'admin') {
                          return const Scaffold(
                            body: Center(
                              child: Text(
                                'No tienes permiso para consultar los reportes.',
                              ),
                            ),
                          );
                        }

                        return AdminReportsScreen(
                          userData: userData,
                          onLogout: () => cerrarSesionSeguro(ref),
                        );
                      },
                    );
                  },
                );
              },
            ),
          )
          .whenComplete(() {
            _abriendoReportes = false;
          }),
    );
  }

  // Registrar la instalación en Firebase Messaging.
  static Future<void> registrarDispositivo() async {
    try {
      final usuario = FirebaseAuth.instance.currentUser;

      if (usuario == null) return;

      await _messaging.register();
    } catch (error) {
      debugPrint('No se pudo registrar el dispositivo FCM: $error');
    }
  }

  // Enviar el FID al backend Express.
  static Future<void> _enviarInstalacionAlBackend(String installationId) async {
    try {
      final usuario = FirebaseAuth.instance.currentUser;

      if (usuario == null) return;

      final idToken = await usuario.getIdToken();

      if (idToken == null || idToken.isEmpty) {
        debugPrint('No se obtuvo el token de autenticación.');
        return;
      }

      final plataforma = kIsWeb
          ? 'web'
          : defaultTargetPlatform == TargetPlatform.iOS
          ? 'ios'
          : 'android';

      final response = await http.post(
        Uri.parse('$_baseUrl/api/notifications/token'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'fid': installationId, 'platform': plataforma}),
      );

      if (response.statusCode == 200) {
        debugPrint('FID registrado correctamente en Express.');
      } else {
        debugPrint(
          'Error registrando FID. '
          'HTTP ${response.statusCode}: ${response.body}',
        );
      }
    } catch (error) {
      debugPrint('Error enviando instalación FID: $error');
    }
  }

  // Solicitar al backend la notificación de un nuevo reporte.

  static Future<void> notificarNuevoReporte(String reportId) async {
    try {
      final usuario = FirebaseAuth.instance.currentUser;

      if (usuario == null) {
        debugPrint('REPORTE: No hay usuario autenticado.');
        return;
      }

      debugPrint('REPORTE: Solicitando notificación.');
      debugPrint('REPORTE: UID ${usuario.uid}');
      debugPrint('REPORTE: ID $reportId');

      final idToken = await usuario.getIdToken();

      if (idToken == null || idToken.isEmpty) {
        debugPrint('REPORTE: No se obtuvo ID token.');
        return;
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/api/notifications/report'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'reportId': reportId}),
      );

      debugPrint('REPORTE: HTTP ${response.statusCode}');
      debugPrint('REPORTE: Respuesta ${response.body}');
    } catch (error, stackTrace) {
      debugPrint('REPORTE: Error enviando notificación: $error');
      debugPrint('$stackTrace');
    }
  }

  // Desvincular la instalación del backend.
  static Future<bool> desvincularInstalacion() async {
    try {
      final usuario = FirebaseAuth.instance.currentUser;

      if (usuario == null) return true;

      String? fid = _ultimoFid;

      if (fid == null || fid.isEmpty) {
        final solicitud = Completer<String>();
        _solicitudFidParaDesvincular = solicitud;

        try {
          await _messaging.register();

          fid = await solicitud.future.timeout(const Duration(seconds: 15));
        } finally {
          if (identical(_solicitudFidParaDesvincular, solicitud)) {
            _solicitudFidParaDesvincular = null;
          }
        }
      }

      if (fid == null || fid.isEmpty) {
        debugPrint('No se obtuvo un FID válido para desvincular.');
        return false;
      }

      final idToken = await usuario.getIdToken();

      if (idToken == null || idToken.isEmpty) {
        debugPrint('No se obtuvo el token para desvincular.');
        return false;
      }

      final response = await http.delete(
        Uri.parse('$_baseUrl/api/notifications/token'),
        headers: {
          'Authorization': 'Bearer $idToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'fid': fid}),
      );

      if (response.statusCode == 200) {
        debugPrint('Instalación FCM desvinculada correctamente.');
        return true;
      }

      debugPrint(
        'Error desvinculando instalación. '
        'HTTP ${response.statusCode}: ${response.body}',
      );

      return false;
    } catch (error) {
      debugPrint('Error desvinculando instalación FCM: $error');
      return false;
    }
  }
}
