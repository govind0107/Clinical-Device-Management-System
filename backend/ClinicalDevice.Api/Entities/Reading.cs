namespace ClinicalDevice.Api.Entities;

public class Reading
{
    public long ReadingId { get; set; }
    public Guid SessionId { get; set; }
    public DateTime Timestamp { get; set; }
    public string Channel { get; set; } = string.Empty; // ECG, SpO2, BP
    public double Value { get; set; }
    public string Unit { get; set; } = string.Empty;

    public Session Session { get; set; } = null!;
}
