// lib/pages/story_map_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/app_drawer.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import '../widgets/loading_fen.dart';

class StoryMapPage extends StatefulWidget {
  @override
  _StoryMapPageState createState() => _StoryMapPageState();
}

class _StoryMapPageState extends State<StoryMapPage> {
  String? _selectedRouteName;
  String? _selectedRouteId;

  Map<String, dynamic>? _currentDialogFlow;
  List<Map<String, dynamic>> _currentOptions = [];
  bool _isLoadingDialog = true;

  String? _currentArrivalSpotId;
  bool _isCurrentSpotLast = false;

  String _currentTaskTitle = '🗺️ 準備出發';
  String _currentTaskDesc = '請等待系統載入路線...';

  List<Map<String, dynamic>> _routeSpotsData = [];
  int _currentSpotIndex = 0;
  bool _isInIntro = false;
  bool _isArrivedWaitingForDialog = false;
  String _pendingDialogId = '';

  LatLng _mockUserLocation = const LatLng(23.4789, 120.4411);

  final List<Map<String, dynamic>> _testLocations = [
    {'name': '📍 原點', 'lat': 23.4789, 'lng': 120.4411, 'spotId': '', 'dialogId': '', 'isLast': false},
    {'name': '📍 1. 月桃', 'lat': 23.4988, 'lng': 120.4566, 'spotId': 'C1_376600000A_000017', 'dialogId': 'DF_R02_1_1', 'isLast': false},
    {'name': '📍 2. 愛木村', 'lat': 23.4933, 'lng': 120.4501, 'spotId': 'C1_376600000A_000065', 'dialogId': 'DF_R02_2_1', 'isLast': false},
    {'name': '📍 3. 酒廠', 'lat': 23.4890, 'lng': 120.4350, 'spotId': 'C1_376500000A_000001', 'dialogId': 'DF_R02_3_1', 'isLast': false},
    {'name': '📍 4. 方城市', 'lat': 23.4855, 'lng': 120.4300, 'spotId': 'C1_376500000A_000026', 'dialogId': 'DF_R02_4_1', 'isLast': false},
    {'name': '📍 5. 梅問屋 (終)', 'lat': 23.4811, 'lng': 120.4288, 'spotId': 'C1_376500000A_000027', 'dialogId': 'DF_R02_5_1', 'isLast': true},
  ];

  final List<Map<String, String>> _allRoutes = [
    {"id": "R01", "name": "凝時之彩", "desc": "名畫家朝聖之路", "image": "assets/menu/R1.png"},
    {"id": "R02", "name": "獨家條款", "desc": "專屬視察企劃", "image": "assets/menu/R2.png"},
    {"id": "R03", "name": "綠野逐光", "desc": "牧羊男的晴空紀行", "image": "assets/menu/R3.png"},
    {"id": "R04", "name": "時光迴遞", "desc": "森之歌專屬列車", "image": "assets/menu/R4.png"},
    {"id": "R05", "name": "諸羅謎影", "desc": "古城踏查檔案", "image": "assets/menu/R5.png"},
    {"id": "R06", "name": "香煙裊裊", "desc": "結緣祈願行", "image": "assets/menu/R6.png"},
  ];

  Future<String> _getRealUserId() async {
    final prefs = await SharedPreferences.getInstance();
    String? cachedId = prefs.getString('current_db_user_id');
    if (cachedId != null && cachedId.isNotEmpty) return cachedId;

    try {
      final userSnap = await FirebaseFirestore.instance.collection('Users').limit(1).get();
      if (userSnap.docs.isNotEmpty) {
        String realId = userSnap.docs.first.id;
        await prefs.setString('current_db_user_id', realId);
        return realId;
      }
    } catch (e) {
      print("⚠️ 撈取真實 User_Id 失敗: $e");
    }

    String fallbackId = "259bgbeRgxYgXTkyREhwoGUNNnw1";
    await prefs.setString('current_db_user_id', fallbackId);
    return fallbackId;
  }

  Future<void> _updateFirebaseProgress({bool completed = false}) async {
    try {
      String userId = await _getRealUserId();
      String sessionId = "session_${userId}_$_selectedRouteId";

      Map<String, dynamic> updateData = {
        'Current_Spot_Seq': _currentSpotIndex,
        'Current_Dialog_Flow_Id': _currentDialogFlow?['Dialog_Flow_Id'] ?? 'DF_${_selectedRouteId}_01',
        'Updated_At': FieldValue.serverTimestamp(),
      };

      if (_currentArrivalSpotId != null) {
        updateData['Selected_Spot_Ids'] = FieldValue.arrayUnion([_currentArrivalSpotId]);
      }

      if (completed) {
        updateData['Status'] = 'completed';
        updateData['Badge_Earned'] = true;
        updateData['Completed_At'] = FieldValue.serverTimestamp();
      }

      await FirebaseFirestore.instance.collection('UserSessions').doc(sessionId).update(updateData);
      print("📊 Firebase 進度同步成功！目前站點序號: $_currentSpotIndex");
    } catch (e) {
      print("⚠️ 同步 Firebase 進度失敗: $e");
    }
  }

  void _simulateLocationChange(double lat, double lng, String spotId, String dialogId, bool isLast) {
    setState(() {
      _mockUserLocation = LatLng(lat, lng);
    });

    if (spotId.isEmpty) {
      _setExploringState();
      return;
    }

    final LatLng targetSpot = LatLng(lat, lng);
    final Distance distance = const Distance();
    final double meter = distance.as(LengthUnit.Meter, _mockUserLocation, targetSpot);

    if (meter <= 50) {
      bool isSpotForCurrentRoute = (_selectedRouteId != null && dialogId.contains(_selectedRouteId!));
      String expectedPattern = "${_selectedRouteId}_${_currentSpotIndex + 1}_";
      bool isCorrectSequence = dialogId.contains(expectedPattern);

      setState(() {
        _currentArrivalSpotId = spotId;

        if (isSpotForCurrentRoute && isCorrectSequence) {
          _isCurrentSpotLast = isLast;
          _isArrivedWaitingForDialog = true;
          _pendingDialogId = dialogId;
          _currentTaskTitle = '🎯 抵達景點';
          _currentTaskDesc = '請點擊畫面上的「開始對話」與角色互動。';
        } else {
          _isArrivedWaitingForDialog = false;
        }
      });
    }
  }

  Future<void> _fetchAndShowSpotInfo(String scenicSpotId) async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

    try {
      // 🌟 1. 精準對應你的 spots_v2 集合
      final querySnapshot = await FirebaseFirestore.instance.collection('spots_v2').where('ScenicSpotID', isEqualTo: scenicSpotId).limit(1).get();
      Navigator.pop(context);

      final appState = Provider.of<AppStateManager>(context, listen: false);

      if (querySnapshot.docs.isNotEmpty) {
        final spotData = querySnapshot.docs.first.data();

        // 🌟 2. 景點名稱雙語支援 (英文抓 NameEn，中文抓 ScenicSpotName)
        final spotName = (appState.currentLang == 'en' && spotData['NameEn'] != null && spotData['NameEn'].toString().isNotEmpty)
            ? spotData['NameEn']
            : (spotData['ScenicSpotName'] ?? spotData['NameZh'] ?? '未知景點');

        // 🌟 3. 景點描述雙語支援 (英文抓 DescriptionEn，中文抓 DescriptionDetail 或 Description)
        final spotDesc = (appState.currentLang == 'en' && spotData['DescriptionEn'] != null && spotData['DescriptionEn'].toString().isNotEmpty)
            ? spotData['DescriptionEn']
            : (spotData['DescriptionDetail'] ?? spotData['Description'] ?? '暫無景點描述');

        // 🌟 4. 精準對應你的圖片欄位 PictureUrl1
        final spotPic = spotData['PictureUrl1'] ?? spotData['PicUrl1'] ?? '';

        _showSpotInfoDialog(spotName, spotDesc, spotPic);
      } else {
        _showSpotInfoDialog(appState.t('景點測試資料'), '${appState.t('系統在資料庫內找不到')} [$scenicSpotId]。', 'https://travel.chiayi.gov.tw/Utility/DisplayImage?id=25575');
      }
    } catch (e) {
      Navigator.pop(context);
      print('⚠️ 讀取景點失敗: $e');
    }
  }

  void _showSpotInfoDialog(String name, String desc, String picUrl) {
    final appState = Provider.of<AppStateManager>(context, listen: false);
    final themeColor = appState.themeColor;
    showDialog(
        context: context,
        builder: (ctx) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: themeColor.withOpacity(0.5), width: 2),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 10))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (picUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                      child: Image.network(picUrl, height: 180, width: double.infinity, fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(height: 120, color: themeColor.withOpacity(0.1), child: Icon(Icons.broken_image, size: 40, color: themeColor.withOpacity(0.5))),
                      ),
                    )
                  else
                    Container(height: 120, color: themeColor.withOpacity(0.1), child: Icon(Icons.museum, size: 50, color: themeColor.withOpacity(0.5))),

                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Text('📍 ${appState.t(name)}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: themeColor), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.3,
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Text(appState.t(desc), style: const TextStyle(fontSize: 15, height: 1.6, color: Colors.black87)),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: themeColor, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(appState.t('了解了！'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
          );
        }
    );
  }

  Future<void> _fetchAndShowBadge() async {
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => const Center(child: CircularProgressIndicator()));
    try {
      final querySnapshot = await FirebaseFirestore.instance.collection('Badges').where('Route_Id', isEqualTo: _selectedRouteId).limit(1).get();
      Navigator.pop(context);

      if (querySnapshot.docs.isNotEmpty) {
        final badgeData = querySnapshot.docs.first.data();
        _showBadgeUnlockedDialog(
          badgeData['Name'] ?? '神秘徽章',
          badgeData['Description'] ?? '恭喜完成路線！',
          badgeData['Image_Url'] ?? 'assets/images/badges/default.png',
        );
      } else {
        _showBadgeUnlockedDialog('通關徽章', '恭喜完成路線所有景點！', '');
      }
    } catch (e) {
      Navigator.pop(context);
      print("讀取徽章失敗: $e");
    }
  }

  void _showBadgeUnlockedDialog(String name, String desc, String imageUrl) {
    final appState = Provider.of<AppStateManager>(context, listen: false);
    final themeColor = appState.themeColor;

    setState(() {
      _currentTaskTitle = '🏆 路線通關';
      _currentTaskDesc = '恭喜獲得專屬通關徽章！';
    });

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (imageUrl.isNotEmpty)
                  Image.asset(imageUrl, height: 120, errorBuilder: (c, e, s) => const Icon(Icons.emoji_events, size: 100, color: Colors.amber))
                else
                  const Icon(Icons.emoji_events, size: 100, color: Colors.amber),

                const SizedBox(height: 16),
                Text('🎉 ${appState.t('獲得徽章：')}${appState.t(name)}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: themeColor), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(appState.t(desc), textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, height: 1.5)),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: themeColor, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 48)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _setExploringState();
                    _showProfileDialog(isFromRouteEnd: true);
                  },
                  child: Text(appState.t('收下徽章'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                )
              ],
            ),
          ).animate().scale(duration: 500.ms, curve: Curves.elasticOut);
        }
    );
  }

  @override
  void initState() {
    super.initState();
    _checkRouteSelection();
  }

  Future<void> _checkRouteSelection() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. 嘗試讀取本機的路線紀錄
    String? savedRouteName = prefs.getString('currentStoryRoute');
    String? savedRouteId = prefs.getString('currentRouteId');

    // 2. 判斷是否有紀錄
    if (savedRouteName != null && savedRouteId != null && savedRouteName.isNotEmpty) {
      // 🟢 情況 A：有紀錄，直接把狀態設定好，並開始載入進度
      setState(() {
        _selectedRouteName = savedRouteName;
        _selectedRouteId = savedRouteId;
      });
      // 呼叫原本寫好的載入進度函式
      _loadRouteSpotsAndStart(savedRouteId);

    } else {
      // 🔴 情況 B：沒有紀錄（或已經按了重置按鈕被清空了），才跳出選擇路線的視窗
      WidgetsBinding.instance.addPostFrameCallback((_) => _showRouteSelectionDialog());
    }
  }

  Future<void> _loadRouteSpotsAndStart(String routeId) async {
    setState(() {
      _isLoadingDialog = true;
      _currentTaskTitle = '🔄 載入中';
      _currentTaskDesc = '正在獲取路線資料...';
    });

    try {
      final snapshot = await FirebaseFirestore.instance.collection('RouteSpots').where('Route_Id', isEqualTo: routeId).get();
      var docs = snapshot.docs.map((d) => d.data()).toList();
      docs.sort((a, b) => (a['Sequence'] as int).compareTo(b['Sequence'] as int));

      _routeSpotsData = docs;

      String userId = await _getRealUserId();
      String sessionId = "session_${userId}_$routeId";

      final sessionDoc = await FirebaseFirestore.instance.collection('UserSessions').doc(sessionId).get();

      if (sessionDoc.exists && sessionDoc.data()?['Status'] == 'in_progress') {
        var sessionData = sessionDoc.data()!;
        _currentSpotIndex = sessionData['Current_Spot_Seq'] ?? 0;
        _isInIntro = (_currentSpotIndex == 0);

        if (_isInIntro) {
          _loadDialogData("${routeId}_01");
        } else {
          _setExploringState();
        }
      } else {
        _currentSpotIndex = 0;
        _isInIntro = true;

        await FirebaseFirestore.instance.collection('UserSessions').doc(sessionId).set({
          'Session_Id': sessionId,
          'User_Id': userId,
          'Route_Id': routeId,
          'Current_Spot_Seq': 0,
          'Current_Dialog_Flow_Id': 'DF_${routeId}_01',
          'Status': 'in_progress',
          'Badge_Earned': false,
          'Started_At': FieldValue.serverTimestamp(),
          'Updated_At': FieldValue.serverTimestamp(),
          'Completed_At': null,
          'Selected_Spot_Ids': [],
          'Dialog_Answers_Json': '{}',
        });

        _loadDialogData("${routeId}_01");
      }
    } catch(e) {
      print("⚠️ 載入進度或 RouteSpots 失敗: $e");
      _currentSpotIndex = 0;
      _isInIntro = true;
      _loadDialogData("${routeId}_01");
    }
  }

  void _setExploringState() {
    setState(() {
      _isLoadingDialog = false;
      _isArrivedWaitingForDialog = false;
      _currentArrivalSpotId = null;
      _currentDialogFlow = null;
      _currentOptions = [];

      if (_routeSpotsData.isNotEmpty && _currentSpotIndex < _routeSpotsData.length) {
        _currentTaskTitle = '🚶 探索任務';
        _currentTaskDesc = _routeSpotsData[_currentSpotIndex]['Task_Text'] ?? '請依照地圖指示前往下一站。';
      } else {
        _currentTaskTitle = '🗺️ 自由探索';
        _currentTaskDesc = '路線任務皆已完成，自由探索嘉義吧！';
      }
    });
  }

  Future<void> _loadDialogData(String dialogFlowId) async {
    setState(() {
      _isLoadingDialog = true;
      _currentTaskTitle = '💬 劇情互動';
      _currentTaskDesc = '請點擊選項，與角色進行互動。';
    });

    final prefs = await SharedPreferences.getInstance();
    String fullDialogId = dialogFlowId.startsWith('DF_') ? dialogFlowId : 'DF_$dialogFlowId';

    // 🌟 快取升級 v2：確保讀到最新翻譯過的資料
    String? cachedDialogStr = prefs.getString('cache_v2_dialog_$fullDialogId');
    String? cachedOptionsStr = prefs.getString('cache_v2_options_$fullDialogId');

    if (cachedDialogStr != null && cachedOptionsStr != null) {
      setState(() {
        _currentDialogFlow = jsonDecode(cachedDialogStr);
        _currentOptions = List<Map<String, dynamic>>.from(jsonDecode(cachedOptionsStr));
        _isLoadingDialog = false;
      });
      return;
    }

    try {
      final db = FirebaseFirestore.instance;
      final dialogDoc = await db.collection('DialogFlows').doc(fullDialogId).get();
      if (!dialogDoc.exists) throw Exception("找不到對話劇本: $fullDialogId");

      final optionsSnapshot = await db.collection('DialogOptions').where('Dialog_Flow_Id', isEqualTo: fullDialogId).orderBy('Sort_Order').get();

      Map<String, dynamic> dialogData = dialogDoc.data()!;
      List<Map<String, dynamic>> optionsData = optionsSnapshot.docs.map((d) => d.data()).toList();

      // 🌟 寫入升級版 v2 快取
      await prefs.setString('cache_v2_dialog_$fullDialogId', jsonEncode(dialogData));
      await prefs.setString('cache_v2_options_$fullDialogId', jsonEncode(optionsData));

      setState(() {
        _currentDialogFlow = dialogData;
        _currentOptions = optionsData;
        _isLoadingDialog = false;
      });
    } catch (e) {
      print("讀取對話失敗: $e");
      setState(() => _isLoadingDialog = false);
    }
  }

  void _showRouteSelectionDialog() {
    final appState = Provider.of<AppStateManager>(context, listen: false);
    final themeColor = appState.themeColor;
    final ScrollController scrollController = ScrollController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        int? expandedIndex;

        return StatefulBuilder(
            builder: (context, setStateDialog) {
              return Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 24),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 0),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(appState.t('✨ 選擇妳的專屬羈絆路線'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                          const SizedBox(height: 16),

                          SizedBox(
                            height: 380,
                            child: ListView.builder(
                              controller: scrollController,
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              itemCount: _allRoutes.length,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              itemBuilder: (ctx, i) {
                                final isExpanded = expandedIndex == i;

                                Matrix4 transform = Matrix4.identity()
                                  ..setEntry(3, 2, 0.002)
                                  ..rotateY(isExpanded ? 0.0 : -0.5);

                                return GestureDetector(
                                  onTap: () {
                                    if (expandedIndex == i) {
                                      setStateDialog(() => expandedIndex = null);
                                    } else {
                                      setStateDialog(() => expandedIndex = i);

                                      Future.delayed(const Duration(milliseconds: 100), () {
                                        if (scrollController.hasClients) {
                                          final viewportWidth = scrollController.position.viewportDimension;
                                          final itemLeftOffset = 20.0 + (i * 86.0);
                                          final itemCenter = itemLeftOffset + (320.0 / 2);

                                          double targetOffset = itemCenter - (viewportWidth / 2);
                                          if (targetOffset < 0) targetOffset = 0;

                                          scrollController.animateTo(
                                            targetOffset,
                                            duration: const Duration(milliseconds: 350),
                                            curve: Curves.easeOutCubic,
                                          );
                                        }
                                      });
                                    }
                                  },

                                  child: Align(
                                    alignment: Alignment.center,
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 400),
                                      curve: Curves.easeOutCubic,
                                      transform: transform,
                                      transformAlignment: Alignment.centerRight,
                                      margin: const EdgeInsets.only(right: 6),

                                      width: isExpanded ? 320.0 : 80.0,
                                      height: 320.0,

                                      decoration: BoxDecoration(
                                        color: themeColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                            color: themeColor.withOpacity(isExpanded ? 0.8 : 0.3),
                                            width: isExpanded ? 4 : 2
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: isExpanded ? themeColor.withOpacity(0.4) : Colors.black12,
                                            blurRadius: isExpanded ? 15 : 4,
                                            offset: isExpanded ? const Offset(0, 8) : const Offset(0, 2),
                                          )
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            Image.asset(
                                              _allRoutes[i]["image"]!,
                                              fit: BoxFit.cover,
                                              alignment: Alignment.centerLeft,
                                              errorBuilder: (c, e, s) => Container(
                                                color: Colors.grey[200],
                                                child: const Icon(Icons.image, color: Colors.grey),
                                              ),
                                            ),

                                            Positioned(
                                              bottom: 0, left: 0, right: 0,
                                              child: AnimatedOpacity(
                                                duration: const Duration(milliseconds: 200),
                                                opacity: isExpanded ? 0.0 : 1.0,
                                                child: Container(
                                                  height: 38,
                                                  color: themeColor.withOpacity(0.85),
                                                  alignment: Alignment.center,
                                                  child: FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    child: Text(
                                                      appState.t(_allRoutes[i]["name"]!),
                                                      style: const TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 14,
                                                          color: Colors.white
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),

                                            if (isExpanded)
                                              Positioned(
                                                top: 10, right: 10,
                                                child: Container(
                                                  padding: const EdgeInsets.all(4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black.withOpacity(0.4),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(Icons.close, size: 16, color: Colors.white),
                                                ).animate().fadeIn(delay: 200.ms),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 12),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: expandedIndex != null
                                ? ElevatedButton(
                              key: ValueKey('btn_$expandedIndex'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: themeColor,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(220, 50),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                                elevation: 6,
                              ),
                              onPressed: () async {
                                final selected = _allRoutes[expandedIndex!];
                                final prefs = await SharedPreferences.getInstance();
                                await prefs.setString('currentStoryRoute', selected["name"]!);
                                await prefs.setString('currentRouteId', selected["id"]!);

                                setState(() {
                                  _selectedRouteName = selected["name"];
                                  _selectedRouteId = selected["id"];
                                });
                                Navigator.pop(context);
                                _loadRouteSpotsAndStart(selected["id"]!);
                              },
                              child: Text(
                                '✨ ${appState.t('進入')}「${appState.t(_allRoutes[expandedIndex!]["name"]!)}」',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2),
                              ),
                            )
                                : Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Text(appState.t('點擊卡片展開預覽'), style: const TextStyle(fontSize: 14, color: Colors.grey)),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),

                    Positioned(
                      top: 12, right: 12,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.black45, size: 28),
                        tooltip: appState.t('關閉並返回上一頁'),
                        onPressed: () {
                          Navigator.pop(context);
                          Provider.of<AppStateManager>(context, listen: false).goBack();
                        },
                      ),
                    ),
                  ],
                ),
              );
            }
        );
      },
    );
  }

  Future<Map<String, dynamic>> _fetchUserProfileData() async {
    String userId = await _getRealUserId();

    final sessionSnap = await FirebaseFirestore.instance
        .collection('UserSessions')
        .where('User_Id', isEqualTo: userId)
        .get();

    Map<String, Map<String, dynamic>> sessionsMap = {};
    for (var doc in sessionSnap.docs) {
      sessionsMap[doc.data()['Route_Id']] = doc.data();
    }

    final badgeSnap = await FirebaseFirestore.instance.collection('Badges').get();
    Map<String, Map<String, dynamic>> badgesMap = {};
    for (var doc in badgeSnap.docs) {
      badgesMap[doc.data()['Route_Id']] = doc.data();
    }

    return {
      'sessions': sessionsMap,
      'badges': badgesMap,
    };
  }

  void _showProfileDialog({bool isFromRouteEnd = false}) {
    final appState = Provider.of<AppStateManager>(context, listen: false);
    final themeColor = appState.themeColor;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
            ),
            child: FutureBuilder<Map<String, dynamic>>(
              future: _fetchUserProfileData(),
              builder: (ctx, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(height: 300, child: Center(child: CircularProgressIndicator()));
                }
                if (snapshot.hasError) {
                  return SizedBox(height: 300, child: Center(child: Text("${appState.t('讀取資料失敗：')}${snapshot.error}")));
                }

                final sessionsMap = snapshot.data!['sessions'] as Map<String, Map<String, dynamic>>;
                final badgesMap = snapshot.data!['badges'] as Map<String, Map<String, dynamic>>;

                int earnedCount = 0;
                for (var route in _allRoutes) {
                  if (sessionsMap[route['id']]?['Badge_Earned'] == true) {
                    earnedCount++;
                  }
                }
                bool isAllCollected = earnedCount == _allRoutes.length && _allRoutes.isNotEmpty;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: themeColor,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(appState.t('📔 玩家手帳：成就與進度'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: const Icon(Icons.close, color: Colors.white),
                          ),
                        ],
                      ),
                    ),

                    Flexible(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isAllCollected)
                              Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 24),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [Colors.amber.shade300, Colors.orange.shade400]),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))],
                                ),
                                child: Column(
                                  children: [
                                    Text(appState.t('🎉 掌聲鼓勵鼓勵 🎉'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                                    const SizedBox(height: 8),
                                    Text(appState.t('太強了！妳已經稱霸嘉義，解鎖了所有路線的專屬羈絆！'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Colors.white)),
                                  ],
                                ),
                              ).animate().scale(curve: Curves.elasticOut, duration: 800.ms).shimmer(duration: const Duration(seconds: 2), delay: const Duration(seconds: 1)),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${appState.t('🏆 羈絆徽章')} ($earnedCount/${_allRoutes.length})', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: themeColor)),
                              ],
                            ),
                            const Divider(),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 16,
                                childAspectRatio: 0.85,
                              ),
                              itemCount: _allRoutes.length,
                              itemBuilder: (context, index) {
                                String routeId = _allRoutes[index]['id']!;
                                bool isEarned = sessionsMap[routeId]?['Badge_Earned'] == true;
                                String badgeImageUrl = badgesMap[routeId]?['Image_Url'] ?? 'assets/images/badges/default.png';

                                return Column(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(color: isEarned ? Colors.amber : Colors.grey.shade300, width: isEarned ? 3 : 1),
                                          boxShadow: isEarned ? [BoxShadow(color: Colors.amber.withOpacity(0.5), blurRadius: 8)] : [],
                                        ),
                                        child: ClipOval(
                                          child: ColorFiltered(
                                            colorFilter: isEarned
                                                ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply)
                                                : ColorFilter.mode(Colors.grey.shade400, BlendMode.srcIn),
                                            child: Image.asset(
                                              badgeImageUrl,
                                              fit: BoxFit.cover,
                                              errorBuilder: (c, e, s) => Container(color: Colors.grey.shade200, child: const Icon(Icons.emoji_events, color: Colors.grey)),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      appState.t(_allRoutes[index]['name']!),
                                      style: TextStyle(fontSize: 12, fontWeight: isEarned ? FontWeight.bold : FontWeight.normal, color: isEarned ? Colors.black87 : Colors.grey),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ).animate(delay: (100 * index).ms).fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0);
                              },
                            ),

                            const SizedBox(height: 32),

                            Text(appState.t('🗺️ 探索進度'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: themeColor)),
                            const Divider(),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _allRoutes.length,
                              itemBuilder: (context, index) {
                                String routeId = _allRoutes[index]['id']!;
                                var sessionData = sessionsMap[routeId];
                                String statusText = appState.t("🔒 未出發");
                                Color statusColor = Colors.grey;
                                IconData statusIcon = Icons.lock_outline;

                                if (sessionData != null) {
                                  if (sessionData['Status'] == 'completed') {
                                    statusText = appState.t("💯 已通關");
                                    statusColor = Colors.green;
                                    statusIcon = Icons.check_circle;
                                  } else {
                                    int seq = sessionData['Current_Spot_Seq'] ?? 0;
                                    statusText = "${appState.t('🏃 進行中 (第')} ${seq + 1} ${appState.t('站)')}";
                                    statusColor = Colors.orange;
                                    statusIcon = Icons.directions_run;
                                  }
                                }

                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    backgroundColor: statusColor.withOpacity(0.1),
                                    child: Icon(statusIcon, color: statusColor, size: 20),
                                  ),
                                  title: Text(appState.t(_allRoutes[index]['name']!), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  subtitle: Text(appState.t(_allRoutes[index]['desc']!), style: const TextStyle(fontSize: 12)),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                                    child: Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                                  ),
                                ).animate(delay: (50 * index).ms).fadeIn(duration: 300.ms).slideX(begin: 0.1, end: 0);
                              },
                            ),

                            if (isFromRouteEnd) ...[
                              const SizedBox(height: 32),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: themeColor,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 56),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  elevation: 6,
                                ),
                                onPressed: () async {
                                  Navigator.pop(context);

                                  final prefs = await SharedPreferences.getInstance();
                                  await prefs.remove('currentStoryRoute');
                                  await prefs.remove('currentRouteId');
                                  setState(() {
                                    _selectedRouteName = null;
                                    _selectedRouteId = null;
                                    _isLoadingDialog = true;
                                    _routeSpotsData = [];
                                    _currentSpotIndex = 0;
                                  });

                                  _showRouteSelectionDialog();
                                },
                                child: Text(appState.t('✨ 選擇下一段羈絆路線'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.2)),
                              ).animate().scale(delay: 800.ms, curve: Curves.easeOutBack),
                            ]
                          ],
                        ),
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 300.ms).scale(curve: Curves.easeOutQuad);
              },
            ),
          ),
        );
      },
    );
  }

  String _getXiaoFenBubbleText(AppStateManager appState) {
    if (_isLoadingDialog) return appState.t('正在調閱資料...');

    // 🌟 讓小芬的氣泡支援英文角色名稱
    if (_currentDialogFlow != null) {
      String charName = (appState.currentLang == 'en' && _currentDialogFlow!['Character_Name_En'] != null && _currentDialogFlow!['Character_Name_En'].toString().isNotEmpty)
          ? _currentDialogFlow!['Character_Name_En']
          : _currentDialogFlow!['Character_Name'];
      return '${appState.t('跟')} $charName ${appState.t('聊聊吧！')}';
    }

    if (_isArrivedWaitingForDialog) {
      if (_routeSpotsData.isNotEmpty && _currentSpotIndex < _routeSpotsData.length) {
        // 🌟 抵達提示雙語支援
        String arrivalText = (appState.currentLang == 'en' && _routeSpotsData[_currentSpotIndex]['Arrival_Hint_Text_En'] != null && _routeSpotsData[_currentSpotIndex]['Arrival_Hint_Text_En'].toString().isNotEmpty)
            ? _routeSpotsData[_currentSpotIndex]['Arrival_Hint_Text_En']
            : _routeSpotsData[_currentSpotIndex]['Arrival_Hint_Text'];
        return arrivalText ?? appState.t('我們到達目的地了！');
      }
      return appState.t('我們到達目的地了！');
    }

    if (_currentArrivalSpotId != null) {
      return appState.t('發現一個新景點！左下角可以查看情報喔。');
    }

    return appState.t('跟著地圖前進吧！');
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedRouteName == null) {
      return Scaffold(body: Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor)));
    }

    final appState = Provider.of<AppStateManager>(context);
    final palette = appState.activePalette;
    final themeColor = palette[0];

    final bool isDialogueActive = _isLoadingDialog || _currentDialogFlow != null;

    // 🌟 1. 計算雙語標題與任務內文
    String taskTitleDisplay = _currentTaskTitle;
    String taskDescDisplay = appState.t(_currentTaskDesc);

    if (taskTitleDisplay == '🚶 探索任務') {
      taskTitleDisplay = '${appState.t('🚶 探索任務')} (${_currentSpotIndex + 1}/${_routeSpotsData.length})';

      // 🌟 探索任務內文雙語支援
      if (_routeSpotsData.isNotEmpty && _currentSpotIndex < _routeSpotsData.length) {
        taskDescDisplay = (appState.currentLang == 'en' && _routeSpotsData[_currentSpotIndex]['Task_Text_En'] != null && _routeSpotsData[_currentSpotIndex]['Task_Text_En'].toString().isNotEmpty)
            ? _routeSpotsData[_currentSpotIndex]['Task_Text_En']
            : _routeSpotsData[_currentSpotIndex]['Task_Text'];
      }
    } else {
      taskTitleDisplay = appState.t(taskTitleDisplay);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(appState.t(_selectedRouteName!), style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: appState.t('個人成就與進度'),
            onPressed: () => _showProfileDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: appState.t('重置路線 (測試用)'),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('currentStoryRoute');
              await prefs.remove('currentRouteId');
              setState(() {
                _selectedRouteName = null;
                _selectedRouteId = null;
                _isLoadingDialog = true;
                _routeSpotsData = [];
                _currentSpotIndex = 0;
              });
              _showRouteSelectionDialog();
            },
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: appState.t('返回'),
            onPressed: () => appState.goBack(),
          )
        ],
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          Expanded(
            flex: isDialogueActive ? 35 : 1,
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(initialCenter: _mockUserLocation, initialZoom: 15.0),
                  children: [
                    TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.explore_chiayi'),
                    MarkerLayer(markers: [
                      Marker(
                          point: _mockUserLocation,
                          child: const Icon(Icons.directions_walk, color: Colors.redAccent, size: 36)
                      )
                    ]),
                  ],
                ),
                Positioned(
                  top: 8, left: 8, right: 8,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _testLocations.map((loc) => Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.black87.withOpacity(0.7), foregroundColor: Colors.white, minimumSize: const Size(80, 36)),
                          onPressed: () => _simulateLocationChange(loc['lat'], loc['lng'], loc['spotId'], loc['dialogId'], loc['isLast']),
                          child: Text(loc['name'].toString(), style: const TextStyle(fontSize: 12)),
                        ),
                      )).toList(),
                    ),
                  ),
                ),

                if (_isArrivedWaitingForDialog)
                  Positioned(
                    bottom: 110,
                    left: 0, right: 0,
                    child: Center(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: Text(appState.t('開始對話'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          elevation: 8,
                        ),
                        onPressed: () {
                          setState(() => _isArrivedWaitingForDialog = false);
                          _loadDialogData(_pendingDialogId);
                        },
                      ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05), duration: 800.ms),
                    ),
                  ),

                Positioned(
                  bottom: 10, left: 10,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_currentArrivalSpotId != null)
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black87, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), elevation: 4, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4)),
                              icon: const Icon(Icons.menu_book, size: 16),
                              label: Text(appState.t('景點情報'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              onPressed: () => _fetchAndShowSpotInfo(_currentArrivalSpotId!),
                            ).animate(onPlay: (c) => c.repeat(reverse: true)).moveY(begin: -2, end: 2, duration: 1000.ms),

                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), margin: const EdgeInsets.only(top: 4),
                            decoration: BoxDecoration(color: themeColor, borderRadius: BorderRadius.circular(10)),
                            child: Text(appState.t('導覽員 · 小芬'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                          ).animate().slideY(begin: 1, end: 0, delay: 200.ms).fadeIn(),
                          Image.asset('assets/image_de9dd8.png', width: 95, height: 95).animate().scale(delay: 100.ms, duration: 400.ms, curve: Curves.easeOutBack),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(left: 8, bottom: 25),
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.95), borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomRight: Radius.circular(16)),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(2, 4))]
                        ),
                        child: Text(_getXiaoFenBubbleText(appState), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      ).animate().scale(delay: 500.ms, duration: 400.ms, alignment: Alignment.bottomLeft, curve: Curves.easeOutBack),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Container(
            height: 90, width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [palette[0].withOpacity(0.9), palette[3].withOpacity(0.9)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
              boxShadow: [BoxShadow(color: palette[0].withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(isDialogueActive ? Icons.chat_bubble : Icons.explore, color: Colors.white, size: 36)
                      .animate(onPlay: (controller) => controller.repeat(reverse: true)).shimmer(duration: 1500.ms),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(taskTitleDisplay, key: ValueKey(taskTitleDisplay), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                        const SizedBox(height: 4),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          // 🌟 2. 這裡改成 taskDescDisplay
                          child: Text(taskDescDisplay, key: ValueKey(taskDescDisplay), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (isDialogueActive)
            Expanded(
              flex: 55,
              child: _isLoadingDialog
                  ? const LoadingFenWidget()
                  : Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset('assets/image_dea0a1.png', fit: BoxFit.cover),
                  Container(color: Colors.black.withOpacity(0.2)),
                  if (_currentDialogFlow?['Character_Avatar_Url'] != null)
                    Positioned(
                      bottom: 0, left: 50,
                      child: Animate(
                        key: ValueKey(_currentDialogFlow!['Character_Avatar_Url']),
                        effects: [
                          FadeEffect(duration: 800.ms),
                          SlideEffect(begin: const Offset(0, 0.1), end: Offset.zero, curve: Curves.easeOut, duration: 800.ms),
                        ],
                        child: Image.asset(
                          _currentDialogFlow!['Character_Avatar_Url'], width: MediaQuery.of(context).size.width * 0.89, fit: BoxFit.fitWidth,
                        ).animate(onPlay: (controller) => controller.repeat(reverse: true)).moveY(begin: -4, end: 4, duration: 2000.ms, curve: Curves.easeInOut),
                      ),
                    ),
                  Positioned(
                    bottom: 85, left: 16, right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(color: themeColor, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))]),
                          // 🌟 角色名稱雙語支援
                          child: Text(
                              (appState.currentLang == 'en' && _currentDialogFlow?['Character_Name_En'] != null && _currentDialogFlow!['Character_Name_En'].toString().isNotEmpty)
                                  ? _currentDialogFlow!['Character_Name_En']
                                  : appState.t(_currentDialogFlow?['Character_Name'] ?? '神秘人物'),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                          ),
                        ).animate().slideX(begin: -0.2, end: 0, delay: 200.ms).fadeIn(),
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity, padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.95), borderRadius: BorderRadius.circular(16), border: Border.all(color: themeColor.withOpacity(0.3), width: 1.5),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4))]
                          ),
                          child: _currentDialogFlow?['Dialog_Text'] != null
                              ? AnimatedTextKit(
                            key: ValueKey(_currentDialogFlow!['Dialog_Text'] ?? 'key'),
                            displayFullTextOnTap: true, stopPauseOnTap: true, isRepeatingAnimation: false,
                            animatedTexts: [
                              TyperAnimatedText(
                                // 🌟 劇情內文雙語支援
                                  (appState.currentLang == 'en' && _currentDialogFlow!['Dialog_Text_En'] != null && _currentDialogFlow!['Dialog_Text_En'].toString().isNotEmpty)
                                      ? _currentDialogFlow!['Dialog_Text_En']
                                      : appState.t(_currentDialogFlow!['Dialog_Text']),
                                  speed: const Duration(milliseconds: 60),
                                  textStyle: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black87, fontWeight: FontWeight.w500)
                              ),
                            ],
                          )
                              : const Text('...', style: TextStyle(fontSize: 16)),
                        ).animate().slideY(begin: 0.2, end: 0, delay: 300.ms, duration: 400.ms, curve: Curves.easeOutQuad).fadeIn(),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 12, left: 16, right: 16,
                    child: _currentOptions.isNotEmpty
                        ? Row(
                      children: _currentOptions.map((option) {
                        int index = _currentOptions.indexOf(option);
                        bool isPrimary = index % 2 == 0;
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: index == 0 && _currentOptions.length > 1 ? 12.0 : 0.0),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: isPrimary ? Colors.white : palette[4], foregroundColor: isPrimary ? themeColor : Colors.white, side: isPrimary ? BorderSide(color: themeColor, width: 2) : null, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 4),
                              onPressed: () async {
                                if (option['Next_Dialog_Flow_Id'] != null) {
                                  _loadDialogData(option['Next_Dialog_Flow_Id']);
                                } else {
                                  if (_isCurrentSpotLast) {
                                    await _updateFirebaseProgress(completed: true);
                                    _fetchAndShowBadge();
                                  } else {
                                    if (_isInIntro) {
                                      _isInIntro = false;
                                      await _updateFirebaseProgress();
                                    } else {
                                      _currentSpotIndex++;
                                      await _updateFirebaseProgress();
                                    }
                                    _setExploringState();
                                  }
                                }
                              },
                              // 🌟 互動選項按鈕雙語支援
                              child: Text(
                                  (appState.currentLang == 'en' && option['Option_Text_En'] != null && option['Option_Text_En'].toString().isNotEmpty)
                                      ? option['Option_Text_En']
                                      : appState.t(option['Option_Text'] ?? '選項'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontWeight: FontWeight.bold)
                              ),
                            ),
                          ).animate().scale(delay: (1100 + index * 100).ms, duration: 300.ms, curve: Curves.easeOutBack),
                        );
                      }).toList(),
                    )
                        : Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: themeColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 4),
                            onPressed: () async {
                              if (_isCurrentSpotLast) {
                                await _updateFirebaseProgress(completed: true);
                                _fetchAndShowBadge();
                              } else {
                                if (_isInIntro) {
                                  _isInIntro = false;
                                  await _updateFirebaseProgress();
                                } else {
                                  _currentSpotIndex++;
                                  await _updateFirebaseProgress();
                                }
                                _setExploringState();
                              }
                            },
                            child: Text(appState.t(_isCurrentSpotLast ? '領取通關徽章 🏆' : '出發！繼續探索 ✨'), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ).animate().scale(delay: 1100.ms, duration: 300.ms, curve: Curves.easeOutBack),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}