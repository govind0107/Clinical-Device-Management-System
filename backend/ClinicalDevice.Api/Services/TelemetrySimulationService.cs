using ClinicalDevice.Api.Data;
using ClinicalDevice.Api.DTOs;
using ClinicalDevice.Api.Entities;
using ClinicalDevice.Api.Hubs;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;

namespace ClinicalDevice.Api.Services;

public class TelemetrySimulationService(
    IServiceScopeFactory scopeFactory,
    SimulationState simulationState,
    IHubContext<TelemetryHub> hub,
    IConfiguration config,
    ILogger<TelemetrySimulationService> logger) : BackgroundService
{
    private readonly Dictionary<Guid, double> _phase = new();

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var rateHz = Math.Clamp(config.GetValue("Simulation:SampleRateHz", 10), 1, 125);
        var interval = TimeSpan.FromMilliseconds(1000.0 / rateHz);
        var batchSize = Math.Max(1, config.GetValue("Simulation:BatchSize", 1));

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                var sessions = simulationState.GetActiveSessions();
                foreach (var sessionId in sessions)
                {
                    await GenerateBatchAsync(sessionId, batchSize, stoppingToken);
                }
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Simulation tick failed");
            }

            await Task.Delay(interval, stoppingToken);
        }
    }

    private async Task GenerateBatchAsync(Guid sessionId, int batchSize, CancellationToken ct)
    {
        using var scope = scopeFactory.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();

        var session = await db.Sessions
            .Include(s => s.Device)
            .FirstOrDefaultAsync(s => s.SessionId == sessionId && s.EndTime == null, ct);

        if (session is null)
        {
            simulationState.Stop(sessionId);
            return;
        }

        if (!_phase.ContainsKey(sessionId))
            _phase[sessionId] = Random.Shared.NextDouble() * Math.PI * 2;

        var readings = new List<Reading>();
        var pushes = new List<TelemetryPushDto>();
        var now = DateTime.UtcNow;
        var spike = simulationState.TryConsumeSpike(sessionId);

        for (var i = 0; i < batchSize; i++)
        {
            _phase[sessionId] += 0.15;
            var t = _phase[sessionId];
            var noise = () => (Random.Shared.NextDouble() - 0.5) * 2;

            var ecg = 75 + 25 * Math.Sin(t * 3) + 8 * Math.Sin(t * 12) + noise() * 3;
            var spo2 = 97 + 2 * Math.Sin(t * 0.5) + noise() * 0.5;
            var bp = 120 + 15 * Math.Sin(t * 0.8) + noise() * 4;

            if (spike)
            {
                ecg = 165;
                spo2 = 88;
                bp = 185;
            }

            foreach (var (channel, value, unit) in new[]
            {
                ("ECG", ecg, "bpm"),
                ("SpO2", spo2, "%"),
                ("BP", bp, "mmHg")
            })
            {
                var ts = now.AddMilliseconds(-(batchSize - i) * 10);
                readings.Add(new Reading
                {
                    SessionId = sessionId,
                    Timestamp = ts,
                    Channel = channel,
                    Value = Math.Round(value, 2),
                    Unit = unit
                });
                pushes.Add(new TelemetryPushDto(sessionId, session.DeviceId, ts, channel, Math.Round(value, 2), unit));
            }
        }

        db.Readings.AddRange(readings);
        session.Device.Status = spike ? "Alert" : "Online";
        session.Device.LastSeen = now;
        await db.SaveChangesAsync(ct);

        foreach (var push in pushes)
        {
            await hub.Clients.Group(TelemetryHub.SessionGroup(sessionId.ToString()))
                .SendAsync("TelemetryReceived", push, ct);
            await hub.Clients.Group(TelemetryHub.DeviceGroup(session.DeviceId.ToString()))
                .SendAsync("TelemetryReceived", push, ct);
        }

        if (spike || readings.Any(r => r.Channel == "SpO2" && r.Value < 90))
        {
            await CreateAlertAsync(db, session, spike ? "Critical threshold exceeded (simulated)" : "SpO2 below threshold", ct);
        }
    }

    private async Task CreateAlertAsync(AppDbContext db, Session session, string message, CancellationToken ct)
    {
        var recent = await db.Alerts.AnyAsync(a =>
            a.DeviceId == session.DeviceId &&
            !a.Acknowledged &&
            a.CreatedAt > DateTime.UtcNow.AddMinutes(-1), ct);

        if (recent) return;

        var alert = new Alert
        {
            AlertId = Guid.NewGuid(),
            DeviceId = session.DeviceId,
            Severity = "Critical",
            Message = message,
            CreatedAt = DateTime.UtcNow,
            Acknowledged = false
        };
        db.Alerts.Add(alert);
        session.Device.Status = "Alert";
        await db.SaveChangesAsync(ct);

        var dto = new AlertDto(alert.AlertId, alert.DeviceId, alert.Severity,
            alert.Message, alert.CreatedAt, alert.Acknowledged);

        await hub.Clients.Group(TelemetryHub.DeviceGroup(session.DeviceId.ToString()))
            .SendAsync("AlertRaised", dto, ct);
        await hub.Clients.Group(TelemetryHub.SessionGroup(session.SessionId.ToString()))
            .SendAsync("AlertRaised", dto, ct);
        await hub.Clients.All.SendAsync("AlertRaised", dto, ct);
    }
}
