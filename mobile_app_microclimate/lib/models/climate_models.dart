double? _toDoubleOrNull(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

String _normKey(String key) => key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

double _pickNumber(dynamic source, List<String> aliases, {double fallback = 0.0}) {
  final aliasSet = aliases.map(_normKey).toSet();

  double? visit(dynamic node) {
    if (node is! Map) return null;
    final map = Map<String, dynamic>.from(node);

    for (final entry in map.entries) {
      if (aliasSet.contains(_normKey(entry.key))) {
        final value = _toDoubleOrNull(entry.value);
        if (value != null) return value;
      }
    }

    for (final entry in map.entries) {
      final nested = entry.value;
      if (nested is Map) {
        final value = visit(nested);
        if (value != null) return value;
      }
    }
    return null;
  }

  return visit(source) ?? fallback;
}

/// Represents a single climate data measurement from an IoT sensor.
/// 
/// Contains temperature, humidity, and gas concentration measurements
/// along with timestamp, device info, and optional predictions.
class ClimateData {
  final double temp;
  final double humidity;
  final double co2;
  final double co;
  final int mcScore;
  final String timestamp;
  final String deviceId;
  final String profile;
  final Predictions? predictions;

  ClimateData({
    required this.temp,
    required this.humidity,
    required this.co2,
    required this.co,
    required this.mcScore,
    required this.timestamp,
    required this.deviceId,
    required this.profile,
    this.predictions,
  });

  factory ClimateData.fromJson(Map<String, dynamic> json) {
    // Поддержка разных форматов от бэкенда
    final current = json['current'] ?? json;
    final root = {
      ...json,
      if (current is Map) ...Map<String, dynamic>.from(current),
    };

    return ClimateData(
      temp: _pickNumber(root, ['temp', 'temperature', 't']),
      humidity: _pickNumber(root, ['hum', 'humidity', 'rh']),
      co2: _pickNumber(root, ['co2', 'co2_ppm', 'co2ppm', 'carbon_dioxide', 'mq135']),
      co: _pickNumber(root, ['co', 'co_ppm', 'coppm', 'carbon_monoxide', 'mq7']),
      mcScore: _pickNumber(root, ['mc_score', 'mcscore'], fallback: 0).toInt(),
      timestamp: json['timestamp'] ?? DateTime.now().toIso8601String(),
      deviceId: json['device_id'] ?? 'unknown',
      profile: json['profile'] ?? 'Default',
      predictions: json['predictions'] != null
          ? Predictions.fromJson(json['predictions'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'temp': temp,
      'humidity': humidity,
      'co2': co2,
      'co': co,
      'mc_score': mcScore,
      'timestamp': timestamp,
      'device_id': deviceId,
      'profile': profile,
      'predictions': predictions?.toJson(),
    };
  }
}

// Модель прогнозов
class Predictions {
  final double temperature;
  final double humidity;
  final double co2;
  final double co;

  Predictions({
    required this.temperature,
    required this.humidity,
    required this.co2,
    required this.co,
  });

  factory Predictions.fromJson(Map<String, dynamic> json) {
    return Predictions(
      temperature: _pickNumber(json, ['temperature', 'temp', 't']),
      humidity: _pickNumber(json, ['humidity', 'hum', 'rh']),
      co2: _pickNumber(json, ['co2', 'co2_ppm', 'co2ppm', 'carbon_dioxide', 'mq135']),
      co: _pickNumber(json, ['co', 'co_ppm', 'coppm', 'carbon_monoxide', 'mq7']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'temperature': temperature,
      'humidity': humidity,
      'co2': co2,
      'co': co,
    };
  }
}

// Модель профиля климата
class ClimateProfile {
  final String? id;
  final String name;
  final double tempMin;
  final double tempMax;
  final double humidityMin;
  final double humidityMax;
  final int co2Max;
  final int coMax;

  ClimateProfile({
    this.id,
    required this.name,
    required this.tempMin,
    required this.tempMax,
    this.humidityMin = 0.0,
    required this.humidityMax,
    required this.co2Max,
    required this.coMax,
  });

  factory ClimateProfile.fromJson(Map<String, dynamic> json) {
    return ClimateProfile(
      id: json['id'],
      name: json['name'] ?? '',
      tempMin: (json['temp_min'] ?? 20.0).toDouble(),
      tempMax: (json['temp_max'] ?? 24.0).toDouble(),
      humidityMin: (json['humidity_min'] ?? 0.0).toDouble(),
      humidityMax: (json['humidity_max'] ?? 60.0).toDouble(),
      co2Max: (json['co2_max'] ?? 800).toInt(),
      coMax: (json['co_max'] ?? 50).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'temp_min': tempMin,
      'temp_max': tempMax,
      'humidity_min': humidityMin,
      'humidity_max': humidityMax,
      'co2_max': co2Max,
      'co_max': coMax,
    };
  }

  ClimateProfile copyWith({
    String? id,
    String? name,
    double? tempMin,
    double? tempMax,
    double? humidityMin,
    double? humidityMax,
    int? co2Max,
    int? coMax,
  }) {
    return ClimateProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      tempMin: tempMin ?? this.tempMin,
      tempMax: tempMax ?? this.tempMax,
      humidityMin: humidityMin ?? this.humidityMin,
      humidityMax: humidityMax ?? this.humidityMax,
      co2Max: co2Max ?? this.co2Max,
      coMax: coMax ?? this.coMax,
    );
  }

  // Дефолтные профили
  static List<ClimateProfile> get defaults => [
        ClimateProfile(
          id: '1',
          name: '💊 Аптека',
          tempMin: 20.0,
          tempMax: 25.0,
          humidityMax: 60.0,
          co2Max: 800,
          coMax: 30,
        ),
        ClimateProfile(
          id: '2',
          name: '🏢 Офис',
          tempMin: 22.0,
          tempMax: 24.0,
          humidityMax: 65.0,
          co2Max: 1000,
          coMax: 30,
        ),
        ClimateProfile(
          id: '3',
          name: '🏠 Дом',
          tempMin: 20.0,
          tempMax: 26.0,
          humidityMax: 70.0,
          co2Max: 1200,
          coMax: 35,
        ),
        ClimateProfile(
          id: '4',
          name: '🌱 Теплица',
          tempMin: 18.0,
          tempMax: 28.0,
          humidityMax: 80.0,
          co2Max: 1500,
          coMax: 40,
        ),
      ];
}

// Модель лога событий
class EventLog {
  final DateTime time;
  final String message;
  final String type;

  EventLog({
    required this.time,
    required this.message,
    required this.type,
  });

  String get formattedTime {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() {
    return {
      'time': time.toIso8601String(),
      'message': message,
      'type': type,
    };
  }

  factory EventLog.fromJson(Map<String, dynamic> json) {
    return EventLog(
      time: DateTime.tryParse(json['time']?.toString() ?? '') ?? DateTime.now(),
      message: json['message']?.toString() ?? '',
      type: json['type']?.toString() ?? 'System',
    );
  }
}

// Модель ответа API
class ApiResponse {
  final ClimateData current;
  final double? prediction;
  final ForecastMeta? forecast;

  ApiResponse({
    required this.current,
    this.prediction,
    this.forecast,
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    return ApiResponse(
      current: ClimateData.fromJson(json),
      prediction: json['predictions']?['temperature']?.toDouble(),
      forecast: json['forecast'] is Map<String, dynamic>
          ? ForecastMeta.fromJson(json['forecast'])
          : null,
    );
  }
}

class ForecastMeta {
  final String? label;
  final int? minutes;
  final int? stepsAhead;
  final int? samplePeriodMin;

  ForecastMeta({
    this.label,
    this.minutes,
    this.stepsAhead,
    this.samplePeriodMin,
  });

  factory ForecastMeta.fromJson(Map<String, dynamic> json) {
    return ForecastMeta(
      label: json['label']?.toString(),
      minutes: (json['minutes'] as num?)?.toInt(),
      stepsAhead: (json['steps_ahead'] as num?)?.toInt(),
      samplePeriodMin: (json['sample_period_min'] as num?)?.toInt(),
    );
  }
}

// История измерений
class HistoryEntry {
  final double temp;
  final double hum;
  final double co2;
  final double co;
  final DateTime time;

  HistoryEntry({
    required this.temp,
    required this.hum,
    required this.co2,
    required this.co,
    required this.time,
  });

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    final root = {
      ...json,
      if (json['current'] is Map) ...Map<String, dynamic>.from(json['current']),
    };
    return HistoryEntry(
      temp: _pickNumber(root, ['temp', 'temperature', 't']),
      hum: _pickNumber(root, ['hum', 'humidity', 'rh']),
      co2: _pickNumber(root, ['co2', 'co2_ppm', 'co2ppm', 'carbon_dioxide', 'mq135']),
      co: _pickNumber(root, ['co', 'co_ppm', 'coppm', 'carbon_monoxide', 'mq7']),
      time: json['time'] is DateTime
          ? json['time']
          : DateTime.parse(
              (json['time'] ??
                      json['timestamp'] ??
                      DateTime.now().toIso8601String())
                  .toString(),
            ),
    );
  }
}

class MetricStats {
  final double current;
  final double min;
  final double max;
  final double avg;

  const MetricStats({
    required this.current,
    required this.min,
    required this.max,
    required this.avg,
  });

  factory MetricStats.fromJson(Map<String, dynamic>? json) {
    final source = json ?? const <String, dynamic>{};
    return MetricStats(
      current: (source['current'] ?? 0.0).toDouble(),
      min: (source['min'] ?? 0.0).toDouble(),
      max: (source['max'] ?? 0.0).toDouble(),
      avg: (source['avg'] ?? 0.0).toDouble(),
    );
  }
}

class ClimateStats {
  final MetricStats temp;
  final MetricStats humidity;
  final MetricStats co2;
  final MetricStats co;

  const ClimateStats({
    required this.temp,
    required this.humidity,
    required this.co2,
    required this.co,
  });

  factory ClimateStats.fromJson(Map<String, dynamic> json) {
    return ClimateStats(
      temp: MetricStats.fromJson(json['temp'] as Map<String, dynamic>?),
      humidity: MetricStats.fromJson(
        json['humidity'] as Map<String, dynamic>?,
      ),
      co2: MetricStats.fromJson(json['co2'] as Map<String, dynamic>?),
      co: MetricStats.fromJson(json['co'] as Map<String, dynamic>?),
    );
  }
}

class HistoryIssue {
  final DateTime time;
  final double? co2Ppm;
  final double? coPpm;
  final String? message;

  const HistoryIssue({
    required this.time,
    this.co2Ppm,
    this.coPpm,
    this.message,
  });

  factory HistoryIssue.fromJson(Map<String, dynamic> json) {
    return HistoryIssue(
      time: DateTime.tryParse(json['time']?.toString() ?? '') ?? DateTime.now(),
      co2Ppm: (json['co2_ppm'] as num?)?.toDouble(),
      coPpm: ((json['co_ppm'] ?? json['co']) as num?)?.toDouble(),
      message: json['message']?.toString(),
    );
  }
}

class HistoryResponse {
  final List<HistoryEntry> items;
  final List<HistoryIssue> issues;

  const HistoryResponse({
    required this.items,
    required this.issues,
  });

  factory HistoryResponse.fromJson(Map<String, dynamic> json) {
    final rows = json['items'] ?? json['history'] ?? const [];
    final issues = json['issues'] ?? const [];
    return HistoryResponse(
      items: (rows as List)
          .whereType<Map>()
          .map((e) => HistoryEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      issues: (issues as List)
          .whereType<Map>()
          .map((e) => HistoryIssue.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}
