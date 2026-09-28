// lib/pages/itinerary_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/app_state.dart';
import '../widgets/app_drawer.dart';

class ItineraryPage extends StatefulWidget {
  const ItineraryPage({super.key});

  @override
  _ItineraryPageState createState() => _ItineraryPageState();
}

class _ItineraryPageState extends State<ItineraryPage> {
  final List<IconData> _itineraryIcons = [
    Icons.card_travel, Icons.flight, Icons.directions_car, Icons.beach_access,
    Icons.camera_alt, Icons.restaurant, Icons.hotel, Icons.map,
    Icons.shopping_bag, Icons.nature, Icons.festival, Icons.train
  ];
  String _displayItineraryTitle(AppStateManager appState, dynamic rawTitle) {
    final title = rawTitle?.toString() ?? '';

    if (title.isEmpty) {
      return appState.currentLang == 'en'
          ? 'Untitled itinerary'
          : '未命名行程';
    }

    // 只處理系統自動產生的固定標題
    if (title == 'Gemini AI 專屬推薦行程') {
      return appState.currentLang == 'en'
          ? 'Gemini AI Custom Itinerary'
          : 'Gemini AI 專屬推薦行程';
    }

    // 使用者自己輸入的行程名稱不要翻譯
    return title;
  }
  bool _isEnglish(AppStateManager appState) {
    return appState.currentLang == 'en';
  }

  String _displayDay(AppStateManager appState, dynamic rawDay) {
    final dayText = rawDay?.toString() ?? '';

    if (dayText.isEmpty) return '';

    if (!_isEnglish(appState)) {
      return dayText;
    }

    final match = RegExp(r'\d+').firstMatch(dayText);
    if (match != null) {
      return 'Day ${match.group(0)}';
    }

    return dayText;
  }

  String _trashDaysLeftText(AppStateManager appState, int daysLeft) {
    if (_isEnglish(appState)) {
      return '$daysLeft day${daysLeft == 1 ? '' : 's'} left before permanent deletion';
    }

    return '剩下 $daysLeft 天後永久刪除';
  }

  String _unnamedItineraryText(AppStateManager appState) {
    return _isEnglish(appState) ? 'Untitled itinerary' : '未命名行程';
  }

  void _showAddItineraryDialog() {
    final TextEditingController titleController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    int selectedIconIndex = 0;

    final appState = Provider.of<AppStateManager>(context, listen: false);
    final palette = appState.activePalette;

    showDialog(
        context: context,
        builder: (dialogCtx) {
          return StatefulBuilder(
            builder: (modalCtx, setStateModal) {
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                title: Text(appState.t('新增專屬行程'), style: const TextStyle(fontWeight: FontWeight.bold)),
                content: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                          labelText: appState.t('行程名稱 (例如：嘉義放鬆之旅)'),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: Icon(Icons.edit, color: palette[0]),
                        ),
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: () async {
                          DateTime? picked = await showDatePicker(
                            context: context, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2030),
                            builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: ColorScheme.light(primary: palette[0])), child: child!),
                          );
                          if (picked != null) setStateModal(() => selectedDate = picked);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(border: Border.all(color: Colors.grey[400]!), borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, color: palette[0]),
                              const SizedBox(width: 12),
                              Text('${selectedDate.year}/${selectedDate.month.toString().padLeft(2,'0')}/${selectedDate.day.toString().padLeft(2,'0')}', style: const TextStyle(fontSize: 16)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Align(alignment: Alignment.centerLeft, child: Text(appState.t('選擇代表圖示：'), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12, runSpacing: 12, alignment: WrapAlignment.center,
                        children: List.generate(_itineraryIcons.length, (idx) {
                          bool isSelected = selectedIconIndex == idx;
                          return InkWell(
                            borderRadius: BorderRadius.circular(50),
                            onTap: () => setStateModal(() => selectedIconIndex = idx),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200), padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: isSelected ? palette[0].withOpacity(0.15) : Colors.transparent, shape: BoxShape.circle, border: Border.all(color: isSelected ? palette[0] : Colors.grey[300]!, width: isSelected ? 2 : 1)),
                              child: Icon(_itineraryIcons[idx], color: isSelected ? palette[0] : Colors.grey[500], size: 26),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(dialogCtx), child: Text(appState.t('取消'), style: const TextStyle(color: Colors.grey))),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: palette[0], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: () {
                      if (titleController.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(appState.t('請輸入行程名稱！')))); return; }
                      Provider.of<AppStateManager>(context, listen: false).addItinerary({
                        "title": titleController.text.trim(),
                        "date": '${selectedDate.year}/${selectedDate.month.toString().padLeft(2,'0')}/${selectedDate.day.toString().padLeft(2,'0')}',
                        "icon": _itineraryIcons[selectedIconIndex].codePoint,
                        "spots": []
                      });
                      Navigator.pop(dialogCtx);
                    },
                    child: Text(appState.t('加入')),
                  ),
                ],
              );
            },
          );
        }
    );
  }

  void _showEditItineraryDialog(int index, Map<String, dynamic> currentIti) {
    final TextEditingController titleController = TextEditingController(text: currentIti['title']);
    DateTime selectedDate;
    try {
      List<String> parts = currentIti['date'].toString().split('/');
      selectedDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    } catch(e) {
      selectedDate = DateTime.now();
    }
    int currentIconCode = currentIti['icon'] ?? Icons.beach_access.codePoint;
    int selectedIconIndex = _itineraryIcons.indexWhere((icon) => icon.codePoint == currentIconCode);
    if (selectedIconIndex == -1) selectedIconIndex = 0;

    final appState = Provider.of<AppStateManager>(context, listen: false);
    final palette = appState.activePalette;

    showDialog(
        context: context,
        builder: (dialogCtx) {
          return StatefulBuilder(
            builder: (modalCtx, setStateModal) {
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                title: Text(appState.t('編輯行程'), style: const TextStyle(fontWeight: FontWeight.bold)),
                content: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                          labelText: appState.t('行程名稱'),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: Icon(Icons.edit, color: palette[0]),
                        ),
                      ),
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: () async {
                          DateTime? picked = await showDatePicker(
                            context: context, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2030),
                            builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: ColorScheme.light(primary: palette[0])), child: child!),
                          );
                          if (picked != null) setStateModal(() => selectedDate = picked);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(border: Border.all(color: Colors.grey[400]!), borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, color: palette[0]),
                              const SizedBox(width: 12),
                              Text('${selectedDate.year}/${selectedDate.month.toString().padLeft(2,'0')}/${selectedDate.day.toString().padLeft(2,'0')}', style: const TextStyle(fontSize: 16)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Align(alignment: Alignment.centerLeft, child: Text(appState.t('更改代表圖示：'), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12, runSpacing: 12, alignment: WrapAlignment.center,
                        children: List.generate(_itineraryIcons.length, (idx) {
                          bool isSelected = selectedIconIndex == idx;
                          return InkWell(
                            borderRadius: BorderRadius.circular(50),
                            onTap: () => setStateModal(() => selectedIconIndex = idx),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200), padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: isSelected ? palette[0].withOpacity(0.15) : Colors.transparent, shape: BoxShape.circle, border: Border.all(color: isSelected ? palette[0] : Colors.grey[300]!, width: isSelected ? 2 : 1)),
                              child: Icon(_itineraryIcons[idx], color: isSelected ? palette[0] : Colors.grey[500], size: 26),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(dialogCtx), child: Text(appState.t('取消'), style: const TextStyle(color: Colors.grey))),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: palette[0], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: () {
                      if (titleController.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(appState.t('請輸入行程名稱！')))); return; }
                      // 🌟 移除重複宣告的 final appState
                      appState.itineraries[index]['title'] = titleController.text.trim();
                      appState.itineraries[index]['icon'] = _itineraryIcons[selectedIconIndex].codePoint;
                      appState.itineraries[index]['date'] = '${selectedDate.year}/${selectedDate.month.toString().padLeft(2,'0')}/${selectedDate.day.toString().padLeft(2,'0')}';
                      appState.updateItinerarySpots(index, appState.itineraries[index]['spots']);
                      Navigator.pop(dialogCtx);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(appState.t('儲存變更'))));
                    },
                    child: Text(appState.t('儲存變更')),
                  ),
                ],
              );
            },
          );
        }
    );
  }

  void _showAddSpotBottomSheet(int itiIndex) {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (ctx) => _AddSpotModal(itiIndex: itiIndex));
  }
  // 🌟 新增：顯示資源回收筒
  void _showTrashBin() {
    final appState = Provider.of<AppStateManager>(context, listen: false);
    final palette = appState.activePalette;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.delete_sweep, color: palette[0]),
                      const SizedBox(width: 8),
                      Text(appState.t('資源回收筒'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx))
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              color: Colors.red[50],
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.red[400], size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(appState.t('放在這裡的行程會在 5 天後自動永久刪除。'), style: TextStyle(color: Colors.red[700], fontSize: 13))),
                ],
              ),
            ),
            Expanded(
              // 🌟 即時去 Firebase 查詢被標記為 deleted 的行程
              child: FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance
                    .collection('Itineraries')
                    .where('User_Id', isEqualTo: appState.uid)
                    .where('Status', isEqualTo: 'deleted')
                    .get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(child: Text(appState.t('垃圾桶空空如也！'), style: const TextStyle(color: Colors.grey)));
                  }

                  final deletedDocs = snapshot.data!.docs;

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: deletedDocs.length,
                    itemBuilder: (context, index) {
                      final data = deletedDocs[index].data() as Map<String, dynamic>;
                      final docId = deletedDocs[index].id;

                      // 計算剩餘天數 (選做，讓 UI 更豐富)
                      int daysLeft = 5;
                      if (data['Expire_At'] != null) {
                        final expireDate = (data['Expire_At'] as Timestamp).toDate();
                        daysLeft = expireDate.difference(DateTime.now()).inDays;
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        color: Colors.grey[100],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          title: Text(
                            data['Title'] ?? data['title'] ?? _unnamedItineraryText(appState),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                          ),
                          subtitle: Text(
                            _trashDaysLeftText(appState, daysLeft),
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                          trailing: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: palette[2],
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                            ),
                            icon: const Icon(Icons.restore, size: 18),
                            label: Text(appState.t('還原')),
                            onPressed: () async {
                              // 執行還原邏輯
                              await appState.restoreItinerary(docId, data);
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(appState.t('行程已還原！'))));
                            },
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateManager>(context);
    final palette = appState.activePalette;
    final themeColor = palette[0];
    final itineraries = appState.itineraries;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(appState.t('行程管理'), style: TextStyle(fontWeight: FontWeight.bold, color: themeColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: themeColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: appState.t('資源回收筒'),
            onPressed: () => _showTrashBin(),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: palette[6],
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(appState.t('建立新行程'), style: const TextStyle(fontWeight: FontWeight.bold)),
        onPressed: _showAddItineraryDialog,
      ).animate().scale(delay: 400.ms, curve: Curves.easeOutBack),

      body: itineraries.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 80, color: Colors.grey[300]).animate().slideY(begin: -0.2, end: 0, duration: 800.ms),
            const SizedBox(height: 16),
            Text(appState.t('還沒有建立任何行程喔！'), style: TextStyle(color: Colors.grey[500], fontSize: 16)),
          ],
        ),
      )
          : ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        itemCount: itineraries.length,
        itemBuilder: (context, itiIndex) {
          final iti = itineraries[itiIndex];
          final spotsList = iti['spots'] as List<dynamic>;
          IconData itiIcon = Icons.beach_access;
          if (iti['icon'] != null) itiIcon = IconData(iti['icon'], fontFamily: 'MaterialIcons');

          return Container(
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: themeColor.withOpacity(0.1), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
                  child: Row(
                    children: [
                      Icon(itiIcon, color: themeColor, size: 28),
                      const SizedBox(width: 12),

                      // 標題區限制寬度，避免英文太長擠爆右邊按鈕
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _displayItineraryTitle(appState, iti['title']),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: themeColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              iti['date'],
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),

                      IconButton(
                        icon: Icon(Icons.edit_note, color: Colors.grey[700]),
                        tooltip: appState.t('編輯行程資訊'),
                        onPressed: () => _showEditItineraryDialog(itiIndex, iti),
                      ),

                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(appState.t('刪除行程')),
                              content: Text(
                                '${appState.t('確定要刪除')}「${_displayItineraryTitle(appState, iti['title'])}」${appState.t('嗎？')}',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: Text(appState.t('取消')),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                  onPressed: () {
                                    appState.deleteItinerary(itiIndex);
                                    Navigator.pop(ctx);
                                  },
                                  child: Text(
                                    appState.t('刪除'),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                if (spotsList.isEmpty)
                  Padding(padding: const EdgeInsets.all(24.0), child: Center(child: Text(appState.t('目前還沒有加入任何地點喔！'), style: const TextStyle(color: Colors.grey))))
                else
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: spotsList.length,
                    onReorder: (oldIndex, newIndex) => appState.reorderItinerarySpots(itiIndex, oldIndex, newIndex),
                    itemBuilder: (context, spotIndex) {
                      final spot = spotsList[spotIndex];

                      return Dismissible(
                        key: ValueKey('${spot["name"]}_${spot.hashCode}'),
                        direction: DismissDirection.endToStart,
                        background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), color: Colors.red, child: const Icon(Icons.delete, color: Colors.white)),
                        onDismissed: (_) => appState.removeSpotFromItinerary(itiIndex, spotIndex),
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 0,
                          color: Colors.grey[50],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: ListTile(
                            leading: CircleAvatar(backgroundColor: palette[2].withOpacity(0.2), child: Text('${spotIndex + 1}', style: TextStyle(color: palette[2], fontWeight: FontWeight.bold))),
                            title: Row(
                              children: [
                                // 判斷如果資料裡有 day 欄位，就畫出一個小標籤
                                if (spot['day'] != null && spot['day'].toString().isNotEmpty)
                                  Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: palette[2].withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      _displayDay(appState, spot['day']),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: palette[2],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                // 景點名稱
                                Expanded(
                                  child: Text(
                                    spot["name"],
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text("${appState.t('預計抵達時間：')}${spot["time"]}"),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.access_time_filled, color: palette[6]),
                                  onPressed: () async {
                                    TimeOfDay? pickedTime = await showTimePicker(
                                      context: context, initialTime: TimeOfDay.now(),
                                      builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: ColorScheme.light(primary: palette[6])), child: child!),
                                    );
                                    if (pickedTime != null) {
                                      var newList = List.from(spotsList);
                                      newList[spotIndex]['time'] = '${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}';
                                      appState.updateItinerarySpots(itiIndex, newList);
                                    }
                                  },
                                ),
                                ReorderableDragStartListener(
                                  index: spotIndex,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 8.0, right: 8.0),
                                    child: Icon(Icons.drag_handle, color: Colors.grey[400], size: 28),
                                  ),
                                )
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(side: BorderSide(color: themeColor.withOpacity(0.5)), minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    icon: Icon(Icons.add_location_alt, color: themeColor),
                    label: Text(appState.t('新增地點至此行程'), style: TextStyle(color: themeColor, fontWeight: FontWeight.bold, fontSize: 16)),
                    onPressed: () => _showAddSpotBottomSheet(itiIndex),
                  ),
                )
              ],
            ),
          ).animate().slideY(begin: 0.1, end: 0, delay: (100 * itiIndex).ms, duration: 400.ms, curve: Curves.easeOut).fadeIn();
        },
      ),
    );
  }
}

class _AddSpotModal extends StatefulWidget {
  final int itiIndex;
  const _AddSpotModal({required this.itiIndex});

  @override
  State<_AddSpotModal> createState() => _AddSpotModalState();
}

class _AddSpotModalState extends State<_AddSpotModal> {
  String _keyword = '';
  String _selectedMainCategory = '景點';
  final List<String> _mainCategories = ['景點', '美食', '住宿', '交通'];
  int _trafficType = 0;

  List<Map<String, dynamic>> _cacheSpots = [];
  List<Map<String, dynamic>> _cacheFoods = [];
  List<Map<String, dynamic>> _cacheHotels = [];

  final List<Map<String, dynamic>> _traStations = [{'NameZh': '嘉義火車站'}, {'NameZh': '嘉北火車站'}, {'NameZh': '水上火車站'}, {'NameZh': '南靖火車站'}];
  final List<Map<String, dynamic>> _thsrStations = [{'NameZh': '高鐵嘉義站'}];

  @override
  void initState() {
    super.initState();
    _loadAllCaches();
  }

  Future<void> _loadAllCaches() async {
    final prefs = await SharedPreferences.getInstance();
    String? spotsJson = prefs.getString('cache_all_spots');
    if (spotsJson != null) _cacheSpots = jsonDecode(spotsJson).cast<Map<String, dynamic>>();
    String? foodsJson = prefs.getString('cache_all_foods_v3');
    if (foodsJson != null) _cacheFoods = jsonDecode(foodsJson).cast<Map<String, dynamic>>();
    String? hotelsJson = prefs.getString('cache_all_hotels');
    if (hotelsJson != null) _cacheHotels = jsonDecode(hotelsJson).cast<Map<String, dynamic>>();
    setState(() {});
  }

  void _addSpotToItinerary(String name) {
    final appState = Provider.of<AppStateManager>(context, listen: false);
    final latestItinerary = appState.itineraries[widget.itiIndex];
    List<dynamic> currentSpots = List.from(latestItinerary['spots']);
    currentSpots.add({"name": name, "time": "12:00"});
    appState.updateItinerarySpots(widget.itiIndex, currentSpots);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${appState.t('加入')} $name')));
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateManager>(context, listen: false);
    final palette = appState.activePalette;
    List<Map<String, dynamic>> currentList = [];
    if (_selectedMainCategory == '景點') currentList = _cacheSpots;
    else if (_selectedMainCategory == '美食') currentList = _cacheFoods;
    else if (_selectedMainCategory == '住宿') currentList = _cacheHotels;
    else if (_selectedMainCategory == '交通') currentList = _trafficType == 0 ? _traStations : _thsrStations;

    List<Map<String, dynamic>> filteredList = currentList.where((item) {
      final name = (item['NameZh'] ?? item['name'] ?? '').toString().toLowerCase();
      return _keyword.isEmpty || name.contains(_keyword.toLowerCase());
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(appState.t('搜尋並加入地點'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              onChanged: (val) => setState(() => _keyword = val),
              decoration: InputDecoration(hintText: appState.t('輸入關鍵字...'), prefixIcon: Icon(Icons.search, color: palette[0]), filled: true, fillColor: Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _mainCategories.map((cat) {
                bool isSel = _selectedMainCategory == cat;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: isSel ? palette[0] : Colors.grey[200], foregroundColor: isSel ? Colors.white : Colors.grey[700], elevation: 0, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: () => setState(() => _selectedMainCategory = cat),
                      child: Text(appState.t(cat), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          if (_selectedMainCategory == '交通')
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ChoiceChip(label: Text(appState.t('火車 (TRA)')), selected: _trafficType == 0, onSelected: (val) { if(val) setState(() => _trafficType = 0); }),
                  const SizedBox(width: 12),
                  ChoiceChip(label: Text(appState.t('高鐵 (THSR)')), selected: _trafficType == 1, onSelected: (val) { if(val) setState(() => _trafficType = 1); }),
                ],
              ),
            ),

          Expanded(
            child: filteredList.isEmpty
                ? Center(child: Text(appState.t('查無資料，請先前往對應頁面瀏覽以建立快取。'), style: const TextStyle(color: Colors.grey)))
                : ListView.builder(
              physics: const BouncingScrollPhysics(), padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: filteredList.length,
              itemBuilder: (context, index) {
                final item = filteredList[index];
                final name = item['NameZh'] ?? item['name'] ?? '未知名稱';
                final picUrl = item['PicUrl1'] ?? '';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12), elevation: 0, color: Colors.grey[50], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: Container(
                      width: 60, height: 60, decoration: BoxDecoration(color: palette[2].withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                      child: picUrl.toString().isNotEmpty ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(picUrl, fit: BoxFit.cover, errorBuilder: (c,e,s) => Icon(Icons.image, color: palette[2]))) : Icon(Icons.place, color: palette[2]),
                    ),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: palette[6], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: () => _addSpotToItinerary(name), child: Text(appState.t('加入'))),
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}