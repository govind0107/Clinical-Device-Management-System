namespace ClinicalDevice.Api.Entities;

public class Session
{
    public Guid SessionId { get; set; }
    public Guid DeviceId { get; set; }
    public Guid? PatientId { get; set; }
    public DateTime StartTime { get; set; }
    public DateTime? EndTime { get; set; }

    public Device Device { get; set; } = null!;
    public Patient? Patient { get; set; }
    public ICollection<Reading> Readings { get; set; } = new List<Reading>();
}
