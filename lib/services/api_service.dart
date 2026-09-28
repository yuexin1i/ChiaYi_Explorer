import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

// ⚠️ 記得引入你專案中的 Models 檔案
import '../models/YouBikeModels.dart';
import '../models/BusModels.dart';
import '../models/TRAModels.dart';
import '../models/THSRModels.dart';

class ApiService {
  // 🔗 FastAPI 的 Base URL (包含 /api)
  static const String baseUrl = "https://flutter-123.onrender.com/api";

  // 共用的逾時設定 (60秒，對付 Render 免費版的冷啟動)
  static const Duration timeoutDuration = Duration(seconds: 60);

  // 共用的錯誤處理函式
  static void _handleError(http.Response response) {
    if (response.statusCode == 429) {
      throw Exception('請求過於頻繁 (TDX 限流)，請稍等 1-2 分鐘後再試。');
    } else if (response.statusCode >= 500) {
      throw Exception('伺服器異常 (${response.statusCode})，請稍後再試。');
    } else if (response.statusCode != 200) {
      // 🌟 神奇修復：加上 response.body，讓 FastAPI 的真正錯誤訊息無所遁形！
      throw Exception('獲取資料失敗: ${response.statusCode}, 後端詳細訊息: ${response.body}');
    }
  }

  // ========================================================
  // 🚲 1. YouBike 即時動態
  // ========================================================
  static Future<List<YouBikeAvailability>> getYouBikeStatus(String city) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/bike/status/$city'))
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final Map<String, dynamic> decoded = json.decode(response.body);
        final List<dynamic> dataList = decoded['data'] ?? [];
        return dataList.map((j) => YouBikeAvailability.fromJson(j)).toList();
      } else {
        _handleError(response);
        return [];
      }
    } on TimeoutException {
      throw Exception('伺服器正在暖機，請稍等約 50 秒後再試一次！');
    } catch (e) {
      throw Exception('網路連線失敗: $e');
    }
  }

  // ========================================================
  // 🚌 2. 公車預估到站時間
  // ========================================================
  static Future<List<BusEta>> getBusEta(String city, String routeId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/bus/eta/$city/$routeId'))
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final Map<String, dynamic> decoded = json.decode(response.body);
        final List<dynamic> dataList = decoded['data'] ?? [];
        return dataList.map((j) => BusEta.fromJson(j)).toList();
      } else {
        _handleError(response);
        return [];
      }
    } on TimeoutException {
      throw Exception('伺服器正在暖機，請稍等約 50 秒後再試一次！');
    } catch (e) {
      throw Exception('網路連線失敗: $e');
    }
  }

  // ========================================================
  // 🚂 3. 台鐵即時到離站資訊
  // ========================================================
  static Future<List<TRALiveBoard>> getTRALive(String stationId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/rail/tra/live/$stationId'))
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final Map<String, dynamic> decoded = json.decode(response.body);
        final List<dynamic> dataList = decoded['data'] ?? [];
        return dataList.map((j) => TRALiveBoard.fromJson(j)).toList();
      } else {
        _handleError(response);
        return [];
      }
    } on TimeoutException {
      throw Exception('伺服器正在暖機，請稍等約 50 秒後再試一次！');
    } catch (e) {
      throw Exception('網路連線失敗: $e');
    }
  }

  // ========================================================
  // 🚄 4. 高鐵特定日期時刻表
  // ========================================================
  static Future<List<THSRTimetable>> getTHSRTimetable(String stationId, String trainDate) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/rail/thsr/timetable/$stationId/$trainDate'))
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final Map<String, dynamic> decoded = json.decode(response.body);
        final List<dynamic> dataList = decoded['data'] ?? [];
        return dataList.map((j) => THSRTimetable.fromJson(j)).toList();
      } else {
        _handleError(response);
        return [];
      }
    } on TimeoutException {
      throw Exception('伺服器正在暖機，請稍等約 50 秒後再試一次！');
    } catch (e) {
      throw Exception('網路連線失敗: $e');
    }
  }

  // ========================================================
  // ⚠️ 5. 台鐵即時營運通阻資訊
  // ========================================================
  static Future<List<dynamic>> getTRAAlert() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/rail/tra/alert'))
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        return json.decode(response.body)['data'] ?? [];
      } else {
        // 🌟 防崩潰：不報錯，直接回傳空陣列
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  // ========================================================
  // ⚠️ 6. 高鐵即時營運通阻資訊
  // ========================================================
  static Future<List<dynamic>> getTHSRAlert() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/rail/thsr/alert'))
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        return json.decode(response.body)['data'] ?? [];
      } else {
        // 🌟 防崩潰：高鐵通常沒有 Alert 或是後端沒寫這個 Route，遇到 404 直接吞掉回傳空陣列
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  // ========================================================
  // ⚠️ 7. 公車即時營運通阻資訊
  // ========================================================
  static Future<List<dynamic>> getBusAlert(String city) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/bus/alert/$city'))
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        return json.decode(response.body)['data'] ?? [];
      } else {
        // 🌟 防崩潰：不報錯，直接回傳空陣列
        return [];
      }
    } catch (e) {
      return [];
    }
  }
}