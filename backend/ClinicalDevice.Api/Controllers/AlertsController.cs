using ClinicalDevice.Api.Data;
using ClinicalDevice.Api.DTOs;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace ClinicalDevice.Api.Controllers;

[ApiController]
[Authorize]
[Route("api/[controller]")]
public class AlertsController(AppDbContext db) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<List<AlertDto>>> GetAll(
        [FromQuery] bool? acknowledged,
        [FromQuery] Guid? deviceId)
    {
        var query = db.Alerts.AsQueryable();
        if (acknowledged.HasValue) query = query.Where(a => a.Acknowledged == acknowledged);
        if (deviceId.HasValue) query = query.Where(a => a.DeviceId == deviceId);

        var alerts = await query.OrderByDescending(a => a.CreatedAt).ToListAsync();
        return Ok(alerts.Select(a => new AlertDto(a.AlertId, a.DeviceId, a.Severity,
            a.Message, a.CreatedAt, a.Acknowledged)).ToList());
    }

    /// <summary>UI acknowledge action (section 3.1) — updates Acknowledged via POST sub-route.</summary>
    [HttpPost("{id:guid}/acknowledge")]
    [Authorize(Roles = "Admin,Clinician")]
    public async Task<ActionResult<AlertDto>> Acknowledge(Guid id, [FromBody] AcknowledgeAlertRequest? request)
    {
        var alert = await db.Alerts.FindAsync(id);
        if (alert is null) return NotFound();

        alert.Acknowledged = request?.Acknowledged ?? true;
        await db.SaveChangesAsync();

        return Ok(new AlertDto(alert.AlertId, alert.DeviceId, alert.Severity,
            alert.Message, alert.CreatedAt, alert.Acknowledged));
    }
}
