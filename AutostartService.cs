using Microsoft.Win32;

namespace Tryvoha;

internal static class AutostartService
{
    private const string RegistryPath = @"Software\Microsoft\Windows\CurrentVersion\Run";
    private const string ValueName = "Тривога";
    private static readonly string[] LegacyValueNames = ["Tryvoha", "AlertTray", "NeptunTray"];

    public static bool IsEnabled()
    {
        using var key = Registry.CurrentUser.OpenSubKey(RegistryPath, writable: false);
        return HasValue(key, ValueName) || LegacyValueNames.Any(name => HasValue(key, name));
    }

    public static void SetEnabled(bool enabled)
    {
        using var key = Registry.CurrentUser.CreateSubKey(RegistryPath, writable: true);
        if (!enabled)
        {
            key.DeleteValue(ValueName, throwOnMissingValue: false);
            DeleteLegacyValues(key);
            return;
        }

        var executablePath = Environment.ProcessPath
            ?? throw new InvalidOperationException("Не вдалося визначити шлях до програми.");
        key.SetValue(ValueName, $"\"{executablePath}\"");
        DeleteLegacyValues(key);
    }

    public static void RefreshPathIfEnabled()
    {
        if (IsEnabled())
        {
            SetEnabled(true);
        }
    }

    private static bool HasValue(RegistryKey? key, string valueName)
    {
        return key?.GetValue(valueName) is string value && !string.IsNullOrWhiteSpace(value);
    }

    private static void DeleteLegacyValues(RegistryKey key)
    {
        foreach (var valueName in LegacyValueNames)
        {
            key.DeleteValue(valueName, throwOnMissingValue: false);
        }
    }
}
