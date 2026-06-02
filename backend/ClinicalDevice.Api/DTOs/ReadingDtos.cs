namespace ClinicalDevice.Api.DTOs;

public record ReadingDto(long ReadingId, Guid SessionId, DateTime Timestamp, string Channel, double Value, string Unit);

public record ReadingBatchItem(DateTime Timestamp, string Channel, double Value, string Unit);
public record ReadingBatchRequest(Guid SessionId, List<ReadingBatchItem> Readings);

public record TelemetryPushDto(Guid SessionId, Guid DeviceId, DateTime Timestamp, string Channel, double Value, string Unit);
