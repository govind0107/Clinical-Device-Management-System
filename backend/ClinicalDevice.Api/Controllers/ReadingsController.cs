using ClinicalDevice.Api.Data;
using ClinicalDevice.Api.DTOs;
using ClinicalDevice.Api.Entities;
using ClinicalDevice.Api.Hubs;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;

namespace ClinicalDevice.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/[controller]")]
public class ReadingsController(AppDbContext db, IHubContext<TelemetryHub> hub) : ControllerBase
{
    [HttpPost("batch")]
    public async Task<IActionResult> IngestBatch([FromBody] ReadingBatchRequest request)
    {
        var session = await db.Sessions.Include(s => s.Device).FirstOrDefaultAsync(s => s.SessionId == request.SessionId);
        if (session is null) return NotFound();

        var entities = request.Readings.Select(r => new Reading
        {
            SessionId = request.SessionId,
            Timestamp = r.Timestamp,
            Channel = r.Channel,
            Value = r.Value,
            Unit = r.Unit
        }).ToList();

        db.Readings.AddRange(entities);
        session.Device.LastSeen = DateTime.UtcNow;
        await db.SaveChangesAsync();

        foreach (var r in entities)
        {
            var push = new TelemetryPushDto(request.SessionId, session.DeviceId, r.Timestamp, r.Channel, r.Value, r.Unit);
            await hub.Clients.Group(TelemetryHub.SessionGroup(request.SessionId.ToString()))
                .SendAsync("TelemetryReceived", push);
        }

        return Accepted(new { count = entities.Count });
    }

    [HttpGet("{sessionId:guid}")]
    public async Task<ActionResult<List<ReadingDto>>> GetBySession(
        Guid sessionId,
        [FromQuery] DateTime? from,
        [FromQuery] DateTime? to,
        [FromQuery] string? channel)
    {
        if (!await db.Sessions.AnyAsync(s => s.SessionId == sessionId))
            return NotFound();

        var query = db.Readings.Where(r => r.SessionId == sessionId);
        if (from.HasValue) query = query.Where(r => r.Timestamp >= from);
        if (to.HasValue) query = query.Where(r => r.Timestamp <= to);
        if (!string.IsNullOrWhiteSpace(channel)) query = query.Where(r => r.Channel == channel);

        var readings = await query.OrderBy(r => r.Timestamp).Take(50000).ToListAsync();
        return Ok(readings.Select(r => new ReadingDto(r.ReadingId, r.SessionId, r.Timestamp, r.Channel, r.Value, r.Unit)).ToList());
    }
}
