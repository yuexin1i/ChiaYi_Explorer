// --------------------------------------------------------
// 1. 公車預估到站時間 (BusEta)
// --------------------------------------------------------
class BusEta {
  final String stopUID;
  final String routeUID;
  final int direction;
  final int? estimateTime; // 預估到站時間 (秒)，null 代表需參考 stopStatus
  final int stopStatus; // 0:正常, 1:尚未發車, 2:交管, 3:末班過, 4:未營運
  final String? nextBusTime;
  final bool isLastBus;
  final String? plateNumb;

  BusEta({
    required this.stopUID,
    required this.routeUID,
    required this.direction,
    this.estimateTime,
    required this.stopStatus,
    this.nextBusTime,
    required this.isLastBus,
    this.plateNumb,
  });

  factory BusEta.fromJson(Map<String, dynamic> json) {
    return BusEta(
      // 💡 同時檢查小寫與大寫開頭，哪個有值就抓哪個！
      stopUID: json['stopUID'] ?? json['StopUID'] ?? '',
      routeUID: json['routeUID'] ?? json['RouteUID'] ?? '',
      direction: json['direction'] ?? json['Direction'] ?? -1,
      estimateTime: json['estimateTime'] ?? json['EstimateTime'],
      stopStatus: json['stopStatus'] ?? json['StopStatus'] ?? -1,
      nextBusTime: json['nextBusTime'] ?? json['NextBusTime'],
      isLastBus: json['isLastBus'] ?? json['IsLastBus'] ?? false,
      plateNumb: json['plateNumb'] ?? json['PlateNumb'],
    );
  }
}
// --------------------------------------------------------
// 2. 公車營運通阻 (BusAlert)
// --------------------------------------------------------
class BusAlert {
  final String alertID;
  final String title;
  final String description;
  final String startTime;
  final String endTime;
  final List<String> affectedRouteIDs;
  final List<String> affectedStopIDs;

  BusAlert({
    required this.alertID,
    required this.title,
    required this.description,
    required this.startTime,
    required this.endTime,
    required this.affectedRouteIDs,
    required this.affectedStopIDs,
  });

  factory BusAlert.fromJson(Map<String, dynamic> json) {
    return BusAlert(
      alertID: json['alertID'] ?? '',
      title: json['title'] ?? '營運通阻公告',
      description: json['description'] ?? '',
      startTime: json['startTime'] ?? '',
      endTime: json['endTime'] ?? '',

      // 💡 後端已經幫忙整理成單純的陣列了，直接在這裡安全轉型 (cast) 即可
      // 不用再寫一堆 if 判斷 json['Scope']['Routes'] 了！
      affectedRouteIDs: List<String>.from(json['affectedRouteIDs'] ?? []),
      affectedStopIDs: List<String>.from(json['affectedStopIDs'] ?? []),
    );
  }
}