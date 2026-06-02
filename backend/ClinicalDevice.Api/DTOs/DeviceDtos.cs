namespace ClinicalDevice.Api.DTOs;

public record DeviceDto(
    Guid DeviceId,
    string SerialNumber,
    string Model,
    string Status,
    DateTime? LastSeen,
    DateTime? CalibrationDate);

public record CreateDeviceRequest(string SerialNumber, string Model, string? Status, DateTime? CalibrationDate);
public record UpdateDeviceRequest(string? SerialNumber, string? Model, string? Status, DateTime? CalibrationDate);

public record DeviceHealthDto(
    Guid DeviceId,
    string Status,
    DateTime? LastSeen,
    Guid? ActiveSessionId,
    Dictionary<string, double?> LatestChannels);
