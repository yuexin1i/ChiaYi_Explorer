// --------------------------------------------------------
// 3. 台鐵即時看板 (TRALiveBoard)
// --------------------------------------------------------
class TRALiveBoard {
  final String stationID;
  final String trainNo;
  final int direction;
  final String trainTypeNameZh;
  final String trainTypeNameEn; // 🌟 新增
  final int tripLine;
  final String endingStationZh;
  final String endingStationEn; // 🌟 新增
  final String scheduledArrivalTime;
  final String scheduledDepartureTime;
  final int delayTime;
  final String updateTime;

  TRALiveBoard({
    required this.stationID,
    required this.trainNo,
    required this.direction,
    required this.trainTypeNameZh,
    required this.trainTypeNameEn,
    required this.tripLine,
    required this.endingStationZh,
    required this.endingStationEn,
    required this.scheduledArrivalTime,
    required this.scheduledDepartureTime,
    required this.delayTime,
    required this.updateTime,
  });

  factory TRALiveBoard.fromJson(Map<String, dynamic> json) {
    return TRALiveBoard(
      stationID: json['stationID'] ?? '',
      trainNo: json['trainNo'] ?? '',
      direction: json['direction'] ?? 0,
      trainTypeNameZh: json['trainTypeNameZh'] ?? '未知車種',
      trainTypeNameEn: json['trainTypeNameEn'] ?? '', // 🌟 接住英文
      tripLine: json['tripLine'] ?? 0,
      endingStationZh: json['endingStationZh'] ?? '',
      endingStationEn: json['endingStationEn'] ?? '', // 🌟 接住英文
      scheduledArrivalTime: json['scheduledArrivalTime'] ?? '',
      scheduledDepartureTime: json['scheduledDepartureTime'] ?? '',
      delayTime: json['delayTime'] ?? 0,
      updateTime: json['updateTime'] ?? '',
    );
  }
}

// --------------------------------------------------------
// 4. 台鐵營運通阻 (TRAAlert)
// --------------------------------------------------------
class TRAAlert {
  final String serviceID;
  final String serviceName;
  final int inboundStatus;
  final String? inboundReason;
  final int outboundStatus;
  final String? outboundReason;

  TRAAlert({
    required this.serviceID,
    required this.serviceName,
    required this.inboundStatus,
    this.inboundReason,
    required this.outboundStatus,
    this.outboundReason,
  });

  factory TRAAlert.fromJson(Map<String, dynamic> json) {
    return TRAAlert(
      serviceID: json['serviceID'] ?? '',
      serviceName: json['serviceName'] ?? '',
      inboundStatus: json['inboundStatus'] ?? 0,
      inboundReason: json['inboundReason'],
      outboundStatus: json['outboundStatus'] ?? 0,
      outboundReason: json['outboundReason'],
    );
  }
}