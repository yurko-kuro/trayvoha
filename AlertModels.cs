using System.Text.Json.Serialization;

namespace NeptunTray;

internal sealed class AlertsResponse
{
    [JsonPropertyName("version")]
    public long Version { get; init; }

    [JsonPropertyName("updatedAt")]
    public DateTimeOffset? UpdatedAt { get; init; }

    [JsonPropertyName("raions")]
    public List<AlertEntry> Raions { get; init; } = [];

    [JsonPropertyName("oblasts")]
    public List<AlertEntry> Oblasts { get; init; } = [];
}

internal sealed class AlertEntry
{
    [JsonPropertyName("key")]
    public string Key { get; init; } = string.Empty;

    [JsonPropertyName("name")]
    public string Name { get; init; } = string.Empty;

    [JsonPropertyName("oblast")]
    public string Oblast { get; init; } = string.Empty;

    [JsonPropertyName("since")]
    public DateTimeOffset? Since { get; init; }
}

internal sealed record ActiveArea(
    string SelectionKey,
    string Name,
    DateTimeOffset? Since);

internal sealed record AlertState(
    string Fingerprint,
    IReadOnlyList<ActiveArea> ActiveAreas)
{
    public bool IsActive => ActiveAreas.Count > 0;
}
