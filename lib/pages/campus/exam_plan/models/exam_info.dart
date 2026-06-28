/// 单门考试信息模型，从教务系统考表 HTML 解析。
class ExamInfo {
  final String courseName;
  final String week;
  final String date;
  final String weekday;
  final String timeRange;
  final String location;
  final String seatNumber;
  final String ticketNumber;
  final String tip;

  const ExamInfo({
    required this.courseName,
    required this.week,
    required this.date,
    required this.weekday,
    required this.timeRange,
    required this.location,
    required this.seatNumber,
    required this.ticketNumber,
    required this.tip,
  });

  Map<String, Object> toJson() {
    return {
      'courseName': courseName,
      'week': week,
      'date': date,
      'weekday': weekday,
      'timeRange': timeRange,
      'location': location,
      'seatNumber': seatNumber,
      'ticketNumber': ticketNumber,
      'tip': tip,
    };
  }
}
