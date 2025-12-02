import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart'; // Usar para manejar el contexto o logs.
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// Importa cualquier servicio de tu dominio para enviar el token al backend

// Inicializa la librería de notificaciones locales (necesaria para mostrar notifs en foreground)
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

// Handler de background, debe ser una función de nivel superior o estática
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Lógica de `onMessageReceived` de tu Kotlin
  final customTitle = message.data['custom_title'] ?? "Nuevo Post Genérico";
  final customBody = message.data['custom_body'] ?? "Se ha publicado una oferta sin detalles.";

  // Puedes registrar la data o hacer lógica de background aquí
  debugPrint("FCM_RECEIVE (Background): Título: $customTitle, Cuerpo: $customBody");
}

class FirebaseMessagingService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  Future<void> initialize() async {
    // 1. Inicializar la configuración de notificaciones locales (para Android)
    const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // 2. Solicitar permiso de notificación (similar a askNotificationPermission en MainActivity.kt)
    // Esto es manejado internamente por `firebase_messaging` al llamar a `requestPermission`
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('Permiso de notificaciones concedido.');

      // 3. Obtener Token (Similar a onNewToken en Notifications.kt)
      final token = await _fcm.getToken();
      debugPrint("FCM_TOKEN: Nuevo Token: $token");
      // TODO: Envía 'token' a tu servidor de aplicaciones.
      // E.g., YourDomainService.sendFcmToken(token);

      // Manejar refresco del token
      _fcm.onTokenRefresh.listen((newToken) {
        debugPrint("FCM_TOKEN: Token actualizado: $newToken");
        // TODO: Envía 'newToken' a tu servidor.
      });

      // 4. Configurar Handlers de Mensajes

      // Manejar mensajes cuando la app está en FOREGROUND
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        // Lógica de `onMessageReceived` de tu Kotlin
        final customTitle = message.data['custom_title'] ?? "Nuevo Post Genérico";
        final customBody = message.data['custom_body'] ?? "Se ha publicado una oferta sin detalles.";

        debugPrint("FCM_RECEIVE (Foreground): Título: $customTitle");

        // Llamar a `sendNotification` de Kotlin -> Usar `flutter_local_notifications`
        _showLocalNotification(customTitle, customBody);
      });

      // Manejar mensajes cuando la app abre desde un mensaje (Background/Terminated)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('Apertura de la app desde una notificación de FCM');
        // Aquí puedes usar tu Navigation/Routing service para navegar a la pantalla del post.
      });

      // Manejar mensajes en background/terminated
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Manejar la notificación si la app estaba terminada y se abre desde la notif
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('Mensaje inicial: App abierta desde notificación terminada.');
        // Manejar navegación si es necesario
      }

    } else {
      debugPrint('Permiso de notificaciones denegado.');
    }
  }

  // Similar a sendNotification en Notifications.kt, pero usa flutter_local_notifications
  void _showLocalNotification(String title, String body) {
    const androidDetails = AndroidNotificationDetails(
      'post_notifications', // CHANNEL_ID
      'Notificaciones de Posts', // CHANNEL_NAME
      channelDescription: 'Canal para notificaciones de nuevos posts.',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      // Usar el ícono configurado en Android (res/drawable/offerapplogo en tu caso Kotlin)
      // Debe ser un ícono adaptativo o 'mipmap/ic_launcher' por defecto en Flutter
      icon: '@mipmap/ic_launcher',
    );
    const notificationDetails = NotificationDetails(android: androidDetails);

    // Usar un ID único para la notificación
    flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      notificationDetails,
      payload: 'item_x', // Puedes pasar data si es necesario
    );
  }
}