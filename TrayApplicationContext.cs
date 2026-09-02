using System.Drawing;
using System.Drawing.Drawing2D;
using System.Runtime.InteropServices;

namespace TrayVoha;

internal sealed class TrayApplicationContext : ApplicationContext
{
    private const int PollIntervalMilliseconds = 10_000;

    private readonly NeptunAlertsClient _client = new();
    private readonly AppSettings _settings = SettingsStore.Load();
    private readonly NotifyIcon _notifyIcon;
    private readonly Icon _normalIcon;
    private readonly Icon _alertIcon;
    private readonly Icon _unknownIcon;
    private readonly System.Windows.Forms.Timer _timer;
    private readonly ToolStripMenuItem _statusItem;
    private readonly ToolStripMenuItem _selectionSummaryItem;
    private readonly ToolStripMenuItem _autostartItem;
    private readonly CancellationTokenSource _shutdown = new();

    private string? _lastFingerprint;
    private bool? _lastIsActive;
    private bool _checkRunning;
    private bool _forceCheckRequested;
    private bool _initialSetupShown;
    private int _consecutiveFailures;
    private ManualStatusForm? _manualStatusForm;
    private bool _manualStatusRequested;
    private DateTime _lastTrayLeftClickUtc = DateTime.MinValue;

    public TrayApplicationContext()
    {
        try
        {
            AutostartService.RefreshPathIfEnabled();
        }
        catch
        {
            // Автозапуск можна змінити пізніше з меню TrayVoha.
        }

        _normalIcon = CreateTrayIcon(Color.FromArgb(55, 65, 80));
        _alertIcon = CreateTrayIcon(Color.FromArgb(205, 32, 48));
        _unknownIcon = CreateTrayIcon(Color.FromArgb(217, 119, 6));

        _statusItem = new ToolStripMenuItem("Перевіряю стан…") { Enabled = false };
        _selectionSummaryItem = new ToolStripMenuItem("Території: …") { Enabled = false };
        UpdateSelectionSummary();

        var selectAreasItem = new ToolStripMenuItem("Налаштувати території…");
        selectAreasItem.Click += async (_, _) =>
        {
            if (ShowRegionSelectionDialog())
            {
                await CheckAsync(forceNotification: true);
            }
        };

        var checkNowItem = new ToolStripMenuItem("Показати стан зараз");
        checkNowItem.Click += async (_, _) => await CheckFromTrayAsync();

        _autostartItem = new ToolStripMenuItem("Запускати разом із Windows")
        {
            Checked = AutostartService.IsEnabled(),
            CheckOnClick = false,
        };
        _autostartItem.Click += (_, _) => ToggleAutostart();

        var sourceItem = new ToolStripMenuItem("Джерело: NEPTUN") { Enabled = false };

        var exitItem = new ToolStripMenuItem("Вийти");
        exitItem.Click += (_, _) => ExitThread();

        var menu = new ContextMenuStrip();
        menu.Items.AddRange(
        [
            _statusItem,
            _selectionSummaryItem,
            new ToolStripSeparator(),
            selectAreasItem,
            checkNowItem,
            _autostartItem,
            new ToolStripSeparator(),
            sourceItem,
            exitItem,
        ]);
        ApplyMenuTheme(menu);
        menu.Opening += (_, _) => ApplyMenuTheme(menu);

        _notifyIcon = new NotifyIcon
        {
            Icon = _unknownIcon,
            Text = "TrayVoha — перевіряю стан",
            ContextMenuStrip = menu,
            Visible = true,
        };
        _notifyIcon.MouseClick += async (_, eventArgs) =>
        {
            if (eventArgs.Button == MouseButtons.Left)
            {
                var now = DateTime.UtcNow;
                if ((now - _lastTrayLeftClickUtc).TotalMilliseconds < 600)
                {
                    return;
                }

                _lastTrayLeftClickUtc = now;
                await CheckFromTrayAsync();
            }
        };

        _timer = new System.Windows.Forms.Timer { Interval = 250 };
        _timer.Tick += OnTimerTick;
        _timer.Start();
    }

    private async void OnTimerTick(object? sender, EventArgs e)
    {
        _timer.Stop();
        _timer.Interval = PollIntervalMilliseconds;

        if (!_initialSetupShown && !_settings.SetupCompleted)
        {
            _initialSetupShown = true;
            ShowRegionSelectionDialog();
        }

        await CheckAsync(forceNotification: _lastFingerprint is null);
        if (!_shutdown.IsCancellationRequested)
        {
            _timer.Start();
        }
    }

    private bool ShowRegionSelectionDialog()
    {
        using var form = new RegionSelectionForm(_settings.SelectedAreaKeys);
        if (form.ShowDialog() != DialogResult.OK)
        {
            return false;
        }

        var previousSelection = _settings.SelectedAreaKeys.ToList();
        var previousSetupCompleted = _settings.SetupCompleted;

        _settings.SelectedAreaKeys = form.SelectedAreaKeys
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .OrderBy(value => value, StringComparer.OrdinalIgnoreCase)
            .ToList();
        _settings.SetupCompleted = true;

        try
        {
            SettingsStore.Save(_settings);
        }
        catch (Exception exception)
        {
            _settings.SelectedAreaKeys = previousSelection;
            _settings.SetupCompleted = previousSetupCompleted;
            _notifyIcon.ShowBalloonTip(
                5_000,
                "Не вдалося зберегти вибір",
                Truncate(exception.Message, 220),
                ToolTipIcon.Error);
            return false;
        }

        _lastFingerprint = null;
        _lastIsActive = null;
        UpdateSelectionSummary();
        return true;
    }

    private async Task CheckAsync(bool forceNotification)
    {
        if (_shutdown.IsCancellationRequested)
        {
            return;
        }

        if (_checkRunning)
        {
            _forceCheckRequested |= forceNotification;
            return;
        }

        if (_settings.SelectedAreaKeys.Count == 0)
        {
            const string noSelectionFingerprint = "selection:none";
            _statusItem.Text = "Не вибрано територій";
            _notifyIcon.Icon = _unknownIcon;
            SetTooltip("TrayVoha — не вибрано територій");

            CompleteManualStatus(
                "Території не вибрані",
                "Відкрийте меню значка та натисніть «Налаштувати території…».",
                isActive: false);

            if (forceNotification ||
                (!_settings.SetupCompleted && _lastFingerprint != noSelectionFingerprint))
            {
                _notifyIcon.ShowBalloonTip(
                    8_000,
                    "Території не вибрані",
                    "Відкрийте меню значка та натисніть «Налаштувати території…».",
                    ToolTipIcon.Info);
            }

            _lastFingerprint = noSelectionFingerprint;
            _lastIsActive = null;
            return;
        }

        _checkRunning = true;
        try
        {
            var checkedSelection = _settings.SelectedAreaKeys.ToArray();
            var state = await _client.GetStateAsync(checkedSelection, _shutdown.Token);

            if (!SameSelection(checkedSelection, _settings.SelectedAreaKeys))
            {
                _forceCheckRequested = true;
                return;
            }

            _consecutiveFailures = 0;
            UpdateStatus(state);
            CompleteManualStatus(
                state.IsActive ? "Повітряна тривога" : "Тривоги немає",
                state.IsActive ? BuildActiveAlertLines(state) : BuildSelectionLines(),
                state.IsActive);

            var changed = !string.Equals(_lastFingerprint, state.Fingerprint, StringComparison.Ordinal);
            if (forceNotification || changed)
            {
                ShowStateNotification(state, isAllClearTransition: _lastIsActive is true && !state.IsActive);
            }

            _lastFingerprint = state.Fingerprint;
            _lastIsActive = state.IsActive;
        }
        catch (OperationCanceledException) when (_shutdown.IsCancellationRequested)
        {
        }
        catch
        {
            _consecutiveFailures++;
            _statusItem.Text = "Немає зв’язку з джерелом даних";
            _notifyIcon.Icon = _unknownIcon;
            SetTooltip("TrayVoha — дані недоступні");
            CompleteManualStatus(
                "Не вдалося оновити стан",
                "Немає зв’язку з джерелом даних. Перевірка продовжиться автоматично.",
                isActive: false);

            if (_consecutiveFailures == 3)
            {
                _notifyIcon.ShowBalloonTip(
                    5_000,
                    "Дані тимчасово недоступні",
                    "Не вдалося оновити стан повітряної тривоги. Перевірка продовжиться автоматично.",
                    ToolTipIcon.Warning);
            }
        }
        finally
        {
            _checkRunning = false;
            if (_forceCheckRequested && !_shutdown.IsCancellationRequested)
            {
                _forceCheckRequested = false;
                _ = CheckAsync(forceNotification: true);
            }
        }
    }

    private void UpdateStatus(AlertState state)
    {
        _notifyIcon.Icon = state.IsActive ? _alertIcon : _normalIcon;

        if (!state.IsActive)
        {
            _statusItem.Text = "Зараз: на вибраних територіях тривоги немає";
            SetTooltip("TrayVoha — тривоги немає");
            return;
        }

        _statusItem.Text = $"Зараз: тривога — {state.ActiveAreas.Count}";
        SetTooltip($"TrayVoha — тривога: {JoinAreaNames(state.ActiveAreas)}");
    }

    private void ShowStateNotification(AlertState state, bool isAllClearTransition)
    {
        if (!state.IsActive)
        {
            _notifyIcon.ShowBalloonTip(
                6_000,
                isAllClearTransition ? "Відбій повітряної тривоги" : "Тривоги немає",
                BuildSelectionNotification(),
                ToolTipIcon.Info);
            return;
        }

        _notifyIcon.ShowBalloonTip(
            8_000,
            "Повітряна тривога",
            BuildAlertNotification(state),
            ToolTipIcon.Warning);
    }

    private static string BuildAlertNotification(AlertState state)
    {
        return BuildActiveAlertLines(state)
            + Environment.NewLine
            + Environment.NewLine
            + "Джерело: NEPTUN";
    }

    private string BuildSelectionNotification()
    {
        return BuildSelectionLines()
            + Environment.NewLine
            + Environment.NewLine
            + "Джерело: NEPTUN";
    }

    private string BuildSelectionLines()
    {
        var lines = _settings.SelectedAreaKeys.Select(DisplayNameForSelection);
        return string.Join(Environment.NewLine, lines);
    }

    private static string BuildActiveAlertLines(AlertState state)
    {
        var blocks = state.ActiveAreas.Select(area =>
            DisplayNameForSelection(area.SelectionKey)
            + Environment.NewLine
            + "Оголошено: "
            + FormatAlertStartTime(area.Since));

        return string.Join(
            Environment.NewLine + Environment.NewLine,
            blocks);
    }

    private static string FormatAlertStartTime(DateTimeOffset? since)
    {
        if (!since.HasValue)
        {
            return "немає даних";
        }

        var localSince = since.Value.ToLocalTime();
        return localSince.Date == DateTimeOffset.Now.Date
            ? localSince.ToString("HH:mm")
            : localSince.ToString("dd.MM, HH:mm");
    }

    private void UpdateSelectionSummary()
    {
        _selectionSummaryItem.Text = DescribeSelection();
    }

    private string DescribeSelection()
    {
        if (_settings.SelectedAreaKeys.Count == 0)
        {
            return "Території: нічого не вибрано";
        }

        var names = _settings.SelectedAreaKeys
            .Select(DisplayNameForSelection)
            .Where(name => !string.IsNullOrWhiteSpace(name))
            .ToList();

        return names.Count <= 2
            ? "Території: " + string.Join(", ", names)
            : $"Території: вибрано {names.Count}";
    }

    private static string DisplayNameForSelection(string selectionKey)
    {
        if (SelectionKey.IsRaion(selectionKey))
        {
            var raion = DistrictCatalog.Find(SelectionKey.Value(selectionKey));
            return raion is null
                ? selectionKey
                : $"{raion.Name} ({raion.Oblast})";
        }

        var normalizedOblast = SelectionKey.Value(selectionKey);
        return Oblasts.All.FirstOrDefault(item => SelectionKey.Normalize(item) == normalizedOblast)
            ?? selectionKey;
    }

    private static bool SameSelection(IEnumerable<string> left, IEnumerable<string> right)
    {
        return new HashSet<string>(left, StringComparer.OrdinalIgnoreCase)
            .SetEquals(right);
    }

    private static string JoinAreaNames(IEnumerable<ActiveArea> areas)
    {
        return string.Join(", ", areas
            .Select(item => item.Name)
            .Distinct(StringComparer.CurrentCultureIgnoreCase)
            .OrderBy(name => name, StringComparer.CurrentCultureIgnoreCase));
    }

    private void ToggleAutostart()
    {
        try
        {
            var enabled = !AutostartService.IsEnabled();
            AutostartService.SetEnabled(enabled);
            _autostartItem.Checked = enabled;
        }
        catch (Exception exception)
        {
            _notifyIcon.ShowBalloonTip(
                5_000,
                "Не вдалося змінити автозапуск",
                Truncate(exception.Message, 220),
                ToolTipIcon.Error);
        }
    }

    private async Task CheckFromTrayAsync()
    {
        _manualStatusRequested = true;
        GetManualStatusForm().ShowChecking();
        await CheckAsync(forceNotification: false);
    }

    private ManualStatusForm GetManualStatusForm()
    {
        return _manualStatusForm ??= new ManualStatusForm();
    }

    private void CompleteManualStatus(string title, string body, bool isActive)
    {
        if (!_manualStatusRequested)
        {
            return;
        }

        _manualStatusRequested = false;
        GetManualStatusForm().ShowResult(title, body, isActive);
    }

    private static void ApplyMenuTheme(ContextMenuStrip menu)
    {
        var palette = AppTheme.Current;
        menu.BackColor = palette.SurfaceBackground;
        menu.ForeColor = palette.PrimaryText;
        menu.Renderer = new ToolStripProfessionalRenderer(new AppColorTable(palette));

        foreach (ToolStripItem item in menu.Items)
        {
            item.BackColor = palette.SurfaceBackground;
            item.ForeColor = palette.PrimaryText;
        }
    }

    private void SetTooltip(string text)
    {
        _notifyIcon.Text = Truncate(text, 63);
    }

    private static string Truncate(string value, int maximumLength)
    {
        return value.Length <= maximumLength
            ? value
            : value[..(maximumLength - 1)] + "…";
    }

    private static Icon CreateTrayIcon(Color backgroundColor)
    {
        using var bitmap = new Bitmap(32, 32);
        using var graphics = Graphics.FromImage(bitmap);
        graphics.SmoothingMode = SmoothingMode.AntiAlias;
        graphics.Clear(Color.Transparent);

        using var background = new SolidBrush(backgroundColor);
        using var mark = new Pen(Color.White, 3.2f)
        {
            StartCap = LineCap.Round,
            EndCap = LineCap.Round,
        };
        using var dot = new SolidBrush(Color.White);

        graphics.FillEllipse(background, 1, 1, 30, 30);
        graphics.DrawLine(mark, 16, 8, 16, 19);
        graphics.FillEllipse(dot, 14.2f, 23, 3.6f, 3.6f);

        var iconHandle = bitmap.GetHicon();
        try
        {
            using var icon = Icon.FromHandle(iconHandle);
            return (Icon)icon.Clone();
        }
        finally
        {
            DestroyIcon(iconHandle);
        }
    }

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool DestroyIcon(IntPtr handle);

    protected override void ExitThreadCore()
    {
        _shutdown.Cancel();
        _timer.Stop();
        _timer.Dispose();
        _notifyIcon.Visible = false;
        _notifyIcon.Dispose();
        _normalIcon.Dispose();
        _alertIcon.Dispose();
        _unknownIcon.Dispose();
        _manualStatusForm?.Dispose();
        _client.Dispose();
        _shutdown.Dispose();
        base.ExitThreadCore();
    }
}
