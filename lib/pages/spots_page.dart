// lib/pages/spots_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/app_drawer.dart';
import '../providers/app_state.dart';

class SpotsPage extends StatefulWidget {
  const SpotsPage({super.key});

  @override
  State<SpotsPage> createState() => _SpotsPageState();
}

class _SpotsPageState extends State<SpotsPage> {
  String _selectedCategory = "全部";
  final List<String> _categories = ["全部", "廟宇", "古蹟", "工廠", "城堡", "自然", "藝文"];
  final Map<String, List<String>> _spotTags = {};
  List<String> _globalCategoryTags = ['古蹟', '網美打卡', '親子友善'];

  List<Map<String, dynamic>> _allSpots = [];
  String _searchKeyword = "";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTags();
    _fetchSpotsFromFirebase();
  }

  Future<void> _fetchSpotsFromFirebase() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // 🌟 核心修復 1：更改 Cache Key，強制 App 拋棄原本「沒有圖片」的舊快取，重新向 Firebase 抓取！
      const cacheKey = 'cache_all_spots_v2_db_img_fix';
      const cacheTimeKey = 'cache_all_spots_ts_v2_db_img_fix';

      final cachedJson = prefs.getString(cacheKey);
      final cachedAt = prefs.getInt(cacheTimeKey) ?? 0;
      final ageMin = (DateTime.now().millisecondsSinceEpoch - cachedAt) / 60000;

      if (cachedJson != null && ageMin < 60) {
        final List<dynamic> decoded = jsonDecode(cachedJson);
        if (mounted) setState(() { _allSpots = decoded.cast<Map<String, dynamic>>(); _isLoading = false; });
        return;
      }

      final snap = await FirebaseFirestore.instance.collection('spots_v2').get();
      final spots = snap.docs.map((doc) {
        var data = doc.data();

        if (data['ScenicSpotName'] != null) data['NameZh'] = data['ScenicSpotName'];

        // 🌟 核心修復 2：精準解析 Picture Map 裡面的 PictureUrl1
        String picUrl = '';
        if (data['PicUrl1'] != null && data['PicUrl1'].toString().isNotEmpty) {
          picUrl = data['PicUrl1'];
        } else if (data['Picture'] is Map && data['Picture']['PictureUrl1'] != null) {
          picUrl = data['Picture']['PictureUrl1']; // 深入 Map 抓取圖片
        } else if (data['PictureUrl1'] != null) {
          picUrl = data['PictureUrl1'];
        }
        data['PicUrl1'] = picUrl; // 統一存到 PicUrl1 供畫面使用

        if (data['Position'] is Map) {
          final posMap = data['Position'];
          if (posMap['PositionLat'] != null && posMap['PositionLon'] != null) {
            data['Location'] = {'lat': posMap['PositionLat'], 'lng': posMap['PositionLon']};
          }
        } else if (data['Location'] is GeoPoint) {
          GeoPoint geo = data['Location'];
          data['Location'] = {'lat': geo.latitude, 'lng': geo.longitude};
        }

        return {"docId": doc.id, ...data};
      }).toList();

      await prefs.setString(cacheKey, jsonEncode(spots));
      await prefs.setInt(cacheTimeKey, DateTime.now().millisecondsSinceEpoch);

      if (mounted) setState(() { _allSpots = spots; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTags() async {
    final prefs = await SharedPreferences.getInstance();
    final savedGlobalTags = prefs.getStringList('global_tags_景點');
    if (savedGlobalTags != null) _globalCategoryTags = savedGlobalTags;

    final keys = prefs.getKeys();
    for (String key in keys) {
      if (key.startsWith('tags_')) {
        String spotName = key.replaceFirst('tags_', '');
        _spotTags[spotName] = prefs.getStringList(key) ?? [];
      }
    }
    setState(() {});
  }

  Future<void> _deleteGlobalTag(String tag) async {
    final appState = Provider.of<AppStateManager>(context, listen: false);
    bool? confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(appState.currentLang == 'en' ? 'Warning: Delete Global Tag' : '警告：刪除全域標籤', style: const TextStyle(color: Colors.red)),
          content: Text(appState.currentLang == 'en' ? 'Are you sure to delete "$tag"? This will remove it from all spots.' : '確定要刪除「$tag」嗎？這將會把其他已使用此標籤的景點紀錄一併刪除。'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(appState.t('取消'))),
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(ctx, true), child: Text(appState.t('確定刪除'), style: const TextStyle(color: Colors.white)))
          ],
        )
    );
    if (confirm == true) {
      setState(() {
        _globalCategoryTags.remove(tag);
        for (var key in _spotTags.keys) { _spotTags[key]?.remove(tag); }
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('global_tags_景點', _globalCategoryTags);
      appState.syncTagsToCloud();
      for (var key in _spotTags.keys) { await prefs.setStringList('tags_$key', _spotTags[key]!); }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(appState.currentLang == 'en' ? 'Tag deleted: $tag' : '已刪除標籤：$tag')));
    }
  }

  Future<void> _deleteItemTag(String spotName, String tag) async {
    final appState = Provider.of<AppStateManager>(context, listen: false);
    bool? confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(appState.t('移除標籤')),
          content: Text(appState.currentLang == 'en' ? 'Remove "$tag" from "$spotName"?' : '確定要從「$spotName」移除「$tag」標籤嗎？'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(appState.t('取消'))),
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(ctx, true), child: Text(appState.t('移除'), style: const TextStyle(color: Colors.white)))
          ],
        )
    );
    if (confirm == true) {
      setState(() { _spotTags[spotName]?.remove(tag); });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('tags_$spotName', _spotTags[spotName]!);
    }
  }

  Future<void> _showAddTagDialog(String spotName) async {
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
                title: Text(appState.currentLang == 'en' ? 'Add tag to "$spotName"' : '為「$spotName」加上標籤', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: tagController,
                      decoration: InputDecoration(hintText: appState.t('輸入自訂標籤 (例: 網美打卡)'), prefixIcon: Icon(Icons.sell, color: palette[3]), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                    const SizedBox(height: 16),
                    Align(alignment: Alignment.centerLeft, child: Text(appState.t('從現有標籤庫選擇 (長按可刪除)：'), style: const TextStyle(color: Colors.grey))),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _globalCategoryTags.map((tag) => GestureDetector(
                        onLongPress: () async {
                          await _deleteGlobalTag(tag);
                          setModalState((){});
                        },
                        child: ActionChip(
                          backgroundColor: palette[0].withOpacity(0.1), side: BorderSide.none,
                          label: Text(tag, style: TextStyle(color: palette[0], fontWeight: FontWeight.w600)),
                          onPressed: () { tagController.text = tag; },
                        ),
                      )).toList(),
                    )
                  ],
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: Text(appState.t('取消'), style: const TextStyle(color: Colors.grey))),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: palette[6], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: () async {
                      final newTag = tagController.text.trim();
                      if (newTag.isNotEmpty) {
                        setState(() {
                          _spotTags[spotName] ??= [];
                          if (!_spotTags[spotName]!.contains(newTag)) _spotTags[spotName]!.add(newTag);
                          if (!_globalCategoryTags.contains(newTag)) _globalCategoryTags.add(newTag);
                        });
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setStringList('global_tags_景點', _globalCategoryTags);
                        appState.syncTagsToCloud();
                        await prefs.setStringList('tags_$spotName', _spotTags[spotName]!);
                        if (!mounted) return;
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(appState.currentLang == 'en' ? '🏷️ Tag added: $newTag' : '🏷️ 已成功標記：$newTag')));
                      }
                    },
                    child: Text(appState.t('確定標記')),
                  )
                ],
              );
            }
        );
      },
    );
  }

  void _addToLatestItinerary(Map<String, dynamic> data) {
    final appState = Provider.of<AppStateManager>(context, listen: false);
    if (appState.itineraries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(appState.t('您還沒有建立任何行程！請先至行程管理頁面新增。'))));
      return;
    }
    final lastIndex = appState.itineraries.length - 1;
    final latestItinerary = appState.itineraries[lastIndex];

    String spotName = appState.currentLang == 'en'
        ? (data['NameEn'] ?? data['NameZh'] ?? 'Unknown Spot')
        : (data['NameZh'] ?? '未知景點');

    List<dynamic> currentSpots = List.from(latestItinerary['spots']);
    currentSpots.add({
      "name": spotName,
      "time": "10:00"
    });

    appState.updateItinerarySpots(lastIndex, currentSpots);
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appState.currentLang == 'en' ? 'Added $spotName to "${latestItinerary['title']}"!' : '已將 $spotName 加入「${latestItinerary['title']}」行程中！'))
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateManager>(context);
    final palette = appState.activePalette;
    final themeColor = palette[0];

    final filteredSpots = _allSpots.where((spot) {
      final nameZh = spot['NameZh']?.toString() ?? '';
      final nameEn = spot['NameEn']?.toString() ?? '';
      final desc = spot['DescriptionDetail']?.toString() ?? spot['Description']?.toString() ?? '';

      final matchKeyword = _searchKeyword.isEmpty ||
          nameZh.contains(_searchKeyword) ||
          nameEn.toLowerCase().contains(_searchKeyword.toLowerCase());

      final matchCategory = _selectedCategory == "全部" || nameZh.contains(_selectedCategory) || desc.contains(_selectedCategory);

      return matchKeyword && matchCategory;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: Text(appState.t('景點探索'), style: TextStyle(fontWeight: FontWeight.bold, color: themeColor)), backgroundColor: Colors.transparent, elevation: 0, iconTheme: IconThemeData(color: themeColor)),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
              child: TextField(
                onChanged: (value) => setState(() => _searchKeyword = value),
                decoration: InputDecoration(hintText: appState.t('搜尋景點關鍵字...'), prefixIcon: Icon(Icons.search, color: palette[3]), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 16)),
              ),
            ),
          ),
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final isSelected = _selectedCategory == _categories[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(appState.t(_categories[index]), style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    selected: isSelected, selectedColor: palette[4].withOpacity(0.15), backgroundColor: Colors.white,
                    side: BorderSide(color: isSelected ? palette[4] : Colors.grey[300]!), checkmarkColor: palette[4],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    onSelected: (bool selected) => setState(() => _selectedCategory = _categories[index]),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: _isLoading ? Center(child: CircularProgressIndicator(color: themeColor)) : filteredSpots.isEmpty ? Center(child: Text(appState.t("找不到相關景點 😢"), style: TextStyle(color: Colors.grey[500]))) : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: filteredSpots.length,
              itemBuilder: (context, index) {
                final spot = filteredSpots[index];

                final spotName = appState.currentLang == 'en'
                    ? (spot['NameEn'] ?? spot['NameZh'] ?? 'Unknown Spot')
                    : (spot['NameZh'] ?? '未知景點');

                final address = appState.currentLang == 'en'
                    ? (spot['AddressEn'] ?? spot['Address'] ?? 'No address info')
                    : (spot['Address'] ?? appState.t('無地址資訊'));

                final picUrl = spot['PicUrl1'] ?? '';
                final currentTags = _spotTags[spot['NameZh'] ?? ''] ?? [];
                final cardColor = palette[(index % 6) + 1];
                final isFav = appState.isFavorite(spot['NameZh'] ?? '');

                return InkWell(
                  onTap: () {
                    appState.setCurrentSpotData(spot);
                    appState.setPageIndex(11);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 90, height: 90,
                                decoration: BoxDecoration(color: cardColor.withOpacity(0.15), borderRadius: BorderRadius.circular(16)),
                                child: picUrl.isNotEmpty
                                    ? ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.network(picUrl, fit: BoxFit.cover, errorBuilder: (ctx, err, stack) => Icon(Icons.image, color: cardColor)))
                                    : Icon(Icons.image, color: cardColor.withOpacity(0.7), size: 40),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(spotName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 6),
                                    Text(address, style: TextStyle(color: Colors.grey[600], fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  IconButton(icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.red : palette[2]), onPressed: () => appState.toggleFavorite(spot)),
                                  Row(
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(color: palette[5].withOpacity(0.15), shape: BoxShape.circle),
                                        child: IconButton(
                                          icon: Icon(Icons.add_task, color: palette[5], size: 20),
                                          tooltip: appState.t('加入最新行程'),
                                          onPressed: () => _addToLatestItinerary(spot),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        decoration: BoxDecoration(color: palette[1].withOpacity(0.15), shape: BoxShape.circle),
                                        child: IconButton(
                                          icon: Icon(Icons.local_offer, color: palette[1], size: 20),
                                          tooltip: appState.t('新增標籤'),
                                          onPressed: () => _showAddTagDialog(spot['NameZh'] ?? ''),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              )
                            ],
                          ),

                          if (currentTags.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8, runSpacing: 8,
                              children: currentTags.asMap().entries.map((entry) {
                                Color tagColor = palette[(entry.key % 5) + 2];
                                return GestureDetector(
                                  onLongPress: () => _deleteItemTag(spot['NameZh'] ?? '', entry.value),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(color: tagColor, borderRadius: BorderRadius.circular(8)),
                                    child: Text(entry.value, style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                                  ),
                                );
                              }).toList(),
                            )
                          ]
                        ],
                      ),
                    ),
                  ),
                ).animate().slideY(begin: 0.1, end: 0, delay: (40 * index).ms, duration: 400.ms, curve: Curves.easeOut).fadeIn();
              },
            ),
          ),
        ],
      ),
    );
  }
}