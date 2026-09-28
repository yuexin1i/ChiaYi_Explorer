// lib/pages/ai_chat_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../widgets/app_drawer.dart';
import '../providers/app_state.dart';

class AiChatPage extends StatefulWidget {
  const AiChatPage({super.key});

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  bool _isMenuExpanded = true;
  String _currentMode = '行程規劃';
  final TextEditingController _controller = TextEditingController();

  bool _isLoading = false;
  late final GenerativeModel _model;
  late ChatSession _chatSession;

  @override
  void initState() {
    super.initState();
    _initGemini();
  }

  void _initGemini() {
    final String apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

    // ... (保留上面的 apiKey 檢查)

    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
      systemInstruction: Content.system('''
你是專業的台灣嘉義市旅遊助理。請遵守以下最高原則：

1. 【語言對應】：使用者用繁體中文問，用繁體中文回答；英文問，用英文回。
2. 【知識來源】：請優先依據我提供的 Firebase 檢索內容回答。若不足再用你的知識補充，但絕不能捏造假地址或電話。
3. 【模式應對】：若使用者單純問景點知識，請詳細生動地介紹；若要求規劃行程，請依序寫出文字版推薦。
4. 【行程格式】：當規劃「超過一天」的行程時，請在文字介紹中明確標示「第1天」、「第2天」。
5. 【嚴格 JSON】：只要是行程規劃，必須在文字最尾端附加 JSON。JSON 內必須新增 `day` 欄位來區分天數！
格式範例如下：
###JSON_START###
[
  {"day": "第1天", "name": "嘉義火車站", "time": "09:00", "note": "集合出發"},
  {"day": "第1天", "name": "嘉義市立美術館", "time": "10:00", "note": "欣賞當代藝術"},
  {"day": "第2天", "name": "阿里山森林遊樂區", "time": "09:00", "note": "享受芬多精"}
]
###JSON_END###
'''),
    );
    _chatSession = _model.startChat();
  }

  bool _isEnglish(String text) {
    final englishLetters = RegExp(r'[A-Za-z]');
    final chineseChars = RegExp(r'[\u4e00-\u9fff]');
    return englishLetters.hasMatch(text) && !chineseChars.hasMatch(text);
  }

  List<String> _extractKeywords(String text) {
    final cleaned = text
        .replaceAll(RegExp(r'[，。！？、,.!?]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final words = cleaned.split(' ');
    return words.where((word) => word.trim().length >= 2).take(4).toList();
  }

  Future<String> _searchFirebaseData(String userText) async {
    final keywords = _extractKeywords(userText);
    final List<String> collections = ['attractions', 'foods'];
    final List<String> results = [];

    for (final collectionName in collections) {
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection(collectionName)
            .limit(30)
            .get();

        for (final doc in snapshot.docs) {
          final data = doc.data();
          final allText = data.toString();

          bool matched = keywords.isEmpty || keywords.any((k) => allText.contains(k));
          if (!matched) continue;

          results.add('''
名稱：${data['NameZh'] ?? data['name'] ?? ''}
分類：${data['Category'] ?? data['category'] ?? ''}
地址：${data['Address'] ?? data['address'] ?? ''}
介紹：${data['Description'] ?? data['description'] ?? ''}
''');
        }
      } catch (e) {
        debugPrint('Firestore 查詢失敗：$e');
      }
    }
    return results.isEmpty ? '目前資料庫無直接相關資料。' : results.take(8).join('\n---\n');
  }

  Future<void> _saveChatToFirebase({
    required bool isUser,
    required String text,
    List<Map<String, dynamic>>? itinerary,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('ai_chats')
          .add({
        'isUser': isUser,
        'text': text,
        'itinerary': itinerary,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('儲存聊天紀錄失敗: $e');
    }
  }

  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;
    final userText = _controller.text.trim();
    final isEnglish = _isEnglish(userText);

    final appState = Provider.of<AppStateManager>(context, listen: false);

    // 🌟 根據目前的模式，把訊息存進不同的口袋
    final userMsg = {'isUser': true, 'text': userText};
    if (_currentMode == '景點問答') {
      appState.addQaChatMessage(userMsg);
    } else {
      appState.addPlanChatMessage(userMsg);
    }

    setState(() => _isLoading = true);
    _controller.clear();

    await _saveChatToFirebase(isUser: true, text: userText);

    try {
      final firebaseContext = await _searchFirebaseData(userText);

      // 讓 AI 知道現在在哪個分頁
      final compoundPrompt = '''
【系統隱藏資訊】
目前模式：$_currentMode
使用者語言：${isEnglish ? 'English' : 'Traditional Chinese'}
Firebase 資料：
$firebaseContext

【強制執行命令】
如果目前模式是「行程規劃」，即使使用者沒提，你也必須在結尾附上包含 day 欄位的 JSON。
請回答使用者的問題：
$userText
''';

      final response = await _chatSession.sendMessage(Content.text(compoundPrompt));
      if (!mounted) return;

      String replyText = response.text ?? '抱歉，我目前無法回應。';
      List<Map<String, dynamic>>? extractedItinerary;

      // 解析 JSON
      if (replyText.contains('###JSON_START###') && replyText.contains('###JSON_END###')) {
        try {
          final start = replyText.indexOf('###JSON_START###') + '###JSON_START###'.length;
          final end = replyText.indexOf('###JSON_END###');
          final jsonStr = replyText.substring(start, end).trim();

          replyText = replyText.substring(0, replyText.indexOf('###JSON_START###')).trim();

          final dynamic decoded = jsonDecode(jsonStr);
          List<dynamic> rawList = [];

          if (decoded is List) rawList = decoded;
          else if (decoded is Map) {
            if (decoded.containsKey('itinerary') && decoded['itinerary'] is List) rawList = decoded['itinerary'];
            else if (decoded.values.isNotEmpty && decoded.values.first is List) rawList = decoded.values.first;
          }

          if (rawList.isNotEmpty) {
            extractedItinerary = rawList.map<Map<String, dynamic>>((e) {
              return {
                'id': '${DateTime.now().millisecondsSinceEpoch}_${e['name']}',
                'day': e['day']?.toString() ?? '第1天', // 🌟 新增抓取天數，AI 沒給就預設第 1 天
                'name': e['name']?.toString() ?? '',
                'time': e['time']?.toString() ?? '',
                'note': e['note']?.toString() ?? '',
              };
            }).toList();
          }
        } catch (e) {
          debugPrint('JSON 解析錯誤: $e');
        }
      }

      final aiMsg = {
        'isUser': false,
        'text': replyText,
        'itinerary': extractedItinerary
      };

      // 🌟 AI 回答也要放進對應的口袋
      if (_currentMode == '景點問答') {
        appState.addQaChatMessage(aiMsg);
      } else {
        appState.addPlanChatMessage(aiMsg);
      }

      await _saveChatToFirebase(isUser: false, text: replyText, itinerary: extractedItinerary);

    } catch (e) {
      // ... (錯誤捕捉保留你原本的邏輯，記得也是要分開存)
      if (!mounted) return;
      final friendlyError = '發生錯誤，請稍後再試。 ($e)';
      if (_currentMode == '景點問答') {
        appState.addQaChatMessage({'isUser': false, 'text': friendlyError});
      } else {
        appState.addPlanChatMessage({'isUser': false, 'text': friendlyError});
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

// 🌟 修改：多接收一個 msg 參數來更新狀態
  void _addItineraryToManager(List<Map<String, dynamic>> newSpots, Map<String, dynamic> msg) {
    final appState = Provider.of<AppStateManager>(context, listen: false);

    // 取得今天的日期作為預設值
    final today = DateTime.now();
    final dateString = '${today.year}/${today.month.toString().padLeft(2, '0')}/${today.day.toString().padLeft(2, '0')}';

    appState.addItinerary({
      "title": "Gemini AI 專屬推薦行程",
      "date": dateString,
      "spots": newSpots,
    });

    // 🌟 將這則對話標記為「已加入」
    setState(() {
      msg['isAdded'] = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(appState.t('✨ 行程已成功加入！'))),
    );

    // 跳轉至行程管理頁面
    appState.setPageIndex(8);
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateManager>(context);
    final palette = appState.activePalette;
    final themeColor = palette[0];

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          appState.t('嘉遊站助理'),
          style: TextStyle(fontWeight: FontWeight.bold, color: themeColor),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: themeColor),
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _isMenuExpanded ? 60 : 0,
            margin: _isMenuExpanded
                ? const EdgeInsets.symmetric(horizontal: 16)
                : EdgeInsets.zero,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: _isMenuExpanded
                  ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
                  : [],
            ),
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: ChoiceChip(
                      label: Text(
                        appState.t('景點問答'),
                        style: TextStyle(
                          fontWeight: _currentMode == '景點問答'
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      selected: _currentMode == '景點問答',
                      selectedColor: palette[2].withOpacity(0.2),
                      checkmarkColor: palette[2],
                      side: BorderSide.none,
                      onSelected: (val) {
                        setState(() => _currentMode = '景點問答');
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: ChoiceChip(
                      label: Text(
                        appState.t('行程規劃'),
                        style: TextStyle(
                          fontWeight: _currentMode == '行程規劃'
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      selected: _currentMode == '行程規劃',
                      selectedColor: palette[4].withOpacity(0.2),
                      checkmarkColor: palette[4],
                      side: BorderSide.none,
                      onSelected: (val) {
                        setState(() => _currentMode = '行程規劃');
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: IconButton(
              icon: Icon(
                _isMenuExpanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                color: Colors.grey,
              ),
              onPressed: () {
                setState(() => _isMenuExpanded = !_isMenuExpanded);
              },
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              physics: const BouncingScrollPhysics(),

              // 🌟 核心：判斷現在要顯示哪一包資料
              itemCount: _currentMode == '景點問答'
                  ? appState.qaChatMessages.length
                  : appState.planChatMessages.length,

              itemBuilder: (context, index) {
                // 🌟 讀取對應的對話陣列
                final activeChatList = _currentMode == '景點問答'
                    ? appState.qaChatMessages
                    : appState.planChatMessages;

                final msg = activeChatList[index];

                final isUser = msg['isUser'];
                final List<Map<String, dynamic>>? aiItinerary = msg['itinerary'];


                String displayMsg = msg['text'];
                if (displayMsg.startsWith('發生錯誤，請確認網路連線')) {
                  displayMsg = displayMsg.replaceFirst(
                      '發生錯誤，請確認網路連線或 API 金鑰是否正確。',
                      appState.t('發生錯誤，請確認網路連線或 API 金鑰是否正確。'));
                } else if (displayMsg == '抱歉，我目前無法回應。') {
                  displayMsg = appState.t(displayMsg);
                } else if (!isUser && index == 0) {
                  displayMsg = appState.t(displayMsg);
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  alignment:
                  isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: isUser
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.8,
                        ),
                        decoration: BoxDecoration(
                          color: isUser
                              ? palette[1].withOpacity(0.15)
                              : Colors.white,
                          boxShadow: isUser
                              ? []
                              : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                          borderRadius: BorderRadius.circular(20).copyWith(
                            bottomRight: isUser
                                ? const Radius.circular(4)
                                : const Radius.circular(20),
                            bottomLeft: isUser
                                ? const Radius.circular(20)
                                : const Radius.circular(4),
                          ),
                        ),
                        child: // 把原本的 Text 替換成這個：
                        MarkdownBody(
                          data: displayMsg,
                          styleSheet: MarkdownStyleSheet(
                            p: TextStyle(
                              fontSize: 15,
                              height: 1.5,
                              color: isUser ? palette[1].withOpacity(0.9) : Colors.black87,
                            ),
                            h3: TextStyle( // 針對 ### 標題做設定
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isUser ? palette[1] : themeColor,
                            ),
                            strong: const TextStyle(fontWeight: FontWeight.bold), // 針對 **粗體** 做設定
                          ),
                        ),
                      ).animate().scale(
                        delay: 50.ms,
                        duration: 300.ms,
                        curve: Curves.easeOutBack,
                        alignment: isUser
                            ? Alignment.bottomRight
                            : Alignment.bottomLeft,
                      ),
                      if (aiItinerary != null) ...[
                        const SizedBox(height: 12),
                        // 🌟 判斷這則訊息的行程是否已經被加入過
                        if (msg['isAdded'] == true)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[600], // 變成綠色代表已完成
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            icon: const Icon(Icons.check_circle),
                            label: Text(
                              appState.t('已加入，前往行程管理查看'),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            onPressed: () {
                              // 點擊後直接跳轉到行程管理頁面
                              Provider.of<AppStateManager>(context, listen: false).setPageIndex(8);
                            },
                          )
                        else
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: palette[5],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            icon: const Icon(Icons.playlist_add),
                            label: Text(
                              appState.t('將此行程加入我的行程表'),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            // 🌟 記得把 msg 傳進去
                            onPressed: () => _addItineraryToManager(aiItinerary, msg),
                          ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0)
                      ]
                    ],
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircularProgressIndicator(color: palette[3]),
            ),
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                )
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: appState.t('告訴我你想去哪裡玩...'),
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: palette[3],
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: palette[3].withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}