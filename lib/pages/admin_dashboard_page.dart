// lib/pages/admin_dashboard_page.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';

// ══════════════════════════════════════════════════
//  管理者主控台 - 完整功能版
// ══════════════════════════════════════════════════
class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _totalUsers = 0, _totalSpots = 0, _totalEvents = 0, _totalAnnouncements = 0;
  bool _loadingStats = true;

  static const Color _accent = Color(0xFF1B6B3A);
  static const Color _accent2 = Color(0xFF2E8B57);
  static const Color _gold = Color(0xFFD4A017);
  static const Color _bg = Color(0xFFF4F6F3);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _loadStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() => _loadingStats = true);
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('Users').count().get(),
        FirebaseFirestore.instance.collection('spots_v2').count().get(),
        FirebaseFirestore.instance.collection('events').count().get(),
        FirebaseFirestore.instance.collection('announcements').count().get(),
      ]);
      if (mounted) {
        setState(() {
          _totalUsers = results[0].count ?? 0;
          _totalSpots = results[1].count ?? 0;
          _totalEvents = results[2].count ?? 0;
          _totalAnnouncements = results[3].count ?? 0;
          _loadingStats = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  void _jumpToTab(int index) => _tabController.animateTo(index);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateManager>();
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.admin_panel_settings, size: 20)),
            const SizedBox(width: 10),
            Text(state.t('管理者主控台'), style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
          ],
        ),
        actions: [IconButton(icon: const Icon(Icons.refresh), tooltip: '重新整理', onPressed: _loadStats)],
        bottom: TabBar(
          controller: _tabController, indicatorColor: _gold, indicatorWeight: 3, labelColor: Colors.white, unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), isScrollable: true,
          tabs: [
            Tab(icon: const Icon(Icons.dashboard, size: 18), text: state.t('總覽')),
            Tab(icon: const Icon(Icons.people, size: 18), text: state.t('使用者')),
            Tab(icon: const Icon(Icons.place, size: 18), text: state.t('景點管理')),
            Tab(icon: const Icon(Icons.event, size: 18), text: state.t('活動管理')),
            Tab(icon: const Icon(Icons.campaign, size: 18), text: state.t('公告管理')),
            Tab(icon: const Icon(Icons.storage, size: 18), text: state.t('資料庫')),
            Tab(icon: const Icon(Icons.import_export, size: 18), text: state.t('匯出入')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _OverviewTab(_totalUsers, _totalSpots, _totalEvents, _totalAnnouncements, _loadingStats, _accent, _accent2, _gold, _jumpToTab),
          _UsersTab(accent: _accent, gold: _gold),
          _SpotsTab(accent: _accent, accent2: _accent2),
          _EventsTab(accent: _accent, gold: _gold),
          _AnnouncementsTab(accent: _accent),
          _DataManagementTab(accent: _accent),
          _ImportExportTab(accent: _accent, gold: _gold),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════
//  1. 總覽
// ══════════════════════════════════════════════════
class _OverviewTab extends StatelessWidget {
  final int u, s, e, a; final bool l; final Color ac, ac2, g; final Function(int) jump;
  const _OverviewTab(this.u, this.s, this.e, this.a, this.l, this.ac, this.ac2, this.g, this.jump);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(gradient: LinearGradient(colors: [ac, ac2]), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: ac.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))]),
            child: Row(children: [
              const Icon(Icons.local_activity, color: Colors.white, size: 36), const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('霸道諸羅帶你回嘉', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2)),
                Text('Admin Console • ${DateTime.now().toString().substring(0,10)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ])),
            ]),
          ),
          const SizedBox(height: 20),
          const Text('資料庫統計', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.5,
            children: [
              _StatCard('總使用者', u, Icons.people, const Color(0xFF1565C0), l),
              _StatCard('景點數量', s, Icons.place, const Color(0xFF6A1B9A), l),
              _StatCard('活動數量', e, Icons.event, const Color(0xFF00695C), l),
              _StatCard('公告數量', a, Icons.campaign, const Color(0xFFE65100), l),
            ],
          ),
          const SizedBox(height: 20),
          const Text('快速操作', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10, runSpacing: 10,
            children: [
              _QuickAction('新增景點', Icons.add_location_alt, ac, () => jump(2)),
              _QuickAction('管理使用者', Icons.manage_accounts, const Color(0xFF1565C0), () => jump(1)),
              _QuickAction('系統公告', Icons.campaign, const Color(0xFFE65100), () => jump(4)),
              _QuickAction('匯出備份', Icons.cloud_download, g, () => jump(6)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label; final int val; final IconData icon; final Color color; final bool loading;
  const _StatCard(this.label, this.val, this.icon, this.color, this.loading);
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border(left: BorderSide(color: color, width: 4))), child: Row(children: [CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color, size: 20)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])), loading ? const LinearProgressIndicator() : Text('$val', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color))]))]));
}

class _QuickAction extends StatelessWidget {
  final String label; final IconData icon; final Color color; final VoidCallback onTap;
  const _QuickAction(this.label, this.icon, this.color, this.onTap);
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.3))), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: color, size: 18), const SizedBox(width: 8), Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13))])));
}

// ══════════════════════════════════════════════════
//  2. 使用者管理
// ══════════════════════════════════════════════════
class _UsersTab extends StatelessWidget {
  final Color accent, gold;
  const _UsersTab({required this.accent, required this.gold});
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('Users').snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: snap.data!.docs.length,
          itemBuilder: (ctx, i) {
            final doc = snap.data!.docs[i];
            final data = doc.data() as Map<String, dynamic>;
            final isAdmin = data['isAdmin'] == true;
            return Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(data['Nickname'] ?? doc.id),
                subtitle: Text(data['Email'] ?? '無 Email'),
                trailing: isAdmin ? Icon(Icons.shield, color: gold) : null,
                onTap: () {
                  FirebaseFirestore.instance.collection('Users').doc(doc.id).update({'isAdmin': !isAdmin});
                },
              ),
            );
          },
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════
//  3. 景點管理 (spots_v2) ── 修正抓取 ScenicSpotName
// ══════════════════════════════════════════════════
class _SpotsTab extends StatefulWidget {
  final Color accent, accent2;
  const _SpotsTab({required this.accent, required this.accent2});
  @override
  State<_SpotsTab> createState() => _SpotsTabState();
}

class _SpotsTabState extends State<_SpotsTab> {
  void _showForm({DocumentSnapshot? doc}) {
    final data = doc?.data() as Map<String, dynamic>?;
    // 🌟 修正：同時讀取 NameZh 或 ScenicSpotName
    final nameCtrl = TextEditingController(text: data?['NameZh'] ?? data?['ScenicSpotName'] ?? '');
    final addressCtrl = TextEditingController(text: data?['Address'] ?? '');
    final cityCtrl = TextEditingController(text: data?['City'] ?? '');
    final classCtrl = TextEditingController(text: data?['Class1'] ?? '');
    final latCtrl = TextEditingController(text: data?['PositionLat']?.toString() ?? '');
    final lonCtrl = TextEditingController(text: data?['PositionLon']?.toString() ?? '');
    final ticketCtrl = TextEditingController(text: data?['TicketInfo'] ?? '');
    final descCtrl = TextEditingController(text: data?['Description'] ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(doc == null ? '新增景點' : '編輯景點'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '名稱 (NameZh)')),
              TextField(controller: cityCtrl, decoration: const InputDecoration(labelText: '城市 (City)')),
              TextField(controller: classCtrl, decoration: const InputDecoration(labelText: '分類 (Class1)')),
              TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: '地址 (Address)')),
              TextField(controller: latCtrl, decoration: const InputDecoration(labelText: '緯度 (PositionLat)')),
              TextField(controller: lonCtrl, decoration: const InputDecoration(labelText: '經度 (PositionLon)')),
              TextField(controller: ticketCtrl, decoration: const InputDecoration(labelText: '票價 (TicketInfo)')),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: '介紹 (Description)'), maxLines: 3),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              final payload = {
                'NameZh': nameCtrl.text, 'City': cityCtrl.text, 'Class1': classCtrl.text, 'Address': addressCtrl.text,
                'TicketInfo': ticketCtrl.text, 'Description': descCtrl.text,
                'PositionLat': double.tryParse(latCtrl.text), 'PositionLon': double.tryParse(lonCtrl.text),
              };
              if (doc == null) FirebaseFirestore.instance.collection('spots_v2').add(payload);
              else doc.reference.update(payload);
              Navigator.pop(context);
            },
            child: const Text('儲存'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(backgroundColor: widget.accent, child: const Icon(Icons.add, color: Colors.white), onPressed: () => _showForm()),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('spots_v2').limit(50).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          return ListView.builder(
            itemCount: snap.data!.docs.length,
            itemBuilder: (ctx, i) {
              final doc = snap.data!.docs[i];
              final data = doc.data() as Map<String, dynamic>;
              // 🌟 修正：列表顯示時也同時抓取 ScenicSpotName
              final displayName = data['NameZh'] ?? data['ScenicSpotName'] ?? '無名稱';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: widget.accent.withOpacity(0.2), child: Icon(Icons.place, color: widget.accent)),
                  title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${data['City'] ?? ''} | ${data['Class1'] ?? ''}\n${data['TicketInfo'] ?? '免費'}'),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showForm(doc: doc)),
                      IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => doc.reference.delete()),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
// ══════════════════════════════════════════════════
//  4. 活動管理 (events)
// ══════════════════════════════════════════════════
class _EventsTab extends StatefulWidget {
  final Color accent, gold;
  const _EventsTab({required this.accent, required this.gold});
  @override
  State<_EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<_EventsTab> {
  void _showForm({DocumentSnapshot? doc}) {
    final data = doc?.data() as Map<String, dynamic>?;
    final titleCtrl = TextEditingController(text: data?['Title'] ?? '');
    final timeCtrl = TextEditingController(text: data?['DetailedTime'] ?? '');
    final locCtrl = TextEditingController(text: data?['Location'] ?? '');
    final feeCtrl = TextEditingController(text: data?['Fee'] ?? '');
    final imgCtrl = TextEditingController(text: data?['ImageUrl'] ?? '');
    final linkCtrl = TextEditingController(text: data?['Link'] ?? '');
    final descCtrl = TextEditingController(text: data?['Description'] ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(doc == null ? '新增活動' : '編輯活動'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: '標題 (Title)')),
              TextField(controller: timeCtrl, decoration: const InputDecoration(labelText: '時間 (DetailedTime)')),
              TextField(controller: locCtrl, decoration: const InputDecoration(labelText: '地點 (Location)')),
              TextField(controller: feeCtrl, decoration: const InputDecoration(labelText: '費用 (Fee)')),
              TextField(controller: imgCtrl, decoration: const InputDecoration(labelText: '圖片網址 (ImageUrl)')),
              TextField(controller: linkCtrl, decoration: const InputDecoration(labelText: '連結 (Link)')),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: '介紹 (Description)'), maxLines: 3),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              final payload = {
                'Title': titleCtrl.text, 'DetailedTime': timeCtrl.text, 'Location': locCtrl.text,
                'Fee': feeCtrl.text, 'ImageUrl': imgCtrl.text, 'Link': linkCtrl.text, 'Description': descCtrl.text,
              };
              if (doc == null) FirebaseFirestore.instance.collection('events').add(payload);
              else doc.reference.update(payload);
              Navigator.pop(context);
            },
            child: const Text('儲存'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(backgroundColor: widget.accent, child: const Icon(Icons.add, color: Colors.white), onPressed: () => _showForm()),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('events').snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          return ListView.builder(
            itemCount: snap.data!.docs.length,
            itemBuilder: (ctx, i) {
              final doc = snap.data!.docs[i];
              final data = doc.data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: widget.gold.withOpacity(0.2), child: Icon(Icons.event, color: widget.gold)),
                  title: Text(data['Title'] ?? '無標題', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${data['DetailedTime'] ?? ''}\n${data['Location'] ?? ''}'),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showForm(doc: doc)),
                      IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => doc.reference.delete()),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
// ══════════════════════════════════════════════════
//  5. 公告管理 (announcements) ── 加入自訂 title, date, icon, color
// ══════════════════════════════════════════════════
class _AnnouncementsTab extends StatefulWidget {
  final Color accent;
  const _AnnouncementsTab({required this.accent});
  @override
  State<_AnnouncementsTab> createState() => _AnnouncementsTabState();
}

class _AnnouncementsTabState extends State<_AnnouncementsTab> {
  void _showForm({DocumentSnapshot? doc}) {
    final data = doc?.data() as Map<String, dynamic>?;
    final titleCtrl = TextEditingController(text: data?['title'] ?? data?['Title'] ?? '');
    final contentCtrl = TextEditingController(text: data?['content'] ?? data?['Content'] ?? '');

    // 預設日期為今天
    String selectedDate = data?['date'] ?? '${DateTime.now().year}/${DateTime.now().month.toString().padLeft(2,'0')}/${DateTime.now().day.toString().padLeft(2,'0')}';
    String selectedIcon = data?['icon'] ?? 'campaign';
    String selectedColor = data?['color'] ?? 'orange';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(doc == null ? '發布公告' : '編輯公告'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('新增的公告將顯示在 App 首頁最新消息', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 12),
                    TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: '標題 (title)')),
                    TextField(controller: contentCtrl, decoration: const InputDecoration(labelText: '內容 (content)'), maxLines: 4),
                    const SizedBox(height: 16),

                    // 🌟 日期選擇器 (date)
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
                        if (picked != null) {
                          setStateDialog(() => selectedDate = '${picked.year}/${picked.month.toString().padLeft(2,'0')}/${picked.day.toString().padLeft(2,'0')}');
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: '發布日期 (date)'),
                        child: Text(selectedDate),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 🌟 圖示選擇器 (icon)
                    DropdownButtonFormField<String>(
                      value: selectedIcon,
                      decoration: const InputDecoration(labelText: '圖示 (icon)'),
                      items: const [
                        DropdownMenuItem(value: 'campaign', child: Text('📢 廣播 (campaign)')),
                        DropdownMenuItem(value: 'directions_bus', child: Text('🚌 交通 (directions_bus)')),
                        DropdownMenuItem(value: 'pedal_bike', child: Text('🚲 腳踏車 (pedal_bike)')),
                        DropdownMenuItem(value: 'cloud_done', child: Text('☁️ 雲端系統 (cloud_done)')),
                        DropdownMenuItem(value: 'event', child: Text('📅 活動 (event)')),
                      ],
                      onChanged: (v) => setStateDialog(() => selectedIcon = v!),
                    ),
                    const SizedBox(height: 16),

                    // 🌟 顏色選擇器 (color)
                    DropdownButtonFormField<String>(
                      value: selectedColor,
                      decoration: const InputDecoration(labelText: '顏色 (color)'),
                      items: const [
                        DropdownMenuItem(value: 'orange', child: Text('🟠 橘色 (orange)')),
                        DropdownMenuItem(value: 'blue', child: Text('🔵 藍色 (blue)')),
                        DropdownMenuItem(value: 'green', child: Text('🟢 綠色 (green)')),
                        DropdownMenuItem(value: 'red', child: Text('🔴 紅色 (red)')),
                        DropdownMenuItem(value: 'purple', child: Text('🟣 紫色 (purple)')),
                      ],
                      onChanged: (v) => setStateDialog(() => selectedColor = v!),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
                ElevatedButton(
                  onPressed: () {
                    final payload = {
                      'title': titleCtrl.text,
                      'content': contentCtrl.text,
                      'date': selectedDate,
                      'icon': selectedIcon,
                      'color': selectedColor,
                      'PublishedAt': doc == null ? FieldValue.serverTimestamp() : (data?['PublishedAt'] ?? FieldValue.serverTimestamp()),
                    };
                    if (doc == null) FirebaseFirestore.instance.collection('announcements').add(payload);
                    else doc.reference.update(payload);
                    Navigator.pop(context);
                  },
                  child: const Text('儲存'),
                )
              ],
            );
          }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(backgroundColor: Colors.orange, child: const Icon(Icons.campaign, color: Colors.white), onPressed: () => _showForm()),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('announcements').orderBy('PublishedAt', descending: true).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          return ListView.builder(
            itemCount: snap.data!.docs.length,
            itemBuilder: (ctx, i) {
              final doc = snap.data!.docs[i];
              final data = doc.data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: const Icon(Icons.campaign, color: Colors.orange),
                  title: Text(data['title'] ?? data['Title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(data['content'] ?? data['Content'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showForm(doc: doc)),
                      IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => doc.reference.delete()),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════
//  6. 資料庫原貌檢視
// ══════════════════════════════════════════════════
class _DataManagementTab extends StatefulWidget {
  final Color accent;
  const _DataManagementTab({required this.accent});
  @override
  State<_DataManagementTab> createState() => _DataManagementTabState();
}

class _DataManagementTabState extends State<_DataManagementTab> {
  String _selectedCollection = 'Users';
  final List<String> _collections = [
    'Users', 'spots_v2', 'events', 'announcements',
    'Cafes', 'Restaurants', 'ChickenRice', 'NightMarkets', 'GiftShops'
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 頂部選擇器
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              const Icon(Icons.storage, color: Colors.grey),
              const SizedBox(width: 12),
              const Text('當前檢視集合：', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedCollection,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: _collections.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (val) => setState(() => _selectedCollection = val!),
                ),
              ),
            ],
          ),
        ),
        // 資料列表
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection(_selectedCollection).limit(50).snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snap.hasData || snap.data!.docs.isEmpty) return const Center(child: Text('此集合目前沒有資料。'));

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: snap.data!.docs.length,
                itemBuilder: (ctx, i) {
                  final doc = snap.data!.docs[i];
                  final data = doc.data() as Map<String, dynamic>;
                  // 將 Map 轉為漂亮的 JSON 字串顯示
                  final jsonString = const JsonEncoder.withIndent('  ').convert(_sanitizeForJson(data));

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ExpansionTile(
                      leading: CircleAvatar(
                        backgroundColor: widget.accent.withOpacity(0.1),
                        child: Text('${i + 1}', style: TextStyle(color: widget.accent, fontWeight: FontWeight.bold)),
                      ),
                      title: Text(doc.id, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text('欄位數量: ${data.keys.length}'),
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          color: Colors.grey[50],
                          child: SelectableText(
                            jsonString,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                          ),
                        )
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════
//  7. 匯入 / 匯出 (利用剪貼簿與 JSON)
// ══════════════════════════════════════════════════
class _ImportExportTab extends StatefulWidget {
  final Color accent, gold;
  const _ImportExportTab({required this.accent, required this.gold});
  @override
  State<_ImportExportTab> createState() => _ImportExportTabState();
}

class _ImportExportTabState extends State<_ImportExportTab> {
  String _selectedCollection = 'spots_v2';
  final TextEditingController _jsonController = TextEditingController();
  bool _isProcessing = false;

  final List<String> _collections = [
    'spots_v2', 'events', 'announcements',
    'Cafes', 'Restaurants', 'ChickenRice', 'NightMarkets', 'GiftShops'
  ];

  Future<void> _exportData() async {
    setState(() => _isProcessing = true);
    try {
      final snap = await FirebaseFirestore.instance.collection(_selectedCollection).get();
      List<Map<String, dynamic>> exportList = [];

      for (var doc in snap.docs) {
        exportList.add(_sanitizeForJson(doc.data()));
      }

      final jsonString = const JsonEncoder.withIndent('  ').convert(exportList);

      // 複製到剪貼簿
      await Clipboard.setData(ClipboardData(text: jsonString));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ 已成功複製 ${_selectedCollection} 的 ${exportList.length} 筆資料到剪貼簿！')));
        _jsonController.text = jsonString; // 同時顯示在輸入框
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('匯出失敗: $e')));
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _importData() async {
    final text = _jsonController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請先在下方輸入 JSON 格式的資料！')));
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final List<dynamic> importList = jsonDecode(text);
      final batch = FirebaseFirestore.instance.batch();
      final collectionRef = FirebaseFirestore.instance.collection(_selectedCollection);

      for (var item in importList) {
        if (item is Map<String, dynamic>) {
          // 自動生成 ID 並加入批次寫入
          batch.set(collectionRef.doc(), item);
        }
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ 成功匯入 ${importList.length} 筆資料至 ${_selectedCollection}！')));
        _jsonController.clear();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('匯入失敗，請檢查 JSON 格式是否正確: $e')));
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('選擇操作的資料庫集合：', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedCollection,
            decoration: InputDecoration(
              filled: true, fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: _collections.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (val) => setState(() => _selectedCollection = val!),
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: widget.accent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                  icon: _isProcessing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.file_download),
                  label: const Text('匯出至剪貼簿', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: _isProcessing ? null : _exportData,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: widget.gold, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                  icon: _isProcessing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.file_upload),
                  label: const Text('從文字框匯入', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: _isProcessing ? null : _importData,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          const Text('資料預覽 / 匯入輸入區：', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          TextField(
            controller: _jsonController,
            maxLines: 15,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            decoration: InputDecoration(
              hintText: '[\n  {\n    "NameZh": "測試景點",\n    "City": "嘉義市"\n  }\n]',
              filled: true, fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════
//  通用輔助函式：將 Firestore 特殊欄位轉為可 JSON 化的格式
// ══════════════════════════════════════════════════
dynamic _sanitizeForJson(dynamic value) {
  if (value is Timestamp) {
    return value.toDate().toIso8601String(); // 將時間戳轉為 ISO 字串
  } else if (value is GeoPoint) {
    return {'lat': value.latitude, 'lng': value.longitude}; // 座標轉為 Map
  } else if (value is Map) {
    return value.map((k, v) => MapEntry(k, _sanitizeForJson(v)));
  } else if (value is List) {
    return value.map((v) => _sanitizeForJson(v)).toList();
  }
  return value;
}