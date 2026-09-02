using System.Net.Http.Json;

namespace TrayVoha;

internal sealed class NeptunAlertsClient : IDisposable
{
    private const string Endpoint = "https://neptun.in.ua/api/v1/alerts";
    private readonly HttpClient _httpClient;

    public NeptunAlertsClient()
    {
        _httpClient = new HttpClient
        {
            Timeout = TimeSpan.FromSeconds(8),
        };
        _httpClient.DefaultRequestHeaders.UserAgent.ParseAdd("TrayVoha/1.3.8");
    }

    public async Task<AlertState> GetStateAsync(
        IReadOnlyCollection<string> selectedAreaKeys,
        CancellationToken cancellationToken)
    {
        var response = await _httpClient.GetFromJsonAsync<AlertsResponse>(Endpoint, cancellationToken)
            ?? throw new InvalidOperationException("Джерело даних повернуло порожню відповідь.");

        var activeAreas = new List<ActiveArea>();
        var fingerprintParts = new List<string>();

        foreach (var selectionKey in selectedAreaKeys.OrderBy(value => value, StringComparer.Ordinal))
        {
            if (SelectionKey.IsOblast(selectionKey))
            {
                AddOblastState(selectionKey, response, activeAreas, fingerprintParts);
            }
            else if (SelectionKey.IsRaion(selectionKey))
            {
                AddRaionState(selectionKey, response, activeAreas, fingerprintParts);
            }
        }

        var fingerprint = string.Join(
            ";",
            fingerprintParts.OrderBy(value => value, StringComparer.Ordinal));

        return new AlertState(fingerprint, activeAreas);
    }

    private static void AddOblastState(
        string selectionKey,
        AlertsResponse response,
        ICollection<ActiveArea> activeAreas,
        ICollection<string> fingerprintParts)
    {
        var normalizedOblast = SelectionKey.Value(selectionKey);
        var oblast = Oblasts.All.FirstOrDefault(item =>
            SelectionKey.Normalize(item) == normalizedOblast);
        if (oblast is null)
        {
            return;
        }

        var wholeAlerts = response.Oblasts
            .Where(item => BelongsToOblast(item, oblast))
            .ToList();
        var raionAlerts = response.Raions
            .Where(item => BelongsToOblast(item, oblast))
            .OrderBy(item => item.Name, StringComparer.CurrentCultureIgnoreCase)
            .ToList();

        foreach (var alert in wholeAlerts)
        {
            fingerprintParts.Add(Fingerprint(selectionKey, "oblast", alert));
        }

        foreach (var alert in raionAlerts)
        {
            fingerprintParts.Add(Fingerprint(selectionKey, "raion", alert));
        }

        if (wholeAlerts.Count > 0)
        {
            activeAreas.Add(new ActiveArea(
                selectionKey,
                oblast,
                EarliestSince(wholeAlerts.Concat(raionAlerts))));
            return;
        }

        foreach (var alert in raionAlerts)
        {
            activeAreas.Add(new ActiveArea(
                SelectionKey.ForRaion(alert.Key),
                alert.Name,
                alert.Since));
        }
    }

    private static void AddRaionState(
        string selectionKey,
        AlertsResponse response,
        ICollection<ActiveArea> activeAreas,
        ICollection<string> fingerprintParts)
    {
        var raion = DistrictCatalog.Find(SelectionKey.Value(selectionKey));
        if (raion is null)
        {
            return;
        }

        var raionAlerts = response.Raions
            .Where(item => string.Equals(item.Key, raion.Key, StringComparison.OrdinalIgnoreCase))
            .ToList();
        var wholeAlerts = response.Oblasts
            .Where(item => BelongsToOblast(item, raion.Oblast))
            .ToList();

        foreach (var alert in wholeAlerts)
        {
            fingerprintParts.Add(Fingerprint(selectionKey, "oblast", alert));
        }

        foreach (var alert in raionAlerts)
        {
            fingerprintParts.Add(Fingerprint(selectionKey, "raion", alert));
        }

        var matchedAlerts = wholeAlerts.Concat(raionAlerts).ToList();
        if (matchedAlerts.Count > 0)
        {
            activeAreas.Add(new ActiveArea(
                selectionKey,
                raion.Name,
                EarliestSince(matchedAlerts)));
        }
    }

    private static bool BelongsToOblast(AlertEntry item, string oblast)
    {
        return SelectionKey.Normalize(item.Oblast) == SelectionKey.Normalize(oblast)
            || SelectionKey.Normalize(item.Name) == SelectionKey.Normalize(oblast);
    }

    private static DateTimeOffset? EarliestSince(IEnumerable<AlertEntry> alerts)
    {
        return alerts
            .Where(item => item.Since.HasValue)
            .Select(item => item.Since)
            .Min();
    }

    private static string Fingerprint(string selectionKey, string sourceType, AlertEntry alert)
    {
        return $"{selectionKey}|{sourceType}|{SelectionKey.Normalize(alert.Key)}|{alert.Since:O}";
    }

    public void Dispose() => _httpClient.Dispose();
}
