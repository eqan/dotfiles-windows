#r "C:\Program Files\workspacer\workspacer.Shared.dll"
#r "C:\Program Files\workspacer\plugins\workspacer.Bar\workspacer.Bar.dll"
#r "C:\Program Files\workspacer\plugins\workspacer.ActionMenu\workspacer.ActionMenu.dll"
#r "C:\Program Files\workspacer\plugins\workspacer.FocusIndicator\workspacer.FocusIndicator.dll"
#r "C:\Program Files\workspacer\System.Diagnostics.PerformanceCounter.dll"
#r "C:\Program Files\workspacer\Microsoft.VisualBasic.Core.dll"
#r "C:\Program Files\workspacer\Microsoft.VisualBasic.dll"
#r "C:\Program Files\workspacer\Microsoft.VisualBasic.Forms.dll"
#r "C:\Program Files\workspacer\plugins\workspacer.Gap\workspacer.Gap.dll"

using System;
using workspacer;
using workspacer.Bar;
using workspacer.ActionMenu;
using workspacer.FocusIndicator;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using static workspacer.ILayoutEngine;
using workspacer.Bar.Widgets;
using System.Diagnostics;
using System.Timers;
using System.Windows.Forms;
using System.Threading;
using Microsoft.VisualBasic.Devices;
using workspacer.Gap;


// Fibbonaci Spiral Layout "[dwindle]"
public static class Orientation
{
    public const bool Horizontal = true;
    public const bool Vertical   = false;
}

public class DwindleLayoutEngine : ILayoutEngine
{
    private readonly int _numInPrimary;
    private readonly double _primaryPercent;
    private readonly double _primaryPercentIncrement;

    private int _numInPrimaryOffset = 0;
    private double _primaryPercentOffset = 0;

    public DwindleLayoutEngine() : this(1, 0.5, 0.03) { }

    public DwindleLayoutEngine(int numInPrimary, double primaryPercent, double primaryPercentIncrement)
    {
        _numInPrimary = numInPrimary;
        _primaryPercent = primaryPercent;
        _primaryPercentIncrement = primaryPercentIncrement;
    }

    public string Name => "dwindle";


    public IEnumerable<IWindowLocation> CalcLayout(IEnumerable<IWindow> windows, int spaceWidth, int spaceHeight)
    {
        var list = new List<IWindowLocation>();
        var numWindows = windows.Count();

        if (numWindows == 0)
            return list;

        int numInPrimary = Math.Min(GetNumInPrimary(), numWindows);

        int primaryWidth = (int)(spaceWidth * (_primaryPercent + _primaryPercentOffset));
        int primaryHeight = spaceHeight / numInPrimary;
        int height = spaceHeight / Math.Max(numWindows - numInPrimary, 1);

        // if there are more "primary" windows than actual windows,
        // then we want the pane to actually spread the entire width
        // of the working area
        if (numInPrimary >= numWindows)
        {
            primaryWidth = spaceWidth;
        }

        int secondaryWidth = spaceWidth - primaryWidth;

        // Recurse in a 'dwindle fibonacci' pattern
        bool curOrientation = Orientation.Vertical;
        int curWidth = secondaryWidth;
        int curTop = 0;
        int curLeft = primaryWidth;
        int curHeight = numWindows > 2 ? spaceHeight / 2 : spaceHeight;
        for (var i = 0; i < numWindows; i++)
        {
            if (i < numInPrimary)
            {
                list.Add(new WindowLocation(0, i * primaryHeight, primaryWidth, primaryHeight, WindowState.Normal));
            }
            else
            {
                list.Add(new WindowLocation(curLeft, curTop, curWidth, curHeight, WindowState.Normal));
                if(curOrientation == Orientation.Vertical) {
                    curTop += curHeight;
                    if(i<numWindows-2) {
                        curWidth /= 2;
                    }
                    curOrientation = Orientation.Horizontal;
                }
                else {
                    curLeft += curWidth;
                    if(i<numWindows-2) {
                        curHeight /= 2;
                    }
                    curOrientation = Orientation.Vertical;
                }
            }
        }        return list;    }    public void ShrinkPrimaryArea()    {        _primaryPercentOffset -= _primaryPercentIncrement;    }    public void ExpandPrimaryArea()    {        _primaryPercentOffset += _primaryPercentIncrement;    }

    public void ResetPrimaryArea()
    {
        _primaryPercentOffset = 0;
    }

    public void IncrementNumInPrimary()
    {
        _numInPrimaryOffset++;
    }

    public void DecrementNumInPrimary()
    {
        if (GetNumInPrimary() > 1)
        {
            _numInPrimaryOffset--;
        }
    }

    private int GetNumInPrimary()
    {
        return _numInPrimary + _numInPrimaryOffset;
    }
}


// A Tiling Layout for vertical monitors
public class VerticalTiledEngine : ILayoutEngine
{
    private readonly int _numInPrimary;
    private readonly double _primaryPercent;
    private readonly double _primaryPercentIncrement;
    private readonly int _maxRows;

    private int _numInPrimaryOffset;
    private double _primaryPercentOffset;

    public string Name => "vertical";

    public VerticalTiledEngine(int numInPrimary, double primaryPercent, double primaryPercentIncrement, int maxRows)
    {
        _numInPrimary = numInPrimary;
        _primaryPercent = primaryPercent;
        _primaryPercentIncrement = primaryPercentIncrement;
        _maxRows = maxRows;
    }

    public VerticalTiledEngine() : this(1, 0.5, 0.03, 3) { }

    public IEnumerable<IWindowLocation> CalcLayout(IEnumerable<IWindow> windows, int spaceWidth, int spaceHeight)
    {
        var locationList = new List<IWindowLocation>();
        var windowList = windows.ToList();
        var numWindows = windowList.Count;

        if (numWindows == 0)
        {
            return locationList;
        }

        var numInPrimary = Math.Min(GetNumInPrimary(), numWindows);
        var numInSecondary = numWindows - numInPrimary;
        var primaryWidth = spaceWidth;

        int CalcHeight(int mon, int n) =>
            (int) (mon * (_maxRows == n + 1 ? 1 : _primaryPercent + _primaryPercentOffset));

        WindowLocation MinimizeWindow(int w, int h) => new WindowLocation(0, 0, w, h, WindowState.Minimized);

        var primaryHeight = 0;
        var remainingHeight = spaceHeight;
        var primaryHeightOffset = 0;
        var rowsAvailable = _maxRows;
        for (var i = 0; i < numInPrimary; ++i)
        {
            if (rowsAvailable < 1)
            {
                locationList.Add(MinimizeWindow(primaryWidth, primaryHeight));
                continue;
            }

            primaryHeight = numWindows == 1 ? spaceHeight : CalcHeight(remainingHeight, i);
            remainingHeight -= primaryHeight;
            locationList.Add(new WindowLocation(0, primaryHeightOffset, primaryWidth, primaryHeight, WindowState.Normal));
            primaryHeightOffset += primaryHeight;
            --rowsAvailable;
        }

        if (rowsAvailable < 1)
        {
            for (var i = 0; i < numInSecondary; ++i)
            {
                locationList.Add(MinimizeWindow(primaryWidth, primaryHeight));
            }
            return locationList;
        }

        var columnsUsed = 0;
        var secondaryIndex = new List<LayoutLocation>();

        for (var i = 0; i < numInSecondary; ++i)
        {
            var horizontalIndex = columnsUsed;
            var verticalIndex = i % rowsAvailable;
            var widthDivisor = horizontalIndex + 1;
            var width = spaceWidth / widthDivisor;

            if (widthDivisor > 1)
            {
                foreach (var idx in secondaryIndex.FindAll(si => si.Y == verticalIndex))
                {
                    idx.W = width;
                }
            }

            if ((i + 1) % rowsAvailable == 0)
            {
                ++columnsUsed;
            }

            secondaryIndex.Add(new LayoutLocation {X = horizontalIndex, Y = verticalIndex, W = width});
        }

        if (numInSecondary <= 0)
        {
            return locationList;
        }

        var secondaryHeight = numInSecondary > rowsAvailable
            ? remainingHeight / rowsAvailable
            : remainingHeight / numInSecondary;

        foreach (var idx in secondaryIndex)
        {
            var horizontalPosition = idx.X * idx.W;
            var verticalPosition = primaryHeightOffset + (idx.Y * secondaryHeight);
            locationList.Add(new WindowLocation(horizontalPosition, verticalPosition, idx.W, secondaryHeight, WindowState.Normal));
        }

        return locationList;
    }

    public void ShrinkPrimaryArea()
    {
        _primaryPercentOffset -= _primaryPercentIncrement;
    }

    public void ExpandPrimaryArea()
    {
        _primaryPercentOffset += _primaryPercentIncrement;
    }

    public void ResetPrimaryArea()
    {
        _primaryPercentOffset = 0;
    }

    public void IncrementNumInPrimary()
    {
        _numInPrimaryOffset++;
    }

    public void DecrementNumInPrimary()
    {
        if (GetNumInPrimary() > 1)
        {
            _numInPrimaryOffset--;
        }
    }

    private int GetNumInPrimary()
    {
        return _numInPrimary + _numInPrimaryOffset;
    }

    private class LayoutLocation
    {
        public int X { get; set; }
        public int Y { get; set; }
        public int W { get; set; }
    }
}

// A Battery Widget with multiple steps of displaying battery percentage
public class BatteryWidget : BarWidgetBase
{
    public Color LowChargeColor { get; set; } = Color.Red;
    public Color MedChargeColor { get; set; } = Color.Yellow;
    public Color HighChargeColor { get; set; } = Color.Green;
    public bool HasBatteryWarning { get; set; } = true;
    public double LowChargeThreshold { get; set; } = 0.10;
    public double MedChargeThreshold { get; set; } = 0.50;
    public int Interval { get; set; } = 5000;

    private System.Timers.Timer _timer;

    public override IBarWidgetPart[] GetParts()
    {
        PowerStatus pwr = SystemInformation.PowerStatus;
        float currentBatteryCharge = pwr.BatteryLifePercent;

        if (HasBatteryWarning)
        {
            if (currentBatteryCharge <= LowChargeThreshold)
            {
                return Parts(Part(currentBatteryCharge.ToString(" #0%"), LowChargeColor));
            }
            else if (currentBatteryCharge <= MedChargeThreshold)
            {
                return Parts(Part(currentBatteryCharge.ToString(" #0%"), MedChargeColor));
            }
            else
            {
                return Parts(Part(currentBatteryCharge.ToString(" #0%"), HighChargeColor));
            }
        }
        else
        {
            return Parts(currentBatteryCharge.ToString(" #0%"));
        }
    }

    public override void Initialize()
    {
        _timer = new System.Timers.Timer(Interval);
        _timer.Elapsed += (s, e) => MarkDirty();
        _timer.Enabled = true;
    }
}


// A Title Widget with character limit on the title
public class BetterTitleWidget : BarWidgetBase
{
    public Color MonitorHasFocusColor { get; set; } = Color.Yellow;

    public static class StringTool
    {
        public static string Truncate(string source, int length)
        {
            if (source.Length > length)
            {
                source = source.Substring(0, length);
            }
            return source;
        }
    }

    public override IBarWidgetPart[] GetParts()
    {
        var window = GetWindow();
        var isFocusedMonitor = Context.MonitorContainer.FocusedMonitor == Context.Monitor;
        var multipleMonitors = Context.MonitorContainer.NumMonitors > 1;
        var color = isFocusedMonitor && multipleMonitors ? MonitorHasFocusColor : null;

        if (window != null)
        {
            // Change the number on this line to restrict the amount of characters in the title
            return Parts(Part(StringTool.Truncate(window.Title, 30), color));
        } else
        {
            return Parts(Part("no windows", color));
        }
    }

    public override void Initialize()
    {
        Context.Workspaces.WindowAdded += RefreshAddRemove;
        Context.Workspaces.WindowRemoved += RefreshAddRemove;
        Context.Workspaces.WindowUpdated += RefreshUpdated;
        Context.Workspaces.FocusedMonitorUpdated += RefreshFocusedMonitor;
    }

    private IWindow GetWindow()
    {
        var currentWorkspace = Context.WorkspaceContainer.GetWorkspaceForMonitor(Context.Monitor);
        return currentWorkspace.FocusedWindow ??
               currentWorkspace.LastFocusedWindow ??
               currentWorkspace.ManagedWindows.FirstOrDefault();
    }

    private void RefreshAddRemove(IWindow window, IWorkspace workspace)
    {
        var currentWorkspace = Context.WorkspaceContainer.GetWorkspaceForMonitor(Context.Monitor);
        if (workspace == currentWorkspace)
        {
            MarkDirty();
        }
    }

    private void RefreshUpdated(IWindow window, IWorkspace workspace)
    {
        var currentWorkspace = Context.WorkspaceContainer.GetWorkspaceForMonitor(Context.Monitor);
        if (workspace == currentWorkspace && window == GetWindow())
        {
            MarkDirty();
        }
    }

    private void RefreshFocusedMonitor()
    {
        MarkDirty();
    }
}

// 24-hour Time Widget
public class FullTimeWidget : BarWidgetBase
{
    private System.Timers.Timer _timer;
    private int _interval;
    private string _format;

    public FullTimeWidget(int interval, string format)
    {
        _interval = interval;
        _format = format;
    }

    public FullTimeWidget() : this(200, "HH:mm:ss") { }

    public override IBarWidgetPart[] GetParts()
    {
        return Parts(DateTime.Now.ToString(_format));
    }

    public override void Initialize()
    {
        _timer = new System.Timers.Timer(_interval);
        _timer.Elapsed += (s, e) => MarkDirty();
        _timer.Enabled = true;
    }
}

Action<IConfigContext> doConfig = (context) =>
{
    /* Variables */
    var fontSize = 9;
    var barHeight = 19;
    var fontName = "Consolas";
    var background = new Color(0x0, 0x0, 0x0);

    /* Config */
    context.CanMinimizeWindows = true;

    /* Gap */
    var gap = barHeight - 8;
    var gapPlugin = context.AddGap(new GapPluginConfig() { InnerGap = gap, OuterGap = gap / 2, Delta = gap / 2 });

    /* Bar */
    context.AddBar(new BarPluginConfig()
    {
        FontSize = fontSize,
        BarHeight = barHeight,
        FontName = fontName,
        DefaultWidgetBackground = background,
        LeftWidgets = () => new IBarWidget[]
        {
            new WorkspaceWidget(){}, new TextWidget(": "), new TitleWidget(){
                IsShortTitle = true
            }        },
        RightWidgets = () => new IBarWidget[]
        {
            new BatteryWidget(),
            new TimeWidget(1000, "HH:mm:ss dd-MMM-yyyy"),
            new ActiveLayoutWidget(),
        }
    });

    // Layouts (1) [dwindle] fibonacci (2) [vertical] vertical (3) [tall] list (4) [full] maximize
    context.DefaultLayouts = () => new ILayoutEngine[] { new DwindleLayoutEngine(), new VerticalTiledEngine(), new FullLayoutEngine(), new TallLayoutEngine() };

    context.AddFocusIndicator();

    // Add "log off" menu to action menu (Alt + P)
    var actionMenu = context.AddActionMenu();

    var subMenu = actionMenu.Create();

    // Sleep
    string sleepCmd;
    sleepCmd = "/C rundll32.exe powrprof.dll,SetSuspendState 0,1,0";
    // Lock Desktop
    string lockCmd;
    lockCmd = "/C rundll32.exe user32.dll,LockWorkStation";
    // Shutdown
    string shutdownCmd;
    shutdownCmd = "/C shutdown /s /t 0";
    // Restart
    string restartCmd;
    restartCmd = "/C shutdown /r /t 0";

    subMenu.Add("sleep", () => System.Diagnostics.Process.Start("CMD.exe", sleepCmd));
    subMenu.Add("lock desktop", () => System.Diagnostics.Process.Start("CMD.exe", lockCmd));
    subMenu.Add("shutdown", () => System.Diagnostics.Process.Start("CMD.exe", shutdownCmd));
    subMenu.Add("restart", () => System.Diagnostics.Process.Start("CMD.exe", restartCmd));

    actionMenu.DefaultMenu.AddMenu("log off", subMenu);

    // Exclude Applications from being managed by workspacer (games & forced fullscreen apps)
    context.WindowRouter.AddFilter((window) => !window.Title.Contains("Snip"));

    // Set certain Applications to a specific workspace
    // context.WindowRouter.AddRoute((window) => window.Title.Contains("Spotify") ? context.WorkspaceContainer["五"] : null);
    // context.WindowRouter.AddRoute((window) => window.Title.Contains("Discord") ? context.WorkspaceContainer["四"] : null);
    // context.WindowRouter.AddRoute((window) => window.Title.Contains("Messenger") ? context.WorkspaceContainer["三"] : null);

    // Set workspaces ( 1, 2, 3, 4, 5 )
    context.WorkspaceContainer.CreateWorkspaces("1", "2", "3", "4", "5", "6", "7", "8", "9");

    // Ignore Windows
    context.WindowRouter.AddFilter((window) => !window.Title.Contains("Search"));
    context.WindowRouter.AddFilter((window) => !window.Title.Contains("Services"));
    context.WindowRouter.AddFilter((window) => !window.Title.Contains("Task Scheduler"));
    context.WindowRouter.AddFilter((window) => !window.Title.Contains("Sticky Notes"));
    context.WindowRouter.AddFilter((window) => !window.Title.Contains("Sticky Notes (2)"));
    context.WindowRouter.AddFilter((window) => !window.Title.Contains("Close sticker edit mode"));

    // Keyboard Shortcuts

    var modKey = KeyModifiers.Alt;
    IKeybindManager manager = context.Keybinds;
    manager.UnsubscribeAll();

    var workspaces = context.Workspaces;
    
    manager.Subscribe(modKey, workspacer.Keys.L, () => workspaces.SwitchToNextWorkspace());
    manager.Subscribe(modKey, workspacer.Keys.H, () => workspaces.SwitchToPreviousWorkspace());

    manager.Subscribe(modKey, workspacer.Keys.J, () => { workspaces.FocusedWorkspace.FocusNextWindow();});
    manager.Subscribe(modKey, workspacer.Keys.K, () => { workspaces.FocusedWorkspace.FocusPreviousWindow();});

    manager.Subscribe(modKey, workspacer.Keys.Oemcomma,  () => workspaces.FocusedWorkspace.ShrinkPrimaryArea(), "shrink primary area");
    manager.Subscribe(modKey, workspacer.Keys.OemPeriod, () => workspaces.FocusedWorkspace.ExpandPrimaryArea(), "expand primary area");

    manager.Subscribe(modKey, workspacer.Keys.Space, () => workspaces.FocusedWorkspace.NextLayoutEngine());
    manager.Subscribe(modKey, workspacer.Keys.Return, () => workspaces.FocusedWorkspace.SwapFocusAndPrimaryWindow(), "make current window primary" );

    manager.Subscribe(modKey, workspacer.Keys.Q, () => workspaces.FocusedWorkspace.CloseFocusedWindow());
    manager.Subscribe(modKey, workspacer.Keys.I, () => context.ToggleConsoleWindow(), "toggle debug console");
    manager.Subscribe(modKey, workspacer.Keys.C,() => context.Workspaces.FocusedWorkspace.CloseFocusedWindow(), "close focused window");
    manager.Subscribe(modKey, workspacer.Keys.Escape,() =>  context.Enabled = !context.Enabled, "toggle enable/disable");


    // manager.Subscribe(modKey, workspacer.Keys.Q, () => context.Quit());
    // manager.Subscribe(modShift, workspacer.Keys.Q, () => context.Restart());


    // string mailCmd;
    // mailCmd = "/C explorer.exe shell:appsFolder\\microsoft.windowscommunicationsapps_8wekyb3d8bbwe!microsoft.windowslive.mail";
    // string browserCmd;
    // browserCmd = "/C start chrome";
    // string browsernCmd;
    // browsernCmd = "/C start chrome -incognito";
    // string settingsCmd;
    // settingsCmd = "/C start ms-settings:";
    // context.Keybinds.Unsubscribe(mod, workspacer.Keys.Q);
    // context.Keybinds.Subscribe(mod, workspacer.Keys.Q, () => context.Workspaces.FocusedWorkspace.CloseFocusedWindow(), "close focused window");

    // Alt + F = File Explorer
    // context.Keybinds.Subscribe(mod, workspacer.Keys.F, () => System.Diagnostics.Process.Start("explorer.exe"), "open file explorer");
    // Alt + B = Chrome
    // context.Keybinds.Subscribe(mod, workspacer.Keys.B, () => System.Diagnostics.Process.Start("CMD.exe", browserCmd), "open chrome");
    // Alt + N = Chrome (Incognito)
    // context.Keybinds.Subscribe(mod, workspacer.Keys.N, () => System.Diagnostics.Process.Start("CMD.exe", browsernCmd), "open chrome (incognito)");
    // Alt + M = Windows Mail
    // context.Keybinds.Subscribe(mod, workspacer.Keys.M, () => System.Diagnostics.Process.Start("CMD.exe", mailCmd), "open windows mail");
    // Alt + Enter = Alacritty
    // context.Keybinds.Subscribe(mod, workspacer.Keys.Enter, () => System.Diagnostics.Process.Start("alacritty.exe"), "open alacritty");
    // Alt + S = Windows Settings
    // context.Keybinds.Subscribe(modKey, workspacer.Keys.S, () => System.Diagnostics.Process.Start("CMD.exe", settingsCmd), "open windows settings");
};
return doConfig;
