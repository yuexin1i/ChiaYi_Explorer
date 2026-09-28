// lib/widgets/app_drawer.dart
import 'dart:io'; // 🌟 為了讀取本機的 File (avatar)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../pages/admin_dashboard_page.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateManager>();
    final palette = appState.activePalette;
    final currentPageIndex = appState.pageIndex;
    // 在 AppDrawer 的 build 流程中加入
    final state = context.watch<AppStateManager>();
    return Drawer(
      backgroundColor: Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        physics: const BouncingScrollPhysics(),
        children: [
          UserAccountsDrawerHeader(
            // 🌟 修正：動態讀取使用者名稱與信箱，並加上翻譯
            accountName: Text(
              "${appState.greetingName} ${appState.t('您好')}",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            accountEmail: Text(
              appState.account ?? "welcome@chiayi.com",
              style: const TextStyle(color: Colors.white70),
            ),
            currentAccountPicture: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              // 🌟 修改這裡：與 Profile 頁面同步的頭像顯示邏輯
              child: CircleAvatar(
                backgroundColor: Colors.white,
                backgroundImage:
                    appState.avatar != null
                        ? FileImage(appState.avatar!) as ImageProvider
                        : (appState.avatarUrl != null &&
                                appState.avatarUrl!.isNotEmpty
                            ? NetworkImage(appState.avatarUrl!)
                            : null),
                child:
                    (appState.avatar == null &&
                            (appState.avatarUrl == null ||
                                appState.avatarUrl!.isEmpty))
                        ? const Icon(Icons.person, color: Colors.grey, size: 40)
                        : null,
              ),
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [palette[0], palette[4]],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          _buildProviderItem(
            context,
            Icons.home,
            appState.t('首頁'),
            0,
            palette[1],
            currentPageIndex,
          ),
          _buildProviderItem(
            context,
            Icons.place,
            appState.t('景點探索'),
            2,
            palette[2],
            currentPageIndex,
          ),
          _buildProviderItem(
            context,
            Icons.restaurant,
            appState.t('在地美食'),
            3,
            palette[3],
            currentPageIndex,
          ),
          _buildProviderItem(
            context,
            Icons.hotel,
            appState.t('特色住宿'),
            4,
            palette[4],
            currentPageIndex,
          ),
          _buildProviderItem(
            context,
            Icons.directions_bus,
            appState.t('交通資訊'),
            5,
            palette[5],
            currentPageIndex,
          ),
          _buildProviderItem(
            context,
            Icons.event,
            appState.t('近期活動'),
            6,
            palette[6],
            currentPageIndex,
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(color: Colors.grey[200]),
          ),

          _buildProviderItem(
            context,
            Icons.map,
            appState.t('互動地圖'),
            1,
            palette[1],
            currentPageIndex,
          ),

          _buildProviderItem(
            context,
            Icons.auto_stories,
            appState.t('互動故事模式'),
            13,
            palette[0],
            currentPageIndex,
          ),

          _buildProviderItem(
            context,
            Icons.smart_toy,
            appState.t('AI助理'),
            7,
            palette[3],
            currentPageIndex,
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(color: Colors.grey[200]),
          ),

          _buildProviderItem(
            context,
            Icons.favorite,
            appState.t('收藏景點'),
            9,
            palette[2],
            currentPageIndex,
          ),
          _buildProviderItem(
            context,
            Icons.calendar_today,
            appState.t('行程管理'),
            8,
            palette[4],
            currentPageIndex,
          ),
          _buildProviderItem(
            context,
            Icons.settings,
            appState.t('使用者資訊與設定'),
            10,
            Colors.grey[700]!,
            currentPageIndex,
          ),
          const SizedBox(height: 20),
          // 👇 請把判斷式加在這裡 👇
          if (state.isAdmin) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Divider(color: Colors.grey[200]),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ListTile(
                leading: const Icon(
                  Icons.admin_panel_settings,
                  color: Colors.amber,
                ),
                title: Text(
                  state.t('管理者主控台'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminDashboardPage(),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProviderItem(
    BuildContext context,
    IconData icon,
    String title,
    int pageIndex,
    Color itemColor,
    int currentPageIndex,
  ) {
    final bool isSelected = (pageIndex == currentPageIndex);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? itemColor.withOpacity(0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? itemColor : itemColor.withOpacity(0.7),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? itemColor : Colors.black87,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onTap: () {
          Navigator.pop(context);
          Provider.of<AppStateManager>(
            context,
            listen: false,
          ).setPageIndex(pageIndex);
        },
      ),
    );
  }
}
