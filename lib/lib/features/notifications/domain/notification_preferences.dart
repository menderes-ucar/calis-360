class NotificationPreferences {
  const NotificationPreferences({
    this.enabled = true,
    this.studyReminders = true,
    this.examReminders = true,
    this.goalReminders = true,
    this.streakReminders = true,
    this.weeklyReports = true,
    this.productUpdates = true,
  });

  final bool enabled;
  final bool studyReminders;
  final bool examReminders;
  final bool goalReminders;
  final bool streakReminders;
  final bool weeklyReports;
  final bool productUpdates;

  NotificationPreferences copyWith({
    bool? enabled,
    bool? studyReminders,
    bool? examReminders,
    bool? goalReminders,
    bool? streakReminders,
    bool? weeklyReports,
    bool? productUpdates,
  }) {
    return NotificationPreferences(
      enabled: enabled ?? this.enabled,
      studyReminders: studyReminders ?? this.studyReminders,
      examReminders: examReminders ?? this.examReminders,
      goalReminders: goalReminders ?? this.goalReminders,
      streakReminders: streakReminders ?? this.streakReminders,
      weeklyReports: weeklyReports ?? this.weeklyReports,
      productUpdates: productUpdates ?? this.productUpdates,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'studyReminders': studyReminders,
      'examReminders': examReminders,
      'goalReminders': goalReminders,
      'streakReminders': streakReminders,
      'weeklyReports': weeklyReports,
      'productUpdates': productUpdates,
    };
  }

  factory NotificationPreferences.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const NotificationPreferences();

    bool readBool(String key, bool fallback) {
      final value = map[key];
      return value is bool ? value : fallback;
    }

    return NotificationPreferences(
      enabled: readBool('enabled', true),
      studyReminders: readBool('studyReminders', true),
      examReminders: readBool('examReminders', true),
      goalReminders: readBool('goalReminders', true),
      streakReminders: readBool('streakReminders', true),
      weeklyReports: readBool('weeklyReports', true),
      productUpdates: readBool('productUpdates', true),
    );
  }
}
