// lib/main.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 引入 dotenv 套件
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'providers/app_state.dart';
import 'pages/main_layout.dart';
import 'pages/story_map_page.dart';
import 'pages/spot_detail_page.dart';
import 'pages/event_detail_page.dart';
import 'pages/login_page.dart';
import 'services/notification_service.dart';
import 'pages/login_page.dart';
import 'pages/splash_page.dart'; // 🌟 新增這一行
import 'services/notification_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

// 處理憑證問題
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

// 這是唯一且合併後的 main() 函數
Future<void> main() async {
  // 1. 確保 Flutter 綁定初始化
  WidgetsFlutterBinding.ensureInitialized();

  // 2. 處理 HTTP 憑證
  HttpOverrides.global = MyHttpOverrides();

  // 3. 載入 .env 檔案
  await dotenv.load(fileName: ".env");

  // 4. 初始化 Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  runApp(
    ChangeNotifierProvider(
      create: (context) => AppStateManager(),
      child: const ExploreChiayiApp(),
    ),
  );
}

class ExploreChiayiApp extends StatelessWidget {
  const ExploreChiayiApp({super.key}); // 把 Key? key 改為 super.key 更簡潔

  @override
  Widget build(BuildContext context) {
    final themeColor = context.watch<AppStateManager>().themeColor;

    return MaterialApp(
      title: '探索諸羅',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: themeColor),
        appBarTheme: AppBarTheme(
          backgroundColor: themeColor,
          foregroundColor: Colors.white,
        ),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
      routes: {
        '/story': (context) => StoryMapPage(), // 建議加上 const
        '/spot_detail': (context) => SpotDetailPage(), // 建議加上 const
        '/event_detail': (context) => EventDetailPage(), // 建議加上 const
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            final state = context.read<AppStateManager>();
            // 🌟 如果狀態管理員還沒載入這個使用者的資料，就去 Firestore 下載他的行程、收藏、標籤！
            if (state.uid != snapshot.data!.uid) {
              await state.loadUserDataFromFirestore(
                snapshot.data!.uid,
                snapshot.data!.email ?? '',
              );

              await NotificationService.init();
            }
          });

          return const MainLayout();
        }

        final bool isLoggedIn = context.watch<AppStateManager>().isLoggedIn;
        if (isLoggedIn) {
          return const MainLayout();
        } else {
          // 🌟 修正這裡：原本是 return const LoginPage();
          // 改成讓未登入的使用者先進入 SplashPage
          return const SplashPage();
        }
      },
    );
  }
}
