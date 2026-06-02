namespace ClinicalDevice.Api.Entities;

public class Alert
{
    public Guid AlertId { get; set; }
    public Guid DeviceId { get; set; }
    public string Severity { get; set; } = "Warning";
    public string Message { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
    public bool Acknowledged { get; set; }

    public Device Device { get; set; } = null!;
}
