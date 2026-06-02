using ClinicalDevice.Api.Data;
using ClinicalDevice.Api.DTOs;
using ClinicalDevice.Api.Entities;
using ClinicalDevice.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace ClinicalDevice.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/[controller]")]
public class SessionsController(AppDbContext db, SimulationState simulationState) : ControllerBase
{
    [HttpPost("start")]
    [Authorize(Roles = "Admin,Clinician,Tech")]
    public async Task<ActionResult<SessionDto>> Start([FromBody] StartSessionRequest request)
    {
        var device = await db.Devices.FindAsync(request.DeviceId);
        if (device is null) return NotFound(new { message = "Device not found" });

        if (request.PatientId.HasValue && await db.Patients.FindAsync(request.PatientId) is null)
            return NotFound(new { message = "Patient not found" });

        var existing = await db.Sessions.AnyAsync(s => s.DeviceId == request.DeviceId && s.EndTime == null);
        if (existing)
            return Conflict(new { message = "Device already has an active session." });

        var session = new Session
        {
            SessionId = Guid.NewGuid(),
            DeviceId = request.DeviceId,
            PatientId = request.PatientId,
            StartTime = DateTime.UtcNow
        };

        db.Sessions.Add(session);
        device.Status = "Online";
        device.LastSeen = DateTime.UtcNow;
        await db.SaveChangesAsync();

        simulationState.Start(session.SessionId);
        return Ok(ToDto(session));
    }

    [HttpPost("{id:guid}/stop")]
    [Authorize(Roles = "Admin,Clinician,Tech")]
    public async Task<ActionResult<SessionDto>> Stop(Guid id)
    {
        var session = await db.Sessions.Include(s => s.Device).FirstOrDefaultAsync(s => s.SessionId == id);
        if (session is null) return NotFound();

        session.EndTime = DateTime.UtcNow;
        simulationState.Stop(id);

        if (session.Device.Status == "Online")
            session.Device.Status = "Offline";

        await db.SaveChangesAsync();
        return Ok(ToDto(session));
    }

    private static SessionDto ToDto(Session s) =>
        new(s.SessionId, s.DeviceId, s.PatientId, s.StartTime, s.EndTime);
}
