import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../widgets/app_drawer.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late Future<List<Map<String, dynamic>>> _futureNotifications;

  @override
  void initState() {
    super.initState();

    final appState = Provider.of<AppStateManager>(context, listen: false);
    _futureNotifications = _loadNotifications(appState);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      appState.markNotificationsAsRead();
    });
  }

  Future<List<Map<String, dynamic>>> _loadNotifications(
    AppStateManager appState,
  ) async {
    final uid = appState.uid;
    if (uid == null) return [];

    final globalSnap =
        await FirebaseFirestore.instance
            .collection('Notifications')
            .where('User_Id', isEqualTo: 'global')
            .get();

    final personalSnap =
        await FirebaseFirestore.instance
            .collection('Notifications')
            .where('User_Id', isEqualTo: uid)
            .get();

    final allDocs = [...globalSnap.docs, ...personalSnap.docs];

    final notifications =
        allDocs.map((doc) {
          final data = doc.data();
          data['docId'] = doc.id;
          return data;
        }).toList();

    notifications.sort((a, b) {
      final aTime = a['Created_At'];
      final bTime = b['Created_At'];

      if (aTime is Timestamp && bTime is Timestamp) {
        return bTime.compareTo(aTime);
      }

      return 0;
    });

    return notifications;
  }

  String _formatTime(dynamic value) {
    if (value is! Timestamp) return '';

    final date = value.toDate();

    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateManager>(context);
    final palette = appState.activePalette;
    final themeColor = palette[0];

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          appState.t('通知中心'),
          style: TextStyle(fontWeight: FontWeight.bold, color: themeColor),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: themeColor),
      ),
      drawer: const AppDrawer(),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _futureNotifications,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: themeColor));
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return Center(
              child: Text(
                appState.t('目前沒有通知'),
                style: TextStyle(color: Colors.grey[500], fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final item = notifications[index];

              final title = item['Title'] ?? item['title'] ?? appState.t('通知');
              final body = item['Body'] ?? item['body'] ?? '';
              final type = item['Type'] ?? '';
              final createdAt = item['Created_At'];

              return Card(
                elevation: 0,
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: CircleAvatar(
                    backgroundColor: themeColor.withOpacity(0.15),
                    child: Icon(
                      type == 'inactive_reminder'
                          ? Icons.favorite
                          : Icons.notifications_active,
                      color: themeColor,
                    ),
                  ),
                  title: Text(
                    title.toString(),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(appState.personalizeGreeting(body.toString())),
                        const SizedBox(height: 6),
                        Text(
                          _formatTime(createdAt),
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
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
