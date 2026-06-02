namespace ClinicalDevice.Api.Entities;

public class Device
{
    public Guid DeviceId { get; set; }
    public string SerialNumber { get; set; } = string.Empty;
    public string Model { get; set; } = string.Empty;
    public string Status { get; set; } = "Offline"; // Online, Offline, Alert
    public DateTime? LastSeen { get; set; }
    public DateTime? CalibrationDate { get; set; }

    public ICollection<Session> Sessions { get; set; } = new List<Session>();
    public ICollection<Alert> Alerts { get; set; } = new List<Alert>();
}
