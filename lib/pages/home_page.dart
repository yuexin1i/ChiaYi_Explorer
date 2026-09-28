// lib/pages/home_page.dart
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/app_drawer.dart';
import '../providers/app_state.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.onNotificationsPressed,
    this.onNotificationLongPress,
    this.hasUnreadNotification = false,
  });

  final VoidCallback? onNotificationsPressed;
  final Future<void> Function()? onNotificationLongPress;
  final bool hasUnreadNotification;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> _activeQuickActions = [];
  List<Map<String, dynamic>> _eventList = [];
  bool _isDrawingFortune = false;
  bool _hasDrawnToday = false;
  String? _todayFortune;

  final List<Map<String, dynamic>> _allActions = [
    {'icon': Icons.place, 'label': '景點探索', 'pageIndex': 2},
    {'icon': Icons.restaurant, 'label': '在地美食', 'pageIndex': 3},
    {'icon': Icons.hotel, 'label': '特色住宿', 'pageIndex': 4},
    {'icon': Icons.directions_bus, 'label': '交通資訊', 'pageIndex': 5},
    {'icon': Icons.map, 'label': '互動地圖', 'pageIndex': 1},
    {'icon': Icons.smart_toy, 'label': 'AI助理', 'pageIndex': 7},
    {'icon': Icons.event, 'label': '近期活動', 'pageIndex': 6},
    {'icon': Icons.favorite, 'label': '收藏景點', 'pageIndex': 9},
    {'icon': Icons.calendar_today, 'label': '行程管理', 'pageIndex': 8},
  ];

  List<Map<String, dynamic>> _carouselSpots = [
    {
      "NameZh": "梅園",
      "NameEn": "Plum Garden",
      "Address": "阿里山森林遊樂區內，阿里山鄉中山村56號。",
      "AddressEn":
          "No. 56, Zhongshan Village, Alishan Township, Alishan Forest Recreation Area.",
      "DescriptionDetail":
          "梅園花海，一向是阿里山最佳賞櫻路線的前哨站，和阿里山賓館廣場、阿里山工作站以及阿里山三代木步道，同為賞櫻最佳景點。梅園位於阿里山派出所前方，園內植物以梅花和櫻花為主，其中又以吉野櫻為大宗。春遊阿里山，三月正是最佳的賞花季，除了粉白美麗的吉野櫻隆重登場之外，滿園的梅花、桃花、八重櫻…等也陸續綻放，到了四月暖天，在主角吉野櫻漂亮退場後，垂絲海棠、西洋蘋果花又將延續另一波的花潮。梅園花海一連串的精采演出，將是每年賞花遊客不可錯過的好去處。",
      "DescriptionEn":
          "Plum Garden Flower Sea has always been the outpost of the best cherry blossom viewing route in Alishan. It is also the best scenic spot for cherry blossom viewing along with Alishan Hotel Plaza, Alishan Work Station and Alishan Sandaimu Trail. The Plum Garden is located in front of the Alishan Police Station. The plants in the garden are mainly plum blossoms and cherry blossoms, among which the Yoshino cherry is the most common. <br/><br/>Spring trip to Alishan, March is the best season for flower viewing. In addition to the beautiful pink and white Yoshino cherry blossoms, plum blossoms, peach blossoms, and double cherry blossoms...etc. are also blooming in the garden. In the warm days of April, after the Yoshino cherry blossoms make a beautiful exit, the weeping crab apples and Western apple blossoms will continue another wave of flowers. A series of wonderful performances in the Plum Garden Flower Sea will be a place not to be missed by flower-viewing tourists every year.",
      "OpenTime": "全日無休",
      "OpenTimeEn": "24/7",
      "Phone": "886-5-2679917",
      "PicUrl1":
          "https://nextws.cyhg.gov.tw//001/Upload/1/RelPic/110496/513589/Title201503301708301.jpg",
    },
    {
      "NameZh": "臺灣菸酒公司嘉義觀光酒廠",
      "NameEn": "Taiwan Tobacco and Liquor Company Chiayi Tourist Winery",
      "Address": "嘉義縣民雄鄉福樂村中山路4號",
      "AddressEn":
          "No. 4, Zhongshan Road, Fule Village, Minxiong Township, Chiayi County",
      "DescriptionDetail":
          "創立自日治時期大正5年（西元1916年），分主館及製酒機械展示區，近千坪場地展出酒廠百年製酒歷程，豐富的酒博物館，還能現場品嚐試飲。（喝酒不開車）",
      "DescriptionEn":
          "Founded in Taisho 5 (1916 AD) during the Japanese colonial period, it is divided into a main hall and a wine-making machinery exhibition area. The nearly 1,000 square meters of space displays the winery's century-old wine-making history. It also has a rich wine museum and on-site tastings. (Don’t drive if you drink)",
      "OpenTime": "8：30-17：00（除夕至初二不開放）",
      "OpenTimeEn":
          "8:30-17:00 (closed from New Year’s Eve to the second day of the lunar month)",
      "Phone": "886-5-2215172",
      "PicUrl1":
          "https://nextws.cyhg.gov.tw//001/Upload/1/RelPic/110496/513546/Title201505261700071.jpg",
    },
    {
      "NameZh": "布袋鹽場",
      "NameEn": "Budai Saltworks",
      "Address": "嘉義縣布袋鎮新厝里新厝仔13號",
      "AddressEn": "No. 13, Xincuozi, Xincuo Li, Butai Town, Chiayi County",
      "DescriptionDetail":
          "台灣西南海岸因沙岸平直、日照強烈，自古以來即是絕佳的鹽場。布袋擁有得天獨厚的地理條件，曬鹽歷史悠久，可以上溯至清乾隆年間，至今已逾二百年。布袋在清乾隆時開始開闢鹽田，到了清道光3年的富鹽商—吳尚新更開闢了鹽埕百甲，奠定了日後布袋曬鹽業的基礎。到了日治時期，布袋的鹽場更為成熟，並使得當時的布袋港成為重要的鹽運港口，將布袋的鹽銷往中國及日本。<br/><br/>白花花的鹽田，曾經具有「白金」級的產業地位，最後則和其他地區的鹽田一樣，鹽工幾乎已經被機械化曬鹽所取代，布袋的鹽業因此式微。偌大的鹽埕上已看不到曬鹽、採鹽的景象，而穿梭在鹽埕中的小火車，也早已功成身退。<br/><br/>布袋鹽場不只限於布袋鎮，事實上，整個鹽場區域範圍跨越了嘉義縣沿海的東石鄉、布袋鎮及義竹鄉等三個鄉鎮。粗略的劃分是從台17線以西到海岸線，從最北的掌潭場務所，一直到最南的新塭場務所，管理約10個生產區。現存於台17及台61號省道間的閒置鹽灘地，則與好美寮生態保護區連成一面，成為鷺科鳥類和來台過冬的冬侯鳥最重要的覓食場所，也是賞鳥的絕佳地點。<br/><br/>布袋鎮上所有的鹽田皆為台鹽所有，曾是全台最大的鹽場，昔日沿台17號省道南行，兩旁盡是鹽田風光，一畦畦整齊的白色鹽池，泛著熠熠光影，一座座雪白的鹽山，彷彿如平地竄起的小雪山，形成特殊的產業景觀。",
      "DescriptionEn":
          "The southwest coast of Taiwan has been an excellent salt field since ancient times due to its straight sandy beaches and strong sunshine. Budai has unique geographical conditions and a long history of drying salt, which can be traced back to the Qianlong period of the Qing Dynasty, more than 200 years ago. Budai began to develop salt fields during the Qianlong period of the Qing Dynasty. In the 3rd year of Daoguang reign of the Qing Dynasty, Wu Shangxin, a wealthy salt merchant, opened up the salt field Baijia, which laid the foundation for the future Budai salt drying industry. During the Japanese colonial period, Butei's salt fields became more mature, and Butai Port became an important salt transportation port at that time, selling Butai's salt to China and Japan. <br/><br/>Baihuahua’s salt fields once had a “platinum” industrial status, but eventually, like salt fields in other areas, the salt workers were almost replaced by mechanized salt drying, and the salt industry in Budai declined as a result. The scene of salt drying and salt mining can no longer be seen in the huge Yancheng, and the small train that shuttled through the Yancheng has long since retired. <br/><br/>Butai Salt Field is not limited to Butai Town. In fact, the entire salt field area spans three coastal towns in Chiayi County: Dongshi Township, Butai Town and Yizhu Township. A rough division is from the west of Provincial Line 17 to the coastline, from the Zhangtan Office in the north to the Xinyang Office in the south, managing about 10 production areas. The existing idle salt flat land between Provincial Highway No. 17 and Provincial Highway No. 61 is connected with the Haomeiliu Ecological Reserve. It has become the most important feeding place for herons and winter migratory birds that come to Taiwan to spend the winter. It is also an excellent place for bird watching. <br/><br/>All the salt fields in Budai Town are owned by Taiwan Salt. It was once the largest salt field in Taiwan. In the past, traveling south along Provincial Highway No. 17, there were salt fields on both sides. Rows of neat white salt ponds, shimmering with light and shadow, and snow-white salt mountains, like small snow-capped mountains rising from the ground, formed a special industrial landscape.",
      "OpenTime": "請洽布袋鹽場",
      "OpenTimeEn": "Please contact Budai Saltworks",
      "Phone": "886-5-3472003",
      "PicUrl1":
          "https://nextws.cyhg.gov.tw//001/Upload/1/RelPic/110496/513575/Title201503281610081.jpg",
    },
    {
      "NameZh": "阿里山神木",
      "NameEn": "Alishan Sacred Tree",
      "Address": "臺灣嘉義縣阿里山遊樂區",
      "AddressEn": "Alishan Recreation Area, Chiayi County, Taiwan",
      "DescriptionDetail":
          "阿里山神木是一棵兩樹合抱、樹齡三千歲以上的紅檜，無論是樹齡或胸徑都曾是亞洲第一，位於阿里山鐵道六十九公里處旁，和阿里山的日出、雲海、高山鐵路與櫻花，並稱為五大奇景。1906年，日本技師小笠原富二郎發現了平均年歲在兩、三千年左右的阿里山巨木群，後來因為預計將森林鐵路貫穿其間，三十萬株通天檜木便被砍伐殆盡。而這棵被遺留下來的老紅檜，卻因為樹心完全被蓮根菌噬光，反而因「無用」而免遭斤斧，甚至被結綵奉神。 <br/><br/>孤單鶴立雞群的神木在民國四十二年慘遭落雷襲擊，雷火沿中空樹幹一路延燒到地表，它卻依然頑強緊抓著一線生機。然而民國四十五年第二次的雷擊，終於將神木的上半身枝椏劈除，導致其完全死亡。民國八十六年七月，整株神木因為耐不住風雨而崩倒，樹幹碎裂成四大塊，壓毀樹旁的阿里山森林鐵路。林務局於是在隔年的六月六日，決定以人工方式將神木原地放倒，讓遊客瞻仰憑弔這棵參天巨木的遺容。 <br/><br/>為迎接2007年，彰顯台灣堅忍屹立精神而舉辦阿里山第二代神木票選，原名「光武檜」的神木，是嘉義縣政府、阿里山國家風景區管理處、嘉義林區管理處共同舉辦「阿里山二代神木誰與爭鋒」票選活動所選出，總共獲得一萬三千八百四十六票，樹齡有兩千三百多歲，樹高四十五公尺，直徑三點九二公尺，幹圍十二點五公尺，相當巨大，英姿挺拔，因而獲選為第二代神木，並於2007年1月1日更名為「阿里山香林神木」",
      "DescriptionEn":
          "The Alishan sacred tree is a red juniper tree that is more than 3,000 years old and is hugged by two trees. It was once the largest tree in Asia in terms of age and diameter at breast height. It is located next to the 69-kilometer Alishan Railway. It is one of the five wonders of Alishan, including the sunrise, sea of ​​clouds, mountain railway and cherry blossoms. In 1906, Japanese technician Tomijiro Ogasawara discovered a group of Alishan giant trees with an average age of about two to three thousand years. Later, because the forest railway was expected to run through them, 300,000 sky-reaching cypress trees were cut down. However, this old red juniper tree that was left behind was completely eaten away by the lotus root fungus at the core. Instead, it was spared the ax because it was 【useless】 and was even decorated with flowers and consecrated to the gods. <br/><br/>The lonely sacred tree that stands out from the crowd was struck by lightning in the 42nd year of the Republic of China. The thunder and fire spread along the hollow trunk to the surface, but it still tenaciously clung to the glimmer of life. However, the second lightning strike in the 45th year of the Republic of China finally chopped off the upper branches of the sacred tree, causing its complete death. In July of the 1986th year of the Republic of China, the entire sacred tree collapsed because it could not withstand the wind and rain. The trunk broke into four large pieces and crushed the Alishan Forest Railway next to the tree. On June 6 of the following year, the Forest Service decided to artificially lower the sacred tree to its original location, allowing tourists to pay their respects to the remains of this towering giant tree. <br/><br/>In order to welcome 2007 and demonstrate Taiwan’s spirit of perseverance, the Alishan second-generation sacred tree voting event was held. The sacred tree, formerly known as 【Guangwu Hinoki】, was jointly organized by the Chiayi County Government, the Alishan National Scenic Area Management Office, and the Chiayi Forest District Management Office to vote for the 【Who Competes for the Alishan Second-generation Sacred Tree】 The tree was selected by the National People's Congress and received a total of 13,846 votes. The tree is more than 2,300 years old, with a height of 45 meters, a diameter of 3.92 meters, and a trunk circumference of 12.5 meters. It is quite huge and tall. Therefore, it was selected as the second generation sacred tree and was renamed 【Alishan Xianglin Sacred Tree】 on January 1, 2007.",
      "OpenTime": "全日無休",
      "OpenTimeEn": "24/7",
      "Phone": "886-5-2679917",
      "PicUrl1":
          "https://nextws.cyhg.gov.tw//001/Upload/1/RelPic/110496/513587/Title201503301705001.jpg",
    },
    {
      "NameZh": "蒜頭糖廠五分車站",
      "NameEn": "Garlic Candy Factory Five-minute Station",
      "Address": "嘉義縣六腳鄉工廠村1號",
      "AddressEn": "No. 1, Factory Village, Liujiao Township, Chiayi County",
      "DescriptionDetail":
          "縱横交錯的五分車鐵道，充滿實用與藝術的氣息，是婚紗照的最愛，而鐵道上陳列早期輕便、巡道車、糖蜜車、飼料車、老火車頭及各式各栟的車廂，令人大開眼界。",
      "DescriptionEn":
          "The criss-crossing five-car railway is full of practicality and art and is a favorite for wedding photos. The early light trucks, patrol cars, molasses cars, feed cars, old locomotives and various carriages on the railway are eye-opening.",
      "OpenTime": "早上8：00至下午5：00",
      "OpenTimeEn": "8:00 am to 5:00 pm",
      "Phone": "886-5-3800741",
      "PicUrl1":
          "https://nextws.cyhg.gov.tw//001/Upload/1/RelPic/110496/513617/Title201508171732381.jpg",
    },
  ];

  List<Map<String, dynamic>> _newsList = [];

  static const Color _fixedLuckyRed = Color(0xFFD32F2F);
  static const Color _fixedLuckyGold = Color(0xFFFFD700);
  static const Color _fixedWeatherBlue = Color(0xFFE3F2FD);
  static const Color _fixedWeatherText = Color(0xFF1565C0);

  @override
  void initState() {
    super.initState();
    _activeQuickActions = List.from(_allActions.take(6));
    _fetchCarouselData();
    _fetchEventsData();
    _fetchNewsData();
    _loadFortuneStatus();
  }

  String get _today => DateTime.now().toIso8601String().substring(0, 10);

  Future<void> _loadFortuneStatus() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final hasDrawn = prefs.getString('fortune_date') == _today;
    setState(() {
      _hasDrawnToday = hasDrawn;
      _todayFortune = hasDrawn ? prefs.getString('fortune_result') : null;
    });
  }

  Future<void> _fetchEventsData() async {
    try {
      final snap =
          await FirebaseFirestore.instance.collection('events').limit(5).get();
      if (mounted) {
        setState(() {
          _eventList =
              snap.docs.map((doc) => {"docId": doc.id, ...doc.data()}).toList();
        });
      }
    } catch (e) {
      debugPrint('首頁活動讀取錯誤: $e');
    }
  }

  Future<void> _fetchNewsData() async {
    try {
      final snap =
          await FirebaseFirestore.instance
              .collection('announcements')
              .orderBy('PublishedAt', descending: true)
              .limit(5)
              .get();

      if (mounted) {
        setState(() {
          _newsList =
              snap.docs.map((doc) {
                final data = doc.data();

                Color getColor(String? colorStr) {
                  switch (colorStr) {
                    case 'blue':
                      return Colors.blue;
                    case 'green':
                      return Colors.green;
                    case 'red':
                      return Colors.red;
                    case 'purple':
                      return Colors.purple;
                    case 'orange':
                    default:
                      return Colors.orange;
                  }
                }

                IconData getIcon(String? iconStr) {
                  switch (iconStr) {
                    case 'directions_bus':
                      return Icons.directions_bus;
                    case 'pedal_bike':
                      return Icons.pedal_bike;
                    case 'cloud_done':
                      return Icons.cloud_done;
                    case 'event':
                      return Icons.event;
                    case 'campaign':
                    default:
                      return Icons.campaign;
                  }
                }

                return {
                  "docId": doc.id,
                  "title": data['title'] ?? data['Title'] ?? '系統公告',
                  "content": data['content'] ?? data['Content'] ?? '',
                  "date": data['date'] ?? '',
                  "icon": getIcon(data['icon']),
                  "color": getColor(data['color']),
                };
              }).toList();
        });
      }
    } catch (e) {
      debugPrint('最新消息讀取錯誤: $e');
    }
  }

  Future<void> _fetchCarouselData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      const cacheKey = 'cache_home_carousel_v3';
      const cacheTimeKey = 'cache_home_carousel_ts_v3';

      final cachedJson = prefs.getString(cacheKey);
      final cachedAt = prefs.getInt(cacheTimeKey) ?? 0;
      final ageMin = (DateTime.now().millisecondsSinceEpoch - cachedAt) / 60000;

      if (cachedJson != null && ageMin < 60) {
        final List<dynamic> decoded = jsonDecode(cachedJson);
        if (mounted) {
          setState(() {
            _carouselSpots = decoded.cast<Map<String, dynamic>>();
          });
        }
        return;
      }

      final snap =
          await FirebaseFirestore.instance
              .collection('spots_v2')
              .where(
                'NameZh',
                whereIn: ['梅園', '臺灣菸酒公司嘉義觀光酒廠', '布袋鹽場', '阿里山神木', '蒜頭糖廠五分車站'],
              )
              .get();
      if (snap.docs.isNotEmpty) {
        List<Map<String, dynamic>> updatedSpots = List.from(_carouselSpots);
        for (var doc in snap.docs) {
          var data = doc.data();
          final name = data['NameZh'] ?? data['ScenicSpotName'] ?? '';
          final index = updatedSpots.indexWhere(
            (spot) => spot['NameZh'] == name,
          );
          if (index != -1) {
            if (data['Location'] is GeoPoint) {
              GeoPoint geo = data['Location'];
              data['Location'] = {'lat': geo.latitude, 'lng': geo.longitude};
            }
            updatedSpots[index] = {
              ...updatedSpots[index],
              ...data,
              "docId": doc.id,
            };
          }
        }
        await prefs.setString(cacheKey, jsonEncode(updatedSpots));
        await prefs.setInt(cacheTimeKey, DateTime.now().millisecondsSinceEpoch);
        if (mounted) {
          setState(() {
            _carouselSpots = updatedSpots;
          });
        }
      }
    } catch (e) {
      debugPrint('首頁輪播圖讀取錯誤: $e');
    }
  }

  Future<void> _drawFortune() async {
    if (_isDrawingFortune || _hasDrawnToday) return;
    setState(() => _isDrawingFortune = true);

    final prefs = await SharedPreferences.getInstance();
    final alreadyDrawn = prefs.getString('fortune_date') == _today;
    final fortunes = ['平', '順', '小吉', '中吉', '大吉'];
    final result =
        alreadyDrawn
            ? prefs.getString('fortune_result') ?? '平'
            : fortunes[Random().nextInt(fortunes.length)];

    if (!alreadyDrawn) {
      await prefs.setString('fortune_date', _today);
      await prefs.setString('fortune_result', result);
    }

    if (!mounted) return;

    final appState = Provider.of<AppStateManager>(context, listen: false);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => PopScope(
            canPop: false,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              content: SizedBox(
                height: 120,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: _fixedLuckyGold),
                    const SizedBox(height: 20),
                    Text(
                      appState.t('正在為你揭曉今日運勢…'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );

    await Future<void>.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    setState(() {
      _isDrawingFortune = false;
      _hasDrawnToday = true;
      _todayFortune = result;
    });

    showDialog<void>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            content: Center(
              child:
                  Container(
                        width: 220,
                        padding: const EdgeInsets.symmetric(
                          vertical: 32,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: _fixedLuckyRed,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: _fixedLuckyGold, width: 4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.yellowAccent.withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              appState.t('今日諸羅運勢'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: _fixedLuckyGold,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    result,
                                    style: const TextStyle(
                                      fontSize: 48,
                                      fontWeight: FontWeight.bold,
                                      color: _fixedLuckyRed,
                                    ),
                                  ),
                                )
                                .animate(
                                  onPlay:
                                      (controller) =>
                                          controller.repeat(reverse: true),
                                )
                                .scale(
                                  duration: 400.ms,
                                  begin: const Offset(1, 1),
                                  end: const Offset(1.1, 1.1),
                                ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _fixedLuckyGold,
                                foregroundColor: _fixedLuckyRed,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: () => Navigator.pop(context),
                              child: Text(appState.t('收下好運')),
                            ),
                          ],
                        ),
                      )
                      .animate()
                      .slideY(begin: 1, end: 0, curve: Curves.easeOutBack)
                      .fadeIn(),
            ),
          ),
    );
  }

  void _showThemeSettings() {
    final state = Provider.of<AppStateManager>(context, listen: false);
    final List<Color> previewColors = [
      const Color(0xFF8D6E63),
      const Color(0xFFFF80AB),
      const Color(0xFFE040FB),
      const Color(0xFF03A9F4),
    ];

    showModalBottomSheet(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      context: context,
      builder:
          (context) => Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.t('主題風格選擇'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  state.t('請選擇您喜歡的 7 色系列風格：'),
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(4, (index) {
                    return GestureDetector(
                      onTap: () {
                        state.setThemeIndex(index);
                        Navigator.pop(context);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border:
                              state.currentThemeIndex == index
                                  ? Border.all(
                                    color: previewColors[index],
                                    width: 3,
                                  )
                                  : null,
                        ),
                        padding: const EdgeInsets.all(4),
                        child: CircleAvatar(
                          backgroundColor: previewColors[index],
                          radius: 24,
                          child:
                              state.currentThemeIndex == index
                                  ? const Icon(Icons.check, color: Colors.white)
                                  : null,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
    );
  }

  void _editQuickActions() {
    List<Map<String, dynamic>> tempActions = List.from(_activeQuickActions);
    final appState = Provider.of<AppStateManager>(context, listen: false);
    final themeColor = appState.themeColor;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(appState.t('自訂快速導覽 (6格)')),
              content: SizedBox(
                width: double.maxFinite,
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 6,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.9,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemBuilder: (ctx, index) {
                    final currentItem = tempActions[index];
                    return InkWell(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(24),
                            ),
                          ),
                          builder:
                              (sheetCtx) => ListView.builder(
                                itemCount: _allActions.length,
                                itemBuilder: (context, i) {
                                  final action = _allActions[i];
                                  return ListTile(
                                    leading: Icon(
                                      action['icon'],
                                      color: themeColor,
                                    ),
                                    title: Text(appState.t(action['label'])),
                                    onTap: () {
                                      setDialogState(() {
                                        tempActions[index] = action;
                                      });
                                      Navigator.pop(sheetCtx);
                                    },
                                  );
                                },
                              ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: themeColor),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(currentItem['icon'], color: themeColor),
                            const SizedBox(height: 4),
                            Text(
                              appState.t(currentItem['label']),
                              style: const TextStyle(fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            const Icon(
                              Icons.swap_horiz,
                              size: 14,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(appState.t('取消')),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    setState(() => _activeQuickActions = tempActions);
                    Navigator.pop(context);
                  },
                  child: Text(appState.t('確定')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateManager>();
    final themeColor = appState.themeColor;
    final palette = appState.activePalette;

    return Scaffold(
      backgroundColor: Colors.grey[50],

      // ✨ 1. 只要有宣告 drawer，原生 AppBar 就會自動產生側邊欄按鈕！
      drawer: const AppDrawer(),

      // ✨ 2. 我們啟用原生的 AppBar 頂端導航列，永遠不會跑版
      appBar: AppBar(
        backgroundColor: Colors.grey[50],
        elevation: 0, // 拿掉陰影，完美融入背景
        leading: Builder(
          builder:
              (scaffoldContext) => IconButton(
                tooltip: appState.t('開啟側邊欄'),
                icon: Icon(
                  Icons.menu,
                  color: themeColor.withValues(alpha: 0.35),
                ),
                onPressed: () => Scaffold.of(scaffoldContext).openDrawer(),
              ),
        ),
        titleSpacing: 0, // 讓文字往左靠齊
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${appState.t('早安，')}${appState.greetingName}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            Text(
              appState.t('準備好探索諸羅了嗎？'),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        actions: [
          GestureDetector(
            onLongPress: widget.onNotificationLongPress,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  tooltip: appState.t('通知中心'),
                  icon: const Icon(Icons.notifications_none),
                  color: themeColor,
                  onPressed: widget.onNotificationsPressed,
                ),
                if (widget.hasUnreadNotification)
                  const Positioned(
                    right: 9,
                    top: 9,
                    child: SizedBox(
                      width: 9,
                      height: 9,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: appState.t('主題風格選擇'),
            icon: const Icon(Icons.palette_outlined),
            color: themeColor,
            onPressed: _showThemeSettings,
          ),
        ],
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 👇 太陽(天氣)圖示與抽籤從這裡開始 👇
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 10.0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 20,
                              horizontal: 12,
                            ),
                            decoration: BoxDecoration(
                              color: _fixedWeatherBlue,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: _fixedWeatherBlue.withOpacity(0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Image.asset(
                                      appState.getWeatherImage(
                                        appState.weatherCondition,
                                      ),
                                      width: 40,
                                      height: 40,
                                      errorBuilder:
                                          (context, error, stackTrace) => Icon(
                                            appState.weatherCondition == 'rainy'
                                                ? Icons.water_drop
                                                : appState.weatherCondition ==
                                                    'cloudy'
                                                ? Icons.cloud
                                                : Icons.wb_sunny,
                                            color:
                                                appState.weatherCondition ==
                                                        'sunny'
                                                    ? Colors.orangeAccent
                                                    : Colors.blueGrey,
                                            size: 40,
                                          ),
                                    )
                                    .animate(
                                      onPlay:
                                          (controller) => controller.repeat(),
                                    )
                                    .shimmer(
                                      duration: 2000.ms,
                                      color: Colors.white.withOpacity(0.5),
                                    ),
                                const SizedBox(height: 12),
                                Text(
                                  appState.weatherTemp,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: _fixedWeatherText,
                                  ),
                                ),
                                Text(
                                  appState.t(appState.weatherWx),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: _fixedWeatherText,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          )
                          .animate()
                          .slideY(
                            begin: 0.2,
                            end: 0,
                            duration: 600.ms,
                            curve: Curves.easeOutQuad,
                          )
                          .fadeIn(duration: 600.ms),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: GestureDetector(
                            onTap:
                                _hasDrawnToday || _isDrawingFortune
                                    ? null
                                    : _drawFortune,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 250),
                              opacity: _hasDrawnToday ? 0.62 : 1,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 20,
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFDEDA6),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: _fixedLuckyRed,
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _fixedLuckyRed.withOpacity(0.15),
                                      blurRadius: 12,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    const Icon(
                                          Icons.casino,
                                          color: _fixedLuckyRed,
                                          size: 40,
                                        )
                                        .animate(
                                          onPlay:
                                              (controller) => controller.repeat(
                                                reverse: true,
                                              ),
                                        )
                                        .rotate(
                                          begin: -0.05,
                                          end: 0.05,
                                          duration: 1000.ms,
                                          curve: Curves.easeInOut,
                                        ),
                                    const SizedBox(height: 12),
                                    Text(
                                      appState.t('今日旅遊運勢'),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: _fixedLuckyRed,
                                      ),
                                    ),
                                    Text(
                                      _hasDrawnToday
                                          ? '${appState.t('今日運勢')}：${_todayFortune ?? appState.t('已抽取')}'
                                          : _isDrawingFortune
                                          ? appState.t('正在揭曉…')
                                          : appState.t('點我抽出！'),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: _fixedLuckyRed,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                          .animate(delay: 200.ms)
                          .slideY(
                            begin: 0.2,
                            end: 0,
                            duration: 600.ms,
                            curve: Curves.easeOutQuad,
                          )
                          .fadeIn(duration: 600.ms),
                    ),
                  ],
                ),
              ),

              CarouselSlider(
                options: CarouselOptions(
                  height: 180.0,
                  autoPlay: true,
                  enlargeCenterPage: true,
                  viewportFraction: 0.85,
                ),
                items:
                    _carouselSpots.map((spotData) {
                      String picUrl =
                          spotData['PicUrl1'] ??
                          spotData['PictureUrl1'] ??
                          spotData['ImageUrl'] ??
                          '';
                      if (picUrl.isEmpty && spotData['Picture'] is Map) {
                        picUrl = spotData['Picture']['PictureUrl1'] ?? '';
                      }

                      final String displayTitle =
                          appState.currentLang == 'en'
                              ? (spotData['NameEn'] ??
                                  spotData['NameZh'] ??
                                  'Unknown')
                              : (spotData['NameZh'] ?? '未知景點');

                      return InkWell(
                        onTap: () {
                          final appState = Provider.of<AppStateManager>(
                            context,
                            listen: false,
                          );
                          appState.setCurrentSpotData(spotData);
                          appState.setPageIndex(11);
                        },
                        child: Container(
                          width: MediaQuery.of(context).size.width,
                          margin: const EdgeInsets.symmetric(
                            horizontal: 5.0,
                            vertical: 10.0,
                          ),
                          decoration: BoxDecoration(
                            color: themeColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                            border: Border.all(
                              color: themeColor.withOpacity(0.1),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (picUrl.isNotEmpty)
                                  Image.network(
                                    picUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (ctx, err, stack) => Center(
                                          child: Icon(
                                            Icons.landscape,
                                            size: 80,
                                            color: themeColor,
                                          ),
                                        ),
                                  )
                                else
                                  Center(
                                    child: Icon(
                                      Icons.landscape,
                                      size: 80,
                                      color: themeColor,
                                    ),
                                  ),
                                Positioned(
                                  bottom: 16,
                                  left: 16,
                                  child: Container(
                                    constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.of(context).size.width *
                                          0.6,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.65),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      displayTitle,
                                      style: const TextStyle(
                                        fontSize: 15.0,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 10.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      appState.t('快速導覽'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton.icon(
                      icon: Icon(Icons.settings, size: 16, color: themeColor),
                      label: Text(
                        appState.t('自訂'),
                        style: TextStyle(
                          color: themeColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: _editQuickActions,
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _activeQuickActions.length,
                  itemBuilder: (context, index) {
                    final act = _activeQuickActions[index];
                    final Color iconColor = palette[(index % 6) + 1];
                    return GestureDetector(
                      onTap:
                          () => Provider.of<AppStateManager>(
                            context,
                            listen: false,
                          ).setPageIndex(act['pageIndex']),
                      child: Container(
                        width: 72,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                act['icon'],
                                size: 28,
                                color: iconColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              appState.t(act['label']),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Text(
                  appState.t('近期推薦活動'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              SizedBox(
                height: 170,
                child:
                    _eventList.isEmpty
                        ? Center(
                          child: CircularProgressIndicator(color: themeColor),
                        )
                        : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: _eventList.length,
                          padding: const EdgeInsets.only(left: 20, right: 4),
                          itemBuilder: (context, index) {
                            final event = _eventList[index];

                            final String titleZh =
                                event['Title'] ?? appState.t('未知活動');
                            final String displayTitle =
                                appState.currentLang == 'en'
                                    ? (event['TitleEn'] ?? titleZh)
                                    : titleZh;

                            String imageUrl =
                                event['ImageUrl']?.toString() ?? '';
                            if (imageUrl.isEmpty && event['Picture'] is Map) {
                              imageUrl = event['Picture']['PictureUrl1'] ?? '';
                            }

                            return InkWell(
                              onTap: () {
                                appState.setCurrentEventData(event);
                                appState.setPageIndex(12);
                              },
                              child: Container(
                                width: 160,
                                margin: const EdgeInsets.only(
                                  right: 16.0,
                                  bottom: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(16),
                                      ),
                                      child:
                                          imageUrl.isNotEmpty
                                              ? Image.network(
                                                imageUrl,
                                                height: 80,
                                                width: double.infinity,
                                                fit: BoxFit.cover,
                                                errorBuilder:
                                                    (c, e, s) => Container(
                                                      height: 80,
                                                      color: themeColor
                                                          .withOpacity(0.1),
                                                      child: Icon(
                                                        Icons.event,
                                                        color: themeColor,
                                                      ),
                                                    ),
                                              )
                                              : Container(
                                                height: 80,
                                                color: themeColor.withOpacity(
                                                  0.1,
                                                ),
                                                child: Icon(
                                                  Icons.event,
                                                  color: themeColor,
                                                ),
                                              ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        displayTitle,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                child: Text(
                  appState.t('最新消息'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _newsList.length,
                itemBuilder: (context, index) {
                  final news = _newsList[index];
                  final Color iconColor = news['color'] as Color;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: iconColor.withOpacity(0.1),
                        child: Icon(news['icon'], color: iconColor),
                      ),
                      title: Text(
                        appState.t(news['title']),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        news['date'],
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: Colors.grey,
                      ),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder:
                              (ctx) => AlertDialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                title: Row(
                                  children: [
                                    Icon(news['icon'], color: iconColor),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        appState.t(news['title']),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${appState.t('發布日期：')}${news['date']}',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      appState.personalizeGreeting(
                                        appState.t(news['content'] ?? ''),
                                      ),
                                      style: const TextStyle(
                                        height: 1.5,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: Text(
                                      appState.t('我知道了'),
                                      style: TextStyle(
                                        color: themeColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                        );
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
