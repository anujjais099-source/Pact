import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/pact_colors.dart';
import '../services/firebase_service.dart';
import 'user_repository.dart';

/// Must match the channelId the Cloud Functions send on.
const AndroidNotificationChannel pactChannel = AndroidNotificationChannel(
  'pact_reminders',
  'Pactly reminders',
  description: 'Daily check-in nudges and streak alerts.',
  importance: Importance.high,
);

class NotificationRepository {
  NotificationRepository(this._messaging, this._users);

  final FirebaseMessaging _messaging;
  final UserRepository _users;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  StreamSubscription<String>? _tokenSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;

  Future<void> init(String uid) async {
    await _local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_stat_pact'),
      ),
    );
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(pactChannel);

    // Android 13+ asks at runtime. Declining is fine — the app still works,
    // it just gets quieter, so we never gate anything behind this.
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    final token = await _messaging.getToken();
    if (token != null) await _users.saveFcmToken(uid, token);

    await _tokenSub?.cancel();
    _tokenSub = _messaging.onTokenRefresh.listen((t) => _users.saveFcmToken(uid, t));

    // FCM does not draw notifications while the app is in the foreground.
    await _foregroundSub?.cancel();
    _foregroundSub = FirebaseMessaging.onMessage.listen(_showLocal);
  }

  Future<void> _showLocal(RemoteMessage message) async {
    final n = message.notification;
    if (n == null) return;
    await _local.show(
      message.hashCode,
      n.title,
      n.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          pactChannel.id,
          pactChannel.name,
          channelDescription: pactChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          color: PactColors.violet,
          icon: '@drawable/ic_stat_pact',
        ),
      ),
      payload: message.data['type'] as String?,
    );
  }

  Future<void> disposeFor(String uid) async {
    final token = await _messaging.getToken();
    if (token != null) await _users.removeFcmToken(uid, token);
    await _tokenSub?.cancel();
    await _foregroundSub?.cancel();
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(
    ref.watch(messagingProvider),
    ref.watch(userRepositoryProvider),
  ),
);
