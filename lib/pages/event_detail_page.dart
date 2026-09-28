// lib/pages/event_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/app_drawer.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';

class EventDetailPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateManager>(context);
    final palette = appState.activePalette;
    final event = appState.currentEventData;

    if (event == null) {
      return Scaffold(appBar: AppBar(title: Text(appState.t('錯誤'))), body: Center(child: Text(appState.t('查無活動資料'))));
    }

    // 🌟 1. 取得中文標題作為系統唯一的身份證 (用來判斷是否已收藏/存入行事曆)
    final String titleZh = event['Title'] ?? appState.t('未知活動');

    // 🌟 2. 以下全部替換成動態中英雙語切換
    final String displayTitle = appState.currentLang == 'en' ? (event['TitleEn'] ?? titleZh) : titleZh;
    final String timeStr = appState.currentLang == 'en' ? (event['DetailedTimeEn'] ?? event['DetailedTime'] ?? 'Check official announcements') : (event['DetailedTime'] ?? appState.t('依官方公告為主'));
    final String location = appState.currentLang == 'en' ? (event['LocationEn'] ?? event['Location'] ?? 'See event details') : (event['Location'] ?? appState.t('詳見活動介紹'));
    final String fee = appState.currentLang == 'en' ? (event['FeeEn'] ?? event['Fee'] ?? 'Free') : (event['Fee'] ?? appState.t('免費'));
    final String desc = appState.currentLang == 'en' ? (event['DescriptionEn'] ?? event['Description'] ?? 'No description available.') : (event['Description'] ?? appState.t('暫無說明'));

    // 🌟 3. 圖片安全防呆
    String imageUrl = event['ImageUrl']?.toString() ?? '';
    if (imageUrl.isEmpty && event['Picture'] is Map) {
      imageUrl = event['Picture']['PictureUrl1'] ?? '';
    }

    final String link = event['Link'] ?? '';

    // 🌟 4. 判斷收藏狀態時，必須使用系統不變的中文 Key
    final bool isSaved = appState.isEventSaved(titleZh);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(appState.currentLang == 'en' ? 'Event Details' : appState.t('活動詳細資訊'), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), shape: BoxShape.circle),
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              tooltip: appState.t('返回'),
              onPressed: () => Provider.of<AppStateManager>(context, listen: false).goBack(),
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
            Container(
              height: 280,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [palette[1], palette[2]], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
                boxShadow: [BoxShadow(color: palette[1].withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
                child: imageUrl.isNotEmpty
                    ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (c,e,s) => SafeArea(child: Center(child: Icon(Icons.festival, size: 100, color: Colors.white.withOpacity(0.8)))))
                    : SafeArea(child: Center(child: Icon(Icons.festival, size: 100, color: Colors.white.withOpacity(0.8)).animate().scale(duration: 600.ms, curve: Curves.easeOutBack))),
              ),
            ),

            Transform.translate(
              offset: const Offset(0, -30),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayTitle, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.calendar_today, size: 20, color: palette[3]), const SizedBox(width: 12), Expanded(child: Text(timeStr, style: const TextStyle(fontSize: 15, height: 1.4)))]),
                    const SizedBox(height: 12),
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.location_on, size: 20, color: palette[4]), const SizedBox(width: 12), Expanded(child: Text(location, style: const TextStyle(fontSize: 15, height: 1.4)))]),
                    const SizedBox(height: 12),
                    Row(children: [Icon(Icons.local_activity, size: 20, color: palette[5]), const SizedBox(width: 12), Text(fee, style: const TextStyle(fontSize: 15))]),
                    if (link.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      InkWell(
                          onTap: () async { if(await canLaunchUrl(Uri.parse(link))) launchUrl(Uri.parse(link)); },
                          child: Row(children: [Icon(Icons.link, size: 20, color: Colors.blue), const SizedBox(width: 12), Expanded(child: Text(appState.currentLang == 'en' ? 'Official Website' : appState.t('前往活動官網'), style: const TextStyle(fontSize: 15, color: Colors.blue, decoration: TextDecoration.underline)))])
                      )
                    ],
                    const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider(height: 1)),

                    Text(appState.currentLang == 'en' ? 'Event Description' : appState.t('活動介紹'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Text(desc, style: TextStyle(fontSize: 15, height: 1.6, color: Colors.grey[800])),
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isSaved ? Colors.grey[300] : palette[6],
                          foregroundColor: isSaved ? Colors.black87 : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        icon: Icon(isSaved ? Icons.event_busy : Icons.event_available),
                        label: Text(
                            isSaved
                                ? (appState.currentLang == 'en' ? 'Remove from Calendar' : appState.t('從行事曆移除'))
                                : (appState.currentLang == 'en' ? 'Add to My Calendar' : appState.t('加入我的行事曆')),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                        ),
                        onPressed: () {
                          appState.toggleSavedEvent(event); // 傳入的 event 會用中文的 titleZh 去判斷
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
                              isSaved
                                  ? (appState.currentLang == 'en' ? 'Removed' : appState.t('已移除'))
                                  : (appState.currentLang == 'en' ? '✅ Added to Calendar' : appState.t('✅ 已加入雲端行事曆'))
                          )));
                        },
                      ),
                    )
                  ],
                ),
              ).animate().slideY(begin: 0.1, end: 0, delay: 200.ms, duration: 500.ms, curve: Curves.easeOut).fadeIn(),
            )
          ],
        ),
      ),
    );
  }
}