// lib/pages/hotel_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:latlong2/latlong.dart';
import '../widgets/app_drawer.dart';
import '../providers/app_state.dart';

class HotelPage extends StatefulWidget {
  const HotelPage({super.key});

  @override
  State<HotelPage> createState() => _HotelPageState();
}

class _HotelPageState extends State<HotelPage> {
  final Map<String, List<String>> _hotelTags = {};
  List<String> _globalCategoryTags = ['飯店', '設計感', '高CP值', '民宿'];

  List<Map<String, dynamic>> _allHotels = [];
  bool _isLoading = true;

  String _searchKeyword = "";
  String _selectedArea = "全部";
  final List<String> _areas = ["全部", "東區", "西區", "阿里山鄉", "梅山鄉", "竹崎鄉", "番路鄉", "中埔鄉"];
  bool _sortByDistance = false;
  final LatLng _userLocation = const LatLng(23.4754, 120.4473);

  @override
  void initState() {
    super.initState();
    _loadTags();
    _fetchHotelsData();
  }

  Future<void> _fetchHotelsData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const cacheKey = 'cache_all_hotels';
      const cacheTimeKey = 'cache_all_hotels_ts';

      final cachedJson = prefs.getString(cacheKey);
      final cachedAt = prefs.getInt(cacheTimeKey) ?? 0;
      final ageMin = (DateTime.now().millisecondsSinceEpoch - cachedAt) / 60000;

      if (cachedJson != null && ageMin < 60) {
        final List<dynamic> decoded = jsonDecode(cachedJson);
        if (mounted) setState(() { _allHotels = decoded.cast<Map<String, dynamic>>(); _isLoading = false; });
        return;
      }

      final snap = await FirebaseFirestore.instance.collection('Hotels').get();
      final hotels = snap.docs.map((doc) {
        var data = doc.data();
        if (data['Location'] is GeoPoint) {
          GeoPoint geo = data['Location'];
          data['Location'] = {'lat': geo.latitude, 'lng': geo.longitude};
        }
        return {"docId": doc.id, ...data};
      }).toList();

      await prefs.setString(cacheKey, jsonEncode(hotels));
      await prefs.setInt(cacheTimeKey, DateTime.now().millisecondsSinceEpoch);

      if (mounted) setState(() { _allHotels = hotels; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTags() async {
    final prefs = await SharedPreferences.getInstance();
    final savedGlobalTags = prefs.getStringList('global_tags_住宿');
    if (savedGlobalTags != null) _globalCategoryTags = savedGlobalTags;

    final keys = prefs.getKeys();
    for (String key in keys) {
      if (key.startsWith('tags_hotel_')) {
        String hotelName = key.replaceFirst('tags_hotel_', '');
        _hotelTags[hotelName] = prefs.getStringList(key) ?? [];
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
          content: Text(appState.currentLang == 'en' ? 'Are you sure to delete "$tag"?' : '確定要刪除「$tag」嗎？這將會把其他已使用此標籤的住宿紀錄一併刪除。'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(appState.t('取消'))),
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(ctx, true), child: Text(appState.t('確定刪除'), style: const TextStyle(color: Colors.white)))
          ],
        )
    );

    if (confirm == true) {
      setState(() {
        _globalCategoryTags.remove(tag);
        for (var key in _hotelTags.keys) { _hotelTags[key]?.remove(tag); }
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('global_tags_住宿', _globalCategoryTags);
      if (context.mounted) {
        context.read<AppStateManager>().syncTagsToCloud();
      }
      for (var key in _hotelTags.keys) { await prefs.setStringList('tags_hotel_$key', _hotelTags[key]!); }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(appState.currentLang == 'en' ? 'Tag deleted: $tag' : '已刪除標籤：$tag')));
    }
  }

  Future<void> _deleteItemTag(String hotelName, String tag) async {
    final appState = Provider.of<AppStateManager>(context, listen: false);
    bool? confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(appState.t('移除標籤')),
          content: Text(appState.currentLang == 'en' ? 'Remove "$tag" from this hotel?' : '確定要移除「$tag」標籤嗎？'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(appState.t('取消'))),
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () => Navigator.pop(ctx, true), child: Text(appState.t('移除'), style: const TextStyle(color: Colors.white)))
          ],
        )
    );
    if (confirm == true) {
      setState(() { _hotelTags[hotelName]?.remove(tag); });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('tags_hotel_$hotelName', _hotelTags[hotelName]!);
      if (mounted) appState.syncTagsToCloud();
    }
  }

  Future<void> _showTagDialog(String hotelName) async {
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
                title: Text(appState.currentLang == 'en' ? 'Add Custom Tag' : '新增自訂標籤', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: tagController,
                      decoration: InputDecoration(hintText: appState.currentLang == 'en' ? 'Enter custom tag...' : '輸入自訂標籤 (例: 網美打卡)', prefixIcon: Icon(Icons.local_offer, color: palette[2]), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                    const SizedBox(height: 16),
                    Text(appState.currentLang == 'en' ? 'Select from existing (Long press to delete):' : '從現有標籤庫選擇 (長按可刪除)：', style: const TextStyle(color: Colors.grey, fontSize: 12)),
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
                          label: Text(tag, style: TextStyle(color: palette[0], fontSize: 12, fontWeight: FontWeight.w600)),
                          onPressed: () { tagController.text = tag; },
                        ),
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
                          _hotelTags[hotelName] ??= [];
                          if (!_hotelTags[hotelName]!.contains(newTag)) _hotelTags[hotelName]!.add(newTag);
                          if (!_globalCategoryTags.contains(newTag)) _globalCategoryTags.add(newTag);
                        });
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setStringList('global_tags_住宿', _globalCategoryTags);
                        await prefs.setStringList('tags_hotel_$hotelName', _hotelTags[hotelName]!);
                        if (context.mounted) {
                          context.read<AppStateManager>().syncTagsToCloud();
                        }
                        if (!mounted) return;
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(appState.currentLang == 'en' ? '🏷️ Tag added: $newTag' : '已成功標記：$newTag')));
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

  void _addToLatestItinerary(Map<String, dynamic> data, String displayHotelName) {
    final appState = Provider.of<AppStateManager>(context, listen: false);
    if (appState.itineraries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(appState.t('您還沒有建立任何行程！請先至行程管理頁面新增。'))));
      return;
    }
    final lastIndex = appState.itineraries.length - 1;
    final latestItinerary = appState.itineraries[lastIndex];
    List<dynamic> currentSpots = List.from(latestItinerary['spots']);
    currentSpots.add({"name": displayHotelName, "time": "15:00"});
    appState.updateItinerarySpots(lastIndex, currentSpots);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(appState.currentLang == 'en' ? 'Added $displayHotelName to "${latestItinerary['title']}"!' : '已將 $displayHotelName 加入「${latestItinerary['title']}」行程中！')));
  }

  Widget _buildFallbackImage(Color bgColor) {
    return Container(height: 140, width: double.infinity, color: bgColor.withOpacity(0.2), child: Center(child: Icon(Icons.hotel, size: 50, color: bgColor)));
  }

  // 🌟 絕美詳細資訊彈窗
  void _showHotelDetailsModal(BuildContext context, Map<String, dynamic> hotel, String displayName, String displayAddr, Color imgBgColor) {
    final appState = Provider.of<AppStateManager>(context, listen: false);
    final palette = appState.activePalette;

    // 處理雙語介紹
    final String descZh = hotel['Description'] ?? '';
    final String descEn = hotel['DescriptionEn'] ?? descZh;
    final String displayDesc = appState.currentLang == 'en' ? descEn : descZh;

    // 處理電話
    final String phone = hotel['Phone']?.toString() ?? '';

    // 🌟 魔法：清理 TDX 雜亂的 Services 逗號字串，並轉為漂亮的標籤清單
    final String rawServices = hotel['Services']?.toString() ?? '';
    final List<String> serviceTags = rawServices
        .split(RegExp(r'[,，、]')) // 支援半形逗號、全形逗號、頓號切分
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty) // 過濾掉空字串 (清除連續逗號)
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Stack(
            children: [
              ListView(
                controller: controller,
                padding: const EdgeInsets.only(bottom: 40),
                children: [
                  // 頂部大圖
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    child: hotel['PicUrl1']?.toString().isNotEmpty == true
                        ? Image.network(hotel['PicUrl1'], height: 260, width: double.infinity, fit: BoxFit.cover, errorBuilder: (c, e, s) => _buildFallbackImage(imgBgColor))
                        : _buildFallbackImage(imgBgColor),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 名稱
                        Text(displayName, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: palette[0])),
                        const SizedBox(height: 12),

                        // 地址
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.location_on, size: 20, color: palette[3]),
                            const SizedBox(width: 8),
                            Expanded(child: Text(displayAddr, style: TextStyle(fontSize: 15, color: Colors.grey[800], height: 1.4))),
                          ],
                        ),

                        // 電話
                        if (phone.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(Icons.phone, size: 20, color: palette[3]),
                              const SizedBox(width: 8),
                              Text(phone, style: TextStyle(fontSize: 15, color: Colors.grey[800])),
                            ],
                          ),
                        ],

                        const Divider(height: 40, thickness: 1, color: Color(0xFFEEEEEE)),

                        // 魔法生成的服務設施標籤區塊
                        if (serviceTags.isNotEmpty) ...[
                          Text(appState.currentLang == 'en' ? 'Services & Facilities' : '服務與設施', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: serviceTags.map((tag) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: palette[2].withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: palette[2].withOpacity(0.2)),
                              ),
                              child: Text(tag, style: TextStyle(color: palette[2], fontSize: 13, fontWeight: FontWeight.w600)),
                            )).toList(),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // 住宿介紹
                        if (displayDesc.isNotEmpty) ...[
                          Text(appState.currentLang == 'en' ? 'About' : '住宿介紹', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Text(displayDesc, style: const TextStyle(fontSize: 15, height: 1.8, color: Colors.black87)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              // 右上角關閉按鈕
              Positioned(
                top: 16,
                right: 16,
                child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), shape: BoxShape.circle),
                    child: const Icon(Icons.close, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateManager>(context);
    final palette = appState.activePalette;
    final themeColor = palette[0];

    List<Map<String, dynamic>> filteredHotels = _allHotels.where((hotel) {
      final nameZh = hotel['NameZh']?.toString() ?? '';
      final nameEn = hotel['NameEn']?.toString() ?? '';
      final address = hotel['Address']?.toString() ?? '';
      final addressEn = hotel['AddressEn']?.toString() ?? '';

      final String searchTarget = (nameZh + nameEn + address + addressEn).toLowerCase();
      final matchKeyword = _searchKeyword.isEmpty || searchTarget.contains(_searchKeyword.toLowerCase());

      final matchArea = _selectedArea == "全部" || address.contains(_selectedArea);
      return matchKeyword && matchArea;
    }).toList();

    if (_sortByDistance) {
      const dist = Distance();
      for (var h in filteredHotels) {
        if (h['Location'] is Map && h['Location']['lat'] != null && h['Location']['lng'] != null) {
          h['distance'] = dist.as(LengthUnit.Meter, _userLocation, LatLng(h['Location']['lat'] as double, h['Location']['lng'] as double));
        } else {
          h['distance'] = double.infinity;
        }
      }
      filteredHotels.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: Text(appState.t('特色住宿'), style: TextStyle(fontWeight: FontWeight.bold, color: themeColor)), backgroundColor: Colors.transparent, elevation: 0, iconTheme: IconThemeData(color: themeColor)),
      drawer: const AppDrawer(),
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
                      decoration: InputDecoration(hintText: appState.t('搜尋住宿名稱、地址關鍵字...'), prefixIcon: Icon(Icons.search, color: palette[3]), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 16)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: () {
                    setState(() {
                      _sortByDistance = !_sortByDistance;
                      if (_sortByDistance) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(appState.t('📍 已為您切換為「距離最近」排序'), style: TextStyle(color: palette[0]))));
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
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))]),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true, value: _selectedArea, icon: Icon(Icons.keyboard_arrow_down, color: palette[2]),
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 15),
                items: _areas.map((e) => DropdownMenuItem(value: e, child: Text(appState.t(e)))).toList(),
                onChanged: (val) { if (val != null) setState(() => _selectedArea = val); },
              ),
            ),
          ),
          Expanded(
            child: _isLoading ? Center(child: CircularProgressIndicator(color: themeColor)) : filteredHotels.isEmpty ? Center(child: Text(appState.t("找不到相關住宿資料"), style: TextStyle(color: Colors.grey[500]))) : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: filteredHotels.length,
              itemBuilder: (context, index) {
                final hotel = filteredHotels[index];

                // 處理雙語切換：保持以 NameZh 作為儲存 Tag 的唯一識別碼
                final String tagKeyName = hotel['NameZh'] ?? '未知住宿';
                final String displayHotelName = appState.currentLang == 'en' ? (hotel['NameEn'] ?? tagKeyName) : tagKeyName;

                final String addrZh = hotel['Address'] ?? '';
                final String addrEn = hotel['AddressEn'] ?? addrZh;
                final String displayAddr = appState.currentLang == 'en' ? addrEn : addrZh;

                final currentTags = _hotelTags[tagKeyName] ?? [];
                final imgBgColor = palette[(index % 3) + 1];

                String distStr = "";
                if (_sortByDistance && hotel['distance'] != null && hotel['distance'] != double.infinity) {
                  final distM = hotel['distance'] as double;
                  distStr = distM > 1000 ? (appState.currentLang == 'en' ? ' · ${(distM / 1000).toStringAsFixed(1)} km' : ' · ${(distM / 1000).toStringAsFixed(1)} 公里') : (appState.currentLang == 'en' ? ' · ${distM.toStringAsFixed(0)} m' : ' · ${distM.toStringAsFixed(0)} 公尺');
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 5))]),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => _showHotelDetailsModal(context, hotel, displayHotelName, displayAddr, imgBgColor),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                          child: hotel['PicUrl1']?.toString().isNotEmpty == true
                              ? Image.network(hotel['PicUrl1'], height: 140, width: double.infinity, fit: BoxFit.cover, errorBuilder: (c, e, s) => _buildFallbackImage(imgBgColor))
                              : _buildFallbackImage(imgBgColor),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(displayHotelName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18), maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Text('$displayAddr$distStr', style: TextStyle(color: Colors.grey[600], fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  if (currentTags.isNotEmpty)
                                    Expanded(
                                      child: Wrap(
                                        spacing: 6, runSpacing: 6,
                                        children: currentTags.map((t) => GestureDetector(
                                          onLongPress: () => _deleteItemTag(tagKeyName, t),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(color: palette[4].withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                                            child: Text(t, style: TextStyle(fontSize: 11, color: palette[4], fontWeight: FontWeight.bold)),
                                          ),
                                        )).toList(),
                                      ),
                                    )
                                  else const Spacer(),
                                  Row(
                                    children: [
                                      IconButton(icon: Icon(Icons.local_offer_outlined, color: palette[2]), tooltip: appState.t('新增標籤'), onPressed: () => _showTagDialog(tagKeyName)),
                                      IconButton(icon: Icon(Icons.add_task, color: palette[5]), tooltip: appState.t('加入最新行程'), onPressed: () => _addToLatestItinerary(hotel, displayHotelName)),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: palette[6], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                        onPressed: () async {
                                          if (displayHotelName.isNotEmpty) {
                                            final targetUrl = 'https://www.google.com/travel/search?q=${Uri.encodeComponent(displayHotelName)}';
                                            if (await canLaunchUrl(Uri.parse(targetUrl))) await launchUrl(Uri.parse(targetUrl), mode: LaunchMode.externalApplication);
                                          }
                                        },
                                        child: Text(appState.t('前往訂房'), style: const TextStyle(fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                ],
                              )
                            ],
                          ),
                        )
                      ],
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