namespace ClinicalDevice.Api.Services;

public class SimulationState
{
    private readonly HashSet<Guid> _activeSessions = new();
    private readonly Queue<Guid> _spikeRequests = new();
    private readonly object _lock = new();

    public void Start(Guid sessionId)
    {
        lock (_lock) _activeSessions.Add(sessionId);
    }

    public void Stop(Guid sessionId)
    {
        lock (_lock) _activeSessions.Remove(sessionId);
    }

    public bool IsActive(Guid sessionId)
    {
        lock (_lock) return _activeSessions.Contains(sessionId);
    }

    public IReadOnlyCollection<Guid> GetActiveSessions()
    {
        lock (_lock) return _activeSessions.ToList();
    }

    public void RequestSpike(Guid sessionId)
    {
        lock (_lock) _spikeRequests.Enqueue(sessionId);
    }

    public bool TryConsumeSpike(Guid sessionId)
    {
        lock (_lock)
        {
            if (_spikeRequests.Count == 0) return false;
            var pending = _spikeRequests.ToList();
            if (!pending.Contains(sessionId)) return false;
            _spikeRequests.Clear();
            foreach (var id in pending.Where(x => x != sessionId))
                _spikeRequests.Enqueue(id);
            return true;
        }
    }
}
