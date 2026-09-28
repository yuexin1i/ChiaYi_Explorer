import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static Future<void> init() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await _requestPermission();

    final token = await _messaging.getToken();

    if (token != null) {
      await _saveTokenToFirestore(user.uid, token);
    }

    await _messaging.subscribeToTopic('global');

    _messaging.onTokenRefresh.listen((newToken) async {
      await _saveTokenToFirestore(user.uid, newToken);
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Foreground message: ${message.notification?.title}');
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Notification clicked: ${message.data}');
    });
  }

  static Future<void> _requestPermission() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  static Future<void> _saveTokenToFirestore(String uid, String token) async {
    await FirebaseFirestore.instance.collection('Users').doc(uid).set({
      'Fcm_Token': token,
      'Fcm_Tokens': FieldValue.arrayUnion([token]),
      'Updated_At': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}