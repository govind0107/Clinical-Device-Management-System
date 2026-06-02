namespace ClinicalDevice.Api.Entities;

public class Patient
{
    public Guid PatientId { get; set; }
    public string Name { get; set; } = string.Empty;
    public DateTime DateOfBirth { get; set; }
    public string MRN { get; set; } = string.Empty;

    public ICollection<Session> Sessions { get; set; } = new List<Session>();
}
