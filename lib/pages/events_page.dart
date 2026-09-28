// lib/pages/events_page.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../widgets/app_drawer.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/app_state.dart';

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  _EventsPageState createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  bool _isSubscribed = true;
  DateTime _selectedDate = DateTime.now();

  final Map<String, List<String>> _itemTags = {};
  List<String> _globalCategoryTags = ['音樂節', '展覽', '免費活動'];
  List<Map<String, dynamic>> _allEvents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTags();
    _fetchEvents();
  }

  Future<void> _fetchEvents() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('events').get();
      if (mounted) {
        setState(() {
          _allEvents = snap.docs.map((doc) => {"docId": doc.id, ...doc.data()}).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTags() async {
    final prefs = await SharedPreferences.getInstance();
    final savedGlobalTags = prefs.getStringList('global_tags_活動');
    if (savedGlobalTags != null) _globalCategoryTags = savedGlobalTags;
    final keys = prefs.getKeys();
    for (String key in keys) {
      if (key.startsWith('tags_event_')) {
        String title = key.replaceFirst('tags_event_', '');
        _itemTags[title] = prefs.getStringList(key) ?? [];
      }
    }
    setState(() {});
  }

  Future<void> _deleteGlobalTag(String tag) async {
    final appState = Provider.of<AppStateManager>(context, listen: false);
    bool? confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(appState.t('警告：刪除全域標籤'), style: const TextStyle(color: Colors.red)),
          content: Text('${appState.t('確定要刪除')}「$tag」${appState.t('嗎？')}'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(appState.t('取消'))),
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(ctx, true), child: Text(appState.t('確定刪除'), style: const TextStyle(color: Colors.white)))
          ],
        )
    );
    if (confirm == true) {
      setState(() {
        _globalCategoryTags.remove(tag);
        for (var key in _itemTags.keys) { _itemTags[key]?.remove(tag); }
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('global_tags_活動', _globalCategoryTags);
      if (mounted) context.read<AppStateManager>().syncTagsToCloud();
      for (var key in _itemTags.keys) { await prefs.setStringList('tags_event_$key', _itemTags[key]!); }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${appState.t('已刪除標籤：')}$tag')));
    }
  }

  Future<void> _deleteItemTag(String title, String tag) async {
    final appState = Provider.of<AppStateManager>(context, listen: false);
    bool? confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(appState.t('移除標籤')),
          content: Text('${appState.t('確定要從移除')}「$tag」${appState.t('標籤嗎？')}'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(appState.t('取消'))),
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(ctx, true), child: Text(appState.t('移除'), style: const TextStyle(color: Colors.white)))
          ],
        )
    );
    if (confirm == true) {
      setState(() { _itemTags[title]?.remove(tag); });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('tags_event_$title', _itemTags[title]!);
      if (mounted) context.read<AppStateManager>().syncTagsToCloud();
    }
  }

  Future<void> _showTagDialog(String title) async {
    final TextEditingController tagController = TextEditingController();
    final appState = Provider.of<AppStateManager>(context, listen: false);
    final palette = appState.activePalette;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
            builder: (context, setModalState) {
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                title: Text(appState.currentLang == 'en' ? 'Add Custom Tag' : appState.t('新增自訂標籤'), style: const TextStyle(fontWeight: FontWeight.bold)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(controller: tagController, decoration: InputDecoration(hintText: appState.currentLang == 'en' ? 'Enter new tag...' : appState.t('輸入新標籤...'), prefixIcon: Icon(Icons.local_offer, color: palette[4]), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                    const SizedBox(height: 16),
                    Text(appState.currentLang == 'en' ? 'Choose from existing tags:' : appState.t('從現有標籤庫選擇：'), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _globalCategoryTags.map((tag) => GestureDetector(
                        onLongPress: () async { await _deleteGlobalTag(tag); setModalState((){}); },
                        child: ActionChip(backgroundColor: palette[1].withOpacity(0.1), side: BorderSide.none, label: Text(appState.t(tag), style: TextStyle(color: palette[1], fontSize: 12, fontWeight: FontWeight.bold)), onPressed: () => tagController.text = tag),
                      )).toList(),
                    )
                  ],
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: Text(appState.t('取消'), style: const TextStyle(color: Colors.grey))),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: palette[3], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: () async {
                      final newTag = tagController.text.trim();
                      if (newTag.isNotEmpty) {
                        setState(() {
                          _itemTags[title] ??= [];
                          if (!_itemTags[title]!.contains(newTag)) _itemTags[title]!.add(newTag);
                          if (!_globalCategoryTags.contains(newTag)) _globalCategoryTags.add(newTag);
                        });
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setStringList('global_tags_活動', _globalCategoryTags);
                        await prefs.setStringList('tags_event_$title', _itemTags[title]!);
                        if (mounted) context.read<AppStateManager>().syncTagsToCloud();
                        if (!mounted) return;
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${appState.currentLang == 'en' ? 'Tag added: ' : appState.t('已成功標記：')}$newTag')));
                      }
                    },
                    child: Text(appState.currentLang == 'en' ? 'Confirm' : appState.t('確定標記')),
                  )
                ],
              );
            }
        );
      },
    );
  }

  // 🌟 日期判斷維持使用中文的 DetailedTime 欄位，確保解析不會出錯
  bool _isEventOnSelectedDate(Map<String, dynamic> event) {
    String timeStr = event['DetailedTime'] ?? '';
    RegExp exp = RegExp(r'(\d{2,3})/(\d{1,2})/(\d{1,2})');
    var matches = exp.allMatches(timeStr).toList();
    if (matches.isEmpty) return false;

    try {
      DateTime? start, end;
      for (int i=0; i<matches.length; i++) {
        int y = int.parse(matches[i].group(1)!);
        if (y < 200) y += 1911;
        int m = int.parse(matches[i].group(2)!);
        int d = int.parse(matches[i].group(3)!);
        DateTime dt = DateTime(y, m, d);
        if (i == 0) start = dt;
        if (i == 1) end = dt;
      }
      end ??= start;

      DateTime target = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      if (start != null && end != null) {
        return target.isAfter(start.subtract(const Duration(days: 1))) && target.isBefore(end.add(const Duration(days: 1)));
      }
    } catch (e) { return false; }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateManager>();
    final palette = appState.activePalette;
    final themeColor = palette[0];

    final currentDaySavedEvents = appState.savedEvents.where((e) => _isEventOnSelectedDate(e)).toList();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(appState.t('活動行事曆'), style: TextStyle(fontWeight: FontWeight.bold, color: themeColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: themeColor),
      ),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))]),
              child: Theme(
                data: Theme.of(context).copyWith(colorScheme: ColorScheme.light(primary: palette[1])),
                child: CalendarDatePicker(
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                  onDateChanged: (date) {
                    setState(() => _selectedDate = date);
                  },
                ),
              ),
            ).animate().fadeIn().slideY(begin: 0.1, end: 0),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Align(alignment: Alignment.centerLeft, child: Text('📅 ${_selectedDate.month}/${_selectedDate.day} ${appState.currentLang == 'en' ? 'Saved Events' : appState.t(' 已加入的活動')}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: palette[1]))),
            ),
            currentDaySavedEvents.isEmpty
                ? Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Text(appState.currentLang == 'en' ? 'No events scheduled for this day!' : appState.t('這天還沒有安排活動喔！'), style: TextStyle(color: Colors.grey[500])))
                : ListView.builder(
                shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: currentDaySavedEvents.length,
                itemBuilder: (context, index) {
                  final event = currentDaySavedEvents[index];
                  // 🌟 行事曆內的動態雙語切換
                  final displayTitle = appState.currentLang == 'en' ? (event['TitleEn'] ?? event['Title']) : event['Title'];

                  return Card(
                    elevation: 0, margin: const EdgeInsets.only(bottom: 8), color: palette[1].withOpacity(0.1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      leading: Icon(Icons.check_circle, color: palette[1]),
                      title: Text(displayTitle ?? '', style: TextStyle(fontWeight: FontWeight.bold, color: palette[1])),
                      trailing: IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent), onPressed: () => appState.toggleSavedEvent(event)),
                      onTap: () { appState.setCurrentEventData(event); appState.setPageIndex(12); },
                    ),
                  );
                }
            ),
            const SizedBox(height: 16),

            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16), padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text(appState.currentLang == 'en' ? 'Subscribe to Event Push' : appState.t('訂閱近期活動推播'), style: const TextStyle(fontWeight: FontWeight.bold)),
                    secondary: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: palette[2].withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.notifications_active, color: palette[2])),
                    value: _isSubscribed, activeColor: palette[2], onChanged: (val) => setState(() => _isSubscribed = val),
                  ),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 16.0), child: Divider(height: 1)),
                  Padding(padding: const EdgeInsets.all(16.0), child: Row(children: [Icon(Icons.category_outlined, size: 18, color: palette[5]), const SizedBox(width: 8), Expanded(child: Text(appState.currentLang == 'en' ? 'Hot: Music Festivals / Fairs / Art Exhibitions' : appState.t('熱門：音樂節 / 廟會 / 藝術展覽'), style: const TextStyle(color: Colors.grey, fontSize: 13)))]))
                ],
              ),
            ).animate(delay: 200.ms).fadeIn(),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Align(alignment: Alignment.centerLeft, child: Text(appState.currentLang == 'en' ? '✨ Explore More Events' : appState.t('✨ 探索更多活動'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            ),

            _isLoading ? Center(child: CircularProgressIndicator(color: themeColor)) : ListView.builder(
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: _allEvents.length,
              itemBuilder: (context, index) {
                final event = _allEvents[index];

                // 🌟 核心：中文標題作為資料庫與標籤的「身份證(Key)」，絕對不能變
                final titleZh = event['Title'] ?? appState.t('未知活動');

                // 🌟 動態顯示切換
                final displayTitle = appState.currentLang == 'en' ? (event['TitleEn'] ?? titleZh) : titleZh;
                final displayTime = appState.currentLang == 'en' ? (event['DetailedTimeEn'] ?? event['DetailedTime'] ?? '') : (event['DetailedTime'] ?? '');

                // 圖片安全抓取
                String imageUrl = event['ImageUrl']?.toString() ?? '';
                if (imageUrl.isEmpty && event['Picture'] is Map) {
                  imageUrl = event['Picture']['PictureUrl1'] ?? '';
                }

                // 讀取自訂標籤 (用中文身份證去抓)
                final currentTags = _itemTags[titleZh] ?? [];
                final Color accentColor = palette[(index % 4) + 3];

                return Container(
                  margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(color: accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: imageUrl.isNotEmpty
                            ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (c,e,s) => Icon(Icons.event, color: accentColor))
                            : Icon(Icons.event, color: accentColor),
                      ),
                    ),
                    title: Text(displayTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        Text('${appState.currentLang == 'en' ? 'Time: ' : appState.t('時間：')}$displayTime', style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (currentTags.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6, runSpacing: 6,
                            children: currentTags.map((t) => GestureDetector(
                              onLongPress: () => _deleteItemTag(titleZh, t), // 刪除標籤依然使用中文 Key
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: accentColor.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                                child: Text(t, style: TextStyle(fontSize: 11, color: accentColor, fontWeight: FontWeight.bold)),
                              ),
                            )).toList(),
                          )
                        ]
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(icon: Icon(Icons.local_offer_outlined, color: palette[4], size: 22), onPressed: () => _showTagDialog(titleZh)), // 新增標籤依然使用中文 Key
                      ],
                    ),
                    onTap: () {
                      appState.setCurrentEventData(event);
                      appState.setPageIndex(12);
                    },
                  ),
                ).animate().slideX(begin: 0.1, end: 0, delay: (index * 100).ms, curve: Curves.easeOut);
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}