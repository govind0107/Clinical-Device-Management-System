namespace ClinicalDevice.Api.DTOs;

public record SessionDto(
    Guid SessionId,
    Guid DeviceId,
    Guid? PatientId,
    DateTime StartTime,
    DateTime? EndTime);

public record StartSessionRequest(Guid DeviceId, Guid? PatientId);
