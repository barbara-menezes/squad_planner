import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

class FirebaseApi {
  final _firebaseMessaging = FirebaseMessaging.instance;
  final _androidChannel = const AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important notifications',
    importance: Importance.defaultImportance,
  );
  late final FlutterLocalNotificationsPlugin _localNotifications;

  FirebaseApi() : _localNotifications = FlutterLocalNotificationsPlugin();

  Future<void> initNotifications() async {
    await _firebaseMessaging.requestPermission();
    final fCMToken = await _firebaseMessaging.getToken();
    print('Token: $fCMToken');
    initLocalNotifications();

    FirebaseMessaging.onBackgroundMessage(handleBackgroundMessage);

    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification == null) return;
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannel.id,
            _androidChannel.name,
            channelDescription: _androidChannel.description,
            icon:
                '@drawable/ic_launcher', // Corrigido o nome da pasta "drawble" para "drawable"
          ),
        ),
        payload: jsonEncode(message
            .toMap()), // Movido o parêntese para dentro do método "jsonEncode"
      );
    });
  }

  Future<void> initLocalNotifications() async {
    const iOS = IOSInitializationSettings();
    const android = AndroidInitializationSettings(
        '@drawable/ic_launcher'); // Corrigido o nome do ícone
    const settings = InitializationSettings(android: android, iOS: iOS);

    await _localNotifications.initialize(settings,
        onSelectNotification: (payload) {
      final message = RemoteMessage.fromMap(jsonDecode(payload!));
      handleMessage(message);
    });

    final platform = _localNotifications
        .resolvePlatformSpecificImplementation(); // Adicionado ponto e vírgula
  }

  Future<void> handleBackgroundMessage(RemoteMessage message) async {
    print('Title: ${message.notification?.title}');
    print('Body: ${message.notification?.body}');
    print('Payload: ${message.data}');
  }

  void handleMessage(RemoteMessage? message) {
    if (message == null) return;
    // Lógica para tratar a mensagem quando o aplicativo estiver aberto
  }

  static void sendNotification(
    String title,
    String body, {
    required String userId,
  }) async {
    final messaging = FirebaseMessaging.instance;
    final token = await messaging.getToken();

    final url = Uri.parse('https://fcm.googleapis.com/fcm/send');
    final serverKey =
        'AAAAe6vgiQg:APA91bHP0N-oBOQhsB-0RRExmATV4-Ys1jgA2N2EceSvNUpba_z44sd3lRP16tLMcfrgQ9TD7FzjGiqiUgvD0eJG3Ir7thKPQbfwLQOB8cza-71NVUgpTJW6LUxCvTn59vGUzcOVWrEO'; // Substitua com a chave do seu servidor FCM

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'key=$serverKey',
    };

    final message = {
      'notification': {
        'title': title,
        'body': body,
      },
      'data': {
        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        'id': '1',
        'status': 'done',
      },
      'to': token,
    };

    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode(message),
    );

    if (response.statusCode == 200) {
      print('Notificação enviada com sucesso para o usuário $userId!');
    } else {
      print(
          'Falha ao enviar notificação para o usuário $userId. Código: ${response.statusCode}');
    }
  }
}
