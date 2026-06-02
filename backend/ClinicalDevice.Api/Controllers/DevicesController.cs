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
public class DevicesController(AppDbContext db, SimulationState simulationState) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<List<DeviceDto>>> GetAll([FromQuery] string? status)
    {
        var query = db.Devices.AsQueryable();
        if (!string.IsNullOrWhiteSpace(status))
            query = query.Where(d => d.Status == status);

        var devices = await query.OrderBy(d => d.SerialNumber).ToListAsync();
        return Ok(devices.Select(ToDto).ToList());
    }

    [HttpGet("{id:guid}")]
    public async Task<ActionResult<DeviceDto>> GetById(Guid id)
    {
        var device = await db.Devices.FindAsync(id);
        return device is null ? NotFound() : Ok(ToDto(device));
    }

    [HttpPost]
    [Authorize(Roles = "Admin,Tech")]
    public async Task<ActionResult<DeviceDto>> Create([FromBody] CreateDeviceRequest request)
    {
        var device = new Device
        {
            DeviceId = Guid.NewGuid(),
            SerialNumber = request.SerialNumber,
            Model = request.Model,
            Status = request.Status ?? "Offline",
            CalibrationDate = request.CalibrationDate,
            LastSeen = null
        };
        db.Devices.Add(device);
        await db.SaveChangesAsync();
        return CreatedAtAction(nameof(GetById), new { id = device.DeviceId }, ToDto(device));
    }

    [HttpPut("{id:guid}")]
    [Authorize(Roles = "Admin,Tech")]
    public async Task<ActionResult<DeviceDto>> Update(Guid id, [FromBody] UpdateDeviceRequest request)
    {
        var device = await db.Devices.FindAsync(id);
        if (device is null) return NotFound();

        if (request.SerialNumber is not null) device.SerialNumber = request.SerialNumber;
        if (request.Model is not null) device.Model = request.Model;
        if (request.Status is not null) device.Status = request.Status;
        if (request.CalibrationDate.HasValue) device.CalibrationDate = request.CalibrationDate;

        await db.SaveChangesAsync();
        return Ok(ToDto(device));
    }

    [HttpDelete("{id:guid}")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> Delete(Guid id)
    {
        var device = await db.Devices.FindAsync(id);
        if (device is null) return NotFound();
        db.Devices.Remove(device);
        await db.SaveChangesAsync();
        return NoContent();
    }

    [HttpGet("{id:guid}/health")]
    public async Task<ActionResult<DeviceHealthDto>> GetHealth(Guid id)
    {
        var device = await db.Devices.FindAsync(id);
        if (device is null) return NotFound();

        var activeSession = await db.Sessions
            .Where(s => s.DeviceId == id && s.EndTime == null)
            .OrderByDescending(s => s.StartTime)
            .FirstOrDefaultAsync();

        var channels = new Dictionary<string, double?>();
        if (activeSession is not null)
        {
            var latest = await db.Readings
                .Where(r => r.SessionId == activeSession.SessionId)
                .GroupBy(r => r.Channel)
                .Select(g => g.OrderByDescending(r => r.Timestamp).First())
                .ToListAsync();

            foreach (var r in latest)
                channels[r.Channel] = r.Value;
        }

        return Ok(new DeviceHealthDto(device.DeviceId, device.Status, device.LastSeen,
            activeSession?.SessionId, channels));
    }

    [HttpPost("{id:guid}/simulate")]
    [Authorize(Roles = "Admin,Clinician,Tech")]
    public async Task<IActionResult> Simulate(Guid id)
    {
        var session = await db.Sessions
            .Where(s => s.DeviceId == id && s.EndTime == null)
            .OrderByDescending(s => s.StartTime)
            .FirstOrDefaultAsync();

        if (session is null)
            return BadRequest(new { message = "No active session for this device. Start a session first." });

        if (!simulationState.IsActive(session.SessionId))
            return BadRequest(new { message = "Session is not simulating." });

        simulationState.RequestSpike(session.SessionId);
        return Accepted(new { message = "Threshold spike scheduled for next telemetry batch." });
    }

    private static DeviceDto ToDto(Device d) => new(d.DeviceId, d.SerialNumber, d.Model, d.Status, d.LastSeen, d.CalibrationDate);
}
