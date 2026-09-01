using Microsoft.Win32;
using System.Drawing;

namespace Tryvoha;

internal sealed record AppPalette(
    Color WindowBackground,
    Color SurfaceBackground,
    Color SecondaryBackground,
    Color PrimaryText,
    Color SecondaryText,
    Color Border,
    Color Selection,
    Color Accent);

internal static class AppTheme
{
    public static bool IsDark => IsDarkMode();

    public static AppPalette Current => IsDark
        ? new AppPalette(
            Color.FromArgb(24, 24, 27),
            Color.FromArgb(36, 36, 40),
            Color.FromArgb(51, 51, 56),
            Color.FromArgb(242, 242, 244),
            Color.FromArgb(177, 177, 184),
            Color.FromArgb(90, 90, 98),
            Color.FromArgb(91, 27, 36),
            Color.FromArgb(205, 32, 48))
        : new AppPalette(
            Color.FromArgb(248, 248, 250),
            Color.White,
            Color.FromArgb(232, 232, 236),
            Color.FromArgb(28, 28, 32),
            Color.FromArgb(86, 86, 94),
            Color.FromArgb(196, 196, 204),
            Color.FromArgb(255, 226, 230),
            Color.FromArgb(205, 32, 48));

    private static bool IsDarkMode()
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(
                @"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize");
            return Convert.ToInt32(key?.GetValue("AppsUseLightTheme", 1)) == 0;
        }
        catch
        {
            return false;
        }
    }
}

internal sealed class AppColorTable(AppPalette palette) : ProfessionalColorTable
{
    public override Color ToolStripDropDownBackground => palette.SurfaceBackground;
    public override Color MenuBorder => palette.Border;
    public override Color MenuItemBorder => palette.Border;
    public override Color MenuItemSelected => palette.Selection;
    public override Color MenuItemSelectedGradientBegin => palette.Selection;
    public override Color MenuItemSelectedGradientEnd => palette.Selection;
    public override Color MenuItemPressedGradientBegin => palette.Selection;
    public override Color MenuItemPressedGradientMiddle => palette.Selection;
    public override Color MenuItemPressedGradientEnd => palette.Selection;
    public override Color ImageMarginGradientBegin => palette.SurfaceBackground;
    public override Color ImageMarginGradientMiddle => palette.SurfaceBackground;
    public override Color ImageMarginGradientEnd => palette.SurfaceBackground;
    public override Color SeparatorDark => palette.Border;
    public override Color SeparatorLight => palette.SurfaceBackground;
}
