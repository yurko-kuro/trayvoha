using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace TrayVoha;

internal sealed class AppSettings
{
    public int Version { get; set; }

    public bool SetupCompleted { get; set; }

    public List<string> SelectedAreaKeys { get; set; } = [];

    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? SelectedOblast { get; set; }
}

internal static class SelectionKey
{
    private const string OblastPrefix = "oblast:";
    private const string RaionPrefix = "raion:";

    public static string ForOblast(string oblast) => OblastPrefix + Normalize(oblast);

    public static string ForRaion(string raionKey) => RaionPrefix + Normalize(raionKey);

    public static bool IsOblast(string key) => key.StartsWith(OblastPrefix, StringComparison.Ordinal);

    public static bool IsRaion(string key) => key.StartsWith(RaionPrefix, StringComparison.Ordinal);

    public static string Value(string key)
    {
        var separator = key.IndexOf(':');
        return separator >= 0 ? key[(separator + 1)..] : string.Empty;
    }

    public static string Normalize(string value)
    {
        return value
            .Normalize(NormalizationForm.FormC)
            .Trim()
            .ToLowerInvariant();
    }
}

internal static class SettingsStore
{
    private const int CurrentVersion = 2;

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true,
    };

    private static string SettingsDirectory => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
        "TrayVoha");

    private static string SettingsPath => Path.Combine(SettingsDirectory, "settings.json");

    public static AppSettings Load()
    {
        try
        {
            if (!File.Exists(SettingsPath))
            {
                return CreateDefault();
            }

            var settings = JsonSerializer.Deserialize<AppSettings>(File.ReadAllText(SettingsPath))
                ?? CreateDefault();

            if (settings.Version < CurrentVersion)
            {
                settings.SelectedAreaKeys = [];
                settings.SetupCompleted = false;
                settings.Version = CurrentVersion;
                settings.SelectedOblast = null;
            }

            settings.SelectedAreaKeys = Sanitize(settings.SelectedAreaKeys);
            return settings;
        }
        catch
        {
            return CreateDefault();
        }
    }

    public static void Save(AppSettings settings)
    {
        settings.Version = CurrentVersion;
        settings.SelectedOblast = null;
        settings.SelectedAreaKeys = Sanitize(settings.SelectedAreaKeys);

        Directory.CreateDirectory(SettingsDirectory);
        var temporaryPath = SettingsPath + ".tmp";
        File.WriteAllText(temporaryPath, JsonSerializer.Serialize(settings, JsonOptions));
        File.Move(temporaryPath, SettingsPath, overwrite: true);
    }

    private static AppSettings CreateDefault()
    {
        return new AppSettings
        {
            Version = CurrentVersion,
            SetupCompleted = false,
            SelectedAreaKeys = [],
        };
    }

    private static List<string> Sanitize(IEnumerable<string>? keys)
    {
        var validKeys = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        validKeys.UnionWith(Oblasts.All.Select(SelectionKey.ForOblast));
        validKeys.UnionWith(DistrictCatalog.All.Select(item => SelectionKey.ForRaion(item.Key)));

        return (keys ?? Enumerable.Empty<string>())
            .Where(validKeys.Contains)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .OrderBy(key => key, StringComparer.OrdinalIgnoreCase)
            .ToList();
    }
}

internal static class Oblasts
{
    public static readonly string[] All =
    [
        "Автономна Республіка Крим",
        "Вінницька область",
        "Волинська область",
        "Дніпропетровська область",
        "Донецька область",
        "Житомирська область",
        "Закарпатська область",
        "Запорізька область",
        "Івано-Франківська область",
        "Київська область",
        "Кіровоградська область",
        "Луганська область",
        "Львівська область",
        "Миколаївська область",
        "Одеська область",
        "Полтавська область",
        "Рівненська область",
        "Сумська область",
        "Тернопільська область",
        "Харківська область",
        "Херсонська область",
        "Хмельницька область",
        "Черкаська область",
        "Чернівецька область",
        "Чернігівська область",
        "м. Київ",
        "Севастополь",
    ];
}
