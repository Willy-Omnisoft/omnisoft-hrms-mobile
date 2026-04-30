class PublicHoliday {
  final DateTime date;
  final String name;

  PublicHoliday({required this.date, required this.name});

  factory PublicHoliday.fromJson(Map<String, dynamic> json) {
    return PublicHoliday(
      date: DateTime.parse(json['date'] as String),
      name: json['name']?.toString() ?? '',
    );
  }
}
