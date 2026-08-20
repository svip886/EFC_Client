/// 签到（每日挂号）状态，对应 `GET /api/checkin`。
/// 字段来源见 docs/ECFC_API.md §5.8 / api-samples/api_checkin.json。
class CheckinStatus {
  final bool checkedToday;
  final int consecutiveDays;
  final int currentStreak;
  final int longestStreak;
  final int totalCheckIns;
  final int points;
  final int exp;
  final int level;
  final int todayCount;
  final String? todayMood;

  const CheckinStatus({
    required this.checkedToday,
    required this.consecutiveDays,
    required this.currentStreak,
    required this.longestStreak,
    required this.totalCheckIns,
    required this.points,
    required this.exp,
    required this.level,
    required this.todayCount,
    this.todayMood,
  });

  factory CheckinStatus.fromJson(Map<String, dynamic> json) {
    final today = json['todayCheckIn'] as Map?;
    return CheckinStatus(
      checkedToday: json['checkedToday'] as bool? ?? false,
      consecutiveDays: (json['consecutiveDays'] as num?)?.toInt() ?? 0,
      currentStreak: (json['currentStreak'] as num?)?.toInt() ?? 0,
      longestStreak: (json['longestStreak'] as num?)?.toInt() ?? 0,
      totalCheckIns: (json['totalCheckIns'] as num?)?.toInt() ?? 0,
      points: (json['points'] as num?)?.toInt() ?? 0,
      exp:
          (json['exp'] as num?)?.toInt() ??
          (json['experience'] as num?)?.toInt() ??
          0,
      level: (json['level'] as num?)?.toInt() ?? 1,
      todayCount: (json['todayCount'] as num?)?.toInt() ?? 0,
      todayMood: today != null ? today['mood'] as String? : null,
    );
  }
}
