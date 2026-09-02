using System.Drawing;
using System.Runtime.InteropServices;

namespace NeptunTray;

internal sealed class RegionSelectionForm : Form
{
    private const int DwmwaUseImmersiveDarkModeBefore20H1 = 19;
    private const int DwmwaUseImmersiveDarkMode = 20;

    private readonly TreeView _tree;
    private readonly Font _oblastFont;
    private readonly AppPalette _palette;
    private bool _updatingChecks;

    public IReadOnlyList<string> SelectedAreaKeys { get; private set; } = [];

    public RegionSelectionForm(IEnumerable<string> selectedAreaKeys)
    {
        _palette = AppTheme.Current;
        Text = "Вибір територій";
        StartPosition = FormStartPosition.CenterScreen;
        ClientSize = new Size(560, 680);
        MinimumSize = new Size(460, 500);
        Font = new Font("Segoe UI", 10F);
        _oblastFont = new Font(Font, FontStyle.Bold);
        BackColor = _palette.WindowBackground;
        ForeColor = _palette.PrimaryText;
        MaximizeBox = false;
        MinimizeBox = false;
        ShowIcon = false;

        var instruction = new Label
        {
            Dock = DockStyle.Top,
            Height = 62,
            Padding = new Padding(12, 10, 12, 6),
            BackColor = _palette.WindowBackground,
            ForeColor = _palette.SecondaryText,
            Text = "Розгорніть потрібну область і позначте території. " +
                   "Галочка на самій області означає весь регіон.",
        };

        _tree = new TreeView
        {
            Dock = DockStyle.Fill,
            CheckBoxes = true,
            HideSelection = false,
            FullRowSelect = true,
            BorderStyle = BorderStyle.FixedSingle,
            BackColor = _palette.SurfaceBackground,
            ForeColor = _palette.PrimaryText,
            LineColor = _palette.Border,
            DrawMode = TreeViewDrawMode.OwnerDrawText,
        };
        _tree.AfterCheck += OnAfterCheck;
        _tree.DrawNode += OnDrawNode;

        var saveButton = new Button
        {
            Text = "Зберегти",
            AutoSize = true,
            Padding = new Padding(10, 2, 10, 2),
        };
        StyleButton(saveButton, _palette.Accent, Color.White);
        saveButton.Click += (_, _) => SaveSelection();

        var cancelButton = new Button
        {
            Text = "Скасувати",
            AutoSize = true,
            Padding = new Padding(10, 2, 10, 2),
            DialogResult = DialogResult.Cancel,
        };
        StyleButton(cancelButton, _palette.SecondaryBackground, _palette.PrimaryText);

        var clearButton = new Button
        {
            Text = "Зняти всі",
            AutoSize = true,
            Padding = new Padding(10, 2, 10, 2),
        };
        StyleButton(clearButton, _palette.SecondaryBackground, _palette.PrimaryText);
        clearButton.Click += (_, _) => ClearAll();

        var buttons = new FlowLayoutPanel
        {
            Dock = DockStyle.Bottom,
            Height = 58,
            FlowDirection = FlowDirection.RightToLeft,
            Padding = new Padding(10),
            WrapContents = false,
            BackColor = _palette.WindowBackground,
        };
        buttons.Controls.Add(saveButton);
        buttons.Controls.Add(cancelButton);
        buttons.Controls.Add(clearButton);

        Controls.Add(_tree);
        Controls.Add(buttons);
        Controls.Add(instruction);

        AcceptButton = saveButton;
        CancelButton = cancelButton;

        BuildTree(selectedAreaKeys);
    }

    private void BuildTree(IEnumerable<string> selectedAreaKeys)
    {
        var selected = new HashSet<string>(selectedAreaKeys, StringComparer.OrdinalIgnoreCase);

        _updatingChecks = true;
        try
        {
            foreach (var oblast in Oblasts.All)
            {
                var oblastKey = SelectionKey.ForOblast(oblast);
                var oblastNode = new TreeNode(oblast)
                {
                    Tag = oblastKey,
                    Checked = selected.Contains(oblastKey),
                    NodeFont = _oblastFont,
                    ForeColor = _palette.PrimaryText,
                };

                foreach (var raion in DistrictCatalog.ForOblast(oblast))
                {
                    var raionKey = SelectionKey.ForRaion(raion.Key);
                    oblastNode.Nodes.Add(new TreeNode(raion.Name)
                    {
                        Tag = raionKey,
                        Checked = !oblastNode.Checked && selected.Contains(raionKey),
                        ForeColor = _palette.PrimaryText,
                    });
                }

                if (oblastNode.Checked || oblastNode.Nodes.Cast<TreeNode>().Any(node => node.Checked))
                {
                    oblastNode.Expand();
                }

                _tree.Nodes.Add(oblastNode);
            }
        }
        finally
        {
            _updatingChecks = false;
        }
    }

    private void OnAfterCheck(object? sender, TreeViewEventArgs e)
    {
        if (_updatingChecks || e.Action == TreeViewAction.Unknown || e.Node is null)
        {
            return;
        }

        var node = e.Node;
        _updatingChecks = true;
        try
        {
            var parent = node.Parent;
            if (parent is null)
            {
                if (node.Checked)
                {
                    foreach (TreeNode child in node.Nodes)
                    {
                        child.Checked = false;
                    }
                }
            }
            else if (node.Checked)
            {
                parent.Checked = false;
            }
        }
        finally
        {
            _updatingChecks = false;
        }
    }

    private void OnDrawNode(object? sender, DrawTreeNodeEventArgs e)
    {
        if (e.Node is null)
        {
            return;
        }

        var font = e.Node.NodeFont ?? _tree.Font;
        var flags = TextFormatFlags.Left
            | TextFormatFlags.VerticalCenter
            | TextFormatFlags.SingleLine
            | TextFormatFlags.NoPrefix
            | TextFormatFlags.NoPadding;
        var measured = TextRenderer.MeasureText(
            e.Graphics,
            e.Node.Text,
            font,
            new Size(int.MaxValue, e.Bounds.Height),
            flags);
        var availableWidth = Math.Max(0, _tree.ClientSize.Width - e.Bounds.X);
        var textBounds = new Rectangle(
            e.Bounds.X,
            e.Bounds.Y,
            Math.Min(availableWidth, measured.Width + 8),
            e.Bounds.Height);
        var selected = (e.State & TreeNodeStates.Selected) != 0;
        var background = selected ? _palette.Selection : _palette.SurfaceBackground;

        using (var brush = new SolidBrush(background))
        {
            e.Graphics.FillRectangle(brush, textBounds);
        }

        TextRenderer.DrawText(
            e.Graphics,
            e.Node.Text,
            font,
            textBounds,
            _palette.PrimaryText,
            background,
            flags);

        if ((e.State & TreeNodeStates.Focused) != 0)
        {
            ControlPaint.DrawFocusRectangle(
                e.Graphics,
                textBounds,
                _palette.PrimaryText,
                background);
        }
    }

    private void ClearAll()
    {
        _updatingChecks = true;
        try
        {
            foreach (TreeNode oblastNode in _tree.Nodes)
            {
                oblastNode.Checked = false;
                foreach (TreeNode raionNode in oblastNode.Nodes)
                {
                    raionNode.Checked = false;
                }
            }
        }
        finally
        {
            _updatingChecks = false;
        }
    }

    private void SaveSelection()
    {
        var selected = new List<string>();
        foreach (TreeNode oblastNode in _tree.Nodes)
        {
            if (oblastNode.Checked && oblastNode.Tag is string oblastKey)
            {
                selected.Add(oblastKey);
                continue;
            }

            foreach (TreeNode raionNode in oblastNode.Nodes)
            {
                if (raionNode.Checked && raionNode.Tag is string raionKey)
                {
                    selected.Add(raionKey);
                }
            }
        }

        SelectedAreaKeys = selected;
        DialogResult = DialogResult.OK;
        Close();
    }

    private static void StyleButton(Button button, Color background, Color foreground)
    {
        button.FlatStyle = FlatStyle.Flat;
        button.FlatAppearance.BorderSize = 0;
        button.BackColor = background;
        button.ForeColor = foreground;
        button.Cursor = Cursors.Hand;
    }

    protected override void OnShown(EventArgs e)
    {
        base.OnShown(e);

        BeginInvoke(new Action(() =>
        {
            _tree.SelectedNode = null;
            ActiveControl = null;
        }));
    }

    protected override void OnHandleCreated(EventArgs e)
    {
        base.OnHandleCreated(e);

        var enabled = AppTheme.IsDark ? 1 : 0;
        if (DwmSetWindowAttribute(
                Handle,
                DwmwaUseImmersiveDarkMode,
                ref enabled,
                sizeof(int)) != 0)
        {
            DwmSetWindowAttribute(
                Handle,
                DwmwaUseImmersiveDarkModeBefore20H1,
                ref enabled,
                sizeof(int));
        }
    }

    [DllImport("dwmapi.dll")]
    private static extern int DwmSetWindowAttribute(
        IntPtr window,
        int attribute,
        ref int value,
        int valueSize);

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            _oblastFont.Dispose();
        }
        base.Dispose(disposing);
    }
}
