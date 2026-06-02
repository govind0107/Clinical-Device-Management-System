using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;

namespace ClinicalDevice.Api.Hubs;

[Authorize]
public class TelemetryHub : Hub
{
    public async Task SubscribeDevice(string deviceId)
    {
        await Groups.AddToGroupAsync(Context.ConnectionId, DeviceGroup(deviceId));
    }

    public async Task UnsubscribeDevice(string deviceId)
    {
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, DeviceGroup(deviceId));
    }

    public async Task SubscribeSession(string sessionId)
    {
        await Groups.AddToGroupAsync(Context.ConnectionId, SessionGroup(sessionId));
    }

    public async Task UnsubscribeSession(string sessionId)
    {
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, SessionGroup(sessionId));
    }

    public static string DeviceGroup(string deviceId) => $"device:{deviceId}";
    public static string SessionGroup(string sessionId) => $"session:{sessionId}";
}
