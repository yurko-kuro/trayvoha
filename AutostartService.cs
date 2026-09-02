using Microsoft.Win32;

namespace NeptunTray;

internal static class AutostartService
{
    private const string RegistryPath = @"Software\Microsoft\Windows\CurrentVersion\Run";
    private const string ValueName = "TrayVoha";
    private const string LegacyAlertTrayValueName = "AlertTray";
    private const string LegacyNeptunTrayValueName = "NeptunTray";

    public static bool IsEnabled()
    {
        using var key = Registry.CurrentUser.OpenSubKey(RegistryPath, writable: false);
        return HasValue(key, ValueName)
            || HasValue(key, LegacyAlertTrayValueName)
            || HasValue(key, LegacyNeptunTrayValueName);
    }

    public static void SetEnabled(bool enabled)
    {
        using var key = Registry.CurrentUser.CreateSubKey(RegistryPath, writable: true);
        if (!enabled)
        {
            key.DeleteValue(ValueName, throwOnMissingValue: false);
            key.DeleteValue(LegacyAlertTrayValueName, throwOnMissingValue: false);
            key.DeleteValue(LegacyNeptunTrayValueName, throwOnMissingValue: false);
            return;
        }

        var executablePath = Environment.ProcessPath
            ?? throw new InvalidOperationException("Не вдалося визначити шлях до програми.");
        key.SetValue(ValueName, $"\"{executablePath}\"");
        key.DeleteValue(LegacyAlertTrayValueName, throwOnMissingValue: false);
        key.DeleteValue(LegacyNeptunTrayValueName, throwOnMissingValue: false);
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
}
