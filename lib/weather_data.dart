class WeatherData {
  final String city;
  final String icon;
  final double tempC;
  final String condition;
  final double windKph;
  final int humidity;

  WeatherData({
    required this.city,
    required this.icon,
    required this.tempC,
    required this.condition,
    required this.windKph,
    required this.humidity,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    if (json == null) {
      throw FormatException('Нет данных');
    }

    try {
      return WeatherData(
        city: json['location']['name'],
        icon: json['current']['condition']['icon'],
        tempC: json['current']['temp_c'],
        condition: json['current']['condition']['text'],
        windKph: json['current']['wind_kph'],
        humidity: json['current']['humidity'],
      );
    } on Exception catch (_) {
      throw FormatException('Некорректные данные');
    }
  }


  factory WeatherData.fromJsonCache(Map<String, dynamic> json) {
    if (json == null) {
      throw FormatException('Нет данных');
    }

    try {
      return WeatherData(
        city: json['city'],
        icon: json['icon'],
        tempC: json['tempC'],
        condition: json['condition'],
        windKph: json['windKph'],
        humidity: json['humidity'],
      );
    } on Exception catch (_) {
      throw FormatException('Некорректные данные');
    }
  }


  Map<String, dynamic> toJson() {
    return {
      'city': city,
      'icon': icon,
      'tempC': tempC,
      'condition': condition,
      'windKph': windKph,
      'humidity': humidity,
    };
  }
}
