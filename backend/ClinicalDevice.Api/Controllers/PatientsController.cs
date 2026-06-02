using ClinicalDevice.Api.Data;
using ClinicalDevice.Api.DTOs;
using ClinicalDevice.Api.Entities;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace ClinicalDevice.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/[controller]")]
public class PatientsController(AppDbContext db) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<List<PatientDto>>> GetAll([FromQuery] string? search)
    {
        var query = db.Patients.AsQueryable();
        if (!string.IsNullOrWhiteSpace(search))
        {
            var term = search.Trim().ToLower();
            query = query.Where(p =>
                p.Name.ToLower().Contains(term) ||
                p.MRN.ToLower().Contains(term));
        }

        var patients = await query.OrderBy(p => p.Name).ToListAsync();
        return Ok(patients.Select(ToDto).ToList());
    }

    [HttpPost]
    [Authorize(Roles = "Admin,Clinician")]
    public async Task<ActionResult<PatientDto>> Create([FromBody] CreatePatientRequest request)
    {
        if (request.PatientId.HasValue)
        {
            var existing = await db.Patients.FindAsync(request.PatientId.Value);
            if (existing is null) return NotFound();
            existing.Name = request.Name;
            existing.DateOfBirth = request.DateOfBirth;
            existing.MRN = request.MRN;
            await db.SaveChangesAsync();
            return Ok(ToDto(existing));
        }

        var patient = new Patient
        {
            PatientId = Guid.NewGuid(),
            Name = request.Name,
            DateOfBirth = request.DateOfBirth,
            MRN = request.MRN
        };
        db.Patients.Add(patient);
        await db.SaveChangesAsync();
        return Created($"/api/patients", ToDto(patient));
    }

    private static PatientDto ToDto(Patient p) => new(p.PatientId, p.Name, p.DateOfBirth, p.MRN);
}
