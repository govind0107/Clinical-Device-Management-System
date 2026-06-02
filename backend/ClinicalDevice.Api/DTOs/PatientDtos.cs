namespace ClinicalDevice.Api.DTOs;

public record PatientDto(Guid PatientId, string Name, DateTime DateOfBirth, string MRN);
/// <summary>POST /api/patients — create when PatientId is null; update when PatientId is set (edit flow).</summary>
public record CreatePatientRequest(string Name, DateTime DateOfBirth, string MRN, Guid? PatientId = null);
