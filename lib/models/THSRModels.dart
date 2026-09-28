// --------------------------------------------------------
// 5. 高鐵營運通阻 (THSRAlert)
// --------------------------------------------------------
class THSRAlert {
  final String alertID;
  final String title;
  final String description;
  final String status;
  final String alertURL;

  THSRAlert({
    required this.alertID,
    required this.title,
    required this.description,
    required this.status,
    required this.alertURL,
  });

  factory THSRAlert.fromJson(Map<String, dynamic> json) {
    return THSRAlert(
      alertID: json['alertID'] ?? '0',
      title: json['title'] ?? '全線營運正常',
      description: json['description'] ?? '',
      status: json['status'] ?? '正常',
      alertURL: json['alertURL'] ?? '',
    );
  }
}

class THSRTimetable {
  final String trainNo;
  final int direction;
  final String startingStationName;
  final String startingStationNameEn; // 🌟 新增
  final String endingStationName;
  final String endingStationNameEn;   // 🌟 新增
  final String arrivalTime;
  final String departureTime;

  THSRTimetable({
    required this.trainNo,
    required this.direction,
    required this.startingStationName,
    required this.startingStationNameEn,
    required this.endingStationName,
    required this.endingStationNameEn,
    required this.arrivalTime,
    required this.departureTime,
  });

  factory THSRTimetable.fromJson(Map<String, dynamic> json) {
    return THSRTimetable(
      trainNo: json['trainNo'] ?? '',
      direction: json['direction'] ?? 0,
      startingStationName: json['startingStationName'] ?? '',
      startingStationNameEn: json['startingStationNameEn'] ?? '', // 🌟 接住英文
      endingStationName: json['endingStationName'] ?? '',
      endingStationNameEn: json['endingStationNameEn'] ?? '', // 🌟 接住英文
      arrivalTime: json['arrivalTime'] ?? '',
      departureTime: json['departureTime'] ?? '',
    );
  }
}