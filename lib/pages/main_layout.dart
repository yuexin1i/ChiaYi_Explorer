// lib/pages/main_layout.dart
import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_page.dart';
import 'map_page.dart' hide ItineraryPage;
import 'spots_page.dart';
import 'food_page.dart';
import 'hotel_page.dart';
import 'traffic_page.dart';
import 'events_page.dart';
import 'ai_chat_page.dart';
import 'itinerary_page.dart' hide EventsPage;
import 'favorites_page.dart';
import 'profile_page.dart';
import 'spot_detail_page.dart';
import 'event_detail_page.dart';
import 'story_map_page.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  final List<Widget> _pages = [
    const HomePage(), // Index 0: 首頁
    const MapPage(), // Index 1: 互動地圖
    SpotsPage(), // Index 2: 景點探索
    const FoodPage(), // Index 3: 在地美食
    HotelPage(), // Index 4: 特色住宿
    const TrafficPage(), // Index 5: 交通資訊
    EventsPage(), // Index 6: 活動行事曆
    const AiChatPage(), // Index 7: AI 助理
    const ItineraryPage(), // Index 8: 行程管理
    FavoritesPage(), // Index 9: 收藏景點
    ProfilePage(), // Index 10: 使用者設定
    SpotDetailPage(), // Index 11: 景點詳細
    EventDetailPage(), // Index 12: 活動詳細
    StoryMapPage(), // Index 13: 互動故事模式
  ];

  @override
  void initState() {
    super.initState();
    // 🌟 核心修正 3：確保首頁一載入，就去抓取即時天氣
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppStateManager>().fetchChiayiWeather();
    });
  }

  int _getBottomNavIndex(int pageIndex) {
    switch (pageIndex) {
      case 1:
        return 0; // 互動地圖
      case 9:
        return 1; // 收藏景點
      case 0:
        return 2; // 首頁 (中間)
      case 10:
        return 3; // 使用者設定
      case 13:
        return 4; // 互動故事
      default:
        return 2;
    }
  }

  void _onBottomNavTapped(int navIndex, AppStateManager appState) {
    int targetPage = 0;
    switch (navIndex) {
      case 0:
        targetPage = 1;
        break;
      case 1:
        targetPage = 9;
        break;
      case 2:
        targetPage = 0;
        break;
      case 3:
        targetPage = 10;
        break;
      case 4:
        targetPage = 13;
        break;
    }
    appState.setPageIndex(targetPage);
  }

  Future<List<Map<String, dynamic>>> _loadNotifications(
    AppStateManager appState,
  ) async {
    final uid = appState.uid;
    if (uid == null) return [];

    final globalSnap =
        await FirebaseFirestore.instance
            .collection('Notifications')
            .where('User_Id', isEqualTo: 'global')
            .get();
    final personalSnap =
        await FirebaseFirestore.instance
            .collection('Notifications')
            .where('User_Id', isEqualTo: uid)
            .get();

    final allDocs = [...globalSnap.docs, ...personalSnap.docs];

    final notifications =
        allDocs.map((doc) {
          final data = doc.data();
          data['docId'] = doc.id;
          return data;
        }).toList();

    notifications.sort((a, b) {
      final aTime = a['Created_At'];
      final bTime = b['Created_At'];

      if (aTime is Timestamp && bTime is Timestamp) {
        return bTime.compareTo(aTime);
      }
      return 0;
    });

    return notifications;
  }

  String _formatNotificationTime(dynamic value) {
    if (value is! Timestamp) return '';
    final date = value.toDate();
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showNotificationPanel(AppStateManager appState) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.55,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.notifications_active,
                      color: appState.themeColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      appState.t('通知中心'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _loadNotifications(appState),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting)
                      return Center(
                        child: CircularProgressIndicator(
                          color: appState.themeColor,
                        ),
                      );
                    final notifications = snapshot.data ?? [];
                    if (notifications.isEmpty)
                      return Center(
                        child: Text(
                          appState.t('目前沒有通知'),
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 16,
                          ),
                        ),
                      );

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: notifications.length,
                      itemBuilder: (context, index) {
                        final item = notifications[index];
                        final title =
                            item['Title'] ?? item['title'] ?? appState.t('通知');
                        final body = item['Body'] ?? item['body'] ?? '';
                        final type = item['Type'] ?? '';
                        final createdAt = item['Created_At'];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(14),
                            leading: CircleAvatar(
                              backgroundColor: appState.themeColor.withOpacity(
                                0.14,
                              ),
                              child: Icon(
                                type == 'inactive_reminder'
                                    ? Icons.favorite
                                    : Icons.campaign,
                                color: appState.themeColor,
                              ),
                            ),
                            title: Text(
                              title.toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    appState.personalizeGreeting(
                                      body.toString(),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _formatNotificationTime(createdAt),
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() async {
      await appState.markNotificationsAsRead();
      await appState.checkUnreadNotifications();
    });
  }

  Widget _buildCurrentPage(AppStateManager appState) {
    if (appState.pageIndex != 0) {
      return _pages[appState.pageIndex];
    }

    return HomePage(
      hasUnreadNotification: appState.hasUnreadNotification,
      onNotificationsPressed: () => _showNotificationPanel(appState),
      onNotificationLongPress: () async {
        await appState.createFakeNotificationTest();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🧪 已送出測試假通知，請查看通知中心！'),
            duration: Duration(seconds: 2),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateManager>(context);
    final Color currentPrimaryColor = appState.themeColor;
    int currentNavIndex = _getBottomNavIndex(appState.pageIndex);

    return Scaffold(
      extendBody: false,
      body: _buildCurrentPage(appState),
      bottomNavigationBar: CurvedNavigationBar(
        backgroundColor: Colors.transparent,
        color: Colors.white,
        buttonBackgroundColor: currentPrimaryColor,
        height: 60,
        animationCurve: Curves.easeInOut,
        animationDuration: const Duration(milliseconds: 300),
        index: currentNavIndex,
        items: <Widget>[
          Icon(
            Icons.map,
            size: 28,
            color: currentNavIndex == 0 ? Colors.white : Colors.black54,
          ),
          Icon(
            Icons.favorite,
            size: 28,
            color: currentNavIndex == 1 ? Colors.white : Colors.black54,
          ),
          Icon(
            Icons.home,
            size: 38,
            color: currentNavIndex == 2 ? Colors.white : Colors.black54,
          ),
          Icon(
            Icons.settings,
            size: 28,
            color: currentNavIndex == 3 ? Colors.white : Colors.black54,
          ),
          Icon(
            Icons.auto_stories,
            size: 28,
            color: currentNavIndex == 4 ? Colors.white : Colors.black54,
          ),
        ],
        onTap: (index) => _onBottomNavTapped(index, appState),
      ),
    );
  }
}
