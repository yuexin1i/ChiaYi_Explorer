// lib/pages/spot_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/app_drawer.dart';
import '../providers/app_state.dart';

class SpotDetailPage extends StatefulWidget {
  @override
  _SpotDetailPageState createState() => _SpotDetailPageState();
}

class _SpotDetailPageState extends State<SpotDetailPage> {

  void _addToLatestItinerary(Map<String, dynamic> spotData) {
    final appState = Provider.of<AppStateManager>(context, listen: false);

    if (appState.itineraries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(appState.t('您還沒有建立任何行程！請先至行程管理頁面新增。'))));
      return;
    }

    final lastIndex = appState.itineraries.length - 1;
    final latestItinerary = appState.itineraries[lastIndex];

    final String spotName = appState.currentLang == 'en'
        ? (spotData['NameEn'] ?? spotData['NameZh'] ?? spotData['ScenicSpotName'] ?? 'Unknown Spot')
        : (spotData['NameZh'] ?? spotData['ScenicSpotName'] ?? '未知景點');

    List<dynamic> currentSpots = List.from(latestItinerary['spots']);
    currentSpots.add({
      "name": spotName,
      "time": "14:00"
    });

    appState.updateItinerarySpots(lastIndex, currentSpots);
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${appState.t('已將')} $spotName ${appState.t('加入')}「${latestItinerary['title']}」${appState.t('行程中！')}'))
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateManager>(context);
    final themeColor = appState.themeColor;
    final spotData = appState.currentSpotData;

    if (spotData == null) {
      return Scaffold(
        appBar: AppBar(title: Text(appState.t('發生錯誤'))),
        body: Center(child: Text(appState.t('找不到景點資料，請回上一頁重試。'))),
      );
    }

    final String name = appState.currentLang == 'en'
        ? (spotData['NameEn'] ?? spotData['NameZh'] ?? spotData['ScenicSpotName'] ?? 'Unknown Spot')
        : (spotData['NameZh'] ?? spotData['ScenicSpotName'] ?? appState.t('未知景點'));

    final String desc = appState.currentLang == 'en'
        ? (spotData['DescriptionDetailEn'] ?? spotData['DescriptionEn'] ?? spotData['ShortDescriptionEn'] ?? spotData['DescriptionDetail'] ?? spotData['Description'] ?? 'No description.')
        : (spotData['DescriptionDetail'] ?? spotData['Description'] ?? appState.t('暫無詳細介紹。'));

    final String address = appState.currentLang == 'en'
        ? (spotData['AddressEn'] ?? spotData['Address'] ?? 'No address info')
        : (spotData['Address'] ?? appState.t('無地址資訊'));

    final String openTime = appState.currentLang == 'en'
        ? (spotData['OpenTimeEn'] ?? spotData['OpenTime'] ?? 'Check official announcements')
        : (spotData['OpenTime'] ?? appState.t('依現場公告為主'));

    final String ticketInfo = appState.currentLang == 'en'
        ? (spotData['TicketInfoEn'] ?? spotData['TicketInfo'] ?? '')
        : (spotData['TicketInfo'] ?? '');

    // 🌟 圖片容錯升級：多重檢查，連巢狀 Map 也幫你挖出來
    String picUrl = spotData['PicUrl1'] ?? spotData['PictureUrl1'] ?? '';
    if (picUrl.isEmpty && spotData['Picture'] is Map) {
      picUrl = spotData['Picture']['PictureUrl1'] ?? '';
    }

    final String phone = spotData['Phone'] ?? appState.t('無聯絡電話');

    LatLng mapCenter = const LatLng(23.4754, 120.4473);
    if (spotData['Location'] is GeoPoint) {
      final geo = spotData['Location'] as GeoPoint;
      mapCenter = LatLng(geo.latitude, geo.longitude);
    } else if (spotData['Location'] is Map) {
      final geoMap = spotData['Location'];
      if (geoMap['lat'] != null && geoMap['lng'] != null) {
        mapCenter = LatLng(geoMap['lat'], geoMap['lng']);
      }
    }

    final bool isFav = appState.isFavorite(spotData['NameZh'] ?? spotData['ScenicSpotName'] ?? '');

    return Scaffold(
      backgroundColor: Colors.grey[50],
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.8), shape: BoxShape.circle),
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.black87),
              onPressed: () => appState.goBack(),
            ),
          )
        ],
      ),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            picUrl.isNotEmpty
                ? Image.network(picUrl, width: double.infinity, height: 300, fit: BoxFit.cover)
                : Container(
              height: 300, width: double.infinity,
              color: themeColor.withOpacity(0.15),
              child: Center(child: Icon(Icons.landscape, size: 80, color: themeColor)),
            ),

            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, fontFamily: 'serif')),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
                        child: IconButton(
                          padding: const EdgeInsets.all(14),
                          icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.red : Colors.grey[600]),
                          onPressed: () => appState.toggleFavorite(spotData),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: themeColor, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                          icon: const Icon(Icons.add_task),
                          label: Text(appState.t('加入行程'), style: const TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () => _addToLatestItinerary(spotData),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]),
                    child: Column(
                      children: [
                        ListTile(leading: const Icon(Icons.location_on, color: Colors.grey), title: Text(address, style: const TextStyle(fontSize: 14))),
                        Divider(height: 1, color: Colors.grey[100]),
                        ListTile(leading: const Icon(Icons.access_time, color: Colors.grey), title: Text(openTime, style: const TextStyle(fontSize: 14))),

                        if (ticketInfo.isNotEmpty) ...[
                          Divider(height: 1, color: Colors.grey[100]),
                          ListTile(leading: const Icon(Icons.confirmation_number, color: Colors.grey), title: Text(ticketInfo, style: const TextStyle(fontSize: 14))),
                        ],

                        Divider(height: 1, color: Colors.grey[100]),
                        ListTile(
                          leading: const Icon(Icons.phone, color: Colors.grey),
                          title: Text(phone, style: TextStyle(color: themeColor, decoration: TextDecoration.underline, fontSize: 14)),
                          onTap: () async {
                            final uri = Uri.parse('tel:$phone');
                            if (await canLaunchUrl(uri)) await launchUrl(uri);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 🌟 動態判斷標題文字 (避免沒有加入翻譯字典檔的問題)
                  Text(appState.currentLang == 'en' ? 'Description' : '景點介紹', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(desc, style: TextStyle(fontSize: 15, height: 1.6, color: Colors.grey[800])),
                  const SizedBox(height: 24),

                  // 🌟 動態判斷標題文字
                  Text(appState.currentLang == 'en' ? 'Location' : '位置資訊', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Container(
                    height: 200,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: FlutterMap(
                        options: MapOptions(initialCenter: mapCenter, initialZoom: 15.0),
                        children: [
                          TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.explore_chiayi'),
                          MarkerLayer(markers: [Marker(point: mapCenter, child: Icon(Icons.location_on, color: themeColor, size: 40))]),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}