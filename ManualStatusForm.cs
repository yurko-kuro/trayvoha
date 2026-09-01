using System.Diagnostics;
using System.Drawing;

namespace NeptunTray;

internal sealed class ManualStatusForm : Form
{
    private const string SourceUrl = "https://neptun.in.ua/";

    private readonly Label _titleLabel;
    private readonly TextBox _bodyBox;
    private readonly System.Windows.Forms.Timer _closeTimer;
    private readonly AppPalette _palette;

    public ManualStatusForm()
    {
        _palette = AppTheme.Current;

        FormBorderStyle = FormBorderStyle.None;
        ShowInTaskbar = false;
        TopMost = true;
        StartPosition = FormStartPosition.Manual;
        BackColor = _palette.WindowBackground;
        ForeColor = _palette.PrimaryText;
        ClientSize = new Size(420, 154);
        Padding = new Padding(15);

        var layout = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            BackColor = _palette.WindowBackground,
            ColumnCount = 2,
            RowCount = 3,
            Margin = new Padding(0),
            Padding = new Padding(0),
        };
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100F));
        layout.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 34F));
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 42F));
        layout.RowStyles.Add(new RowStyle(SizeType.Percent, 100F));
        layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 28F));

        _titleLabel = new Label
        {
            Dock = DockStyle.Fill,
            AutoEllipsis = true,
            Font = new Font("Segoe UI Semibold", 12F, FontStyle.Bold),
            ForeColor = _palette.PrimaryText,
            TextAlign = ContentAlignment.MiddleLeft,
        };

        var closeButton = new Button
        {
            Dock = DockStyle.Fill,
            Text = "×",
            Font = new Font("Segoe UI", 14F),
            FlatStyle = FlatStyle.Flat,
            BackColor = _palette.WindowBackground,
            ForeColor = _palette.SecondaryText,
            Cursor = Cursors.Hand,
            Margin = new Padding(0),
            TabStop = false,
        };
        closeButton.FlatAppearance.BorderSize = 0;
        closeButton.Click += (_, _) => Hide();

        _bodyBox = new TextBox
        {
            Dock = DockStyle.Fill,
            Multiline = true,
            ReadOnly = true,
            BorderStyle = BorderStyle.None,
            ScrollBars = ScrollBars.None,
            BackColor = _palette.WindowBackground,
            ForeColor = _palette.PrimaryText,
            Font = new Font("Segoe UI", 10.5F),
            TabStop = false,
        };

        var sourceLink = new LinkLabel
        {
            Dock = DockStyle.Fill,
            Text = "Neptune",
            Font = new Font("Segoe UI", 8.5F),
            LinkColor = _palette.SecondaryText,
            ActiveLinkColor = _palette.Accent,
            VisitedLinkColor = _palette.SecondaryText,
            TextAlign = ContentAlignment.BottomLeft,
            TabStop = false,
        };
        sourceLink.LinkClicked += (_, _) =>
            Process.Start(new ProcessStartInfo(SourceUrl) { UseShellExecute = true });

        layout.Controls.Add(_titleLabel, 0, 0);
        layout.Controls.Add(closeButton, 1, 0);
        layout.Controls.Add(_bodyBox, 0, 1);
        layout.SetColumnSpan(_bodyBox, 2);
        layout.Controls.Add(sourceLink, 0, 2);
        layout.SetColumnSpan(sourceLink, 2);

        Controls.Add(layout);

        _closeTimer = new System.Windows.Forms.Timer { Interval = 10_000 };
        _closeTimer.Tick += (_, _) =>
        {
            _closeTimer.Stop();
            Hide();
        };

        Paint += (_, eventArgs) =>
        {
            using var border = new Pen(_palette.Border);
            eventArgs.Graphics.DrawRectangle(
                border,
                0,
                0,
                ClientSize.Width - 1,
                ClientSize.Height - 1);
        };
    }

    public void ShowChecking()
    {
        ShowContent(
            "Перевіряю стан…",
            "Оновлюю дані для вибраних територій.",
            isActive: false,
            autoClose: false);
    }

    public void ShowResult(string title, string body, bool isActive)
    {
        ShowContent(title, body, isActive, autoClose: true);
    }

    private void ShowContent(string title, string body, bool isActive, bool autoClose)
    {
        _closeTimer.Stop();
        _titleLabel.Text = title;
        _titleLabel.ForeColor = isActive ? _palette.Accent : _palette.PrimaryText;
        _bodyBox.Text = body;
        _bodyBox.SelectionStart = 0;
        _bodyBox.SelectionLength = 0;

        var lineCount = Math.Max(1, body.Split('\n').Length);
        _bodyBox.ScrollBars = lineCount > 14
            ? ScrollBars.Vertical
            : ScrollBars.None;
        ClientSize = new Size(420, Math.Clamp(116 + lineCount * 24, 154, 500));

        var workingArea = Screen.FromPoint(Cursor.Position).WorkingArea;
        Location = new Point(
            workingArea.Right - Width - 16,
            workingArea.Bottom - Height - 16);

        if (!Visible)
        {
            Show();
        }

        BringToFront();
        Activate();

        if (autoClose)
        {
            _closeTimer.Start();
        }
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            _closeTimer.Dispose();
        }

        base.Dispose(disposing);
    }
}
