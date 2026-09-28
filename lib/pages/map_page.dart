// lib/pages/map_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/app_drawer.dart';
import '../providers/app_state.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();

  // 🌟 將預設定位修改為嘉義大學蘭潭校區 (資工系館附近座標)
  final LatLng _currentLocation = const LatLng(23.4686, 120.4842);

  String _currentGuideText = '歡迎來到探索地圖！地圖目前乾乾淨淨的，請從右上角選擇您感興趣的標籤吧！';

  Set<String> _activeFilters = {};
  List<LatLng> _navigationRoute = [];
  Set<String> _selectedSubTags = {};
  Set<String> _visibleFacilities = {};
  Map<String, dynamic>? _activeItinerary;

  List<Map<String, dynamic>> _allLocations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchFirebaseLocations();
  }

  Future<void> _fetchFirebaseLocations() async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> loadedLocations = [];

    Future<void> fetchCollection(String collection, String category, String tagPrefix, {List<String> defaultTags = const []}) async {
      try {
        final snap = await FirebaseFirestore.instance.collection(collection).get();
        for (var doc in snap.docs) {
          final data = doc.data();
          double? lat;
          double? lng;

          if (data['Position'] is Map) {
            final posMap = data['Position'];
            if (posMap['PositionLat'] != null && posMap['PositionLon'] != null) {
              data['Location'] = {'lat': posMap['PositionLat'], 'lng': posMap['PositionLon']};
            }
          }

          if (data['Location'] is GeoPoint) {
            lat = (data['Location'] as GeoPoint).latitude;
            lng = (data['Location'] as GeoPoint).longitude;
          } else if (data['Location'] is Map) {
            lat = data['Location']['lat'];
            lng = data['Location']['lng'];
          }

          if (lat != null && lng != null) {
            String nameZh = data['NameZh']?.toString().trim() ?? data['ScenicSpotName']?.toString().trim() ?? '';
            String nameEn = data['NameEn']?.toString().trim() ?? '';

            String addressZh = data['Address']?.toString().trim() ?? '無地址資訊';
            String addressEn = data['AddressEn']?.toString().trim() ?? '';

            if (nameZh.isEmpty) {
              String addr = data['Address']?.toString().trim() ?? '';
              nameZh = addr.isNotEmpty ? '$category - $addr' : '$category - 依座標定位';
            }
            if (nameEn.isEmpty) {
              String addrEn = data['AddressEn']?.toString().trim() ?? '';
              if (addrEn.isNotEmpty) {
                nameEn = '$category - $addrEn';
              } else {
                String addr = data['Address']?.toString().trim() ?? '';
                nameEn = addr.isNotEmpty ? '$category - $addr' : '$category - Located by Coordinates';
              }
            }

            if (addressEn.isEmpty) {
              addressEn = addressZh;
            }

            String descZh = data['DescriptionDetail']?.toString().trim() ?? data['Description']?.toString().trim() ?? '暫無詳細介紹';
            String descEn = data['ShortDescriptionEn']?.toString().trim() ?? '';
            if (descEn.isEmpty) {
              descEn = data['DescriptionEn']?.toString().trim() ?? descZh;
            }

            String openTimeZh = data['OpenTime']?.toString().trim() ?? '';
            String openTimeEn = data['OpenTimeEn']?.toString().trim() ?? openTimeZh;

            String openDaysZh = data['OpenDays']?.toString().trim() ?? '';
            String openDaysEn = data['OpenDaysEn']?.toString().trim() ?? openDaysZh;

            String ticketInfoZh = data['TicketInfo']?.toString().trim() ?? '';
            String ticketInfoEn = data['TicketInfoEn']?.toString().trim() ?? ticketInfoZh;

            String phone = data['Phone']?.toString().trim() ?? '';
            String url = data['Url']?.toString().trim() ?? '';

            List<String> tags = prefs.getStringList('$tagPrefix$nameZh') ?? [];
            for (var dt in defaultTags) {
              if (!tags.contains(dt)) tags.add(dt);
            }

            loadedLocations.add({
              'name': nameZh,
              'nameZh': nameZh,
              'nameEn': nameEn,
              'addressZh': addressZh,
              'addressEn': addressEn,
              'descZh': descZh,
              'descEn': descEn,
              'openTimeZh': openTimeZh,
              'openTimeEn': openTimeEn,
              'openDaysZh': openDaysZh,
              'openDaysEn': openDaysEn,
              'ticketInfoZh': ticketInfoZh,
              'ticketInfoEn': ticketInfoEn,
              'phone': phone,
              'url': url,
              'category': category,
              'tags': tags,
              'lat': lat,
              'lng': lng,
            });
          }
        }
      } catch (e) {
        debugPrint('地圖抓取 $collection 失敗: $e');
      }
    }

    await Future.wait([
      fetchCollection('spots_v2', '景點', 'tags_'),
      fetchCollection('Hotels', '住宿', 'tags_hotel_'),
      fetchCollection('Cafes', '美食', 'tags_food_'),
      fetchCollection('ChickenRice', '美食', 'tags_food_'),
      fetchCollection('GiftShops', '美食', 'tags_food_'),
      fetchCollection('NightMarkets', '美食', 'tags_food_'),
      fetchCollection('Restaurants', '美食', 'tags_food_'),
      fetchCollection('TRAStations', '交通', 'tags_', defaultTags: ['台鐵']),
      fetchCollection('THSRStations', '交通', 'tags_', defaultTags: ['高鐵']),
      fetchCollection('TouristStations', '借問站', 'tags_'),
      fetchCollection('AccessibleToilets', '無障礙廁所', 'tags_'),
    ]);

    Map<String, Map<String, dynamic>> uniqueLocs = {};
    for (var loc in loadedLocations) {
      String name = loc['nameZh'];
      if (uniqueLocs.containsKey(name)) {
        if (!uniqueLocs[name]!['category'].contains(loc['category'])) {
          uniqueLocs[name]!['category'] += ' / ${loc['category']}';
        }
      } else {
        uniqueLocs[name] = loc;
      }
    }

    List<Map<String, dynamic>> finalLocs = uniqueLocs.values.toList();
    for (var loc in finalLocs) {
      if (loc['category'].contains('借問站') || loc['category'].contains('無障礙廁所')) {
        _visibleFacilities.add(loc['nameZh']);
      }
    }

    if (mounted) setState(() { _allLocations = finalLocs; _isLoading = false; });
  }

  void _clearAllMap() {
    setState(() {
      _activeFilters.clear();
      _selectedSubTags.clear();
      _navigationRoute.clear();
      _activeItinerary = null;
      _currentGuideText = '地圖已為您清空囉！隨時可以重新選擇想去的地方！';
    });
  }

  void _endNavigation() {
    setState(() {
      _navigationRoute.clear();
      _currentGuideText = '導航已結束！接下來我們去哪裡探險呢？';
    });
  }

  List<String> _getAvailableSubTags(String mainCategory) {
    Set<String> activeTags = {};
    for (var loc in _allLocations) {
      if (loc['category'].toString().contains(mainCategory) && loc.containsKey('tags')) {
        activeTags.addAll(List<String>.from(loc['tags']));
      }
    }
    return activeTags.toList();
  }

  void _showLocationBottomSheet(Map<String, dynamic> loc, Color categoryColor, IconData categoryIcon) {
    final appState = Provider.of<AppStateManager>(context, listen: false);

    final bool isEn = appState.currentLang == 'en';
    final displayName = isEn && loc['nameEn'] != null && loc['nameEn'].isNotEmpty ? loc['nameEn'] : loc['nameZh'];
    final displayAddr = isEn && loc['addressEn'] != null && loc['addressEn'].isNotEmpty ? loc['addressEn'] : loc['addressZh'];
    final displayDesc = isEn && loc['descEn'] != null && loc['descEn'].isNotEmpty ? loc['descEn'] : loc['descZh'];
    final displayOpenTime = isEn && loc['openTimeEn'] != null && loc['openTimeEn'].isNotEmpty ? loc['openTimeEn'] : loc['openTimeZh'];
    final displayOpenDays = isEn && loc['openDaysEn'] != null && loc['openDaysEn'].isNotEmpty ? loc['openDaysEn'] : loc['openDaysZh'];
    final displayTicketInfo = isEn && loc['ticketInfoEn'] != null && loc['ticketInfoEn'].isNotEmpty ? loc['ticketInfoEn'] : loc['ticketInfoZh'];
    final displayPhone = loc['phone'] ?? '';
    final displayUrl = loc['url'] ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.5,
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: categoryColor.withOpacity(0.15), shape: BoxShape.circle),
                    child: Icon(categoryIcon, color: categoryColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(displayName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.map, size: 14, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Expanded(child: Text(displayAddr, style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.3))),
                          ],
                        ),
                        if (displayOpenTime.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                              const SizedBox(width: 4),
                              Expanded(child: Text(displayOpenTime, style: TextStyle(fontSize: 13, color: Colors.grey[600]))),
                            ],
                          ),
                        ],
                        if (displayOpenDays.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.calendar_month, size: 14, color: Colors.grey[500]),
                              const SizedBox(width: 4),
                              Expanded(child: Text(displayOpenDays, style: TextStyle(fontSize: 13, color: Colors.grey[600]))),
                            ],
                          ),
                        ],
                        if (displayTicketInfo.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.confirmation_number, size: 14, color: Colors.grey[500]),
                              const SizedBox(width: 4),
                              Expanded(child: Text(displayTicketInfo, style: TextStyle(fontSize: 13, color: Colors.grey[600]))),
                            ],
                          ),
                        ],
                        if (displayPhone.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () async {
                              final uri = Uri.parse('tel:$displayPhone');
                              if (await canLaunchUrl(uri)) await launchUrl(uri);
                            },
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.phone, size: 14, color: Colors.grey[500]),
                                const SizedBox(width: 4),
                                Expanded(child: Text(displayPhone, style: TextStyle(fontSize: 13, color: Colors.blue, decoration: TextDecoration.underline))),
                              ],
                            ),
                          ),
                        ],
                        if (displayUrl.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () async {
                              final uri = Uri.parse(displayUrl);
                              if (await canLaunchUrl(uri)) await launchUrl(uri);
                            },
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.language, size: 14, color: Colors.grey[500]),
                                const SizedBox(width: 4),
                                Expanded(child: Text(appState.t('官方網站'), style: const TextStyle(fontSize: 13, color: Colors.blue, decoration: TextDecoration.underline))),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayDesc.replaceAll('<br/>', '\n'), style: TextStyle(fontSize: 14, height: 1.5, color: Colors.grey[800])),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: categoryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: categoryColor.withOpacity(0.3))),
                child: Row(
                  children: [
                    Image.asset('assets/image_de9dd8.png', width: 50, height: 50),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${appState.t('這看起來是個好地方！\n要去「')}$displayName${appState.t('」嗎？')}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, height: 1.4)),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.navigation, size: 16),
                              label: Text(appState.t('好！開始導航'), style: const TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(backgroundColor: categoryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 8)),
                              onPressed: () async {
                                Navigator.pop(context);
                                setState(() {
                                  _navigationRoute = [_currentLocation, LatLng(loc['lat'], loc['lng'])];
                                  _currentGuideText = '已繪製路線並開啟 Google Maps！抵達後記得注意安全喔！';
                                });
                                _mapController.move(LatLng((_currentLocation.latitude + loc['lat']) / 2, (_currentLocation.longitude + loc['lng']) / 2), 14.5);

                                // 🌟 修正：改成 Google Maps 路線規劃專屬格式，設定起點為目前的定位(_currentLocation)與終點(loc)
                                final mapUrl = 'https://www.google.com/maps/dir/?api=1&origin=${_currentLocation.latitude},${_currentLocation.longitude}&destination=${loc["lat"]},${loc["lng"]}';

                                if (await canLaunchUrl(Uri.parse(mapUrl))) {
                                  await launchUrl(Uri.parse(mapUrl), mode: LaunchMode.externalApplication);
                                }
                              },
                            ),
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }

  void _showFacilityBottomSheet(String mainCategory, Color categoryColor) {
    final appState = Provider.of<AppStateManager>(context, listen: false);
    List<Map<String, dynamic>> facilityList = _allLocations.where((l) => l['category'].contains(mainCategory)).toList();

    const dist = Distance();
    for (var f in facilityList) {
      f['distVal'] = dist.as(LengthUnit.Meter, _currentLocation, LatLng(f['lat'], f['lng']));
    }
    facilityList.sort((a, b) => (a['distVal'] as double).compareTo(b['distVal'] as double));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${appState.t('選取')}${appState.t(mainCategory)}${appState.t(' (依距離)')}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            bool allSelected = facilityList.every((f) => _visibleFacilities.contains(f['nameZh']));
                            if (allSelected) {
                              for (var f in facilityList) { _visibleFacilities.remove(f['nameZh']); }
                            } else {
                              for (var f in facilityList) { _visibleFacilities.add(f['nameZh']); }
                            }
                          });
                          setState(() {});
                        },
                        child: Text(appState.t('全選/全清'), style: TextStyle(color: categoryColor, fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: facilityList.length,
                        itemBuilder: (context, index) {
                          final f = facilityList[index];
                          final isChecked = _visibleFacilities.contains(f['nameZh']);
                          final distM = f['distVal'] as double;
                          final distStr = distM > 1000 ? '${(distM / 1000).toStringAsFixed(1)} ${appState.t('公里')}' : '${distM.toStringAsFixed(0)} ${appState.t('公尺')}';

                          final displayName = appState.currentLang == 'en' && f['nameEn'] != null && f['nameEn'].isNotEmpty ? f['nameEn'] : f['nameZh'];

                          return CheckboxListTile(
                            activeColor: categoryColor,
                            contentPadding: EdgeInsets.zero,
                            title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Text('${appState.t('距離目前位置: ')}$distStr', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                            value: isChecked,
                            onChanged: (val) {
                              setModalState(() {
                                if (val == true) _visibleFacilities.add(f['nameZh']);
                                else _visibleFacilities.remove(f['nameZh']);
                              });
                              setState(() {});
                            },
                          );
                        }
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24, top: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[50], foregroundColor: Colors.red, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                            onPressed: () { setState(() => _activeFilters.remove(mainCategory)); Navigator.pop(ctx); },
                            child: Text(appState.t('隱藏此標籤'), style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: categoryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(appState.t('確認顯示'), style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSubTagBottomSheet(String mainCategory, Color categoryColor) {
    final appState = Provider.of<AppStateManager>(context, listen: false);
    final tags = _getAvailableSubTags(mainCategory);
    if (tags.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('目前「$mainCategory」還沒有任何標籤資料喔！')));
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${appState.t('過濾「')}${appState.t(mainCategory)}」', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            bool allSelected = tags.every((t) => _selectedSubTags.contains(t));
                            if (allSelected) {
                              _selectedSubTags.removeAll(tags);
                            } else {
                              _selectedSubTags.addAll(tags);
                            }
                          });
                          setState(() {});
                        },
                        child: Text(appState.t('全選/全清'), style: TextStyle(color: categoryColor, fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                  const Divider(),
                  Wrap(
                    spacing: 8,
                    children: tags.map((tag) {
                      final isChecked = _selectedSubTags.contains(tag);
                      return FilterChip(
                        label: Text(tag, style: TextStyle(fontWeight: isChecked ? FontWeight.bold : FontWeight.normal)),
                        selected: isChecked,
                        selectedColor: categoryColor.withOpacity(0.2),
                        checkmarkColor: categoryColor,
                        backgroundColor: Colors.grey[100],
                        side: BorderSide(color: isChecked ? categoryColor : Colors.grey[300]!),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        onSelected: (bool value) {
                          setModalState(() {
                            if (value) {
                              _selectedSubTags.add(tag);
                            } else {
                              _selectedSubTags.remove(tag);
                            }
                          });
                          setState(() {});
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red[50], foregroundColor: Colors.red, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                          onPressed: () { setState(() => _activeFilters.remove(mainCategory)); Navigator.pop(ctx); },
                          child: Text(appState.t('隱藏此類別'), style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: categoryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(appState.t('完成篩選'), style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showItineraryBottomSheet(Color categoryColor) {
    final appState = Provider.of<AppStateManager>(context, listen: false);
    final itineraries = appState.itineraries;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(appState.t('選擇要顯示軌跡的行程'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Divider(height: 24),
                  if (itineraries.isEmpty)
                    Padding(padding: const EdgeInsets.all(16.0), child: Text(appState.t('目前還沒有行程喔！')))
                  else
                    ...itineraries.map((iti) {
                      final isSelected = _activeItinerary == iti;
                      return ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        tileColor: isSelected ? categoryColor.withOpacity(0.1) : null,
                        leading: Icon(Icons.map, color: isSelected ? categoryColor : Colors.grey),
                        title: Text(iti['title'], style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                        subtitle: Text(iti['date']),
                        trailing: isSelected ? Icon(Icons.check_circle, color: categoryColor) : null,
                        onTap: () {
                          setState(() {
                            _activeItinerary = iti;
                            _activeFilters.add('行程');
                            _currentGuideText = '${appState.t('為您顯示軌跡：')}${iti['title']}';
                          });
                          Navigator.pop(ctx);
                        },
                      );
                    }).toList(),
                  const SizedBox(height: 16),
                  if (_activeItinerary != null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red[50], foregroundColor: Colors.red, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                        onPressed: () {
                          setState(() {
                            _activeItinerary = null;
                            _activeFilters.remove('行程');
                          });
                          Navigator.pop(ctx);
                        },
                        child: Text(appState.t('取消行程顯示'), style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateManager>();
    final palette = appState.activePalette;
    final themeColor = palette[0];

    final List<Map<String, dynamic>> dynamicFilterTags = [
      {'name': '景點', 'icon': Icons.camera_alt, 'color': palette[1]},
      {'name': '美食', 'icon': Icons.restaurant, 'color': palette[2]},
      {'name': '住宿', 'icon': Icons.hotel, 'color': palette[3]},
      {'name': '交通', 'icon': Icons.train, 'color': palette[4]},
      {'name': '借問站', 'icon': Icons.help_outline, 'color': Colors.teal},
      {'name': '無障礙廁所', 'icon': Icons.accessible, 'color': Colors.indigo},
      {'name': '行程', 'icon': Icons.map, 'color': Colors.deepOrange},
    ];

    final filteredLocations = _allLocations.where((loc) {
      if (loc['category'].contains('借問站') || loc['category'].contains('無障礙廁所')) {
        if (!_activeFilters.contains('借問站') && loc['category'].contains('借問站')) return false;
        if (!_activeFilters.contains('無障礙廁所') && loc['category'].contains('無障礙廁所')) return false;
        return _visibleFacilities.contains(loc['nameZh']);
      }

      bool passMainCategory = false;
      for (var f in _activeFilters) {
        if (['景點', '美食', '住宿', '交通'].contains(f) && loc['category'].toString().contains(f)) {
          passMainCategory = true;
        }
      }
      if (!passMainCategory) return false;

      final availableTags = _getAvailableSubTags(loc['category']);
      final activeTags = _selectedSubTags.intersection(availableTags.toSet());
      if (activeTags.isEmpty) return true;
      return (loc['tags'] as List<String>).any((t) => activeTags.contains(t));
    }).toList();

    List<LatLng> itineraryPoints = [];
    List<Marker> itineraryMarkers = [];

    if (_activeFilters.contains('行程') && _activeItinerary != null) {
      List<dynamic> spots = _activeItinerary!['spots'] ?? [];
      for (int i = 0; i < spots.length; i++) {
        String spotName = spots[i]['name'];
        final locIndex = _allLocations.indexWhere((l) {
          String dbName = l['nameZh'].toString();
          if (dbName == spotName) return true;

          if (spotName.contains('站') || dbName.contains('站')) {
            String s1 = spotName.replaceAll('火車站', '').replaceAll('車站', '').replaceAll('高鐵', '').replaceAll('站', '');
            String s2 = dbName.replaceAll('火車站', '').replaceAll('車站', '').replaceAll('高鐵', '').replaceAll('站', '');
            if (s1 == s2 && s1.isNotEmpty) return true;
          }

          if (spotName.length > 2 && dbName.length > 2) {
            if (dbName.contains(spotName) || spotName.contains(dbName)) return true;
          }

          return false;
        });

        if (locIndex != -1) {
          final loc = _allLocations[locIndex];
          final pt = LatLng(loc['lat'], loc['lng']);
          itineraryPoints.add(pt);

          itineraryMarkers.add(Marker(
            point: pt,
            width: 44, height: 44,
            alignment: Alignment.topCenter,
            child: GestureDetector(
              onTap: () => _showLocationBottomSheet(loc, Colors.deepOrange, Icons.map),
              child: Container(
                decoration: BoxDecoration(color: Colors.deepOrange, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 4)]),
                child: Center(child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
              ).animate().slideY(begin: -0.5, end: 0, duration: 400.ms, curve: Curves.bounceOut),
            ),
          ));
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(appState.t('探索地圖'), style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      drawer: const AppDrawer(),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: _currentLocation, initialZoom: 14.5),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.explore_chiayi'),

              if (_navigationRoute.isNotEmpty)
                PolylineLayer(polylines: [Polyline(points: _navigationRoute, color: palette[6], strokeWidth: 5.0, pattern: StrokePattern.dashed(segments: [10, 8]))]),

              if (itineraryPoints.isNotEmpty)
                PolylineLayer(polylines: [Polyline(points: itineraryPoints, color: Colors.deepOrange, strokeWidth: 4.0, pattern: StrokePattern.dashed(segments: [12, 10]))]),

              MarkerLayer(
                markers: [
                  Marker(
                      point: _currentLocation,
                      child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(color: themeColor, shape: BoxShape.circle, boxShadow: [BoxShadow(color: themeColor.withOpacity(0.5), blurRadius: 8)]),
                          child: const Icon(Icons.my_location, color: Colors.white, size: 24)
                      ).animate(onPlay: (controller) => controller.repeat(reverse: true)).scale(begin: const Offset(1,1), end: const Offset(1.1,1.1), duration: 1.seconds)
                  ),

                  ...filteredLocations.map((loc) {
                    Map<String, dynamic> categoryData = dynamicFilterTags[0];
                    bool matchedActive = false;

                    for (var tag in dynamicFilterTags) {
                      if (_activeFilters.contains(tag['name']) && loc['category'].toString().contains(tag['name'])) {
                        categoryData = tag;
                        matchedActive = true;
                        break;
                      }
                    }

                    if (!matchedActive) {
                      for (var tag in dynamicFilterTags) {
                        if (loc['category'].toString().contains(tag['name'])) {
                          categoryData = tag;
                          break;
                        }
                      }
                    }

                    return Marker(
                      point: LatLng(loc['lat'], loc['lng']),
                      width: 50, height: 50,
                      alignment: Alignment.topCenter,
                      child: GestureDetector(
                          onTap: () => _showLocationBottomSheet(loc, categoryData['color'], categoryData['icon']),
                          child: Stack(
                            alignment: Alignment.topCenter,
                            children: [
                              Icon(Icons.location_on, color: categoryData['color'], size: 50),
                              Positioned(
                                top: 8,
                                child: Icon(categoryData['icon'], color: Colors.white, size: 20),
                              ),
                            ],
                          ).animate().slideY(begin: -0.5, end: 0, duration: 400.ms, curve: Curves.bounceOut)
                      ),
                    );
                  }).toList(),

                  ...itineraryMarkers,
                ],
              ),
            ],
          ),

          if (_isLoading)
            Container(
              color: Colors.white.withOpacity(0.6),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)]),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: themeColor),
                      const SizedBox(width: 16),
                      Text(appState.t('正在載入最新地圖資訊...'), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),

          Positioned(
            top: 10, right: 10, left: 10,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: dynamicFilterTags.map((tag) {
                  final bool isSelected = _activeFilters.contains(tag['name']);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          if (['借問站', '無障礙廁所'].contains(tag['name'])) {
                            if (!isSelected) _activeFilters.add(tag['name']);
                            _currentGuideText = '${appState.t('為您顯示附近的「')}${appState.t(tag['name'])}${appState.t('」囉！')}';
                            _showFacilityBottomSheet(tag['name'], tag['color']);
                          } else if (tag['name'] == '行程') {
                            if (!isSelected) _activeFilters.add(tag['name']);
                            _showItineraryBottomSheet(tag['color']);
                          } else {
                            if (isSelected) {
                              _showSubTagBottomSheet(tag['name'], tag['color']);
                            } else {
                              _activeFilters.add(tag['name']);
                              _currentGuideText = '${appState.t('好的！為您標示出「')}${appState.t(tag['name'])}${appState.t('」囉！')}';
                            }
                          }
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                            color: isSelected ? tag['color'] : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6, offset: const Offset(0, 2))]
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(tag['icon'], color: isSelected ? Colors.white : tag['color'], size: 16),
                            const SizedBox(width: 6),
                            Text(appState.t(tag['name']), style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ).animate().slideX(begin: 1, end: 0, duration: 500.ms, curve: Curves.easeOutQuad),
          ),

          Positioned(
            right: 10, top: MediaQuery.of(context).size.height * 0.2,
            child: Column(
              children: [
                _buildMapApiBtn(Icons.my_location, appState.t('回到我的位置'), themeColor, () {
                  setState(() { _mapController.move(_currentLocation, 15.0); _currentGuideText = '回到目前位置，準備好去哪裡探險了嗎？'; });
                }),
                const SizedBox(height: 12),
                _buildMapApiBtn(Icons.layers_clear, appState.t('清空地圖'), Colors.redAccent, _clearAllMap),
                const SizedBox(height: 12),
                _buildMapApiBtn(Icons.add, appState.t('放大'), themeColor, () { _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1); }),
                const SizedBox(height: 12),
                _buildMapApiBtn(Icons.remove, appState.t('縮小'), themeColor, () { _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1); }),
              ],
            ).animate().slideX(begin: 1, end: 0, delay: 200.ms, duration: 500.ms, curve: Curves.easeOut),
          ),

          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))]
              ),
              padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: palette[6].withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                        child: Text(appState.t('導覽員 · 小芬'), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: palette[6])),
                      ),
                      Image.asset('assets/image_de9dd8.png', width: 80, height: 80, errorBuilder: (c,e,s) => const SizedBox(width: 80, height: 80)),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomRight: Radius.circular(16)),
                              border: Border.all(color: themeColor.withOpacity(0.2)),
                              boxShadow: [BoxShadow(color: themeColor.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))]
                          ),
                          child: Text(appState.t(_currentGuideText), style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87, fontWeight: FontWeight.w500)),
                        ),

                        if (_navigationRoute.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[50], foregroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                            icon: const Icon(Icons.cancel, size: 16),
                            label: Text(appState.t('結束並清除導航路線'), style: const TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: _endNavigation,
                          )
                        ]
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().slideY(begin: 1, end: 0, delay: 300.ms, duration: 500.ms, curve: Curves.easeOutQuad),
          ),
        ],
      ),
    );
  }

  Widget _buildMapApiBtn(IconData icon, String tooltip, Color themeColor, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 3))]
      ),
      child: IconButton(
        icon: Icon(icon, color: themeColor),
        onPressed: onPressed,
        tooltip: tooltip,
      ),
    );
  }
}