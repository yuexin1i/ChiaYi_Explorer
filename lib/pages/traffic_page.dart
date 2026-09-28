// lib/pages/traffic_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../widgets/app_drawer.dart';
import '../providers/app_state.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../models/YouBikeModels.dart';
import '../models/BusModels.dart';
import '../models/TRAModels.dart';
import '../models/THSRModels.dart';
import 'package:marquee/marquee.dart';
import '../widgets/loading_fen.dart';

class FirebaseTrafficService {
  static const int _cacheTtlMinutes = 60;

  static Future<List<Map<String, dynamic>>> fetch({
    required String collection,
    required String nameField,
    String? subtitleField,
    List<String> extraFields = const [],
  }) async {
    final cacheKey = 'cache_v4_$collection';
    final prefs = await SharedPreferences.getInstance();

    final cachedJson = prefs.getString(cacheKey);
    final cachedAt = prefs.getInt('${cacheKey}_ts') ?? 0;
    final ageMin = (DateTime.now().millisecondsSinceEpoch - cachedAt) / 60000;

    if (cachedJson != null && ageMin < _cacheTtlMinutes) {
      final List decoded = jsonDecode(cachedJson);
      return decoded.cast<Map<String, dynamic>>();
    }

    final snapshot =
    await FirebaseFirestore.instance.collection(collection).get();

    final List<Map<String, dynamic>> results = [];
    for (final doc in snapshot.docs) {
      final d = doc.data();
      final geo = d['Location'] as GeoPoint?;
      final entry = <String, dynamic>{
        'docId': doc.id,
        'name': d[nameField] ?? doc.id,
        'subtitle': subtitleField != null ? (d[subtitleField] ?? '') : '',
        'lat': geo?.latitude,
        'lng': geo?.longitude,
      };
      for (final f in extraFields) {
        entry[f] = d[f];
      }
      results.add(entry);
    }

    await prefs.setString(cacheKey, jsonEncode(results));
    await prefs.setInt('${cacheKey}_ts', DateTime.now().millisecondsSinceEpoch);
    return results;
  }

  static Future<void> clearCache(String collection) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cache_$collection');
    await prefs.remove('cache_${collection}_ts');
  }
}

class _MarqueeAlertBar extends StatelessWidget {
  final List<BusAlert> alerts;
  final Color color;
  const _MarqueeAlertBar({required this.alerts, required this.color});

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) return const SizedBox.shrink();

    final text = alerts.map((a) => '${a.title}：${a.description}').join('     ');

    return Container(
      height: 32,
      color: color.withOpacity(0.12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            color: color.withOpacity(0.2),
            child: Icon(Icons.campaign, color: color, size: 16),
          ),
          Expanded(
            child: Marquee(
              text: text,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              scrollAxis: Axis.horizontal,
              crossAxisAlignment: CrossAxisAlignment.center,
              blankSpace: 50.0,
              velocity: 40.0,
              pauseAfterRound: const Duration(seconds: 1),
              startPadding: 10.0,
              accelerationDuration: const Duration(seconds: 1),
              accelerationCurve: Curves.easeIn,
              decelerationDuration: const Duration(milliseconds: 500),
              decelerationCurve: Curves.easeOut,
            ),
          ),
        ],
      ),
    );
  }
}

class TrafficPage extends StatefulWidget {
  const TrafficPage({super.key});
  @override
  State<TrafficPage> createState() => _TrafficPageState();
}

class _TrafficPageState extends State<TrafficPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final LatLng _userLocation = const LatLng(23.4791, 120.4415);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateManager>();
    final palette = appState.activePalette;
    final themeColor = palette[0];

    return Scaffold(
      backgroundColor: Colors.grey[50],
      drawer: const AppDrawer(),
      appBar: AppBar(
        title:
        Text(appState.t('交通資訊'), style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          isScrollable: true,
          physics: const BouncingScrollPhysics(),
          tabs: [
            Tab(icon: const Icon(Icons.local_parking), text: appState.t('停車場')),
            const Tab(icon: Icon(Icons.directions_bike), text: 'YouBike'),
            Tab(icon: const Icon(Icons.directions_bus), text: appState.t('市區公車')),
            Tab(icon: const Icon(Icons.local_taxi), text: appState.t('計程車')),
            Tab(icon: const Icon(Icons.train), text: appState.t('台鐵')),
            Tab(icon: const Icon(Icons.directions_railway), text: appState.t('高鐵')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _FirebaseMapListTab(
            collection: 'Parking',
            nameField: 'NameZh',
            subtitleBuilder: (d) =>
            d['FareDescription'] ?? d['Address'] ?? '',
            extraFields: const ['Address', 'FareDescription', 'CarParkType', 'NameEn', 'AddressEn'],
            dialogContentBuilder: (d) =>
            '${appState.t('地址：')}${d['Address'] ?? '-'}\n${appState.t('收費：')}${d['FareDescription'] ?? '-'}',
            userLocation: _userLocation,
            iconData: Icons.local_parking,
            color: palette[1],
            label: '停車場',
          ),

          _YouBikeTab(
            userLocation: _userLocation,
            color: palette[2],
          ),

          _BusMapListTab(
              userLocation: _userLocation, themeColor: palette[3]),

          _TaxiTab(
            userLocation: _userLocation,
            color: palette[4],
          ),

          _TRATab(
            userLocation: _userLocation,
            color: palette[5],
          ),

          _THSRTab(
            userLocation: _userLocation,
            color: palette[6],
          ),
        ],
      ),
    );
  }
}

class _FirebaseMapListTab extends StatefulWidget {
  final String collection;
  final String nameField;
  final String Function(Map<String, dynamic>) subtitleBuilder;
  final String Function(Map<String, dynamic>) dialogContentBuilder;
  final List<String> extraFields;
  final LatLng userLocation;
  final IconData iconData;
  final Color color;
  final String label;

  const _FirebaseMapListTab({
    required this.collection,
    required this.nameField,
    required this.subtitleBuilder,
    required this.dialogContentBuilder,
    required this.extraFields,
    required this.userLocation,
    required this.iconData,
    required this.color,
    required this.label,
  });

  @override
  State<_FirebaseMapListTab> createState() => _FirebaseMapListTabState();
}

class _FirebaseMapListTabState extends State<_FirebaseMapListTab> {
  final MapController _mapController = MapController();
  List<Map<String, dynamic>> _locations = [];
  bool _isLoading = true;

  Map<String, dynamic>? _selectedLoc;
  LatLngBounds? _mapBounds;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    if (forceRefresh) {
      await FirebaseTrafficService.clearCache(widget.collection);
    }
    try {
      final raw = await FirebaseTrafficService.fetch(
        collection: widget.collection,
        nameField: widget.nameField,
        extraFields: widget.extraFields,
      );

      const dist = Distance();
      for (final loc in raw) {
        if (loc['lat'] != null && loc['lng'] != null) {
          loc['distance'] = dist.as(
            LengthUnit.Meter,
            widget.userLocation,
            LatLng(loc['lat'] as double, loc['lng'] as double),
          );
        } else {
          loc['distance'] = double.infinity;
        }
      }
      raw.sort((a, b) =>
          (a['distance'] as double).compareTo(b['distance'] as double));

      if (mounted) {
        setState(() {
          _locations = raw;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _focusOnLocation(double lat, double lng) =>
      _mapController.move(LatLng(lat, lng), 16.0);

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateManager>(context);
    return Column(
      children: [
        SizedBox(
          height: 240,
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24)),
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: widget.userLocation,
                initialZoom: 15.5,
                onPositionChanged: (camera, _) {
                  if (mounted) setState(() => _mapBounds = camera.visibleBounds);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.explore_chiayi',
                ),
                MarkerLayer(markers: [
                  Marker(
                    point: widget.userLocation,
                    width: 40, height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                          color: Colors.redAccent, shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 2))]
                      ),
                      child: const Icon(Icons.my_location, color: Colors.white, size: 22),
                    ),
                  ),

                  ...() {
                    final normalMarkers = <Marker>[];
                    Marker? highlightedMarker;

                    for (final loc in _locations) {
                      if (loc['lat'] == null || loc['lng'] == null) continue;
                      if (_mapBounds != null && !_mapBounds!.contains(LatLng(loc['lat'] as double, loc['lng'] as double))) continue;

                      final isSelected = _selectedLoc == loc;

                      final marker = Marker(
                        point: LatLng(loc['lat'] as double, loc['lng'] as double),
                        width: isSelected ? 64 : 36,
                        height: isSelected ? 64 : 36,
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _selectedLoc = loc);
                            final index = _locations.indexOf(loc);
                            if (index != -1 && _scrollController.hasClients) {
                              _scrollController.animateTo(
                                index * 95.0,
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeOutQuart,
                              );
                            }
                            _focusOnLocation(loc['lat'] as double, loc['lng'] as double);
                            _showDetail(loc, appState);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.elasticOut,
                            decoration: BoxDecoration(
                              color: isSelected ? widget.color : Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: isSelected ? Colors.white : widget.color, width: isSelected ? 4 : 2),
                              boxShadow: [
                                BoxShadow(
                                  color: isSelected ? widget.color.withOpacity(0.6) : Colors.black26,
                                  blurRadius: isSelected ? 12 : 4,
                                  spreadRadius: isSelected ? 4 : 0,
                                  offset: const Offset(0, 2),
                                )
                              ],
                            ),
                            child: Icon(widget.iconData, color: isSelected ? Colors.white : widget.color, size: isSelected ? 30 : 18),
                          ),
                        ),
                      );

                      if (isSelected) highlightedMarker = marker;
                      else normalMarkers.add(marker);
                    }
                    if (highlightedMarker != null) normalMarkers.add(highlightedMarker);
                    return normalMarkers;
                  }(),
                ]),
              ],
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(children: [
            Icon(Icons.sort, color: widget.color),
            const SizedBox(width: 8),
            Text(appState.t('依距離排序'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
        ),

        Expanded(
          child: _isLoading
              ? const LoadingFenWidget()
              : _locations.isEmpty
              ? Center(child: Text('${appState.t('目前沒有')}${appState.t(widget.label)}${appState.t('資料')}', style: TextStyle(color: Colors.grey[500])))
              : ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            physics: const BouncingScrollPhysics(),
            itemCount: _locations.length,
            itemBuilder: (context, index) {
              final loc = _locations[index];
              final distM = loc['distance'] as double;
              final distStr = distM == double.infinity ? '-' : '${distM.toStringAsFixed(0)} ${appState.t('公尺')}';

              final isSelected = _selectedLoc == loc;

              return GestureDetector(
                onTap: () {
                  setState(() => _selectedLoc = loc);
                  if (loc['lat'] != null) {
                    _focusOnLocation(loc['lat'] as double, loc['lng'] as double);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? widget.color.withOpacity(0.08) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: isSelected
                        ? Border.all(color: widget.color.withOpacity(0.6), width: 1.5)
                        : Border.all(color: Colors.transparent, width: 1.5),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: widget.color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12)),
                      child: Icon(widget.iconData, color: widget.color),
                    ),
                    title: Text(
                        (appState.currentLang == 'en' && loc['NameEn'] != null && loc['NameEn'].toString().isNotEmpty)
                            ? loc['NameEn']
                            : loc['name'],
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)
                    ),
                    subtitle: Text(
                      (appState.currentLang == 'en' && loc['AddressEn'] != null && loc['AddressEn'].toString().isNotEmpty)
                          ? '${loc['AddressEn']}  ·  $distStr'
                          : '${widget.subtitleBuilder(loc)}  ·  $distStr',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    trailing: loc['lat'] != null
                        ? Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: isSelected ? widget.color : Colors.grey[50],
                          shape: BoxShape.circle),
                      child: Icon(Icons.map, color: isSelected ? Colors.white : widget.color, size: 20),
                    )
                        : null,
                  ),
                ),
              ).animate().slideY(begin: 0.1, end: 0, delay: (index * 40).ms).fadeIn();
            },
          ),
        ),
      ],
    );
  }

  void _showDetail(Map<String, dynamic> loc, AppStateManager appState) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text((appState.currentLang == 'en' && loc['NameEn'] != null && loc['NameEn'].toString().isNotEmpty) ? loc['NameEn'] : loc['name']),
        content: Text(
            (appState.currentLang == 'en' && loc['AddressEn'] != null && loc['AddressEn'].toString().isNotEmpty)
                ? '${appState.t('地址：')}${loc['AddressEn']}\n${appState.t('收費：')}${loc['FareDescription'] ?? '-'}'
                : widget.dialogContentBuilder(loc)
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(appState.t('關閉')))
        ],
      ),
    );
  }
}

class _TaxiTab extends StatefulWidget {
  final LatLng userLocation;
  final Color color;
  const _TaxiTab({required this.userLocation, required this.color});

  @override
  State<_TaxiTab> createState() => _TaxiTabState();
}

class _TaxiTabState extends State<_TaxiTab> {
  final MapController _mapController = MapController();
  List<Map<String, dynamic>> _stops = [];
  List<Map<String, dynamic>> _operators = [];
  Map<String, dynamic>? _selectedStop;
  LatLngBounds? _mapBounds;
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();

  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    if (forceRefresh) {
      await FirebaseTrafficService.clearCache('TaxiStops');
      await FirebaseTrafficService.clearCache('TaxiOperators');
    }
    try {
      final stopsFuture = FirebaseTrafficService.fetch(
        collection: 'TaxiStops',
        nameField: 'LocationNameZh',
        extraFields: const ['RoadSection', 'Scope', 'TaxiStopID', 'LocationNameEn', 'RoadSectionEn'],
      );
      final opsFuture = FirebaseTrafficService.fetch(
        collection: 'TaxiOperators',
        nameField: 'OperatorName',
        extraFields: const ['Phone', 'FareStandard', 'OperatorID'],
      );
      final results = await Future.wait([stopsFuture, opsFuture]);

      const dist = Distance();
      final stops = results[0];
      for (final s in stops) {
        if (s['lat'] != null && s['lng'] != null) {
          s['distance'] = dist.as(LengthUnit.Meter, widget.userLocation,
              LatLng(s['lat'] as double, s['lng'] as double));
        } else {
          s['distance'] = double.infinity;
        }
      }
      stops.sort((a, b) =>
          (a['distance'] as double).compareTo(b['distance'] as double));

      if (mounted) {
        setState(() {
          _stops = stops;
          _operators = results[1];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingFenWidget();
    }

    final appState = Provider.of<AppStateManager>(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: widget.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _currentIndex = 0),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _currentIndex == 0 ? widget.color : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              appState.t('附近招呼站'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _currentIndex == 0 ? Colors.white : widget.color,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _currentIndex = 1),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _currentIndex == 1 ? widget.color : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              appState.t('叫車專線'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _currentIndex == 1 ? Colors.white : widget.color,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              Container(
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: _isLoading
                      ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: widget.color)
                  )
                      : Icon(Icons.refresh, color: widget.color),
                  onPressed: _isLoading ? null : () => _load(forceRefresh: true),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: _currentIndex == 0 ? _buildStopsView(appState) : _buildOperatorsView(appState),
        ),
      ],
    );
  }

  Widget _buildStopsView(AppStateManager appState) {
    return Column(
      children: [
        SizedBox(
          height: 220,
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24)),
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: widget.userLocation,
                initialZoom: 15.5,
                onPositionChanged: (camera, _) {
                  if (mounted) setState(() => _mapBounds = camera.visibleBounds);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.explore_chiayi',
                ),
                MarkerLayer(markers: [
                  Marker(point: widget.userLocation, width: 40, height: 40, child: Container(decoration: BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 2))]), child: const Icon(Icons.my_location, color: Colors.white, size: 22))),

                  ...() {
                    final normalMarkers = <Marker>[];
                    Marker? highlightedMarker;

                    for (final s in _stops) {
                      if (s['lat'] == null || s['lng'] == null) continue;
                      if (_mapBounds != null && !_mapBounds!.contains(LatLng(s['lat'] as double, s['lng'] as double))) continue;

                      final isSelected = _selectedStop == s;

                      final marker = Marker(
                        point: LatLng(s['lat'] as double, s['lng'] as double),
                        width: isSelected ? 64 : 36,
                        height: isSelected ? 64 : 36,
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _selectedStop = s);
                            final index = _stops.indexOf(s);
                            if (index != -1 && _scrollController.hasClients) {
                              _scrollController.animateTo(
                                index * 85.0,
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeOutQuart,
                              );
                            }
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                title: Row(children: [
                                  Icon(Icons.local_taxi, color: widget.color),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(
                                      (appState.currentLang == 'en' && s['LocationNameEn'] != null && s['LocationNameEn'].toString().isNotEmpty)
                                          ? s['LocationNameEn']
                                          : s['name']
                                  ))
                                ]),
                                content: Text(
                                    '${(appState.currentLang == 'en' && s['RoadSectionEn'] != null && s['RoadSectionEn'].toString().isNotEmpty) ? s['RoadSectionEn'] : (s['RoadSection'] ?? "")}\n${s["Scope"] ?? ""}',
                                    style: const TextStyle(height: 1.6)
                                ),
                                actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(appState.t('關閉')))],
                              ),
                            );
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.elasticOut,
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isSelected ? widget.color : Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: isSelected ? Colors.white : widget.color, width: isSelected ? 4 : 2),
                              boxShadow: [
                                BoxShadow(
                                  color: isSelected ? widget.color.withOpacity(0.6) : Colors.black26,
                                  blurRadius: isSelected ? 12 : 4,
                                  spreadRadius: isSelected ? 4 : 0,
                                  offset: const Offset(0, 2),
                                )
                              ],
                            ),
                            child: Icon(Icons.local_taxi, color: isSelected ? Colors.white : widget.color, size: isSelected ? 24 : 18),
                          ),
                        ),
                      );

                      if (isSelected) highlightedMarker = marker;
                      else normalMarkers.add(marker);
                    }

                    if (highlightedMarker != null) normalMarkers.add(highlightedMarker);
                    return normalMarkers;
                  }(),
                ]),
              ],
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(children: [
            Icon(Icons.place, color: widget.color),
            const SizedBox(width: 8),
            Text(appState.t('附近招呼站'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
        ),

        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: _stops.length,
            itemBuilder: (context, index) {
              final s = _stops[index];
              final distM = s['distance'] as double;
              final distStr = distM == double.infinity ? '-' : '${distM.toStringAsFixed(0)} ${appState.t('公尺')}';
              final isSelected = _selectedStop == s;

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                    color: isSelected ? widget.color.withOpacity(0.08) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: isSelected ? Border.all(color: widget.color.withOpacity(0.6), width: 1.5) : Border.all(color: Colors.transparent, width: 1.5),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)]),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: widget.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.local_taxi, color: widget.color),
                  ),
                  title: Text(
                      (appState.currentLang == 'en' && s['LocationNameEn'] != null && s['LocationNameEn'].toString().isNotEmpty)
                          ? s['LocationNameEn']
                          : s['name'],
                      style: const TextStyle(fontWeight: FontWeight.bold)
                  ),
                  subtitle: Text(
                      '${(appState.currentLang == 'en' && s['RoadSectionEn'] != null) ? s['RoadSectionEn'] : (s['RoadSection'] ?? '')}  ·  ${s['Scope'] ?? ''}  ·  $distStr',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  trailing: s['lat'] != null
                      ? Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: isSelected ? widget.color : Colors.grey[50],
                        shape: BoxShape.circle),
                    child: Icon(Icons.map,
                        color: isSelected ? Colors.white : widget.color,
                        size: 20),
                  )
                      : null,
                  onTap: () {
                    setState(() => _selectedStop = s);
                    if (s['lat'] != null) {
                      _mapController.move(LatLng(s['lat'] as double, s['lng'] as double), 16.0);
                    }
                  },
                ),
              ).animate().slideY(begin: 0.1, end: 0, delay: (index * 40).ms).fadeIn();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOperatorsView(AppStateManager appState) {
    if (_operators.isEmpty) {
      return Center(
        child: Text(appState.t('目前沒有業者資料'), style: TextStyle(color: Colors.grey[500])),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      physics: const BouncingScrollPhysics(),
      itemCount: _operators.length,
      itemBuilder: (context, index) {
        final op = _operators[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)]),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.business, color: widget.color),
            ),
            title: Text(op['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            subtitle: Text(
                '${appState.t('計費：')}${op['FareStandard'] ?? '-'}',
                style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            trailing: op['Phone'] != null
                ? Container(
              decoration: BoxDecoration(
                color: widget.color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(Icons.phone, color: widget.color, size: 22),
                onPressed: () async {
                  final uri = Uri.parse('tel:${op['Phone']}');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                },
              ),
            )
                : null,
          ),
        ).animate().slideY(begin: 0.1, end: 0, delay: (index * 40).ms).fadeIn();
      },
    );
  }
}

class _YouBikeTab extends StatefulWidget {
  final LatLng userLocation;
  final Color color;
  const _YouBikeTab({required this.userLocation, required this.color});
  @override
  State<_YouBikeTab> createState() => _YouBikeTabState();
}

class _YouBikeTabState extends State<_YouBikeTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final MapController _mapController = MapController();

  List<Map<String, dynamic>> _stations = [];
  bool _staticLoading = true;
  Map<String, dynamic>? _selectedStation;
  LatLngBounds? _mapBounds;
  final ScrollController _scrollController = ScrollController();

  Map<String, YouBikeAvailability> _liveMap = {};
  bool _liveLoading = false;
  String? _liveError;
  DateTime? _liveUpdatedAt;
  DateTime? _liveLastFetched;

  @override
  void initState() {
    super.initState();
    _loadStatic();
  }

  Future<void> _loadStatic() async {
    setState(() => _staticLoading = true);
    try {
      final raw = await FirebaseTrafficService.fetch(
        collection: 'YouBikeStations',
        nameField: 'NameZh',
        extraFields: const ['Address', 'Capacity', 'StationUID','NameEn', 'AddressEn'],
      );
      const dist = Distance();
      for (final s in raw) {
        if (s['lat'] != null && s['lng'] != null) {
          s['distance'] = dist.as(LengthUnit.Meter, widget.userLocation,
              LatLng(s['lat'] as double, s['lng'] as double));
        } else {
          s['distance'] = double.infinity;
        }
      }
      raw.sort((a, b) =>
          (a['distance'] as double).compareTo(b['distance'] as double));
      if (mounted) setState(() { _stations = raw; _staticLoading = false; });
      _loadLive();
    } catch (e) {
      if (mounted) setState(() => _staticLoading = false);
    }
  }

  Future<void> _loadLive({bool forceRefresh = false}) async {
    if (_liveLoading) return;
    if (!forceRefresh && _liveLastFetched != null &&
        DateTime.now().difference(_liveLastFetched!).inSeconds < 60) {
      return;
    }
    setState(() { _liveLoading = true; _liveError = null; });
    try {
      final list = await ApiService.getYouBikeStatus('Chiayi');
      final map = <String, YouBikeAvailability>{};

      for (final a in list) { map[a.stationUID] = a; }
      if (mounted) {
        setState(() {
          _liveMap = map;
          _liveLoading = false;
          _liveUpdatedAt = DateTime.now();
          _liveLastFetched = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) setState(() { _liveLoading = false; _liveError = e.toString(); });
    }
  }

  void _showStationDetail(Map<String, dynamic> s, AppStateManager appState) {
    final uid = s['StationUID'] as String? ?? '';
    final live = _liveMap[uid];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: widget.color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.directions_bike, color: widget.color)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  (appState.currentLang == 'en' && s['NameEn'] != null && s['NameEn'].toString().isNotEmpty)
                      ? s['NameEn']
                      : s['name'].toString().replaceFirst('YouBike2.0_', ''),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
              ),
              Text(
                  (appState.currentLang == 'en' && s['AddressEn'] != null && s['AddressEn'].toString().isNotEmpty)
                      ? s['AddressEn']
                      : (s['Address'] ?? ''),
                  style: TextStyle(color: Colors.grey[500], fontSize: 12)
              ),
            ])),
          ]),
          const SizedBox(height: 16),
          if (live != null) Row(children: [
            Expanded(child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                  color: live.rentBikes > 0 ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                Text('${live.rentBikes}', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold,
                    color: live.rentBikes > 0 ? Colors.green[700] : Colors.grey)),
                Text(appState.t('可借'), style: TextStyle(fontSize: 12,
                    color: live.rentBikes > 0 ? Colors.green[600] : Colors.grey)),
              ]),
            )),
            const SizedBox(width: 10),
            Expanded(child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                  color: live.returnBikes > 0 ? Colors.blue.withOpacity(0.1) : Colors.grey.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                Text('${live.returnBikes}', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold,
                    color: live.returnBikes > 0 ? Colors.blue[700] : Colors.grey)),
                Text(appState.t('可還'), style: TextStyle(fontSize: 12,
                    color: live.returnBikes > 0 ? Colors.blue[600] : Colors.grey)),
              ]),
            )),
            const SizedBox(width: 10),
            Expanded(child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: Colors.grey.withOpacity(0.06), borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                Text('${s['Capacity'] ?? '-'}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black54)),
                Text(appState.t('總車位'), style: const TextStyle(fontSize: 12, color: Colors.black45)),
              ]),
            )),
          ])
          else
            Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: Colors.grey.withOpacity(0.06), borderRadius: BorderRadius.circular(12)),
                child: Center(child: Text(appState.t('即時資料載入中…'), style: TextStyle(color: Colors.grey[400])))),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final appState = Provider.of<AppStateManager>(context);

    return Column(children: [
      SizedBox(
        height: 220,
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.userLocation,
              initialZoom: 15.5,
              onPositionChanged: (camera, _) {
                if (mounted) setState(() => _mapBounds = camera.visibleBounds);
              },
            ),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.explore_chiayi'),
              MarkerLayer(markers: [
                Marker(point: widget.userLocation, width: 40, height: 40,
                    child: Container(decoration: BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 6, offset: Offset(0, 2))]), child: const Icon(Icons.my_location, color: Colors.white, size: 22))),

                ...() {
                  final normalMarkers = <Marker>[];
                  Marker? highlightedMarker;

                  for (final s in _stations) {
                    if (s['lat'] == null) continue;
                    if (_mapBounds != null && !_mapBounds!.contains(LatLng(s['lat'] as double, s['lng'] as double))) continue;

                    final uid = s['StationUID'] as String? ?? '';
                    final live = _liveMap[uid];
                    final rentable = live?.rentBikes ?? -1;

                    final statusColor = live == null ? widget.color : (rentable == 0 ? Colors.grey : (rentable <= 3 ? Colors.orange : Colors.green));
                    final isSelected = _selectedStation == s;

                    final marker = Marker(
                      point: LatLng(s['lat'] as double, s['lng'] as double),
                      width: isSelected ? 64 : 36,
                      height: isSelected ? 64 : 36,
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selectedStation = s);
                          final index = _stations.indexOf(s);
                          if (index != -1 && _scrollController.hasClients) {
                            _scrollController.animateTo(
                              index * 125.0,
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeOutQuart,
                            );
                          }
                          _mapController.move(LatLng(s['lat'] as double, s['lng'] as double), 16);
                          _showStationDetail(s, appState);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.elasticOut,
                          decoration: BoxDecoration(
                            color: isSelected ? statusColor : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: isSelected ? Colors.white : statusColor, width: isSelected ? 4 : 2),
                            boxShadow: [
                              BoxShadow(
                                color: isSelected ? statusColor.withOpacity(0.6) : Colors.black26,
                                blurRadius: isSelected ? 12 : 4,
                                spreadRadius: isSelected ? 4 : 0,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Icon(Icons.directions_bike, color: isSelected ? Colors.white : statusColor, size: isSelected ? 30 : 18),
                        ),
                      ),
                    );

                    if (isSelected) highlightedMarker = marker;
                    else normalMarkers.add(marker);
                  }

                  if (highlightedMarker != null) normalMarkers.add(highlightedMarker);
                  return normalMarkers;
                }(),
              ]),
            ],
          ),
        ),
      ),

      Container(
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
            color: widget.color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: widget.color.withOpacity(0.2))),
        child: Row(children: [
          Icon(Icons.bolt, color: widget.color, size: 18),
          const SizedBox(width: 6),
          Expanded(child: _liveError != null
              ? Text(
              _liveError!.contains('429') || _liveError!.contains('限流') || _liveError!.contains('rate')
                  ? appState.t('TDX 限流，請稍後重試')
                  : '${appState.t('錯誤：')}$_liveError',
              style: TextStyle(color: Colors.red[700], fontSize: 11))
              : _liveLoading
              ? Text(appState.t('正在抓取即時車位...'), style: TextStyle(color: widget.color, fontSize: 13))
              : Text(
            _liveUpdatedAt != null
                ? '${appState.t('即時車位已更新')}（${_liveUpdatedAt!.hour.toString().padLeft(2,'0')}:${_liveUpdatedAt!.minute.toString().padLeft(2,'0')}）'
                : appState.t('即時車位未載入'),
            style: TextStyle(color: widget.color, fontSize: 13, fontWeight: FontWeight.w500),
          )),
          IconButton(
            icon: _liveLoading
                ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: widget.color))
                : Icon(Icons.refresh, color: widget.color, size: 18),
            onPressed: _liveLoading ? null : () => _loadLive(forceRefresh: true),
            padding: EdgeInsets.zero, constraints: const BoxConstraints(),
          ),
        ]),
      ),

      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        child: Row(children: [
          Icon(Icons.sort, color: widget.color),
          const SizedBox(width: 8),
          Text(appState.t('依距離排序'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
      ),

      Expanded(
        child: _staticLoading
            ? const LoadingFenWidget()
            : ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          physics: const BouncingScrollPhysics(),
          itemCount: _stations.length,
          itemBuilder: (context, i) {
            final s = _stations[i];
            final uid = s['StationUID'] as String? ?? '';
            final live = _liveMap[uid];
            final distM = (s['distance'] as double?) ?? double.infinity;
            final distStr = distM == double.infinity ? '-' : '${distM.toStringAsFixed(0)} ${appState.t('公尺')}';
            final capacity = s['Capacity'] ?? '-';
            final isSelected = _selectedStation == s;

            return GestureDetector(
              onTap: () {
                setState(() => _selectedStation = s);
                if (s['lat'] != null) {
                  _mapController.move(LatLng(s['lat'] as double, s['lng'] as double), 16);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: isSelected
                      ? Border.all(color: widget.color.withOpacity(0.6), width: 1.5)
                      : Border.all(color: Colors.transparent, width: 1.5),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8)],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: widget.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.directions_bike, color: widget.color, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              (appState.currentLang == 'en' && s['NameEn'] != null && s['NameEn'].isNotEmpty)
                                  ? s['NameEn']
                                  : s['name'].toString().replaceFirst('YouBike2.0_', ''),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)
                          ),
                          Text('$distStr  ·  ${appState.t('總車位')} $capacity',
                              style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                        ],
                      )),
                    ]),
                    const SizedBox(height: 10),
                    if (_liveLoading)
                      Row(children: [
                        SizedBox(width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: widget.color)),
                        const SizedBox(width: 8),
                        Text(appState.t('載入即時車位中…'), style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                      ])
                    else if (live != null)
                      Row(children: [
                        Expanded(child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: live.rentBikes > 0
                                ? Colors.green.withOpacity(0.1)
                                : Colors.grey.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(children: [
                            Text(
                              '${live.rentBikes}',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: live.rentBikes > 0 ? Colors.green[700] : Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.directions_bike, size: 12,
                                  color: live.rentBikes > 0 ? Colors.green[600] : Colors.grey),
                              const SizedBox(width: 3),
                              Text(appState.t('可借'), style: TextStyle(
                                  fontSize: 11,
                                  color: live.rentBikes > 0 ? Colors.green[600] : Colors.grey)),
                            ]),
                          ]),
                        )),
                        const SizedBox(width: 8),
                        Expanded(child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: live.returnBikes > 0
                                ? Colors.blue.withOpacity(0.1)
                                : Colors.grey.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(children: [
                            Text(
                              '${live.returnBikes}',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: live.returnBikes > 0 ? Colors.blue[700] : Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Icon(Icons.lock_open, size: 12,
                                  color: live.returnBikes > 0 ? Colors.blue[600] : Colors.grey),
                              const SizedBox(width: 3),
                              Text(appState.t('可還'), style: TextStyle(
                                  fontSize: 11,
                                  color: live.returnBikes > 0 ? Colors.blue[600] : Colors.grey)),
                            ]),
                          ]),
                        )),
                      ])
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(appState.t('即時車位未載入'),
                              style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                        ),
                      ),
                  ],
                ),
              ),
            ).animate().slideY(begin: 0.1, end: 0, delay: (i * 40).ms).fadeIn();
          },
        ),
      ),
    ]);
  }
}

class _TRATab extends StatefulWidget {
  final LatLng userLocation;
  final Color color;
  const _TRATab({required this.userLocation, required this.color});
  @override
  State<_TRATab> createState() => _TRATabState();
}

class _TRATabState extends State<_TRATab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final MapController _mapController = MapController();
  List<Map<String, dynamic>> _stations = [];
  Map<String, dynamic>? _selected;
  bool _staticLoading = true;
  int _direction = 0;

  List<TRALiveBoard> _liveBoard = [];
  bool _liveLoading = false;
  String? _liveError;
  final Map<String, DateTime> _liveLastFetched = {};
  LatLngBounds? _mapBounds;

  List<BusAlert> _traAlerts = [];

  @override
  void initState() {
    super.initState();
    _loadStatic();
    _loadTraAlerts();
  }

  Future<void> _loadTraAlerts() async {
    try {
      final list = await ApiService.getTRAAlert();
      if (mounted) {
        setState(() {
          _traAlerts = list
              .map((e) => BusAlert.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        });
      }
    } catch (e) {
      print("❌ 台鐵通阻 API 發生錯誤: $e");
    }
  }

  Future<void> _loadStatic() async {
    setState(() => _staticLoading = true);
    try {
      final raw = await FirebaseTrafficService.fetch(
        collection: 'TRAStations',
        nameField: 'NameZh',
        extraFields: const ['Address', 'Phone', 'StationID', 'NameEn'],
      );
      const dist = Distance();
      for (final s in raw) {
        if (s['lat'] != null && s['lng'] != null) {
          s['distance'] = dist.as(LengthUnit.Meter, widget.userLocation,
              LatLng(s['lat'] as double, s['lng'] as double));
        } else { s['distance'] = double.infinity; }
      }
      raw.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
      if (mounted) {
        setState(() { _stations = raw; _staticLoading = false; });
        if (raw.isNotEmpty) _selectStation(raw.first);
      }
    } catch (e) {
      if (mounted) setState(() => _staticLoading = false);
    }
  }

  void _selectStation(Map<String, dynamic> s) {
    setState(() => _selected = s);
    if (s['lat'] != null) {
      _mapController.move(LatLng(s['lat'] as double, s['lng'] as double), 14.0);
    }
    final stationId = s['StationID'] as String?;
    if (stationId != null) _loadLive(stationId);
  }

  Future<void> _loadLive(String stationId, {bool forceRefresh = false}) async {
    if (_liveLoading) return;

    final last = _liveLastFetched[stationId];
    if (!forceRefresh && last != null &&
        DateTime.now().difference(last).inSeconds < 60) {
      return;
    }
    setState(() { _liveLoading = true; _liveError = null; _liveBoard = []; });
    try {
      final data = await ApiService.getTRALive(stationId);
      data.sort((a, b) => a.scheduledDepartureTime.compareTo(b.scheduledDepartureTime));
      if (mounted) {
        setState(() {
          _liveBoard = data;
          _liveLoading = false;
          _liveLastFetched[stationId] = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) setState(() { _liveLoading = false; _liveError = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final appState = Provider.of<AppStateManager>(context);
    return Column(children: [
      _MarqueeAlertBar(alerts: _traAlerts, color: widget.color),
      SizedBox(
        height: 200,
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.userLocation,
              initialZoom: 13.0,
              onPositionChanged: (camera, _) {
                if (mounted) setState(() => _mapBounds = camera.visibleBounds);
              },
            ),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.explore_chiayi'),
              MarkerLayer(markers: [
                Marker(point: widget.userLocation,
                    child: Container(decoration: BoxDecoration(color: Colors.redAccent,
                        shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                        child: const Icon(Icons.my_location, color: Colors.white, size: 20))),
                ..._stations.where((s) {
                  if (s['lat'] == null) return false;
                  if (_mapBounds == null) return true;
                  return _mapBounds!.contains(LatLng(s['lat'] as double, s['lng'] as double));
                }).map((s) => Marker(
                  point: LatLng(s['lat'] as double, s['lng'] as double),
                  child: GestureDetector(
                    onTap: () => _selectStation(s),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                          color: _selected == s ? widget.color : widget.color.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: widget.color, width: 2)),
                      child: Icon(Icons.train,
                          color: _selected == s ? Colors.white : widget.color, size: 16),
                    ),
                  ),
                )).toList(),
              ]),
            ],
          ),
        ),
      ),

      SizedBox(
        height: 48,
        child: _staticLoading
            ? const SizedBox()
            : ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          itemCount: _stations.length,
          itemBuilder: (context, i) {
            final s = _stations[i];
            final isSelected = _selected == s;
            return GestureDetector(
              onTap: () => _selectStation(s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                    color: isSelected ? widget.color : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: widget.color.withOpacity(0.4)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)]),
                child: Text(appState.currentLang == 'en' && s['NameEn'] != null ? s['NameEn'] : s['name'],
                    style: TextStyle(
                        color: isSelected ? Colors.white : widget.color,
                        fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            );
          },
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Container(
          decoration: BoxDecoration(
            color: widget.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              _buildDirectionTab(0, appState.t('逆行 (北上)')),
              _buildDirectionTab(1, appState.t('順行 (南下)')),
            ],
          ),
        ),
      ),
      if (_selected != null)
        Expanded(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 8, 4),
              child: Row(children: [
                Icon(Icons.train, color: widget.color, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('${appState.currentLang == 'en' && _selected!['NameEn'] != null ? _selected!['NameEn'] : _selected!['name']} ${appState.t('即時看板')}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      overflow: TextOverflow.ellipsis),
                ),
                IconButton(
                  icon: _liveLoading
                      ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: widget.color))
                      : Icon(Icons.refresh, color: widget.color, size: 20),
                  onPressed: _liveLoading ? null : () {
                    final sid = _selected?['StationID'] as String?;
                    if (sid != null) _loadLive(sid);
                  },
                ),
              ]),
            ),
            Expanded(
              child: Builder(builder: (context) {
                final filteredList = _liveBoard.where((t) => t.direction == _direction).toList();

                if (_liveLoading) return const LoadingFenWidget();
                if (_liveError != null) {
                  bool isLimit = _liveError!.contains('429') || _liveError!.contains('rate') || _liveError!.contains('限流');
                  if (isLimit) {
                    return TdxRateLimitWidget(
                      themeColor: widget.color,
                      onRetry: () {
                        final sid = _selected?['StationID'] as String?;
                        if (sid != null) _loadLive(sid, forceRefresh: true);
                      },
                    );
                  }

                  return Center(child: Text('${appState.t('即時看板載入失敗：')}\n$_liveError', textAlign: TextAlign.center, style: TextStyle(color: Colors.red[400], fontSize: 12)));
                }
                if (filteredList.isEmpty) return Center(child: Text(appState.t('目前無列車資料'), style: TextStyle(color: Colors.grey[500])));

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  physics: const BouncingScrollPhysics(),
                  itemCount: filteredList.length,
                  itemBuilder: (context, i) {
                    final train = filteredList[i];
                    final delay = train.delayTime;
                    final isDelayed = delay >= 3;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)]),
                      child: Row(children: [
                        Container(
                          width: 56, alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(color: widget.color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8)),
                          child: Text(train.trainNo, style: TextStyle(color: widget.color, fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          // 🌟 這裡使用真正的英文變數
                          Text(
                              '${(appState.currentLang == 'en' && train.trainTypeNameEn.isNotEmpty) ? train.trainTypeNameEn : train.trainTypeNameZh} → ${(appState.currentLang == 'en' && train.endingStationEn.isNotEmpty) ? train.endingStationEn : train.endingStationZh}',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)
                          ),
                          Text(train.direction == 0 ? appState.t('南向') : appState.t('北向'), style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                        ])),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(train.scheduledDepartureTime.length >= 5 ? train.scheduledDepartureTime.substring(0, 5) : train.scheduledDepartureTime,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          if (isDelayed)
                            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(6)),
                                child: Text('${appState.t('誤點')} $delay ${appState.t('分')}', style: TextStyle(color: Colors.orange[800], fontSize: 11, fontWeight: FontWeight.bold)))
                          else
                            Text(delay > 0 ? appState.t('準時 (晚 $delay 分)') : appState.t('準時'), style: TextStyle(color: Colors.green[600], fontSize: 11)),
                        ]),
                      ]),
                    ).animate().slideY(begin: 0.08, end: 0, delay: (i * 30).ms).fadeIn();
                  },
                );
              }),
            ),
          ]),
        ),

      if (_staticLoading)
        const Expanded(child: LoadingFenWidget()),
      if (_selected == null && !_staticLoading)
        Expanded(child: Center(child: Text(appState.t('請選擇一個台鐵站')))),
    ]);
  }
  Widget _buildDirectionTab(int dir, String label) {
    final isSelected = _direction == dir;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _direction = dir),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? widget.color : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: isSelected ? Colors.white : widget.color,
                  fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

class _THSRTab extends StatefulWidget {
  final LatLng userLocation;
  final Color color;
  const _THSRTab({required this.userLocation, required this.color});
  @override
  State<_THSRTab> createState() => _THSRTabState();
}

class _THSRTabState extends State<_THSRTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<Map<String, dynamic>> _stations = [];
  Map<String, dynamic>? _selected;
  bool _staticLoading = true;

  List<THSRTimetable> _timetable = [];
  bool _ttLoading = false;
  String? _ttError;
  int _direction = 0;
  final Map<String, DateTime> _ttLastFetched = {};
  final ScrollController _listScrollController = ScrollController();
  List<BusAlert> _thsrAlerts = [];

  @override
  void initState() {
    super.initState();
    _loadStatic();
    _loadThsrAlerts();
  }

  Future<void> _loadThsrAlerts() async {
    try {
      final list = await ApiService.getTHSRAlert();
      if (mounted) {
        setState(() {
          _thsrAlerts = list
              .map((e) => BusAlert.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        });
      }
    } catch (e) {
      print("❌ THSR Alert API Error: $e");
    }
  }

  Future<void> _loadStatic() async {
    try {
      final raw = await FirebaseTrafficService.fetch(
        collection: 'THSRStations',
        nameField: 'NameZh',
        extraFields: const ['NameEn', 'StationID'],
      );
      const dist = Distance();
      for (final s in raw) {
        if (s['lat'] != null && s['lng'] != null) {
          s['distance'] = dist.as(LengthUnit.Meter, widget.userLocation,
              LatLng(s['lat'] as double, s['lng'] as double));
        } else { s['distance'] = double.infinity; }
      }
      raw.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
      if (mounted) {
        setState(() { _stations = raw; _staticLoading = false; });
        if (raw.isNotEmpty) _selectStation(raw.first);
      }
    } catch (e) {
      if (mounted) setState(() => _staticLoading = false);
    }
  }

  void _selectStation(Map<String, dynamic> s) {
    if (_selected == s) return;

    setState(() { _selected = s; _timetable = []; _ttError = null; });
    _loadTimetable(s);
  }

  Future<void> _loadTimetable(Map<String, dynamic> s, {bool forceRefresh = false}) async {
    final rawId = s['StationID']?.toString();
    final stationId = rawId != null ? rawId.padLeft(4, '0') : null;

    if (stationId == null || stationId == '0000') {
      setState(() { _ttError = '資料庫中缺少 StationID (目前抓到: $rawId)'; });
      return;
    }
    if (_ttLoading) return;

    setState(() { _ttLoading = true; _ttError = null; });
    try {
      final today = DateTime.now();
      final dateStr = '${today.year}-${today.month.toString().padLeft(2,'0')}-${today.day.toString().padLeft(2,'0')}';

      final data = await ApiService.getTHSRTimetable(stationId, dateStr);

      data.sort((a, b) => a.departureTime.compareTo(b.departureTime));
      data.sort((a, b) => a.departureTime.compareTo(b.departureTime));
      if (mounted) {
        setState(() {
          _timetable = data;
          _ttLoading = false;
          _ttLastFetched[stationId] = DateTime.now();
        });

        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToNearest());
      }

    } catch (e) {
      if (mounted) setState(() { _ttLoading = false; _ttError = e.toString(); });
    }
  }

  void _scrollToNearest() {
    final now = TimeOfDay.now();
    int nearestIndex = 0;

    for (int i = 0; i < _filtered.length; i++) {
      final parts = _filtered[i].departureTime.split(':');
      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = int.tryParse(parts[1]) ?? 0;

      if (hour > now.hour || (hour == now.hour && minute >= now.minute)) {
        nearestIndex = i;
        break;
      }
    }

    if (_listScrollController.hasClients) {
      _listScrollController.animateTo(
        nearestIndex * 80.0,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    }
  }
  List<THSRTimetable> get _filtered =>
      _timetable.where((t) => t.direction == _direction).toList();

  void _openThsrMap() {
    final stationId = _selected?['StationID'] as String?;
    if (stationId == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ThsrMapBottomSheet(
        stationId: stationId,
        themeColor: widget.color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final appState = Provider.of<AppStateManager>(context);
    final today = DateTime.now();
    final dateLabel = '${today.month}/${today.day}';

    return Column(children: [
      _MarqueeAlertBar(alerts: _thsrAlerts, color: widget.color),
      Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: _staticLoading
            ? const SizedBox()
            : Wrap(
          spacing: 8, runSpacing: 8,
          children: _stations.map((s) {
            final isSelected = _selected == s;
            return GestureDetector(
              onTap: () => _selectStation(s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                    color: isSelected ? widget.color : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: widget.color.withOpacity(0.5), width: 1.5),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.directions_railway,
                      color: isSelected ? Colors.white : widget.color, size: 20),
                  const SizedBox(height: 2),
                  Text(appState.currentLang == 'en' && s['NameEn'] != null ? s['NameEn'] : s['name'],
                      style: TextStyle(
                          color: isSelected ? Colors.white : widget.color,
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  if (s['distance'] != null && (s['distance'] as double) < double.infinity)
                    Text(
                      '${((s['distance'] as double) / 1000).toStringAsFixed(1)} ${appState.t('公里')}',
                      style: TextStyle(
                          color: isSelected ? Colors.white70 : Colors.grey[500],
                          fontSize: 11),
                    ),
                ]),
              ),
            );
          }).toList(),
        ),
      ),
      if (_staticLoading)
        const Expanded(child: LoadingFenWidget()),
      if (_selected != null) ...[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                _openThsrMap();
              },
              icon: const Icon(Icons.map),
              label: Text(appState.t('查看站區平面圖與出口資訊'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.color.withOpacity(0.1),
                foregroundColor: widget.color,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(children: [
            Icon(Icons.directions_railway, color: widget.color, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Text('${appState.currentLang == 'en' && _selected!['NameEn'] != null ? _selected!['NameEn'] : _selected!['name']} · $dateLabel ${appState.t('時刻表')}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  overflow: TextOverflow.ellipsis),
            ),
            Container(
              decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                GestureDetector(
                  onTap: () => setState(() => _direction = 0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                        color: _direction == 0 ? widget.color : Colors.transparent,
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(appState.t('南下'), style: TextStyle(
                        color: _direction == 0 ? Colors.white : widget.color,
                        fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _direction = 1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                        color: _direction == 1 ? widget.color : Colors.transparent,
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(appState.t('北上'), style: TextStyle(
                        color: _direction == 1 ? Colors.white : widget.color,
                        fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
              ]),
            ),
            IconButton(
              icon: _ttLoading
                  ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: widget.color))
                  : Icon(Icons.refresh, color: widget.color, size: 20),
              onPressed: _ttLoading ? null : () => _loadTimetable(_selected!),
            ),
          ]),
        ),

        Expanded(
          child: _ttLoading
              ? const LoadingFenWidget()
              : _ttError != null
              ? Builder(
              builder: (context) {
                bool isLimit = _ttError!.contains('限流') || _ttError!.contains('429') || _ttError!.contains('rate');
                if (isLimit) {
                  return TdxRateLimitWidget(
                    themeColor: widget.color,
                    onRetry: () => _loadTimetable(_selected!, forceRefresh: true),
                  );
                }
                return Center(child: Text('${appState.t('時刻表載入失敗：')}\n$_ttError', textAlign: TextAlign.center, style: TextStyle(color: Colors.red[400], fontSize: 12)));
              }
          )
              : _filtered.isEmpty
              ? Center(child: Text('${appState.t('今日無')}${_direction == 0 ? appState.t("南下") : appState.t("北上")}${appState.t('班次')}',
              style: TextStyle(color: Colors.grey[500])))
              : ListView.builder(
            controller: _listScrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            physics: const BouncingScrollPhysics(),
            itemCount: _filtered.length,
            itemBuilder: (context, i) {
              final t = _filtered[i];
              final now = TimeOfDay.now();
              final depParts = t.departureTime.split(':');
              final isPast = depParts.length >= 2 &&
                  (int.tryParse(depParts[0]) ?? 0) < now.hour ||
                  ((int.tryParse(depParts[0]) ?? 0) == now.hour &&
                      (int.tryParse(depParts[1]) ?? 0) < now.minute);
              return AnimatedOpacity(
                opacity: isPast ? 0.4 : 1.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                      color: isPast ? Colors.grey[50] : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)]),
                  child: Row(children: [
                    Container(
                      width: 56, alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                          color: isPast ? Colors.grey[200] : widget.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(t.trainNo,
                          style: TextStyle(
                              color: isPast ? Colors.grey : widget.color,
                              fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // 🌟 這裡使用真正的英文變數
                      Text(
                          '${(appState.currentLang == 'en' && t.startingStationNameEn.isNotEmpty) ? t.startingStationNameEn : t.startingStationName} → ${(appState.currentLang == 'en' && t.endingStationNameEn.isNotEmpty) ? t.endingStationNameEn : t.endingStationName}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)
                      ),
                      Text('${appState.t('抵達')} ${t.arrivalTime}', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    ])),
                    Text(t.departureTime,
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18,
                            color: isPast ? Colors.grey : widget.color)),
                  ]),
                ),
              ).animate().slideY(begin: 0.08, end: 0, delay: (i * 25).ms).fadeIn();
            },
          ),
        ),
      ],
    ]);
  }
}

class _ThsrMapBottomSheet extends StatelessWidget {
  final String stationId;
  final Color themeColor;

  const _ThsrMapBottomSheet({
    Key? key,
    required this.stationId,
    required this.themeColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateManager>(context);
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          Text(appState.t('站區平面圖'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: SfPdfViewer.network(
                'https://www.thsrc.com.tw/event/map/Chiayi.pdf',
                canShowScrollHead: false,
                canShowScrollStatus: false,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BusMapListTab extends StatefulWidget {
  final LatLng userLocation;
  final Color themeColor;
  const _BusMapListTab(
      {required this.userLocation, required this.themeColor});

  @override
  State<_BusMapListTab> createState() => _BusMapListTabState();
}

class _BusMapListTabState extends State<_BusMapListTab> {
  final MapController _mapController = MapController();
  Map<String, dynamic>? _selectedBus;
  int _currentDir = 0;

  List<Map<String, dynamic>> _busRoutes = [];
  bool _isLoading = true;
  LatLngBounds? _mapBounds;

  List<BusEta> _etaList = [];
  bool _etaLoading = false;
  String? _etaError;
  final Map<String, DateTime> _etaLastFetched = {};

  List<BusAlert> _alerts = [];
  String _searchQuery = '';
  int _filterType = 0;

  List<Map<String, dynamic>> get _displayRoutes {
    return _busRoutes.where((bus) {
      final name = bus['name'] as String;
      final matchSearch = _searchQuery.isEmpty || name.contains(_searchQuery);

      final uid = bus['routeUID'] as String;
      bool matchFilter = true;
      if (_filterType == 1) matchFilter = uid.startsWith('CYI');
      if (_filterType == 2) matchFilter = uid.startsWith('CYQ');

      return matchSearch && matchFilter;
    }).toList();
  }

  static const String _cacheKey = 'cache_BusRoutes_v1001';
  static const int _cacheTtlMinutes = 60;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    try {
      final list = await ApiService.getBusAlert('Chiayi');
      if (mounted) {
        setState(() => _alerts = list
            .map((e) => BusAlert.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList());
      }
    } catch (_) {}
  }

  Future<void> _loadRoutes({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();

    if (forceRefresh) {
      await prefs.remove(_cacheKey);
      await prefs.remove('${_cacheKey}_ts');
    }

    final cachedJson = prefs.getString(_cacheKey);
    final cachedAt = prefs.getInt('${_cacheKey}_ts') ?? 0;
    final ageMin = (DateTime.now().millisecondsSinceEpoch - cachedAt) / 60000;

    if (cachedJson != null && ageMin < _cacheTtlMinutes && !forceRefresh) {
      final List decoded = jsonDecode(cachedJson);
      if (mounted) {
        setState(() {
          _busRoutes = decoded.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final allSnap = await FirebaseFirestore.instance.collection('PointsOfInterest3').get();

      final routeDocs = <String, Map<String, dynamic>>{};
      final seqDocs = <Map<String, dynamic>>[];

      for (final doc in allSnap.docs) {
        final data = doc.data();
        if (data.containsKey('Stops')) {
          seqDocs.add(data);
        } else if (data.containsKey('RouteNameZh')) {
          final uid = data['RouteUID'] as String? ?? doc.id;
          routeDocs[uid] = data;
        }
      }

      final Map<String, Map<String, dynamic>> routeMap = {};

      for (final seqData in seqDocs) {
        final routeUID = seqData['RouteUID'] as String? ?? '';

        final parentRoute = routeDocs[routeUID] ?? {};
        final mainRouteName = parentRoute['RouteNameZh'] as String? ?? routeUID;
        final mainRouteNameEn = parentRoute['RouteNameEn'] as String? ?? '';

        final subRouteName = seqData['SubRouteName'] as String?;
        final subRouteNameEn = seqData['SubRouteNameEn'] as String?;
        final direction = seqData['Direction'] as int? ?? 0;

        String displayName = mainRouteName;
        String displayNameEn = mainRouteNameEn;
        if (subRouteName != null && subRouteName.isNotEmpty && subRouteName != mainRouteName) {
          displayName = subRouteName;
          displayNameEn = (subRouteNameEn != null && subRouteNameEn.isNotEmpty) ? subRouteNameEn : displayNameEn;
        }

        final depZh = parentRoute['DepartureStopZh'] ?? '';
        final destZh = parentRoute['DestinationStopZh'] ?? '';
        final depEn = parentRoute['DepartureStopEn'] ?? depZh;
        final destEn = parentRoute['DestinationStopEn'] ?? destZh;

        final descZh = '$depZh ⇌ $destZh';
        final descEn = '$depEn ⇌ $destEn';

        final stopsRaw = seqData['Stops'] as List<dynamic>? ?? [];
        final sorted = List<Map<String, dynamic>>.from(
            stopsRaw.map((s) => Map<String, dynamic>.from(s as Map)));

        sorted.sort((a, b) => ((a['StopSequence'] ?? 0) as int).compareTo((b['StopSequence'] ?? 0) as int));

        List<Map<String, dynamic>> stops = [];
        for (final s in sorted) {
          double? lat;
          double? lng;
          final locData = s['Location'];
          if (locData != null) {
            if (locData is GeoPoint) {
              lat = locData.latitude; lng = locData.longitude;
            } else if (locData is Map) {
              lat = (locData['latitude'] as num?)?.toDouble();
              lng = (locData['longitude'] as num?)?.toDouble();
            }
          }

          stops.add({
            'name': s['StopNameZh'] ?? '',
            'StopNameEn': s['StopNameEn'] ?? '',
            'stopUID': s['StopUID'] ?? '',
            'sequence': s['StopSequence'] ?? 0,
            'boarding': s['StopBoarding'] ?? 0,
            'lat': lat,
            'lng': lng,
          });
        }

        final key = displayName;
        if (!routeMap.containsKey(key)) {
          routeMap[key] = {
            'routeUID': routeUID,
            'name': displayName,
            'nameEn': displayNameEn,
            'desc': descZh,
            'descEn': descEn,
            'directions': <String, List<Map<String, dynamic>>>{},
          };
        }
        (routeMap[key]!['directions'] as Map)[direction.toString()] = stops;
      }

      final List<Map<String, dynamic>> routes = routeMap.values.toList();
      routes.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

      await prefs.setString(_cacheKey, jsonEncode(routes));
      await prefs.setInt('${_cacheKey}_ts', DateTime.now().millisecondsSinceEpoch);

      if (mounted) {
        setState(() {
          _busRoutes = routes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showRouteOnMap(Map<String, dynamic> bus, int dir) {
    setState(() {
      if (_selectedBus != bus) {
        _etaList = [];
        _etaError = null;
      }
      _selectedBus = bus;
      _currentDir = dir;
    });

    final directions = bus['directions'] as Map? ?? {};
    final stops = directions[_currentDir.toString()] as List? ?? [];

    if (stops.isNotEmpty && stops[0]['lat'] != null) {
      _mapController.move(LatLng(stops[0]['lat'] as double, stops[0]['lng'] as double), 14.0);
    }
    _loadEta(bus);
  }

  Future<void> _loadEta(Map<String, dynamic> bus, {bool forceRefresh = false}) async {
    final routeUID = bus['routeUID'] as String? ?? '';
    if (routeUID.isEmpty) return;
    if (_etaLoading) return;

    final lastFetched = _etaLastFetched[routeUID];
    if (!forceRefresh && lastFetched != null && DateTime.now().difference(lastFetched).inSeconds < 60) return;

    setState(() { _etaLoading = true; _etaError = null; });
    try {
      final city = routeUID.startsWith('CYQ') ? 'ChiayiCounty' : 'Chiayi';
      final list = await ApiService.getBusEta(city, routeUID);
      if (mounted) {
        setState(() {
          _etaList = list.cast<BusEta>();
          _etaLoading = false;
          _etaLastFetched[routeUID] = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) setState(() { _etaLoading = false; _etaError = e.toString(); });
    }
  }

  Widget _buildDirectionTab(int index, String title, Map<String, dynamic> bus) {
    final hasData = (bus['directions'] as Map).containsKey(index.toString());
    if (!hasData) return const SizedBox.shrink();
    final isSelected = _currentDir == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _showRouteOnMap(bus, index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? widget.themeColor : widget.themeColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? widget.themeColor : Colors.transparent),
          ),
          child: Text(title, textAlign: TextAlign.center, style: TextStyle(color: isSelected ? Colors.white : widget.themeColor, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      ),
    );
  }

  Widget _buildFilterTab(int index, String title) {
    final isSelected = _filterType == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _filterType = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(color: isSelected ? widget.themeColor : Colors.transparent, borderRadius: BorderRadius.circular(20)),
          child: Text(title, textAlign: TextAlign.center, style: TextStyle(color: isSelected ? Colors.white : widget.themeColor, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateManager>(context);
    List<LatLng> routePoints = [];
    List<dynamic> currentStops = [];

    if (_selectedBus != null) {
      final directions = _selectedBus!['directions'] as Map? ?? {};
      currentStops = directions[_currentDir.toString()] as List? ?? [];
      for (final stop in currentStops) {
        if (stop['lat'] != null && stop['lng'] != null) {
          routePoints.add(LatLng(stop['lat'] as double, stop['lng'] as double));
        }
      }
    }

    return Column(
      children: [
        _MarqueeAlertBar(alerts: _alerts, color: widget.themeColor),
        SizedBox(
          height: 240,
          child: ClipRRect(
            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: widget.userLocation,
                initialZoom: 15.5,
                onPositionChanged: (camera, _) { if (mounted) setState(() => _mapBounds = camera.visibleBounds); },
              ),
              children: [
                TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.explore_chiayi'),
                if (routePoints.isNotEmpty)
                  PolylineLayer(polylines: [Polyline(points: routePoints, color: widget.themeColor, strokeWidth: 4.0, borderColor: Colors.white, borderStrokeWidth: 1.5)]),
                MarkerLayer(markers: [
                  Marker(
                      point: widget.userLocation,
                      child: Container(decoration: BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)), child: const Icon(Icons.my_location, color: Colors.white, size: 20))),
                  if (_selectedBus != null)
                    ...currentStops.where((s) {
                      if (s['lat'] == null || s['lng'] == null) return false;
                      if (_mapBounds == null) return true;
                      return _mapBounds!.contains(LatLng(s['lat'] as double, s['lng'] as double));
                    }).toList().asMap().entries.map((entry) {
                      final i = entry.key; final stop = entry.value;
                      final isFirst = i == 0; final isLast = i == currentStops.length - 1;
                      return Marker(
                        point: LatLng(stop['lat'] as double, stop['lng'] as double),
                        child: GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                title: Text((appState.currentLang == 'en' && stop['StopNameEn'] != null && stop['StopNameEn'].toString().isNotEmpty) ? stop['StopNameEn'] : stop['name']),
                                content: Text('${appState.t('站序：第')} ${stop['sequence']} ${appState.t('站')}\n${appState.t('站點代碼：')}${stop['stopUID']}'),
                                actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(appState.t('確定')))],
                              ),
                            );
                          },
                          child: Container(
                            width: isFirst || isLast ? 28 : 20, height: isFirst || isLast ? 28 : 20,
                            decoration: BoxDecoration(color: isFirst ? Colors.green : isLast ? Colors.red : widget.themeColor, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                            child: Icon(Icons.directions_bus, color: Colors.white, size: isFirst || isLast ? 16 : 12),
                          ),
                        ),
                      );
                    }).toList(),
                ]),
              ],
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: appState.t('搜尋公車路線 (例如: 中山幹線)'),
                  prefixIcon: Icon(Icons.search, color: widget.themeColor),
                  filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(color: widget.themeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: Row(children: [ _buildFilterTab(0, appState.t('全部路線')), _buildFilterTab(1, appState.t('嘉市公車')), _buildFilterTab(2, appState.t('嘉縣公車')) ]),
              ),
            ],
          ),
        ),

        Expanded(
          child: _isLoading
              ? const LoadingFenWidget()
              : _displayRoutes.isEmpty
              ? Center(child: Text(appState.t('目前沒有公車路線資料'), style: TextStyle(color: Colors.grey[500])))
              : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            physics: const BouncingScrollPhysics(),
            itemCount: _displayRoutes.length,
            itemBuilder: (context, index) {
              final bus = _displayRoutes[index];
              final isSelected = _selectedBus == bus;
              final directions = bus['directions'] as Map? ?? {};
              final defaultStops = directions['0'] as List? ?? directions.values.firstOrNull as List? ?? [];

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: isSelected ? Border.all(color: widget.themeColor.withOpacity(0.5), width: 1.5) : null, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    onExpansionChanged: (expand){ if(expand) _showRouteOnMap(bus, directions.containsKey('0') ? 0 : 1); },
                    leading: CircleAvatar(backgroundColor: widget.themeColor.withOpacity(0.15), child: Icon(Icons.directions_bus, color: widget.themeColor)),
                    title: Text(
                        (appState.currentLang == 'en' && bus['nameEn'] != null && bus['nameEn'].toString().isNotEmpty) ? bus['nameEn'] : bus['name'],
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            '${(appState.currentLang == 'en' && bus['descEn'] != null && bus['descEn'].toString().length > 3) ? bus['descEn'] : bus['desc']}  ·  ${defaultStops.length} ${appState.t('站')}',
                            style: TextStyle(color: Colors.grey[600], fontSize: 13)
                        ),
                        if (isSelected && _etaLoading)
                          Padding(padding: const EdgeInsets.only(top: 4), child: Row(children: [ SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: widget.themeColor)), const SizedBox(width: 6), Text(appState.t('載入即時到站…'), style: TextStyle(color: widget.themeColor, fontSize: 11)) ]))
                        else if (isSelected && _etaError != null)
                          Padding(padding: const EdgeInsets.only(top: 4), child: Text(_etaError!.contains('429') || _etaError!.contains('rate') ? appState.t('TDX限流，請稍候重試') : appState.t('ETA 載入失敗'), style: TextStyle(color: Colors.red[400], fontSize: 11)))
                        else if (isSelected && _etaList.isNotEmpty)
                            Padding(padding: const EdgeInsets.only(top: 4), child: Text(appState.t('即時到站已更新 ✓'), style: TextStyle(color: Colors.green[600], fontSize: 11, fontWeight: FontWeight.w500))),
                      ],
                    ),
                    trailing: IconButton(icon: Icon(Icons.map, color: isSelected ? widget.themeColor : Colors.grey[400], size: 26), onPressed: () => _showRouteOnMap(bus, directions.containsKey('0') ? 0 : 1)),
                    children: [
                      if (isSelected)
                        Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 12), child: Row(children: [ _buildDirectionTab(0, appState.t('去程'), bus), _buildDirectionTab(1, appState.t('返程'), bus) ])),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 280),
                        decoration: BoxDecoration(color: Colors.grey[50], borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20))),
                        child: currentStops.isEmpty
                            ? Padding(padding: const EdgeInsets.all(16), child: Text(appState.t('此路線尚無站牌資料'), textAlign: TextAlign.center))
                            : ListView.builder(
                          shrinkWrap: true, physics: const BouncingScrollPhysics(), itemCount: currentStops.length,
                          itemBuilder: (ctx, si) {
                            final stop = currentStops[si];
                            final isFirst = si == 0; final isLast = si == currentStops.length - 1;
                            return ListTile(
                              dense: true,
                              leading: _StopDot(sequence: stop['sequence'] as int, isFirst: isFirst, isLast: isLast, color: widget.themeColor),
                              title: Text(
                                  (appState.currentLang == 'en' && stop['StopNameEn'] != null && stop['StopNameEn'].toString().isNotEmpty) ? stop['StopNameEn'] : stop['name'],
                                  style: TextStyle(fontWeight: isFirst || isLast ? FontWeight.bold : FontWeight.normal, color: isFirst ? Colors.green[700] : isLast ? Colors.red[700] : Colors.black87, fontSize: 14)
                              ),
                              trailing: Builder(builder: (ctx) {
                                final stopUID = stop['stopUID'] as String? ?? '';
                                final etaItems = _etaList.where((e) => e.stopUID == stopUID && e.direction == _currentDir).toList();
                                if (_etaLoading) return SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: widget.themeColor));
                                if (etaItems.isEmpty) return Text('${appState.t('第')} ${stop['sequence']} ${appState.t('站')}', style: TextStyle(color: Colors.grey[400], fontSize: 12));
                                final firstEta = etaItems.first;
                                if (firstEta.stopStatus != 0) {
                                  final statusLabel = [appState.t('正常'), appState.t('尚未發車'), appState.t('交管'), appState.t('末班過'), appState.t('未營運')];
                                  final label = firstEta.stopStatus < statusLabel.length ? statusLabel[firstEta.stopStatus] : '—';
                                  return Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11));
                                }
                                final sec = firstEta.estimateTime ?? -1;
                                String etaStr; Color etaColor;
                                if (sec < 0) { etaStr = '—'; etaColor = Colors.grey; }
                                else if (sec < 60) { etaStr = appState.t('即將到站'); etaColor = Colors.red; }
                                else if (sec < 300) { etaStr = '${(sec / 60).ceil()} ${appState.t('分')}'; etaColor = Colors.orange; }
                                else { etaStr = '${(sec / 60).ceil()} ${appState.t('分')}'; etaColor = Colors.green[700]!; }
                                return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: etaColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)), child: Text(etaStr, style: TextStyle(color: etaColor, fontSize: 12, fontWeight: FontWeight.bold)));
                              }),
                              onTap: () {
                                if (stop['lat'] != null) { _mapController.move(LatLng(stop['lat'] as double, stop['lng'] as double), 16.0); setState(() => _selectedBus = bus); }
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().slideY(begin: 0.1, end: 0, delay: (index * 60).ms, duration: 350.ms, curve: Curves.easeOut).fadeIn();
            },
          ),
        ),
      ],
    );
  }
}

class _StopDot extends StatelessWidget {
  final int sequence;
  final bool isFirst;
  final bool isLast;
  final Color color;
  const _StopDot({required this.sequence, required this.isFirst, required this.isLast, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 24, height: 24,
          decoration: BoxDecoration(
            color: isFirst ? Colors.green : isLast ? Colors.red : color.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(color: isFirst ? Colors.green : isLast ? Colors.red : color, width: 1.5),
          ),
          child: Center(
            child: Text('$sequence', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isFirst || isLast ? Colors.white : color)),
          ),
        ),
      ]),
    );
  }
}