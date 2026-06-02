namespace ClinicalDevice.Api.DTOs;

public record AlertDto(
    Guid AlertId,
    Guid DeviceId,
    string Severity,
    string Message,
    DateTime CreatedAt,
    bool Acknowledged);

public record AcknowledgeAlertRequest(bool Acknowledged = true);
