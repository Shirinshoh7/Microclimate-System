/// Represents environmental control preferences for a specific location.
/// 
/// Defines acceptable ranges for temperature, humidity, and gas concentrations.
/// Used to validate sensor readings and trigger alerts.
class Profile {
  final String name;
  final double tempMin;
  final double tempMax;
  final double humidityMax;
  final double co2Max;
  final double coMax;

  Profile({
    required this.name,
    required this.tempMin,
    required this.tempMax,
    required this.humidityMax,
    required this.co2Max,
    required this.coMax,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      name: json['name'] ?? '',
      tempMin: (json['temp_min'] ?? 20.0).toDouble(),
      tempMax: (json['temp_max'] ?? 24.0).toDouble(),
      humidityMax: (json['humidity_max'] ?? 60.0).toDouble(),
      co2Max: (json['co2_max'] ?? 800.0).toDouble(),
      coMax: (json['co_max'] ?? 50.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'temp_min': tempMin,
      'temp_max': tempMax,
      'humidity_max': humidityMax,
      'co2_max': co2Max,
      'co_max': coMax,
    };
  }

  Profile copyWith({
    String? name,
    double? tempMin,
    double? tempMax,
    double? humidityMax,
    double? co2Max,
    double? coMax,
  }) {
    return Profile(
      name: name ?? this.name,
      tempMin: tempMin ?? this.tempMin,
      tempMax: tempMax ?? this.tempMax,
      humidityMax: humidityMax ?? this.humidityMax,
      co2Max: co2Max ?? this.co2Max,
      coMax: coMax ?? this.coMax,
    );
  }
}
