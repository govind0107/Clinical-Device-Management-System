class UserSession {
  final String token;
  final String username;
  final String role;
  final DateTime expiresAt;

  UserSession({
    required this.token,
    required this.username,
    required this.role,
    required this.expiresAt,
  });

  factory UserSession.fromJson(Map<String, dynamic> json) => UserSession(
        token: json['token'] as String,
        username: json['username'] as String,
        role: json['role'] as String,
        expiresAt: DateTime.parse(json['expiresAt'] as String),
      );
}

class DeviceModel {
  final String deviceId;
  final String serialNumber;
  final String model;
  final String status;
  final DateTime? lastSeen;
  final DateTime? calibrationDate;

  DeviceModel({
    required this.deviceId,
    required this.serialNumber,
    required this.model,
    required this.status,
    this.lastSeen,
    this.calibrationDate,
  });

  factory DeviceModel.fromJson(Map<String, dynamic> json) => DeviceModel(
        deviceId: json['deviceId'] as String,
        serialNumber: json['serialNumber'] as String,
        model: json['model'] as String,
        status: json['status'] as String,
        lastSeen: json['lastSeen'] != null
            ? DateTime.parse(json['lastSeen'] as String)
            : null,
        calibrationDate: json['calibrationDate'] != null
            ? DateTime.parse(json['calibrationDate'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'serialNumber': serialNumber,
        'model': model,
        if (status.isNotEmpty) 'status': status,
        if (calibrationDate != null) 'calibrationDate': calibrationDate!.toIso8601String(),
      };
}

class PatientModel {
  final String patientId;
  final String name;
  final DateTime dateOfBirth;
  final String mrn;

  PatientModel({
    required this.patientId,
    required this.name,
    required this.dateOfBirth,
    required this.mrn,
  });

  factory PatientModel.fromJson(Map<String, dynamic> json) => PatientModel(
        patientId: json['patientId'] as String,
        name: json['name'] as String,
        dateOfBirth: DateTime.parse(json['dateOfBirth'] as String),
        mrn: json['mrn'] as String,
      );

  Map<String, dynamic> toCreateJson({bool forUpdate = false}) => {
        if (forUpdate) 'patientId': patientId,
        'name': name,
        'dateOfBirth': dateOfBirth.toIso8601String(),
        'mrn': mrn,
      };
}

class SessionModel {
  final String sessionId;
  final String deviceId;
  final String? patientId;
  final DateTime startTime;
  final DateTime? endTime;

  SessionModel({
    required this.sessionId,
    required this.deviceId,
    this.patientId,
    required this.startTime,
    this.endTime,
  });

  factory SessionModel.fromJson(Map<String, dynamic> json) => SessionModel(
        sessionId: json['sessionId'] as String,
        deviceId: json['deviceId'] as String,
        patientId: json['patientId'] as String?,
        startTime: DateTime.parse(json['startTime'] as String),
        endTime: json['endTime'] != null
            ? DateTime.parse(json['endTime'] as String)
            : null,
      );
}

class ReadingModel {
  final int readingId;
  final String sessionId;
  final DateTime timestamp;
  final String channel;
  final double value;
  final String unit;

  ReadingModel({
    required this.readingId,
    required this.sessionId,
    required this.timestamp,
    required this.channel,
    required this.value,
    required this.unit,
  });

  factory ReadingModel.fromJson(Map<String, dynamic> json) => ReadingModel(
        readingId: (json['readingId'] as num).toInt(),
        sessionId: json['sessionId'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        channel: json['channel'] as String,
        value: (json['value'] as num).toDouble(),
        unit: json['unit'] as String,
      );
}

class TelemetryPoint {
  final DateTime timestamp;
  final double value;

  TelemetryPoint(this.timestamp, this.value);
}

class AlertModel {
  final String alertId;
  final String deviceId;
  final String severity;
  final String message;
  final DateTime createdAt;
  final bool acknowledged;

  AlertModel({
    required this.alertId,
    required this.deviceId,
    required this.severity,
    required this.message,
    required this.createdAt,
    required this.acknowledged,
  });

  factory AlertModel.fromJson(Map<String, dynamic> json) => AlertModel(
        alertId: json['alertId'] as String,
        deviceId: json['deviceId'] as String,
        severity: json['severity'] as String,
        message: json['message'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        acknowledged: json['acknowledged'] as bool? ?? false,
      );
}
