// lib/pages/favorites_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../widgets/app_drawer.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';

class FavoritesPage extends StatefulWidget {
  @override
  _FavoritesPageState createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  String _selectedCategory = "全部";

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateManager>(context);
    final palette = appState.activePalette;
    final themeColor = palette[0];

    final globalFavorites = appState.favoriteSpotsList;
    final filteredList = _selectedCategory == "全部"
        ? globalFavorites
        : globalFavorites.where((spot) => spot["category"] == _selectedCategory).toList();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(appState.t('我的收藏景點'), style: TextStyle(fontWeight: FontWeight.bold, color: themeColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: themeColor),
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: ["全部", "自然風景", "藝文展覽", "文化古蹟", "在地美食"].map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 12.0, top: 8, bottom: 8),
                  child: FilterChip(
                    label: Text(appState.t(cat), style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    selected: isSelected,
                    selectedColor: palette[4].withOpacity(0.15),
                    checkmarkColor: palette[4],
                    backgroundColor: Colors.white,
                    side: BorderSide(color: isSelected ? palette[4] : Colors.grey[300]!),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    onSelected: (val) {
                      setState(() => _selectedCategory = cat);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: filteredList.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, size: 64, color: Colors.grey[300]).animate().shake(),
                  const SizedBox(height: 16),
                  Text(appState.t('目前沒有此分類的收藏項目'), style: TextStyle(color: Colors.grey[500])),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              physics: const BouncingScrollPhysics(),
              itemCount: filteredList.length,
              itemBuilder: (context, index) {
                final spot = filteredList[index];
                final Color imgBgColor = palette[(index % 6) + 1];
                final spotName = spot["name"] ?? spot["NameZh"];

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(color: imgBgColor.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
                      child: spot["PicUrl1"] != null && spot["PicUrl1"].toString().isNotEmpty
                          ? ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.network(spot["PicUrl1"], fit: BoxFit.cover))
                          : Icon(Icons.image, color: imgBgColor.withOpacity(0.8)),
                    ),
                    title: Text(spotName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.star, color: palette[2], size: 16),
                            const SizedBox(width: 4),
                            Text("${spot["rating"]} (${spot["reviews"]} ${appState.t('則評分')})", style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(spot["Address"] ?? "", maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                      ],
                    ),
                    trailing: Container(
                      decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
                      child: IconButton(
                        icon: const Icon(Icons.favorite, color: Colors.red, size: 20),
                        onPressed: () {
                          appState.toggleFavorite(spot);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(appState.currentLang == 'en' ? 'Removed $spotName from favorites' : '已將 $spotName 從收藏中移除')));
                        },
                      ),
                    ),
                    onTap: () {
                      if (spot["originalData"] != null) {
                        appState.setCurrentSpotData(spot["originalData"]);
                        appState.setPageIndex(11);
                      }
                    },
                  ),
                ).animate().slideY(begin: 0.1, end: 0, delay: (50 * index).ms, duration: 400.ms, curve: Curves.easeOut).fadeIn();
              },
            ),
          ),
        ],
      ),
    );
  }
}