// lib/pages/food_page.dart
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:latlong2/latlong.dart';
import '../widgets/app_drawer.dart';
import '../providers/app_state.dart';

class FoodPage extends StatefulWidget {
  const FoodPage({super.key});

  @override
  State<FoodPage> createState() => _FoodPageState();
}

class _FoodPageState extends State<FoodPage> {
  final Map<String, List<String>> _foodTags = {};
  List<String> _globalCategoryTags = ['咖啡廳', '傳統小吃', '甜點', '宵夜', '伴手禮', '排隊名店', '餐廳'];

  String _searchKeyword = "";
  String _selectedCategory = "全部";
  final List<String> _categories = ["全部", "咖啡廳", "雞肉飯", "嘉市好店", "夜市", "餐廳"];

  List<Map<String, dynamic>> _allFoods = [];
  bool _isLoading = true;
  bool _sortByDistance = false;
  final LatLng _userLocation = const LatLng(23.4754, 120.4473);

  Map<String, dynamic>? _lastRolledFood;

  @override
  void initState() {
    super.initState();
    _loadTags();
    _fetchFoodData();
  }

  bool _isSimilarName(String nameA, String nameB) {
    if (nameA == nameB) return true;
    int matchCount = 0;
    String shorter = nameA.length < nameB.length ? nameA : nameB;
    String longer = nameA.length >= nameB.length ? nameA : nameB;
    List<String> longerChars = longer.split('');

    for (String char in shorter.split('')) {
      if (longerChars.contains(char)) {
        matchCount++;
        longerChars.remove(char);
      }
    }
    return matchCount > (longer.length / 2);
  }

  Future<void> _fetchFoodData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const cacheKey = 'cache_all_foods_v6'; // 🌟 強制更新快取
      const cacheTimeKey = 'cache_all_foods_ts_v6';

      final cachedJson = prefs.getString(cacheKey);
      final cachedAt = prefs.getInt(cacheTimeKey) ?? 0;
      final ageMin = (DateTime.now().millisecondsSinceEpoch - cachedAt) / 60000;

      if (cachedJson != null && ageMin < 60) {
        final List<dynamic> decoded = jsonDecode(cachedJson);
        if (mounted) setState(() { _allFoods = decoded.cast<Map<String, dynamic>>(); _isLoading = false; });
        return;
      }

      final results = await Future.wait([
        FirebaseFirestore.instance.collection('Cafes').get(),
        FirebaseFirestore.instance.collection('ChickenRice').get(),
        FirebaseFirestore.instance.collection('GiftShops').get(),
        FirebaseFirestore.instance.collection('NightMarkets').get(),
        FirebaseFirestore.instance.collection('Restaurants').get(),
      ]);

      Map<String, Map<String, dynamic>> uniqueFoods = {};

      void _processSnapshot(QuerySnapshot snap, String categoryName) {
        for (var doc in snap.docs) {
          var data = doc.data() as Map<String, dynamic>;
          if (data['Location'] is GeoPoint) {
            GeoPoint geo = data['Location'];
            data['Location'] = {'lat': geo.latitude, 'lng': geo.longitude};
          }

          // 🌟 超級整合器：統整 5 大資料庫的不同欄位
          String nameZh = data['NameZh']?.toString().trim() ?? '未知名稱';
          String nameEn = data['NameEn']?.toString().trim() ?? nameZh;
          String addressZh = data['Address']?.toString().trim() ?? '無地址資訊';
          String addressEn = data['AddressEn']?.toString().trim() ?? addressZh;
          String descZh = data['DescriptionDetail']?.toString() ?? data['Description']?.toString() ?? '';
          String descEn = data['DescriptionEn']?.toString() ?? descZh;

          // 處理營業時間 (有些叫 OpenTime，有些叫 OpenDays)
          String openTimeZh = data['OpenTime']?.toString() ?? data['OpenDays']?.toString() ?? '';
          String openTimeEn = data['OpenTimeEn']?.toString() ?? data['OpenDaysEn']?.toString() ?? openTimeZh;

          // 處理特色產品 (伴手禮專用)
          String productZh = data['Product']?.toString() ?? '';
          String productEn = data['ProductEn']?.toString() ?? productZh;

          String? matchedKey;
          for (String existingName in uniqueFoods.keys) {
            if (_isSimilarName(existingName, nameZh)) { matchedKey = existingName; break; }
          }

          if (matchedKey != null) {
            if (!uniqueFoods[matchedKey]!['category'].contains(categoryName)) {
              uniqueFoods[matchedKey]!['category'] += ' / $categoryName';
            }
          } else {
            uniqueFoods[nameZh] = {
              "docId": doc.id, "category": categoryName,
              "nameZh": nameZh, "nameEn": nameEn,
              "addressZh": addressZh, "addressEn": addressEn,
              "descZh": descZh, "descEn": descEn,
              "openTimeZh": openTimeZh, "openTimeEn": openTimeEn,
              "productZh": productZh, "productEn": productEn,
              "Phone": data['Phone']?.toString() ?? '',
              "Url": data['Url']?.toString() ?? '',
              "Location": data['Location'],
              "PicUrl1": data['PicUrl1'] ?? data['PictureUrl1'] ?? ''
            };
          }
        }
      }

      _processSnapshot(results[0], "咖啡廳");
      _processSnapshot(results[1], "雞肉飯");
      _processSnapshot(results[2], "嘉市好店");
      _processSnapshot(results[3], "夜市");
      _processSnapshot(results[4], "餐廳");

      List<Map<String, dynamic>> combinedFoods = uniqueFoods.values.toList();
      combinedFoods.sort((a, b) => (a['nameZh'] as String).compareTo(b['nameZh'] as String));

      await prefs.setString(cacheKey, jsonEncode(combinedFoods));
      await prefs.setInt(cacheTimeKey, DateTime.now().millisecondsSinceEpoch);

      if (mounted) setState(() { _allFoods = combinedFoods; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTags() async {
    final prefs = await SharedPreferences.getInstance();
    final savedGlobalTags = prefs.getStringList('global_tags_美食');
    if (savedGlobalTags != null) _globalCategoryTags = savedGlobalTags;

    final keys = prefs.getKeys();
    for (String key in keys) {
      if (key.startsWith('tags_food_')) {
        String foodName = key.replaceFirst('tags_food_', '');
        _foodTags[foodName] = prefs.getStringList(key) ?? [];
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
          content: Text(appState.currentLang == 'en' ? 'Are you sure to delete "$tag"?' : '確定要刪除「$tag」嗎？這將會把其他已使用此標籤的美食紀錄一併刪除。'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(appState.t('取消'), style: const TextStyle(color: Colors.grey))),
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(ctx, true), child: Text(appState.t('確定刪除'), style: const TextStyle(color: Colors.white)))
          ],
        )
    );

    if (confirm == true) {
      setState(() {
        _globalCategoryTags.remove(tag);
        for (var key in _foodTags.keys) { _foodTags[key]?.remove(tag); }
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('global_tags_美食', _globalCategoryTags);
      if (mounted) appState.syncTagsToCloud();
      for (var key in _foodTags.keys) { await prefs.setStringList('tags_food_$key', _foodTags[key]!); }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(appState.currentLang == 'en' ? 'Tag deleted: $tag' : '已刪除標籤：$tag')));
    }
  }

  Future<void> _deleteItemTag(String foodName, String tag) async {
    final appState = Provider.of<AppStateManager>(context, listen: false);
    bool? confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(appState.t('移除標籤')),
          content: Text(appState.currentLang == 'en' ? 'Remove "$tag" from "$foodName"?' : '確定要從「$foodName」移除「$tag」標籤嗎？'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(appState.t('取消'), style: const TextStyle(color: Colors.grey))),
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(ctx, true), child: Text(appState.t('移除'), style: const TextStyle(color: Colors.white)))
          ],
        )
    );

    if (confirm == true) {
      setState(() { _foodTags[foodName]?.remove(tag); });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('tags_food_$foodName', _foodTags[foodName]!);
      if (mounted) appState.syncTagsToCloud();
    }
  }

  Future<void> _showAddTagDialog(String foodName) async {
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
                title: Text(appState.currentLang == 'en' ? 'Add tag to "$foodName"' : '為「$foodName」加上標籤', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: tagController,
                      decoration: InputDecoration(hintText: appState.t('輸入自訂標籤 (例: 必吃)'), prefixIcon: Icon(Icons.sell, color: palette[3]), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                    const SizedBox(height: 16),
                    Align(alignment: Alignment.centerLeft, child: Text(appState.t('從現有標籤庫選擇 (長按可刪除)：'), style: const TextStyle(color: Colors.grey))),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _globalCategoryTags.map((tag) => GestureDetector(
                        onLongPress: () async { await _deleteGlobalTag(tag); setModalState((){}); },
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
                          _foodTags[foodName] ??= [];
                          if (!_foodTags[foodName]!.contains(newTag)) _foodTags[foodName]!.add(newTag);
                          if (!_globalCategoryTags.contains(newTag)) _globalCategoryTags.add(newTag);
                        });
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setStringList('global_tags_美食', _globalCategoryTags);
                        await prefs.setStringList('tags_food_$foodName', _foodTags[foodName]!);

                        if (mounted) { appState.syncTagsToCloud(); Navigator.pop(ctx); }
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

  void _addToLatestItinerary(Map<String, dynamic> data, String displayName) {
    final appState = Provider.of<AppStateManager>(context, listen: false);
    if (appState.itineraries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(appState.t('您還沒有建立任何行程！'))));
      return;
    }
    final lastIndex = appState.itineraries.length - 1;
    final latestItinerary = appState.itineraries[lastIndex];
    List<dynamic> currentSpots = List.from(latestItinerary['spots']);
    currentSpots.add({"name": displayName, "time": "12:00"});
    appState.updateItinerarySpots(lastIndex, currentSpots);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(appState.currentLang == 'en' ? 'Added $displayName to "${latestItinerary['title']}"!' : '已將 $displayName 加入「${latestItinerary['title']}」行程中！')));
  }

  void _rollRandomFood(List<Map<String, dynamic>> filteredList) {
    final appState = Provider.of<AppStateManager>(context, listen: false);
    if (filteredList.isEmpty) return;

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.casino, size: 80, color: Colors.white).animate(onPlay: (c) => c.repeat()).shake(),
              const SizedBox(height: 16),
              Text(appState.t('正在為您精選美食...'), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        )
    );

    Future.delayed(const Duration(milliseconds: 1500), () {
      Navigator.pop(context);
      final random = Random();
      _lastRolledFood = filteredList[random.nextInt(filteredList.length)];
      _showFoodDetail(_lastRolledFood!, appState.activePalette, isRandomMode: true);
    });
  }

  void _showFoodDetail(Map<String, dynamic> food, List<Color> palette, {bool isRandomMode = false}) {
    final appState = Provider.of<AppStateManager>(context, listen: false);
    final double? lat = food['Location'] != null ? food['Location']['lat'] as double? : null;
    final double? lng = food['Location'] != null ? food['Location']['lng'] as double? : null;

    final String displayName = appState.currentLang == 'en' ? food['nameEn'] : food['nameZh'];
    final String displayAddr = appState.currentLang == 'en' ? food['addressEn'] : food['addressZh'];
    final String displayDesc = appState.currentLang == 'en' ? food['descEn'] : food['descZh'];
    final String displayTime = appState.currentLang == 'en' ? food['openTimeEn'] : food['openTimeZh'];
    final String displayProduct = appState.currentLang == 'en' ? food['productEn'] : food['productZh'];
    final String phone = food['Phone'] ?? '';
    final String url = food['Url'] ?? '';

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Column(
                    children: [
                      Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: palette[1].withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                            child: Text(
                                appState.currentLang == 'en' ? food['category'].split(' / ').map((e) => appState.t(e)).join(' / ') : food['category'],
                                style: TextStyle(color: palette[1], fontWeight: FontWeight.bold, fontSize: 13)
                            ),
                          ),
                          const Spacer(),
                          IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(context))
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(displayName, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 20),

                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[200]!)),
                          child: Column(
                            children: [
                              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Icon(Icons.location_on, color: palette[3], size: 20),
                                const SizedBox(width: 12),
                                Expanded(child: Text(displayAddr, style: const TextStyle(fontSize: 15, height: 1.4))),
                              ]),

                              if (displayTime.isNotEmpty) ...[
                                const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),
                                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Icon(Icons.access_time, color: palette[2], size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(child: Text(displayTime, style: const TextStyle(fontSize: 15, height: 1.4))),
                                ]),
                              ],

                              if (displayProduct.isNotEmpty) ...[
                                const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),
                                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Icon(Icons.star, color: Colors.orange, size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(child: Text(displayProduct, style: const TextStyle(fontSize: 15, height: 1.4))),
                                ]),
                              ],

                              if (phone.isNotEmpty) ...[
                                const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),
                                InkWell(
                                  onTap: () => launchUrl(Uri.parse('tel:$phone')),
                                  child: Row(children: [
                                    Icon(Icons.phone, color: palette[4], size: 20),
                                    const SizedBox(width: 12),
                                    Text(phone, style: TextStyle(fontSize: 15, color: palette[4], decoration: TextDecoration.underline)),
                                  ]),
                                ),
                              ],

                              if (url.isNotEmpty) ...[
                                const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),
                                InkWell(
                                  onTap: () async { if (await canLaunchUrl(Uri.parse(url))) launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication); },
                                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    const Icon(Icons.link, color: Colors.blue, size: 20),
                                    const SizedBox(width: 12),
                                    Expanded(child: Text(url, style: const TextStyle(fontSize: 15, color: Colors.blue, decoration: TextDecoration.underline))),
                                  ]),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (displayDesc.isNotEmpty) ...[
                          Text(appState.t('店家簡介'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(displayDesc.replaceAll('<br/>', '\n'), style: TextStyle(fontSize: 15, height: 1.6, color: Colors.grey[700])),
                          const SizedBox(height: 24),
                        ],

                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: palette[0], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                                icon: const Icon(Icons.navigation),
                                label: Text(appState.t('開始導航'), style: const TextStyle(fontWeight: FontWeight.bold)),
                                onPressed: () async {
                                  if (lat != null && lng != null) {
                                    final mapUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng?q=$lat,$lng';
                                    if (await canLaunchUrl(Uri.parse(mapUrl))) await launchUrl(Uri.parse(mapUrl), mode: LaunchMode.externalApplication);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: palette[4].withOpacity(0.1), foregroundColor: palette[4], elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                                icon: const Icon(Icons.add_task),
                                label: Text(appState.t('加入行程'), style: const TextStyle(fontWeight: FontWeight.bold)),
                                onPressed: () => _addToLatestItinerary(food, displayName),
                              ),
                            ),
                          ],
                        ),

                        if (isRandomMode) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                              icon: const Icon(Icons.refresh),
                              label: Text(appState.t('🎲 不喜歡？再抽一次！'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              onPressed: () {
                                Navigator.pop(context);
                                List<Map<String, dynamic>> currentFiltered = _allFoods.where((f) {
                                  final matchKeyword = _searchKeyword.isEmpty || (f['nameZh']?.toString().contains(_searchKeyword) ?? false);
                                  final matchCategory = _selectedCategory == "全部" || f['category'].toString().contains(_selectedCategory);
                                  return matchKeyword && matchCategory;
                                }).toList();
                                _rollRandomFood(currentFiltered);
                              },
                            ),
                          )
                        ],
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                )
              ],
            ),
          );
        }
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateManager>(context);
    final palette = appState.activePalette;
    final themeColor = palette[0];

    List<Map<String, dynamic>> filteredFoods = _allFoods.where((food) {
      final name = food['nameZh']?.toString() ?? '';
      final nameEn = food['nameEn']?.toString() ?? '';

      final matchKeyword = _searchKeyword.isEmpty ||
          name.toLowerCase().contains(_searchKeyword.toLowerCase()) ||
          nameEn.toLowerCase().contains(_searchKeyword.toLowerCase());

      final matchCategory = _selectedCategory == "全部" || food['category'].toString().contains(_selectedCategory);

      return matchKeyword && matchCategory;
    }).toList();

    if (_sortByDistance) {
      const dist = Distance();
      for (var f in filteredFoods) {
        if (f['Location'] is Map && f['Location']['lat'] != null && f['Location']['lng'] != null) {
          f['distance'] = dist.as(LengthUnit.Meter, _userLocation, LatLng(f['Location']['lat'] as double, f['Location']['lng'] as double));
        } else {
          f['distance'] = double.infinity;
        }
      }
      filteredFoods.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: Text(appState.t('在地美食'), style: TextStyle(fontWeight: FontWeight.bold, color: themeColor)), backgroundColor: Colors.transparent, elevation: 0, iconTheme: IconThemeData(color: themeColor)),
      drawer: const AppDrawer(),

      floatingActionButton: FloatingActionButton(
        backgroundColor: palette[6],
        tooltip: appState.t('隨機推薦美食'),
        child: const Icon(Icons.casino, color: Colors.white, size: 28),
        onPressed: () {
          if (filteredFoods.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(appState.t('目前沒有美食可以抽喔！'))));
            return;
          }
          if (_lastRolledFood != null && filteredFoods.any((f) => f['nameZh'] == _lastRolledFood!['nameZh'])) {
            _showFoodDetail(_lastRolledFood!, palette, isRandomMode: true);
          } else {
            _rollRandomFood(filteredFoods);
          }
        },
      ).animate().scale(delay: 500.ms, curve: Curves.easeOutBack),

      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
                    child: TextField(
                      onChanged: (value) => setState(() => _searchKeyword = value),
                      decoration: InputDecoration(hintText: appState.t('搜尋美食名稱...'), prefixIcon: Icon(Icons.search, color: palette[3]), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 16)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: () {
                    setState(() {
                      _sortByDistance = !_sortByDistance;
                      if (_sortByDistance) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(appState.t('📍 已切換為「距離最近」排序'), style: TextStyle(color: palette[0]))));
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: _sortByDistance ? palette[3] : Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
                    child: Icon(Icons.my_location, color: _sortByDistance ? Colors.white : palette[3]),
                  ),
                ),
              ],
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
            child: _isLoading ? Center(child: CircularProgressIndicator(color: themeColor)) : filteredFoods.isEmpty ? Center(child: Text(appState.t("找不到相關美食資料 😢"), style: TextStyle(color: Colors.grey[500]))) : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: filteredFoods.length,
              itemBuilder: (context, index) {
                final food = filteredFoods[index];

                final String displayName = appState.currentLang == 'en' ? food['nameEn'] : food['nameZh'];
                final String displayAddr = appState.currentLang == 'en' ? food['addressEn'] : food['addressZh'];

                final currentTags = _foodTags[food['nameZh']] ?? [];
                final Color cardAccentColor = palette[(index % 5) + 1];

                String distStr = "";
                if (_sortByDistance && food['distance'] != null && food['distance'] != double.infinity) {
                  final distM = food['distance'] as double;
                  distStr = distM > 1000 ? (appState.currentLang == 'en' ? ' · ${(distM / 1000).toStringAsFixed(1)} km' : ' · ${(distM / 1000).toStringAsFixed(1)} 公里') : (appState.currentLang == 'en' ? ' · ${distM.toStringAsFixed(0)} m' : ' · ${distM.toStringAsFixed(0)} 公尺');
                }

                return InkWell(
                  onTap: () => _showFoodDetail(food, palette),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border(left: BorderSide(color: cardAccentColor, width: 4)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(appState.currentLang == 'en' ? food['category'].split(' / ').map((e) => appState.t(e)).join(' / ') : food['category'], style: TextStyle(color: cardAccentColor, fontSize: 12, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(displayName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))
                              ])),
                              Row(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(color: palette[5].withOpacity(0.15), shape: BoxShape.circle),
                                    child: IconButton(icon: Icon(Icons.add_task, color: palette[5], size: 20), tooltip: appState.t('加入最新行程'), onPressed: () => _addToLatestItinerary(food, displayName)),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    decoration: BoxDecoration(color: palette[1].withOpacity(0.15), shape: BoxShape.circle),
                                    child: IconButton(icon: Icon(Icons.local_offer, color: palette[1], size: 20), tooltip: appState.t('新增標籤'), onPressed: () => _showAddTagDialog(food['nameZh'])),
                                  ),
                                ],
                              )
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.location_on, size: 16, color: Colors.grey[400]), const SizedBox(width: 4), Expanded(child: Text('$displayAddr$distStr', style: TextStyle(color: Colors.grey[600], height: 1.2, fontSize: 13)))]),
                          const SizedBox(height: 12),
                          if (currentTags.isNotEmpty)
                            Wrap(
                              spacing: 8, runSpacing: 8,
                              children: currentTags.asMap().entries.map((entry) {
                                Color tagColor = palette[(entry.key % 5) + 2];
                                return GestureDetector(
                                  onLongPress: () => _deleteItemTag(food['nameZh'], entry.value),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(color: tagColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: tagColor.withOpacity(0.3))),
                                    child: Text(entry.value, style: TextStyle(fontSize: 11, color: tagColor, fontWeight: FontWeight.bold)),
                                  ),
                                );
                              }).toList(),
                            )
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