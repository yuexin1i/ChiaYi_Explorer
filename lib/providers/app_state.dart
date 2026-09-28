// lib/providers/app_state.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class AppStateManager extends ChangeNotifier {
  final List<Color> _earthPalette = [
    const Color(0xFF8D6E63),
    const Color(0xFFA1887F),
    const Color(0xFFBCAAA4),
    const Color(0xFF8D6E63),
    const Color(0xFFD2E196),
    const Color(0xFFB2E36C),
    const Color(0xFF394E2E),
  ];
  final List<Color> _candyPalette = [
    const Color(0xFFFF80AB),
    const Color(0xFFFF4081),
    const Color(0xFFF50057),
    const Color(0xFFC51162),
    const Color(0xFFFF8A80),
    const Color(0xFFFF5252),
    const Color(0xFFFF1744),
  ];
  final List<Color> _rainbowPalette = [
    const Color(0xFFFF7B7B),
    const Color(0xFFFF9A52),
    const Color(0xFFE6CA0D),
    const Color(0xFF69F0AE),
    const Color(0xFF40C4FF),
    const Color(0xFF4D65FF),
    const Color(0xFFA748EC),
  ];
  final List<Color> _oceanPalette = [
    const Color(0xFF03A9F4),
    const Color(0xFF00E5FF),
    const Color(0xFF00B8D4),
    const Color(0xFF0091EA),
    const Color(0xFF0288D1),
    const Color(0xFF365BBF),
    const Color(0xFF70BEFF),
  ];

  int _currentThemeIndex = 2;

  int get currentThemeIndex => _currentThemeIndex;

  List<Color> get activePalette {
    switch (_currentThemeIndex) {
      case 0:
        return _earthPalette;
      case 1:
        return _candyPalette;
      case 2:
        return _rainbowPalette;
      case 3:
        return _oceanPalette;
      default:
        return _earthPalette;
    }
  }

  Color get themeColor => activePalette[0];

  void setThemeIndex(int index) {
    _currentThemeIndex = index;
    notifyListeners();
  }

  // 🧪 加入這段用來做假通知測試的方法
  Future<void> createFakeNotificationTest() async {
    if (_uid == null) return;

    try {
      await FirebaseFirestore.instance.collection('Notifications').add({
        'User_Id': _uid, // 設定為當前使用者，若是全域通知則改為 'global'
        'Title': '🧪 系統測試通知',
        'Body':
            '這是一則從 App 內生成的假通知，用來測試小紅點與清單是否正常運作！\n${DateTime.now().toString()}',
        'Type': 'test_reminder',
        'Created_At': FieldValue.serverTimestamp(),
        'Is_Read': false,
      });

      // 寫入後立刻檢查紅點狀態
      await checkUnreadNotifications();
      debugPrint('✅ 假通知已成功寫入 Firestore');
    } catch (e) {
      debugPrint('❌ 建立假通知失敗: $e');
    }
  }

  // ==========================================
  // 🌍 國際化多國語系 (i18n) 系統
  // ==========================================
  String _currentLang = 'zh';

  String get currentLang => _currentLang;

  void setLanguage(String lang) {
    _currentLang = lang;
    notifyListeners();
    _syncToFirestore();
  }

  void setPushEnabled(bool value) {
    _pushEnabled = value;
    notifyListeners();
    _syncToFirestore();
  }

  void setVoiceSpeed(double value) {
    _voiceSpeed = value;
    notifyListeners();
    _syncToFirestore();
  }

  String t(String text) {
    if (_currentLang == 'zh') return text;
    return _enDict[text] ?? text;
  }

  // 🌟 終極完整版英文翻譯字典檔
  final Map<String, String> _enDict = {
    // --- 基礎共用 ---
    '取消': 'Cancel',
    '確定': 'Confirm',
    '我知道了': 'Got it',
    '全部': 'All',
    '無地址資訊': 'No address info',
    '加入最新行程': 'Add to Itinerary',
    '新增標籤': 'Add Tag',
    '確定刪除': 'Delete',
    '移除標籤': 'Remove Tag',
    '移除': 'Remove',
    '確定標記': 'Confirm',
    '加入': 'Add',
    '錯誤': 'Error',
    // --- 分類標籤 ---
    '廟宇': 'Temple',
    '古蹟': 'Historic',
    '工廠': 'Factory',
    '城堡': 'Castle',
    '自然': 'Nature',
    '藝文': 'Art',
    '網美打卡': 'IG Spot',
    '親子友善': 'Family Friendly',
    '咖啡廳': 'Cafe',
    '傳統小吃': 'Local Snacks',
    '甜點': 'Dessert',
    '宵夜': 'Midnight Snack',
    '伴手禮': 'Souvenir',
    '排隊名店': 'Popular',
    '雞肉飯': 'Chicken Rice',
    '嘉市好店': 'Good Shops',
    '夜市': 'Night Market',
    '飯店': 'Hotel',
    '設計感': 'Design',
    '高CP值': 'High CP',
    '民宿': 'B&B',
    '東區': 'East Dist.',
    '西區': 'West Dist.',
    '阿里山鄉': 'Alishan',
    '梅山鄉': 'Meishan',
    '竹崎鄉': 'Zhuqi',
    '番路鄉': 'Fanlu',
    '中埔鄉': 'Zhongpu',
    '自然風景': 'Nature Scenery',
    '藝文展覽': 'Art Exhibition',
    '文化古蹟': 'Cultural Heritage',
    '借問站': 'Info Station',
    '無障礙廁所': 'Accessible Toilet',
    '行程': 'Itinerary',
    '交通': 'Transport',
    // --- 個人與設定 ---
    '使用者資訊與設定': 'Profile & Settings',
    '基本資料': 'Basic Info',
    '真實姓名 / 暱稱': 'Name / Nickname',
    '登入帳號 (不可修改)': 'Account (Unchangeable)',
    '修改密碼 (若不修改請留白)': 'Change Password (Leave blank to keep)',
    '系統設定': 'System Settings',
    'App 介面語言': 'App Language',
    '目前語系：繁體中文': 'Current Language: Traditional Chinese',
    '目前語系：English': 'Current Language: English',
    '接收智慧推播通知': 'Smart Push Notifications',
    '活動提醒、天氣預報、景點異動': 'Events, Weather, Spot Updates',
    '智慧推播靜音時段': 'Do Not Disturb (DND)',
    '設定晚上或不便打擾的時間': 'Set silent hours',
    '儲存修改': 'Save Changes',
    '退出登入': 'Log Out',
    '資料同步中，請稍候...': 'Syncing data, please wait...',
    '✅ 設定已成功同步至雲端！': '✅ Settings successfully synced to cloud!',
    // --- 首頁 ---
    '早安，': 'Good morning, ',
    '旅人': 'Traveler',
    '準備好探索諸羅了嗎？': 'Ready to explore Chiayi?',
    '主題風格選擇': 'Theme Style Selection',
    '請選擇您喜歡的 7 色系列風格：': 'Choose your favorite 7-color palette:',
    '快速導覽': 'Quick Nav',
    '自訂': 'Edit',
    '自訂快速導覽 (6格)': 'Customize Quick Nav (6 slots)',
    '近期推薦活動': 'Recommended Events',
    '最新消息': 'Latest News',
    '發布日期：': 'Published: ',
    '今日旅遊運勢': 'Daily Travel Fortune',
    '點我抽出！': 'Draw Now!',
    '今日運勢': "Today's fortune",
    '已抽取': 'Drawn',
    '正在揭曉…': 'Revealing…',
    '正在為你揭曉今日運勢…': "Revealing today's fortune…",
    '今日諸羅運勢': 'Chiayi Daily Fortune',
    '收下好運': 'Accept Luck',
    '28°C': '28°C',
    '晴時多雲': 'Partly Cloudy',
    '晴朗': 'Clear',
    '多雲': 'Cloudy',
    '有霧': 'Foggy',
    '毛毛雨': 'Drizzle',
    '下雨': 'Rain',
    '降雪': 'Snow',
    '陣雨': 'Showers',
    '陣雪': 'Snow showers',
    '雷雨': 'Thunderstorm',
    '天氣變化中': 'Variable weather',
    '天氣資料暫時無法載入': 'Weather unavailable',
    '開啟側邊欄': 'Open navigation menu',
    '景點探索': 'Attractions',
    '在地美食': 'Local Food',
    '特色住宿': 'Stays',
    '交通資訊': 'Traffic Info',
    '互動地圖': 'Interactive Map',
    'AI助理': 'AI Assistant',
    '近期活動': 'Recent Events',
    '收藏景點': 'Favorites',
    '行程管理': 'Itinerary',
    '【交通】台灣好行光林我嘉線，持電子票證免費搭乘！':
        '[Traffic] Free ride on Taiwan Trip Bus with E-ticket!',
    '【活動】市區 YouBike 2.0E 電輔車新站點全面啟用':
        '[Event] YouBike 2.0E new stations officially opened',
    '【公告】諸羅探索 App 雲端同步功能全新上線✨':
        '[Announcement] Cloud Sync feature is now online✨',
    '為鼓勵民眾搭乘大眾運輸，自即日起至2026年底，只要持悠遊卡、一卡通等電子票證搭乘「台灣好行光林我嘉線」，即可享全線免費搭乘優惠！帶您輕鬆暢遊嘉義市各大景點。':
        'To encourage public transportation, free rides are available on the Taiwan Trip Bus with E-tickets until the end of 2026!',
    '嘉義市 YouBike 2.0 系統再升級！全新引進 YouBike 2.0E 電力輔助自行車，並於市區各大商圈、車站新增 50 個租借站點，讓您爬坡更省力，騎乘更輕鬆。':
        'Chiayi City YouBike 2.0 upgraded! 50 new YouBike 2.0E electric assist bikes stations added.',
    '親愛的探索者您好：\n\n期待已久的「雲端同步」功能正式上線啦！現在只要註冊或綁定 Google 帳號，您的專屬行程、收藏景點與自訂標籤都會自動備份到雲端，換手機也不怕資料遺失囉！快去個人頁面看看吧！':
        'Dear Explorer:\n\nThe long-awaited Cloud Sync is here! Your itineraries, favorites, and tags will automatically sync to the cloud when you bind your Google account.',
    // --- 景點/美食/住宿/收藏清單 ---
    '搜尋景點關鍵字...': 'Search attractions...',
    '找不到相關景點 😢': 'No attractions found 😢',
    '輸入自訂標籤 (例: 網美打卡)': 'Enter custom tag (e.g. IG Spot)',
    '從現有標籤庫選擇 (長按可刪除)：': 'Choose from existing tags (Long press to delete):',
    '您還沒有建立任何行程！請先至行程管理頁面新增。':
        'No itinerary created yet! Please create one in Itinerary page.',
    '搜尋美食名稱、地址或簡介...': 'Search food, address or description...',
    '📍 已切換為「距離最近」排序': '📍 Sorted by nearest distance',
    '找不到相關美食資料 😢': 'No food found 😢',
    '隨機推薦美食': 'Random Food',
    '目前沒有美食可以抽喔！': 'No food to roll!',
    '正在為您精選美食...': 'Selecting food for you...',
    '店家簡介': 'Description',
    '開始導航': 'Navigate',
    '加入行程': 'Add to Itinerary',
    '🎲 不喜歡？再抽一次！': '🎲 Re-roll!',
    '搜尋住宿名稱、地址關鍵字...': 'Search hotel or address...',
    '📍 已為您切換為「距離最近」排序': '📍 Sorted by nearest distance',
    '找不到相關住宿資料': 'No hotels found',
    '前往訂房': 'Book Now',
    '輸入自訂標籤 (例: 必吃)': 'Enter custom tag (e.g. Must Eat)',
    '我的收藏景點': 'My Favorites',
    '目前沒有此分類的收藏項目': 'No favorites in this category',
    '則評分': 'reviews',
    // --- 互動地圖 ---
    '探索地圖': 'Explore Map',
    '歡迎來到探索地圖！地圖目前乾乾淨淨的，請從右上角選擇您感興趣的標籤吧！':
        'Welcome to the map! It is currently clean, please select tags of interest from the top right!',
    '過濾「': 'Filter "',
    '全選/全清': 'Select All/Clear',
    '隱藏此類別': 'Hide this category',
    '完成篩選': 'Done',
    '選取': 'Select ',
    ' (依距離)': ' (By Distance)',
    '距離目前位置: ': 'Distance: ',
    '隱藏此標籤': 'Hide this tag',
    '確認顯示': 'Confirm Display',
    '選擇要顯示軌跡的行程': 'Select itinerary to show route',
    '目前還沒有行程喔！': 'No itineraries yet!',
    '取消行程顯示': 'Cancel route display',
    '這看起來是個好地方！\n要去「': 'Looks like a good place!\nGo to "',
    '」嗎？': '"?',
    '好！開始導航': 'Yes! Navigate',
    '正在載入最新地圖資訊...': 'Loading latest map info...',
    '為您顯示附近的「': 'Showing nearby "',
    '」囉！': '"!',
    '好的！為您標示出「': 'Done! Showing "',
    '回到我的位置': 'My Location',
    '清空地圖': 'Clear Map',
    '放大': 'Zoom In',
    '縮小': 'Zoom Out',
    '導覽員 · 小芬': 'Guide · Xiaofen',
    '結束並清除導航路線': 'End Navigation',
    // --- AI 助理 ---
    '嘉遊站助理': 'AI Assistant',
    '景點問答': 'Spot Q&A',
    '行程規劃': 'Itinerary Planning',
    '將此行程加入我的行程表': 'Add to my itinerary',
    '告訴我你想去哪裡玩...': 'Tell me where you want to go...',
    '嗨！我是您的 AI 旅遊助理。您可以對我說：「幫我安排嘉義一日遊」，或詢問特定景點資訊喔！':
        'Hi! I am your AI travel assistant. You can say: "Plan a Chiayi day trip", or ask about specific spots!',
    // --- 活動與活動詳細 ---
    '活動詳細資訊': 'Event Details',
    '查無活動資料': 'Event not found',
    '前往活動官網': 'Visit Website',
    '活動介紹': 'Event Description',
    '從行事曆移除': 'Remove from Calendar',
    '加入我的行事曆': 'Add to Calendar',
    '活動行事曆': 'Event Calendar',
    ' 已加入的活動': ' Saved Events',
    '這天還沒有安排活動喔！': 'No events scheduled for this day!',
    '✨ 探索更多活動': '✨ Explore More Events',
    '熱門：音樂節 / 廟會 / 藝術展覽': 'Popular: Music Fest / Temple Fair / Art Expo',
    '時間：': 'Time: ',
    // --- 行程管理 ---
    '建立新行程': 'New Itinerary',
    '新增專屬行程': 'Add Exclusive Itinerary',
    '行程名稱 (例如：嘉義放鬆之旅)': 'Itinerary Name (e.g., Chiayi Relax Trip)',
    '選擇代表圖示：': 'Select an icon:',
    '編輯行程': 'Edit Itinerary',
    '行程名稱': 'Itinerary Name',
    '更改代表圖示：': 'Change icon:',
    '儲存變更': 'Save Changes',
    '還沒有建立任何行程喔！': 'No itineraries created yet!',
    '編輯行程資訊': 'Edit Info',
    '刪除行程': 'Delete Itinerary',
    '刪除': 'Delete',
    '目前還沒有加入任何地點喔！': 'No spots added yet!',
    '預計抵達時間：': 'Est. Arrival: ',
    '新增地點至此行程': 'Add spot to itinerary',
    '搜尋並加入地點': 'Search & Add Spot',
    '輸入關鍵字...': 'Enter keyword...',
    '火車 (TRA)': 'Train (TRA)',
    '高鐵 (THSR)': 'HSR (THSR)',
    '查無資料，請先前往對應頁面瀏覽以建立快取。':
        'No data. Please visit the corresponding page to build cache.',
    // --- 景點詳細 ---
    '語音導覽設定': 'Audio Guide Settings',
    '選擇語言：': 'Select Language:',
    '語速調整：': 'Speed Adjustment:',
    '找不到景點資料，請回上一頁重試。': 'Spot data not found, please go back and retry.',
    '暫無詳細介紹。': 'No detailed description available.',
    '依現場公告為主': 'Subject to on-site announcement',
    '無聯絡電話': 'No contact number',
    '語音導覽': 'Audio Guide',
    '位置資訊': 'Location Info',
    // --- 漏網之魚補齊區 ---
    '您好': 'Hello',
    '首頁': 'Home',
    '互動故事模式': 'Interactive Story Mode',
    '景點': 'Attractions',
    '美食': 'Food',
    '住宿': 'Stays',
    '這看起來是個好地方！\n要去「': 'Looks like a great place!\nWant to go to "',
    '」嗎？': '"?',
    '好！開始導航': 'Yes! Start Navigation',
    // --- AI 助理與故事地圖補充 ---
    '抱歉，我目前無法回應。': 'Sorry, I cannot respond right now.',
    '發生錯誤，請確認網路連線或 API 金鑰是否正確。': 'Error, please check network or API key.',
    '✨ 行程已加入！': '✨ Itinerary added!',
    '景點問答': 'Spot Q&A',
    '行程規劃': 'Itinerary Planning',
    '將此行程加入我的行程表': 'Add to my itinerary',
    '告訴我你想去哪裡玩...': 'Tell me where you want to go...',
    '🗺️ 準備出發': '🗺️ Ready to go',
    '請等待系統載入路線...': 'Loading route...',
    '🎯 抵達景點': '🎯 Arrived',
    '請點擊畫面上的「開始對話」與角色互動。': 'Click "Start Conversation" to interact.',
    '系統在資料庫內找不到': 'System cannot find in database',
    '了解了！': 'Got it!',
    '神秘徽章': 'Mystery Badge',
    '恭喜完成路線！': 'Congratulations on completing the route!',
    '通關徽章': 'Clear Badge',
    '恭喜完成路線所有景點！': 'Congratulations on visiting all spots!',
    '🏆 路線通關': '🏆 Route Cleared',
    '恭喜獲得專屬通關徽章！': 'Congratulations on earning the exclusive badge!',
    '獲得徽章：': 'Earned Badge: ',
    '收下徽章': 'Accept Badge',
    '🔄 載入中': '🔄 Loading',
    '正在獲取路線資料...': 'Fetching route data...',
    '🚶 探索任務': '🚶 Explore Task',
    '請依照地圖指示前往下一站。': 'Please follow the map to the next stop.',
    '🗺️ 自由探索': '🗺️ Free Explore',
    '路線任務皆已完成，自由探索嘉義吧！': 'All tasks completed, explore Chiayi freely!',
    '💬 劇情互動': '💬 Story Interaction',
    '請點擊選項，與角色進行互動。': 'Click an option to interact.',
    '✨ 選擇妳的專屬羈絆路線': '✨ Choose Your Route',
    '進入': 'Enter ',
    '點擊卡片展開預覽': 'Tap card to preview',
    '關閉並返回上一頁': 'Close and return',
    '讀取資料失敗：': 'Failed to load data: ',
    '📔 玩家手帳：成就與進度': '📔 Travel Journal: Progress',
    '🎉 掌聲鼓勵鼓勵 🎉': '🎉 Round of Applause 🎉',
    '太強了！妳已經稱霸嘉義，解鎖了所有路線的專屬羈絆！': 'Amazing! You unlocked all routes!',
    '🏆 羈絆徽章': '🏆 Badges',
    '🔒 未出發': '🔒 Not Started',
    '💯 已通關': '💯 Cleared',
    '🏃 進行中 (第': '🏃 In Progress (Stop ',
    '站)': ')',
    '✨ 選擇下一段羈絆路線': '✨ Choose Next Route',
    '正在調閱資料...': 'Retrieving data...',
    '跟': 'Talk to ',
    '聊聊吧！': '!',
    '我們到達目的地了！': 'We have arrived!',
    '發現一個新景點！左下角可以查看情報喔。': 'New spot found! Check info on bottom left.',
    '跟著地圖前進吧！': 'Follow the map!',
    '開始對話': 'Start Conversation',
    '景點情報': 'Spot Info',
    '選項': 'Option',
    '出發！繼續探索 ✨': 'Let\'s Go! Keep Exploring ✨',
    '領取通關徽章 🏆': 'Claim Badge 🏆',
    '重置路線 (測試用)': 'Reset Route (Test)',
    '繁中': 'TW',
    '日本語': 'JP',
    '凝時之彩': 'Colors of Time',
    '名畫家朝聖之路': 'Painter\'s Pilgrimage',
    '獨家條款': 'Show U Around',
    '專屬視察企劃': 'Special Inspection with Boss Gu',
    '綠野逐光': 'Chasing the Light',
    '牧羊男的晴空紀行': 'Shepherd\'s Journey',
    '時光迴遞': 'Time Loop',
    '森之歌專屬列車': 'Forest Song Train',
    '諸羅謎影': 'Chiayi Enigma',
    '古城踏查檔案': 'Old City Files',
    '香煙裊裊': 'Incense Smoke',
    '結緣祈願行': 'Prayer Journey',
    // --- 登入與註冊頁面 ---
    '歡迎回到諸羅探索': 'Welcome back to Chiayi Explore',
    '請輸入帳號與密碼': 'Please enter account and password',
    '登入中...': 'Logging in...',
    '找不到您的帳號資料，為您跳轉至註冊頁！': 'Account not found, redirecting to register page!',
    '登入成功！': 'Login successful!',
    '查無此帳號或密碼錯誤，將跳轉至註冊頁面...':
        'Account not found or incorrect password, redirecting...',
    '登入失敗: ': 'Login failed: ',
    '正在連線至 Google...': 'Connecting to Google...',
    '已取消 Google 登入': 'Google login canceled',
    '您尚未建立帳號，請先完成註冊！': 'Account not found, please register first!',
    '歡迎回來, ': 'Welcome back, ',
    '登入已取消或發生錯誤': 'Login canceled or error occurred',
    '帳號': 'Account',
    '密碼': 'Password',
    '登入': 'Login',
    '或': 'Or',
    '使用 Google 帳號登入': 'Login with Google',
    '還沒有帳號嗎？': 'Don\'t have an account?',
    '立即註冊': 'Register Now',
    '註冊新帳號': 'Register New Account',
    '已取消 Google 註冊': 'Google registration canceled',
    '✅ Google 帳號綁定成功, 歡迎 ': '✅ Google account linked, welcome ',
    '註冊失敗，請稍後再試 (': 'Registration failed, please try again (',
    '正在建立帳號...': 'Creating account...',
    '✅ 註冊成功，請登入您的帳號！': '✅ Registration successful, please log in!',
    '這個信箱已經被註冊過了！請換一個。': 'This email is already registered!',
    '密碼太弱，請至少輸入 6 個字元！': 'Password is too weak (min 6 chars)!',
    '信箱格式不正確！': 'Invalid email format!',
    '發生錯誤: ': 'Error: ',
    '加入諸羅探索': 'Join Chiayi Explore',
    '點擊上傳頭像 (選填)': 'Click to upload avatar (Optional)',
    '暱稱': 'Nickname',
    '再次輸入密碼': 'Confirm Password',
    '兩次輸入的密碼不一致！': 'Passwords do not match!',
    '完成註冊': 'Complete Registration',
    '使用 Google 帳號註冊': 'Register with Google',
    '此欄位為必填': 'This field is required',
    '帳號必須是有效的 Email 格式 (例如: a@b.com)':
        'Account must be a valid email (e.g. a@b.com)',
    '密碼長度至少需要 6 個字元': 'Password must be at least 6 characters',
    // --- 交通資訊頁面 ---
    '停車場': 'Parking',
    '市區公車': 'Bus',
    '計程車': 'Taxi',
    '台鐵': 'TRA',
    '高鐵': 'THSR',
    '地址：': 'Address: ',
    '收費：': 'Fee: ',
    '依距離排序': 'Sort by Distance',
    '目前沒有': 'No ',
    '資料': ' data available',
    '公尺': 'm',
    '關閉': 'Close',
    '附近招呼站': 'Nearby Stops',
    '叫車專線': 'Call Taxi',
    '計費：': 'Fare: ',
    '目前沒有業者資料': 'No operators available',
    '可借': 'Avail',
    '可還': 'Dock',
    '總車位': 'Total',
    '即時資料載入中…': 'Loading live data...',
    'TDX 限流，請稍後重試': 'API Rate Limited, try again later',
    '錯誤：': 'Error: ',
    '正在抓取即時車位...': 'Fetching live bikes...',
    '即時車位已更新': 'Live updated ',
    '即時車位未載入': 'Live data not loaded',
    '載入即時車位中…': 'Loading live bikes...',
    '逆行 (北上)': 'Northbound',
    '順行 (南下)': 'Southbound',
    '即時看板': 'Live Board',
    '即時看板載入失敗：': 'Failed to load live board: ',
    '目前無列車資料': 'No train data available',
    '南向': 'South',
    '北向': 'North',
    '誤點': 'Delay',
    '分': 'min',
    '準時': 'On Time',
    '請選擇一個台鐵站': 'Please select a TRA station',
    '公里': 'km',
    '查看站區平面圖與出口資訊': 'View Station Map & Exits',
    '時刻表': 'Timetable',
    '時刻表載入失敗：': 'Failed to load timetable: ',
    '今日無': 'No ',
    '南下': 'South',
    '北上': 'North',
    '班次': ' trains today',
    '抵達': 'Arrive',
    '站區平面圖': 'Station Map',
    '搜尋公車路線 (例如: 中山幹線)': 'Search bus route (e.g. Zhongshan Main Line)',
    '全部路線': 'All Routes',
    '嘉市公車': 'Chiayi City Bus',
    '嘉縣公車': 'Chiayi County Bus',
    '目前沒有公車路線資料': 'No bus route data available',
    '站': 'stops',
    '載入即時到站…': 'Loading ETA...',
    'TDX限流，請稍候重試': 'TDX rate limited, try again',
    'ETA 載入失敗': 'Failed to load ETA',
    '即時到站已更新 ✓': 'ETA updated ✓',
    '去程': 'Outbound',
    '返程': 'Inbound',
    '此路線尚無站牌資料': 'No stop data for this route',
    '站序：第': 'Seq: ',
    '站點代碼：': 'Stop UID: ',
    '第': 'Stop ',
    '正常': 'Normal',
    '尚未發車': 'Not Departed',
    '交管': 'Traffic Control',
    '末班過': 'Last Bus Passed',
    '未營運': 'Out of Service',
    '即將到站': 'Arriving Soon',
    '景點介紹': 'Spot Description',
    // --- 地圖頁面遺漏翻譯 ---
    '依座標定位': 'Locate by Coordinates',
    '無地址資訊': 'No address info',
    '暫無詳細介紹': 'No detailed description available.',
    '歡迎來到探索地圖！地圖目前乾乾淨淨的轉，請從右上角選擇您感興趣的標籤吧！':
        'Welcome to the map! It is currently empty. Please select a tag from the top right to start exploring!',
    '地圖已為您清空囉！隨時可以重新選擇想去的地方！':
        'Map cleared! Feel free to pick new places to explore!',
    '回到目前位置，準備好去哪裡探險了嗎？': 'Back to current location, ready to explore?',
    '導航已結束！接下來我們去哪裡探險呢？': 'Navigation ended! Where to next?',
    '為您顯示附近的「': 'Showing nearby "',
    '」囉！': '"!',
    '好的！為您標示出「': 'Okay! Highlighting "',
    '為您顯示軌跡：': 'Showing itinerary: ',
    '已繪製路線並開啟 Google Maps！抵達後記得注意安全喔！':
        'Route drawn and Google Maps opened! Please stay safe upon arrival!',
    '選取': 'Select ',
    ' (依距離)': ' (By Distance)',
    '全選/全清': 'Select All / Clear',
    '距離目前位置: ': 'Distance from current location: ',
    '隱藏此標籤': 'Hide this tag',
    '確認顯示': 'Confirm display',
    '過濾「': 'Filter "',
    '隱藏此類別': 'Hide this category',
    '完成篩選': 'Finish Filtering',
    '取消行程顯示': 'Cancel Itinerary Display',
    '回到我的位置': 'Back to My Location',
    '清空地圖': 'Clear Map',
    '放大': 'Zoom In',
    '縮小': 'Zoom Out',
    '官方網站': 'Official Website',
    '餐廳': 'Restaurant',
    // --- 在地美食頁面 (Food Page) ---
    '全部': 'All',
    '咖啡廳': 'Cafes',
    '雞肉飯': 'Turkey Rice',
    '嘉市好店': 'Chiayi Elite',
    '夜市': 'Night Markets',
    '餐廳': 'Restaurants',
    '傳統小吃': 'Traditional Snacks',
    '甜點': 'Desserts',
    '宵夜': 'Late Night Snacks',
    '伴手禮': 'Souvenirs',
    '排隊名店': 'Popular Queues',
    '切換為預設排序': 'Switch to Default Sort',
    '切換為距離排序': 'Switch to Distance Sort',
    '已切換為：依距離排序': 'Switched to: Sort by Distance',
    '已切換為：預設排序': 'Switched to: Default Sort',
    '搜尋美食、小吃或店家...': 'Search for food, snacks, or stores...',
    '查無符合條件的美食': 'No food matches your criteria',
    '已加入收藏：': 'Added to favorites: ',
    '已取消收藏：': 'Removed from favorites: ',
    '請輸入行程名稱！': 'Please enter an itinerary name!',
    '確定要刪除': 'Are you sure you want to delete',
    '嗎？': '?',
    '資源回收筒': 'Trash',
    '垃圾桶空空如也！': 'Trash is empty!',
    '放在這裡的行程會在 5 天後自動永久刪除。':
        'Itineraries here will be permanently deleted after 5 days.',
    '還原': 'Restore',
    '行程已還原！': 'Itinerary restored!',
    '未命名行程': 'Untitled itinerary',
    'Gemini AI 專屬推薦行程': 'Gemini AI Custom Itinerary',
    '通知中心': 'Notifications',
    '目前沒有通知': 'No notifications yet',
    '通知': 'Notification',
  };

  String? _uid;
  String? _nickname;
  String? _account;
  String? _password;
  String? _avatarUrl;
  File? _avatar;
  bool _isLoggedIn = false;
  bool _isAdmin = false;

  bool _pushEnabled = true;
  double _voiceSpeed = 1.0;
  bool _hasUnreadNotification = false;

  String? get uid => _uid;

  String? get nickname => _nickname;

  /// The name shown in greetings throughout the app.
  ///
  /// Prefer the nickname saved at registration. While Firestore is loading (or
  /// for an older account without a nickname), fall back to the authenticated
  /// Google name and then the account name instead of showing a hard-coded
  /// "探索者".
  String get greetingName {
    final savedNickname = _nickname?.trim();
    if (savedNickname != null &&
        savedNickname.isNotEmpty &&
        savedNickname != '探索者' &&
        savedNickname.toLowerCase() != 'explorer') {
      return savedNickname;
    }

    final authName = FirebaseAuth.instance.currentUser?.displayName?.trim();
    if (authName != null && authName.isNotEmpty) return authName;

    final email =
        (_account ?? FirebaseAuth.instance.currentUser?.email)?.trim();
    if (email != null && email.isNotEmpty) {
      final accountName = email.split('@').first.trim();
      if (accountName.isNotEmpty) return accountName;
    }

    return t('旅人');
  }

  String personalizeGreeting(String text) {
    return text
        .replaceAll('探索者', greetingName)
        .replaceAll('Explorer', greetingName);
  }

  String? get account => _account;

  String? get avatarUrl => _avatarUrl;

  File? get avatar => _avatar;

  bool get isLoggedIn => _isLoggedIn;

  bool get isAdmin => _isAdmin;

  bool get pushEnabled => _pushEnabled;

  double get voiceSpeed => _voiceSpeed;

  bool get hasUnreadNotification => _hasUnreadNotification;
  List<Map<String, dynamic>> _itineraries = [];
  List<Map<String, dynamic>> _favoriteSpotsList = [];
  List<Map<String, dynamic>> _savedEvents = [];

  List<Map<String, dynamic>> get itineraries => _itineraries;

  List<Map<String, dynamic>> get favoriteSpotsList => _favoriteSpotsList;

  List<Map<String, dynamic>> get savedEvents => _savedEvents;

  Future<void> loadUserDataFromFirestore(String uid, String email) async {
    if (_uid == uid) return;

    _uid = uid;
    _account = email;
    _isLoggedIn = true;

    try {
      final userRef = FirebaseFirestore.instance.collection('Users').doc(uid);
      final doc = await userRef.get();

      Map<String, dynamic> data = {};

      if (doc.exists && doc.data() != null) {
        data = doc.data()!;

        final storedNickname = data['Nickname']?.toString().trim();
        final isLegacyPlaceholder =
            storedNickname == '探索者' ||
            storedNickname?.toLowerCase() == 'explorer';
        _nickname =
            storedNickname != null &&
                    storedNickname.isNotEmpty &&
                    !isLegacyPlaceholder
                ? storedNickname
                : null;
        _avatarUrl = data['Avatar_Url'];
        _isAdmin = data['Role'] == 'admin';

        if (data['Language_Pref'] != null) {
          _currentLang = data['Language_Pref'];
        }

        if (data['Push_Enabled'] != null) {
          _pushEnabled = data['Push_Enabled'];
        }

        if (data['Voice_Speed'] != null) {
          final rawSpeed = data['Voice_Speed'];

          if (rawSpeed is int) {
            _voiceSpeed = rawSpeed.toDouble();
          } else if (rawSpeed is double) {
            _voiceSpeed = rawSpeed;
          }
        }

        if (data['Favorites'] != null) {
          _favoriteSpotsList = List<Map<String, dynamic>>.from(
            data['Favorites'],
          );
        }

        if (data['SavedEvents'] != null) {
          _savedEvents = List<Map<String, dynamic>>.from(data['SavedEvents']);
        }

        if (data['User_Tags'] != null) {
          final prefs = await SharedPreferences.getInstance();
          Map<String, dynamic> cloudTags = data['User_Tags'];

          for (var key in cloudTags.keys) {
            await prefs.setStringList(key, List<String>.from(cloudTags[key]));
          }
        }
      }

      if (!doc.exists) {
        _isAdmin = false;
      }

      await userRef.set({
        'User_Id': uid,
        if (_avatarUrl != null) 'Avatar_Url': _avatarUrl,
        'Language_Pref': _currentLang,
        'Push_Enabled': _pushEnabled,
        'Voice_Speed': _voiceSpeed,
        'Last_Login': FieldValue.serverTimestamp(),
        if (data['Created_At'] == null)
          'Created_At': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Older versions could persist the temporary placeholder during the
      // first-login race. Migrate those records to the best authenticated name.
      final cloudNickname = data['Nickname']?.toString().trim();
      if (doc.exists &&
          (cloudNickname == null ||
              cloudNickname.isEmpty ||
              cloudNickname == '探索者' ||
              cloudNickname.toLowerCase() == 'explorer')) {
        _nickname = greetingName;
        await userRef.update({'Nickname': _nickname});
      }

      await _loadItinerariesFromCollection();
      await checkUnreadNotifications();

      notifyListeners();
    } catch (e) {
      debugPrint('讀取使用者資料失敗: $e');
    }
  }

  Future<void> _syncToFirestore() async {
    if (_uid == null) return;

    try {
      await FirebaseFirestore.instance.collection('Users').doc(_uid).set({
        'User_Id': _uid,
        'Nickname': greetingName,
        if (_avatarUrl != null) 'Avatar_Url': _avatarUrl,
        'Language_Pref': _currentLang,
        'Push_Enabled': _pushEnabled,
        'Voice_Speed': _voiceSpeed,
        'Favorites': _favoriteSpotsList,
        'SavedEvents': _savedEvents,
        'Updated_At': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('同步使用者資料失敗: $e');
    }
  }

  Future<void> syncTagsToCloud() async {
    if (_uid == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      Map<String, List<String>> allTags = {};
      for (String key in prefs.getKeys()) {
        if (key.startsWith('tags_') || key.startsWith('global_tags_'))
          allTags[key] = prefs.getStringList(key) ?? [];
      }
      await FirebaseFirestore.instance.collection('Users').doc(_uid).set({
        'User_Tags': allTags,
      }, SetOptions(merge: true));
    } catch (e) {}
  }

  void register(String nick, String acc, String pass, File? avt) {
    _nickname = nick;
    _account = acc;
    _password = pass;
    _avatar = avt;
    notifyListeners();
  }

  bool login(String acc, String pass) {
    if (acc == _account && pass == _password) {
      _isLoggedIn = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  void forceLogin(String acc, String pass) {
    _account = acc;
    _password = pass;
    _isLoggedIn = true;
    notifyListeners();
  }

  Future<void> updateProfile(String nick, String pass, File? newAvatar) async {
    _nickname = nick;
    await FirebaseAuth.instance.currentUser?.updateDisplayName(nick);
    if (pass.isNotEmpty) _password = pass;
    if (newAvatar != null) _avatar = newAvatar;
    notifyListeners();
    if (_uid != null) {
      String? uploadedUrl;
      if (newAvatar != null) {
        try {
          final ref = FirebaseStorage.instance
              .ref()
              .child('avatars')
              .child('$_uid.jpg');
          await ref.putFile(newAvatar);
          uploadedUrl = await ref.getDownloadURL();
          _avatarUrl = uploadedUrl;
        } catch (e) {}
      }
      await FirebaseFirestore.instance.collection('Users').doc(_uid).update({
        'Nickname': nick,
        if (uploadedUrl != null) 'Avatar_Url': uploadedUrl,
      });
    }
  }

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn.instance.signOut();
    final prefs = await SharedPreferences.getInstance();
    for (String key in prefs.getKeys()) {
      if (key.startsWith('tags_') || key.startsWith('global_tags_'))
        await prefs.remove(key);
    }
    _isLoggedIn = false;
    _isAdmin = false;
    _uid = null;
    _account = null;
    _nickname = null;
    _avatarUrl = null;
    _avatar = null;
    _itineraries.clear();
    _favoriteSpotsList.clear();
    _savedEvents.clear();
    notifyListeners();
  }

  int _pageIndex = 0;
  int _previousPageIndex = 0;

  int get pageIndex => _pageIndex;

  int get previousPageIndex => _previousPageIndex;

  void setPageIndex(int index) {
    _previousPageIndex = _pageIndex;
    _pageIndex = index;
    notifyListeners();
  }

  void goBack() {
    _pageIndex = _previousPageIndex;
    notifyListeners();
  }

  String _createItineraryId() {
    return 'itin_${DateTime.now().millisecondsSinceEpoch}';
  }

  String _toFirestoreDate(String? date) {
    if (date == null || date.isEmpty) {
      final now = DateTime.now();
      return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    }

    return date.replaceAll('/', '-');
  }

  String _toUiDate(dynamic date) {
    if (date == null) return '2026/01/01';

    final text = date.toString();

    if (text.contains('-')) {
      return text.replaceAll('-', '/');
    }

    return text;
  }

  List<Map<String, dynamic>> _parseSpots(dynamic rawSpots) {
    if (rawSpots == null || rawSpots is! List) return [];

    return rawSpots.map<Map<String, dynamic>>((item) {
      return Map<String, dynamic>.from(item as Map);
    }).toList();
  }

  Map<String, dynamic> _itineraryDocToLocal(
    String docId,
    Map<String, dynamic> data,
  ) {
    return {
      'Itinerary_Id': data['Itinerary_Id'] ?? docId,
      'id': data['Itinerary_Id'] ?? docId,
      'title': data['Title'] ?? data['title'] ?? '未命名行程',
      'date': _toUiDate(data['Start_Date'] ?? data['date']),
      'endDate': _toUiDate(data['End_Date'] ?? data['endDate']),
      'spots': _parseSpots(data['Spots'] ?? data['spots']),
      'icon': data['Icon'] ?? data['icon'],
    };
  }

  Map<String, dynamic> _localItineraryToDoc(Map<String, dynamic> itinerary) {
    final itineraryId =
        itinerary['Itinerary_Id'] ?? itinerary['id'] ?? _createItineraryId();

    final startDate = _toFirestoreDate(itinerary['date']?.toString());
    final endDate = _toFirestoreDate(
      itinerary['endDate']?.toString() ?? itinerary['date']?.toString(),
    );

    return {
      'Itinerary_Id': itineraryId,
      'User_Id': _uid,
      'Title': itinerary['title'] ?? '未命名行程',
      'Start_Date': startDate,
      'End_Date': endDate,
      'Status': itinerary['Status'] ?? 'planning',
      'Spots': itinerary['spots'] ?? [],
      'Icon': itinerary['icon'],
      'Updated_At': FieldValue.serverTimestamp(),
    };
  }

  DateTime _getItinerarySortTime(Map<String, dynamic> data) {
    final value = data['Created_At'] ?? data['Updated_At'];

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<void> _loadItinerariesFromCollection() async {
    if (_uid == null) return;

    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('Itineraries')
              .where('User_Id', isEqualTo: _uid)
              .get();

      final docs =
          snapshot.docs.where((doc) {
            final data = doc.data();
            return data['Status'] != 'deleted';
          }).toList();

      // 新建立的排最上面
      docs.sort((a, b) {
        final aTime = _getItinerarySortTime(a.data());
        final bTime = _getItinerarySortTime(b.data());
        return bTime.compareTo(aTime);
      });

      final loaded =
          docs.map((doc) => _itineraryDocToLocal(doc.id, doc.data())).toList();

      _itineraries = loaded;
    } catch (e) {
      debugPrint('讀取 Itineraries collection 失敗: $e');
    }
  }

  Future<void> addItinerary(Map<String, dynamic> newItinerary) async {
    if (_uid == null) return;

    final itineraryId =
        newItinerary['Itinerary_Id'] ??
        newItinerary['id'] ??
        _createItineraryId();

    newItinerary['Itinerary_Id'] = itineraryId;
    newItinerary['id'] = itineraryId;

    // 新增的行程放最上面
    _itineraries.insert(0, newItinerary);
    notifyListeners();

    try {
      final data = _localItineraryToDoc(newItinerary);

      await FirebaseFirestore.instance
          .collection('Itineraries')
          .doc(itineraryId)
          .set({
            ...data,
            'Created_At': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('新增行程到 Itineraries 失敗: $e');
    }
  }

  Future<void> updateItinerarySpots(int index, List<dynamic> newSpots) async {
    if (_uid == null) return;

    _itineraries[index]['spots'] = newSpots;
    notifyListeners();

    final itineraryId =
        _itineraries[index]['Itinerary_Id'] ?? _itineraries[index]['id'];

    if (itineraryId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('Itineraries')
          .doc(itineraryId)
          .set(
            _localItineraryToDoc(_itineraries[index]),
            SetOptions(merge: true),
          );
    } catch (e) {
      debugPrint('更新行程失敗: $e');
    }
  }

  Future<void> deleteItinerary(int index) async {
    if (_uid == null) return;

    final deletedIti = _itineraries[index];
    final itineraryId = deletedIti['Itinerary_Id'] ?? deletedIti['id'];

    _itineraries.removeAt(index);
    notifyListeners();

    if (itineraryId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('Itineraries')
          .doc(itineraryId)
          .update({
            'Status': 'deleted',
            'Expire_At': Timestamp.fromDate(
              DateTime.now().add(const Duration(days: 5)),
            ),
            'Updated_At': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint('移至垃圾桶失敗: $e');
    }
  }

  Future<void> restoreItinerary(
    String docId,
    Map<String, dynamic> restoredData,
  ) async {
    if (_uid == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('Itineraries')
          .doc(docId)
          .update({
            'Status': 'planning',
            'Expire_At': FieldValue.delete(),
            'Updated_At': FieldValue.serverTimestamp(),
          });

      final restoredLocal = _itineraryDocToLocal(docId, restoredData);

      final exists = _itineraries.any((iti) {
        return iti['Itinerary_Id'] == docId || iti['id'] == docId;
      });

      if (!exists) {
        _itineraries.insert(0, restoredLocal);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('還原行程失敗: $e');
    }
  }

  Future<void> removeSpotFromItinerary(int itiIndex, int spotIndex) async {
    final currentSpots = List<dynamic>.from(_itineraries[itiIndex]['spots']);
    currentSpots.removeAt(spotIndex);

    await updateItinerarySpots(itiIndex, currentSpots);
  }

  Future<void> reorderItinerarySpots(
    int itiIndex,
    int oldIndex,
    int newIndex,
  ) async {
    if (newIndex > oldIndex) newIndex -= 1;

    final currentSpots = List<dynamic>.from(_itineraries[itiIndex]['spots']);
    final item = currentSpots.removeAt(oldIndex);
    currentSpots.insert(newIndex, item);

    await updateItinerarySpots(itiIndex, currentSpots);
  }

  bool isFavorite(String spotName) {
    return _favoriteSpotsList.any(
      (spot) => spot['NameZh'] == spotName || spot['name'] == spotName,
    );
  }

  void toggleFavorite(Map<String, dynamic> spotData) {
    final spotName = spotData['NameZh'] ?? spotData['name'] ?? '未知景點';
    if (isFavorite(spotName)) {
      _favoriteSpotsList.removeWhere(
        (spot) => spot['NameZh'] == spotName || spot['name'] == spotName,
      );
    } else {
      _favoriteSpotsList.add({
        "NameZh": spotName,
        "name": spotName,
        "Address": spotData['Address'] ?? "嘉義市",
        "category": "自然風景",
        "rating": "4.5",
        "reviews": "99+",
        "PicUrl1": spotData['PicUrl1'] ?? "",
        "originalData": spotData,
      });
    }
    _syncToFirestore();
    notifyListeners();
  }

  bool isEventSaved(String eventTitle) {
    return _savedEvents.any((e) => e['Title'] == eventTitle);
  }

  void toggleSavedEvent(Map<String, dynamic> eventData) {
    final title = eventData['Title'] ?? '未知活動';
    if (isEventSaved(title)) {
      _savedEvents.removeWhere((e) => e['Title'] == title);
    } else {
      _savedEvents.add(eventData);
    }
    _syncToFirestore();
    notifyListeners();
  }

  Future<void> checkUnreadNotifications() async {
    if (_uid == null) return;

    try {
      final userDoc =
          await FirebaseFirestore.instance.collection('Users').doc(_uid).get();

      final userData = userDoc.data() ?? {};

      final Timestamp? lastReadGlobal =
          userData['Last_Read_Global_Notification_At'] as Timestamp?;

      Query globalQuery = FirebaseFirestore.instance
          .collection('Notifications')
          .where('User_Id', isEqualTo: 'global');

      if (lastReadGlobal != null) {
        globalQuery = globalQuery.where(
          'Created_At',
          isGreaterThan: lastReadGlobal,
        );
      }

      final globalSnap = await globalQuery.limit(1).get();

      final personalSnap =
          await FirebaseFirestore.instance
              .collection('Notifications')
              .where('User_Id', isEqualTo: _uid)
              .where('Is_Read', isEqualTo: false)
              .limit(1)
              .get();

      _hasUnreadNotification =
          globalSnap.docs.isNotEmpty || personalSnap.docs.isNotEmpty;

      notifyListeners();
    } catch (e) {
      debugPrint('檢查通知紅點失敗: $e');
    }
  }

  Future<void> markNotificationsAsRead() async {
    if (_uid == null) return;

    try {
      await FirebaseFirestore.instance.collection('Users').doc(_uid).set({
        'Last_Read_Global_Notification_At': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final personalSnap =
          await FirebaseFirestore.instance
              .collection('Notifications')
              .where('User_Id', isEqualTo: _uid)
              .where('Is_Read', isEqualTo: false)
              .get();

      final batch = FirebaseFirestore.instance.batch();

      for (final doc in personalSnap.docs) {
        batch.update(doc.reference, {
          'Is_Read': true,
          'Read_At': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      _hasUnreadNotification = false;
      notifyListeners();
    } catch (e) {
      debugPrint('標記通知已讀失敗: $e');
    }
  }

  Map<String, dynamic>? _currentSpotData;

  Map<String, dynamic>? get currentSpotData => _currentSpotData;

  void setCurrentSpotData(Map<String, dynamic> spotData) {
    _currentSpotData = spotData;
    notifyListeners();
  }

  Map<String, dynamic>? _currentEventData;

  Map<String, dynamic>? get currentEventData => _currentEventData;

  void setCurrentEventData(Map<String, dynamic> eventData) {
    _currentEventData = eventData;
    notifyListeners();
  }

  // --- 替換原本的 AI 聊天紀錄狀態 ---

  // 1. 景點問答專用的紀錄
  final List<Map<String, dynamic>> _qaChatMessages = [
    {'isUser': false, 'text': '哈囉！我是嘉遊站知識助理。想知道嘉義哪裡有好吃的火雞肉飯，或是什麼景點的歷史嗎？儘管問我！'},
  ];

  // 2. 行程規劃專用的紀錄
  final List<Map<String, dynamic>> _planChatMessages = [
    {
      'isUser': false,
      'text': '嗨！我是您的 AI 排程助理。請告訴我您的旅遊天數與偏好，例如：「幫我規劃嘉義兩天一夜親子遊」。',
    },
  ];

  // 開放給外部讀取的 getter
  List<Map<String, dynamic>> get qaChatMessages => _qaChatMessages;

  List<Map<String, dynamic>> get planChatMessages => _planChatMessages;

  // 新增問答訊息
  void addQaChatMessage(Map<String, dynamic> message) {
    _qaChatMessages.add(message);
    notifyListeners();
  }

  // 新增行程訊息
  void addPlanChatMessage(Map<String, dynamic> message) {
    _planChatMessages.add(message);
    notifyListeners();
  }

  // ==========================================
  // ⛅ 天氣資訊狀態管理 (即時觀測)
  // ==========================================
  String _weatherWx = '載入中...';
  String _weatherTemp = '--';
  String _weatherHumidity = '--';
  String _weatherCondition = 'sunny';

  String get weatherWx => _weatherWx;
  String get weatherTemp => _weatherTemp;
  String get weatherHumidity => _weatherHumidity;
  String get weatherCondition => _weatherCondition;

  String getWeatherImage(String condition) {
    switch (condition) {
      case 'sunny':
        return 'assets/images/weather_sunny.png';
      case 'rainy':
        return 'assets/images/weather_rainy.png';
      case 'cloudy':
        return 'assets/images/weather_cloudy.png';
      default:
        return 'assets/images/weather_default.png';
    }
  }

  String _weatherTextFromCode(int code) {
    if (code == 0) return '晴朗';
    if (code <= 3) return '多雲';
    if (code == 45 || code == 48) return '有霧';
    if (code >= 51 && code <= 57) return '毛毛雨';
    if (code >= 61 && code <= 67) return '下雨';
    if (code >= 71 && code <= 77) return '降雪';
    if (code >= 80 && code <= 82) return '陣雨';
    if (code >= 85 && code <= 86) return '陣雪';
    if (code >= 95) return '雷雨';
    return '天氣變化中';
  }

  void _updateWeatherConditionFromCode(int code) {
    if ((code >= 51 && code <= 67) ||
        (code >= 80 && code <= 82) ||
        code >= 95) {
      _weatherCondition = 'rainy';
    } else if (code >= 1 && code <= 48) {
      _weatherCondition = 'cloudy';
    } else {
      _weatherCondition = 'sunny';
    }
  }

  // Open-Meteo 免金鑰即時天氣 API，座標固定為嘉義市中心。
  Future<void> fetchChiayiWeather() async {
    try {
      final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': '23.48',
        'longitude': '120.45',
        'current': 'temperature_2m,relative_humidity_2m,weather_code,is_day',
        'timezone': 'Asia/Taipei',
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw Exception('Weather API returned ${response.statusCode}');
      }

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final current = data['current'];
      if (current is! Map<String, dynamic>) {
        throw const FormatException('Missing current weather data');
      }

      final temperature = current['temperature_2m'];
      final humidity = current['relative_humidity_2m'];
      final weatherCode = current['weather_code'];
      if (temperature is! num || humidity is! num || weatherCode is! num) {
        throw const FormatException('Invalid current weather data');
      }

      _weatherTemp = '${temperature.round()}°C';
      _weatherHumidity = '${humidity.round()}%';
      _weatherWx = _weatherTextFromCode(weatherCode.toInt());
      _updateWeatherConditionFromCode(weatherCode.toInt());
      notifyListeners();
      debugPrint('✅ 嘉義即時天氣更新：$_weatherWx, $_weatherTemp, 濕度 $_weatherHumidity');
    } catch (e) {
      _weatherWx = '天氣資料暫時無法載入';
      _weatherTemp = '--';
      notifyListeners();
      debugPrint('❌ 天氣資料載入失敗: $e');
    }
  }
}
