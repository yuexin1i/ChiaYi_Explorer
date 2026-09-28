// --------------------------------------------------------
// 6. YouBike 即時車位 (YouBikeAvailability)
// --------------------------------------------------------
class YouBikeAvailability {
  final String stationUID;
  final int serviceStatus; // 通常 1 代表正常營運
  final int rentBikes;     // 總可借
  final int returnBikes;   // 可還空位
  final int generalBikes;  // 1.0/2.0 可借
  final int electricBikes; // 2.0E (電輔車) 可借
  final String updateTime;

  YouBikeAvailability({
    required this.stationUID,
    required this.serviceStatus,
    required this.rentBikes,
    required this.returnBikes,
    required this.generalBikes,
    required this.electricBikes,
    required this.updateTime,
  });

  factory YouBikeAvailability.fromJson(Map<String, dynamic> json) {
    return YouBikeAvailability(
      // 👇 這裡的 key 已經全部改為對應 transformer.py 送出的小寫開頭格式
      stationUID: json['stationUID'] ?? '',
      serviceStatus: json['status'] ?? 0,
      rentBikes: json['availableRentBikes'] ?? 0,
      returnBikes: json['availableReturnBikes'] ?? 0,

      // 👇 因為你的 transformer 目前沒有送出底下這三個欄位，所以先給安全的預設值
      // 如果未來需要顯示，可以再去 transformer.py 把資料補送出來
      generalBikes: 0,
      electricBikes: 0,
      updateTime: '',
    );
  }
}